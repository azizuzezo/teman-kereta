import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/transit_models.dart';
import '../../domain/providers/transit_providers.dart';

/// Backs `TRANSIT_PROVIDER=local_supabase` against the schema in
/// `supabase/migrations/`. Schedule search only resolves **direct** trips —
/// a single `trip_id` that serves both stations in the right stop order, via
/// the `search_direct_trips` SQL function (see the
/// `..._transit_query_functions.sql` migration). There is no multi-transfer
/// router; a pair of stations that only connects via a transfer returns an
/// empty result rather than a fabricated or wrong route.
///
/// **Not runtime-verified against a live Supabase instance this session** —
/// written against the documented `supabase_flutter` 2.16 API and the
/// project's own migration/seed files, but this machine's local Supabase
/// stack (`docker`) wasn't running. See ENGINEERING.md.
class SupabaseTransitProvider
    implements
        StationProvider,
        TransitScheduleProvider,
        TransitRealtimeProvider,
        PlacesProvider {
  SupabaseTransitProvider(this._client);

  final SupabaseClient _client;
  Map<String, String>? _stationCodeById;

  static const _stationColumns =
      'id, code, name, latitude, longitude, address, wheelchair_accessible, '
      'facilities, station_lines(stop_order, lines(code))';

  @override
  Future<List<Station>> getStations() async {
    final rows = await _client
        .from('stations')
        .select(_stationColumns)
        .eq('is_active', true);
    return rows.map(_stationFromRow).toList(growable: false);
  }

  @override
  Future<Station?> getStation(String stationId) async {
    final row = await _client
        .from('stations')
        .select(_stationColumns)
        .eq('code', stationId)
        .maybeSingle();
    return row == null ? null : _stationFromRow(row);
  }

  Station _stationFromRow(Map<String, dynamic> row) {
    final facilities = (row['facilities'] as Map<String, dynamic>?) ?? const {};
    final stationLines = (row['station_lines'] as List<dynamic>? ?? <dynamic>[])
        .cast<Map<String, dynamic>>()
        .toList()
      ..sort(
        (a, b) => ((a['stop_order'] as int?) ?? 0).compareTo(
          (b['stop_order'] as int?) ?? 0,
        ),
      );
    return Station(
      id: row['code'] as String,
      code: row['code'] as String,
      name: row['name'] as String,
      latitude: (row['latitude'] as num).toDouble(),
      longitude: (row['longitude'] as num).toDouble(),
      wheelchairAccessible: row['wheelchair_accessible'] as bool? ?? false,
      facilities: _facilityTags(facilities),
      lineIds: stationLines
          .map((sl) => (sl['lines'] as Map<String, dynamic>?)?['code'] as String?)
          .whereType<String>()
          .toList(growable: false),
    );
  }

  /// `stations.facilities` has carried two shapes over time: a boolean map
  /// (`{"toilet": true}`, from manual admin entry) and, since the KRL
  /// community-conversion GTFS import, a free-text label map parsed from
  /// GTFS `stop_desc` (`{"fasilitas": "Parkir, lift, toilet, ..."}` — see
  /// `parseStationDescription` in `admin/lib/gtfs/parser.ts`). Handles both
  /// rather than silently dropping the free-text case (a real gap this
  /// caused briefly: real facility data was imported but never rendered,
  /// since the old code only ever matched boolean `true` values).
  List<String> _facilityTags(Map<String, dynamic> facilities) {
    final rawList = facilities['fasilitas'];
    if (rawList is String) {
      if (rawList.contains('belum dirinci')) {
        return const <String>[];
      }
      return rawList
          .split(',')
          .map((tag) => tag.trim().replaceAll(RegExp(r'\.$'), ''))
          .where((tag) => tag.isNotEmpty)
          .toList(growable: false);
    }
    return facilities.entries
        .where((entry) => entry.value == true)
        .map((entry) => entry.key)
        .toList(growable: false);
  }

  @override
  Future<List<Departure>> getStationDepartures(
    String stationId,
    DateTime time,
  ) async {
    final rows = await _client.rpc<List<dynamic>>(
      'get_station_departures',
      params: <String, Object?>{
        'p_station_code': stationId,
        'p_from': time.toUtc().toIso8601String(),
        'p_limit': 20,
      },
    );
    return rows.cast<Map<String, dynamic>>().map((row) {
      final scheduled = DateTime.parse(row['scheduled_departure'] as String);
      return Departure(
        id: row['trip_id'] as String,
        stationId: stationId,
        destination: row['headsign'] as String,
        lineName: (row['line_name'] as String?) ?? 'Commuter Line',
        scheduledAt: scheduled,
        expectedAt: scheduled,
        freshness: DataFreshness.estimated,
        sourceLabel: 'Basis data KRL • jadwal statis',
        tripNumber: row['trip_number'] as String?,
        isDemo: row['data_source'] == 'demo',
      );
    }).toList(growable: false);
  }

  @override
  Future<List<TransitTrip>> searchTrips(TripSearchQuery query) async {
    final origin = await getStation(query.originStationId);
    final destination = await getStation(query.destinationStationId);
    final originName = origin?.name ?? query.originStationId;
    final destinationName = destination?.name ?? query.destinationStationId;

    final directRows = await _client.rpc<List<dynamic>>(
      'search_direct_trips',
      params: <String, Object?>{
        'p_origin_code': query.originStationId,
        'p_destination_code': query.destinationStationId,
        'p_from': query.departureAt.toUtc().toIso8601String(),
        'p_limit': 5,
      },
    );
    final transferRows = await _client.rpc<List<dynamic>>(
      'search_one_transfer_trips',
      params: <String, Object?>{
        'p_origin_code': query.originStationId,
        'p_destination_code': query.destinationStationId,
        'p_from': query.departureAt.toUtc().toIso8601String(),
        'p_limit': 5,
      },
    );

    final trips = <TransitTrip>[
      ...await Future.wait(
        directRows
            .cast<Map<String, dynamic>>()
            .map((row) => _directTripFromRow(row, query, originName, destinationName)),
      ),
      ...await Future.wait(
        transferRows
            .cast<Map<String, dynamic>>()
            .map((row) => _transferTripFromRow(row, query, originName, destinationName)),
      ),
    ];
    trips.sort((a, b) {
      final byDeparture = a.departureAt.compareTo(b.departureAt);
      return byDeparture != 0 ? byDeparture : a.arrivalAt.compareTo(b.arrivalAt);
    });
    return trips;
  }

  Future<List<String>> _tripStopCodes(
    String tripId,
    int fromSequence,
    int toSequence,
  ) async {
    final stopRows = await _client.rpc<List<dynamic>>(
      'get_trip_stop_codes',
      params: <String, Object?>{
        'p_trip_id': tripId,
        'p_from_sequence': fromSequence,
        'p_to_sequence': toSequence,
      },
    );
    return stopRows
        .cast<Map<String, dynamic>>()
        .map((stop) => stop['station_code'] as String)
        .toList(growable: false);
  }

  Future<TransitTrip> _directTripFromRow(
    Map<String, dynamic> row,
    TripSearchQuery query,
    String originName,
    String destinationName,
  ) async {
    final tripId = row['trip_id'] as String;
    final stationCodes = await _tripStopCodes(
      tripId,
      row['origin_sequence'] as int,
      row['destination_sequence'] as int,
    );
    final departure = DateTime.parse(row['origin_departure'] as String);
    final arrival = DateTime.parse(row['destination_arrival'] as String);

    return TransitTrip(
      id: tripId,
      originStationId: query.originStationId,
      destinationStationId: query.destinationStationId,
      departureAt: departure,
      arrivalAt: arrival,
      legs: <TripLeg>[
        TripLeg(
          id: '$tripId-rail',
          mode: TransportMode.commuterRail,
          originName: originName,
          destinationName: destinationName,
          departureAt: departure,
          arrivalAt: arrival,
          lineName: row['line_name'] as String?,
          headsign: row['headsign'] as String?,
          stationIds: stationCodes,
          externalTripId: row['external_trip_id'] as String?,
          serviceDate: DateTime.tryParse(row['service_date'] as String? ?? ''),
        ),
      ],
      freshness: DataFreshness.estimated,
      sourceLabel: 'Basis data KRL • jadwal statis, hanya perjalanan langsung',
      updatedAt: DateTime.now(),
      isDemo: row['data_source'] == 'demo',
    );
  }

  /// Single-transfer candidate from `search_one_transfer_trips` — exactly one
  /// line change, at a station reachable directly from both the origin and
  /// the destination. See that SQL function's own doc comment for why this
  /// is not a general multi-transfer router.
  Future<TransitTrip> _transferTripFromRow(
    Map<String, dynamic> row,
    TripSearchQuery query,
    String originName,
    String destinationName,
  ) async {
    final outboundTripId = row['outbound_trip_id'] as String;
    final inboundTripId = row['inbound_trip_id'] as String;
    final transferCode = row['transfer_station_code'] as String;
    final transferStation = await getStation(transferCode);
    final transferName = transferStation?.name ?? transferCode;

    final outboundStationCodes = await _tripStopCodes(
      outboundTripId,
      row['outbound_origin_sequence'] as int,
      row['outbound_transfer_sequence'] as int,
    );
    final inboundStationCodes = await _tripStopCodes(
      inboundTripId,
      row['inbound_transfer_sequence'] as int,
      row['inbound_destination_sequence'] as int,
    );

    final departure = DateTime.parse(row['outbound_origin_departure'] as String);
    final transferArrival = DateTime.parse(row['outbound_transfer_arrival'] as String);
    final transferDeparture = DateTime.parse(row['inbound_transfer_departure'] as String);
    final arrival = DateTime.parse(row['inbound_destination_arrival'] as String);
    final isDemo = row['outbound_data_source'] == 'demo' || row['inbound_data_source'] == 'demo';

    return TransitTrip(
      id: '$outboundTripId-$inboundTripId',
      originStationId: query.originStationId,
      destinationStationId: query.destinationStationId,
      departureAt: departure,
      arrivalAt: arrival,
      transfers: 1,
      legs: <TripLeg>[
        TripLeg(
          id: '$outboundTripId-rail',
          mode: TransportMode.commuterRail,
          originName: originName,
          destinationName: transferName,
          departureAt: departure,
          arrivalAt: transferArrival,
          lineName: row['outbound_line_name'] as String?,
          headsign: row['outbound_headsign'] as String?,
          stationIds: outboundStationCodes,
          transferInstruction: 'Transit di $transferName ke arah ${row['inbound_line_name']}.',
          externalTripId: row['outbound_external_trip_id'] as String?,
          serviceDate: DateTime.tryParse(row['outbound_service_date'] as String? ?? ''),
        ),
        TripLeg(
          id: '$inboundTripId-rail',
          mode: TransportMode.commuterRail,
          originName: transferName,
          destinationName: destinationName,
          departureAt: transferDeparture,
          arrivalAt: arrival,
          lineName: row['inbound_line_name'] as String?,
          headsign: row['inbound_headsign'] as String?,
          stationIds: inboundStationCodes,
          externalTripId: row['inbound_external_trip_id'] as String?,
          serviceDate: DateTime.tryParse(row['inbound_service_date'] as String? ?? ''),
        ),
      ],
      freshness: DataFreshness.estimated,
      sourceLabel: 'Basis data KRL • jadwal statis, satu kali transit',
      updatedAt: DateTime.now(),
      isDemo: isDemo,
    );
  }

  @override
  Stream<List<VehiclePosition>> watchVehiclePositions() {
    return _client
        .from('vehicle_positions')
        .stream(primaryKey: <String>['id'])
        .asyncMap((rows) async {
          final codes = await _stationCodesById();
          return rows.map((row) => _vehiclePositionFromRow(row, codes)).toList(
            growable: false,
          );
        });
  }

  VehiclePosition _vehiclePositionFromRow(
    Map<String, dynamic> row,
    Map<String, String> codes,
  ) {
    final recordedAt = DateTime.parse(row['recorded_at'] as String);
    final source = row['source'] as String;
    return VehiclePosition(
      id: row['id'] as String,
      tripId: (row['trip_id'] as String?) ?? '',
      latitude: (row['latitude'] as num).toDouble(),
      longitude: (row['longitude'] as num).toDouble(),
      recordedAt: recordedAt,
      freshness: _freshnessFromAccuracyStatus(row['accuracy_status'] as String),
      sourceLabel: 'Basis data KRL • $source',
      previousStationId: codes[row['current_station_id']],
      nextStationId: codes[row['next_station_id']],
      bearing: (row['bearing'] as num?)?.toDouble(),
      speedMetersPerSecond: (row['speed'] as num?)?.toDouble(),
      isDemo: source == 'demo',
    );
  }

  @override
  Stream<List<TripUpdate>> watchTripUpdates() {
    return _client
        .from('trip_updates')
        .stream(primaryKey: <String>['id'])
        .asyncMap((rows) async {
          final codes = await _stationCodesById();
          return rows
              .map(
                (row) => TripUpdate(
                  tripId: row['trip_id'] as String,
                  stationId:
                      codes[row['station_id']] ?? row['station_id'] as String,
                  arrivalDelaySeconds:
                      (row['arrival_delay_seconds'] as num?)?.toInt() ?? 0,
                  departureDelaySeconds:
                      (row['departure_delay_seconds'] as num?)?.toInt() ?? 0,
                  updatedAt: DateTime.parse(row['updated_at'] as String),
                ),
              )
              .toList(growable: false);
        });
  }

  @override
  Stream<List<ServiceAlert>> watchServiceAlerts() {
    return _client.from('service_alerts').stream(primaryKey: <String>['id']).map(
      (rows) => rows
          .map(
            (row) => ServiceAlert(
              id: row['id'] as String,
              title: row['title'] as String,
              description: row['description'] as String,
              // Alert severity (info/warning/severe/critical) is the closest
              // proxy this schema has for a line's operational status — there
              // is no separate "current line status" table.
              status: _statusFromSeverity(row['severity'] as String),
              updatedAt: DateTime.parse(
                (row['updated_at'] ?? row['starts_at']) as String,
              ),
              sourceLabel: 'Basis data KRL • ${row['source']}',
              lineId: row['line_id'] as String?,
              isOfficial: row['is_official'] as bool? ?? false,
              isDemo: row['source'] == 'demo',
            ),
          )
          .toList(growable: false),
    );
  }

  @override
  Future<List<NearbyPlace>> getNearbyPlaces(
    double latitude,
    double longitude,
    PlaceFilter filter,
  ) async {
    String? stationUuid;
    if (filter.stationId != null) {
      final station = await _client
          .from('stations')
          .select('id')
          .eq('code', filter.stationId!)
          .maybeSingle();
      if (station == null) {
        return const <NearbyPlace>[];
      }
      stationUuid = station['id'] as String;
    }

    final rows = await _client
        .from('nearby_places')
        .select()
        .let((query) => stationUuid == null ? query : query.eq('station_id', stationUuid))
        .let((query) => filter.category == null ? query : query.eq('category', filter.category!));

    return rows
        .cast<Map<String, dynamic>>()
        .map((row) {
          final distance = (row['distance_meters'] as num?)?.toInt() ?? 0;
          return NearbyPlace(
            id: row['id'] as String,
            stationId: filter.stationId ?? '',
            name: row['name'] as String,
            category: row['category'] as String,
            distanceMeters: distance,
            walkingMinutes: (row['walking_duration_minutes'] as num?)?.toInt() ?? 0,
            description: (row['description'] as String?) ?? '',
            sourceLabel: 'Basis data KRL • ${row['source']}',
            address: row['address'] as String?,
            isDemo: row['source'] == 'demo',
          );
        })
        .where((place) => place.distanceMeters <= filter.radiusMeters)
        .toList(growable: false);
  }

  Future<Map<String, String>> _stationCodesById() async {
    final cached = _stationCodeById;
    if (cached != null) {
      return cached;
    }
    final rows = await _client.from('stations').select('id, code');
    final map = <String, String>{
      for (final row in rows.cast<Map<String, dynamic>>())
        row['id'] as String: row['code'] as String,
    };
    _stationCodeById = map;
    return map;
  }

  static DataFreshness _freshnessFromAccuracyStatus(String status) => switch (status) {
    'real_time' => DataFreshness.realtime,
    'near_real_time' => DataFreshness.nearRealtime,
    'estimated' => DataFreshness.estimated,
    _ => DataFreshness.unavailable,
  };

  static ServiceStatus _statusFromSeverity(String severity) => switch (severity) {
    'info' => ServiceStatus.normal,
    'warning' => ServiceStatus.delayed,
    'severe' => ServiceStatus.limited,
    'critical' => ServiceStatus.disrupted,
    _ => ServiceStatus.unavailable,
  };
}

extension _Let<T> on T {
  R let<R>(R Function(T value) block) => block(this);
}
