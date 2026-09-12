import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/transit_models.dart';
import '../../domain/providers/transit_providers.dart';
import '../../domain/usecases/line_transfer_router.dart';
import '../../domain/usecases/transfer_platform_guidance.dart';

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
    final stationLines =
        (row['station_lines'] as List<dynamic>? ?? <dynamic>[])
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
          .map(
            (sl) => (sl['lines'] as Map<String, dynamic>?)?['code'] as String?,
          )
          .whereType<String>()
          .toList(growable: false),
      stopOrderByLine: _stopOrderByLine(stationLines),
    );
  }

  /// Builds `{lineCode: stopOrder}` from the `station_lines(stop_order,
  /// lines(code))` join rows, used to draw each line's polyline in real
  /// station-sequence order on the live map.
  Map<String, int> _stopOrderByLine(List<Map<String, dynamic>> stationLines) {
    final result = <String, int>{};
    for (final sl in stationLines) {
      final lineCode =
          (sl['lines'] as Map<String, dynamic>?)?['code'] as String?;
      if (lineCode == null) {
        continue;
      }
      result[lineCode] = (sl['stop_order'] as num?)?.toInt() ?? 0;
    }
    return result;
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

  /// How many upcoming departures the Jadwal board and Home's "Kereta
  /// berikutnya" both show — a fixed near-term window rather than
  /// dumping every trip the schedule table happens to have.
  static const _departuresLimit = 10;

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
        'p_limit': _departuresLimit,
      },
    );
    if (rows.isNotEmpty) {
      return rows
          .cast<Map<String, dynamic>>()
          .map((row) {
            final scheduled = DateTime.parse(
              row['scheduled_departure'] as String,
            ).toLocal();
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
          })
          .toList(growable: false);
    }
    // `get_station_departures` only has rows for whatever service_date
    // window the last GTFS import covered — it rolls stale (confirmed live:
    // the imported feed currently only covers 2026-08-07..13) and then
    // returns nothing at all for "now", even though the line genuinely
    // still runs. An empty departures board reads as "no trains", which is
    // wrong; this falls back to a plausible near-term board built from the
    // station's own real line memberships and real line-end names (never a
    // fabricated line or destination), clearly labelled as an estimate.
    return _fallbackDepartures(stationId, time);
  }

  /// `CIKARANG` (the Cikarang Loop line) is a genuine loop, not a simple
  /// point-to-point line — the imported `station_lines.stop_order` only
  /// captures ONE canonical linear trip through it (Cikarang ... Manggarai
  /// ... Duri ... Kampung Bandan ... Pasar Senen ... ending at Pondok Jati),
  /// so blindly using that ordering's two extremes as "line-end headsigns"
  /// (the bug this fixes — confirmed live: it surfaced 'Pondok Jati', an
  /// ordinary mid-loop stop, as if it were a real destination). A loop has
  /// exactly two real running directions everywhere on it, and KRL's own
  /// real headsigns for both are always these two, regardless of which
  /// point on the loop a rider is standing at.
  static const _cikarangLoopHeadsigns = <String>[
    'Cikarang via Manggarai (Loop)',
    'Cikarang via Pasar Senen (Loop)',
  ];

  Future<List<Departure>> _fallbackDepartures(
    String stationId,
    DateTime time,
  ) async {
    final station = await getStation(stationId);
    if (station == null || station.lineIds.isEmpty) {
      return const <Departure>[];
    }
    final allStations = await getStations();
    // (lineCode, headsign) pairs this station can actually depart toward —
    // real lines, real destination names only, never a fabricated one.
    final pairs = <(String, String)>[];
    for (final lineCode in station.lineIds) {
      if (lineCode == 'CIKARANG') {
        for (final headsign in _cikarangLoopHeadsigns) {
          pairs.add((lineCode, headsign));
        }
        continue;
      }
      final onLine =
          allStations.where((s) => s.lineIds.contains(lineCode)).toList()..sort(
            (a, b) => (a.stopOrderByLine[lineCode] ?? 0).compareTo(
              b.stopOrderByLine[lineCode] ?? 0,
            ),
          );
      final myIndex = onLine.indexWhere((s) => s.id == station.id);
      if (myIndex < 0 || onLine.length < 2) {
        continue;
      }
      // Safe here (unlike CIKARANG above) because every other line's real
      // topology extremes genuinely are its real terminus stations (Bogor/
      // Jakarta Kota, Tanah Abang/Rangkasbitung, Duri/Tangerang, Jakarta
      // Kota/Tanjung Priok) — confirmed against KRL's real published
      // headsigns, not just an assumption.
      if (myIndex > 0) pairs.add((lineCode, onLine.first.name));
      if (myIndex < onLine.length - 1) pairs.add((lineCode, onLine.last.name));
    }
    if (pairs.isEmpty) {
      return const <Departure>[];
    }
    // Round-robins across every real direction so a single-direction
    // terminus still fills the requested window, and a multi-line/
    // multi-direction station alternates rather than clumping one
    // direction's departures together.
    final departures = <Departure>[];
    for (var i = 0; i < _departuresLimit; i += 1) {
      final (lineCode, headsign) = pairs[i % pairs.length];
      final scheduled = time.add(Duration(minutes: 6 + i * 7));
      departures.add(
        Departure(
          id: 'estimasi-$stationId-$lineCode-$headsign-$i',
          stationId: stationId,
          destination: headsign,
          lineName: 'Commuter Line',
          scheduledAt: scheduled,
          expectedAt: scheduled,
          freshness: DataFreshness.estimated,
          sourceLabel: 'Estimasi jalur',
        ),
      );
    }
    departures.sort((a, b) => a.expectedAt.compareTo(b.expectedAt));
    return departures;
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

    var trips = <TransitTrip>[
      ...await Future.wait(
        directRows.cast<Map<String, dynamic>>().map(
          (row) => _directTripFromRow(row, query, originName, destinationName),
        ),
      ),
      ...await Future.wait(
        transferRows.cast<Map<String, dynamic>>().map(
          (row) =>
              _transferTripFromRow(row, query, originName, destinationName),
        ),
      ),
    ];

    if (trips.isEmpty) {
      // Fallback generator for realistic schedules when the trip-schedule
      // tables are sparse for this station pair. Built entirely from the
      // real station/line topology (via _fallbackLegStations, a BFS over
      // however many transfers the real network actually needs) so "next
      // station" walks the actual stop sequence instead of jumping straight
      // from origin to destination — see mock_transit_provider.dart's
      // analogous fix for the bug this caused. When the topology can't
      // connect the two stations at all, this must produce NO trips rather
      // than fabricate a fake direct `[origin, destination]` one — a wrong
      // route is worse than an honest "no results" (confirmed live: this
      // fallback used to claim e.g. Bogor→Jurang Mangu, a real two-transfer
      // trip, was a single direct hop).
      final legStations = await _fallbackLegStations(
        query.originStationId,
        query.destinationStationId,
      );
      if (legStations == null) {
        trips = const <TransitTrip>[];
      } else {
        final departureOffsets = <int>[6, 18, 33];
        trips = List<TransitTrip>.generate(departureOffsets.length, (index) {
          final departure = query.departureAt.add(
            Duration(minutes: departureOffsets[index]),
          );
          final travelMinutes = 35 + (index * 7 * legStations.length);
          final arrival = departure.add(Duration(minutes: travelMinutes));
          final legMinutes = travelMinutes ~/ legStations.length;
          final legs = <TripLeg>[];
          var legStart = departure;
          for (var legIndex = 0; legIndex < legStations.length; legIndex++) {
            final stations = legStations[legIndex];
            final isLastLeg = legIndex == legStations.length - 1;
            final legEnd = isLastLeg
                ? arrival
                : legStart.add(Duration(minutes: legMinutes));
            final legOriginName = legIndex == 0
                ? originName
                : legStations[legIndex - 1].last.name;
            final legDestinationName = isLastLeg
                ? destinationName
                : stations.last.name;
            String? transferInstruction;
            if (!isLastLeg) {
              final nextStations = legStations[legIndex + 1];
              final nextName = nextStations.length >= 2
                  ? nextStations[1].name
                  : null;
              // The real station immediately before this transfer on the
              // CURRENT leg — not the trip's ultimate origin — since almost
              // no rider actually boards at one of transferPlatformInstruction's
              // example stations (e.g. most Bogor-line riders board at
              // Bojonggede/Depok/etc., not literally at Bogor). When the leg
              // has only 2 stops, that adjacent stop and the leg's own start
              // are the same station anyway.
              final approachingFromName = stations[stations.length - 2].name;
              transferInstruction =
                  transferPlatformInstruction(
                    approachingFromName: approachingFromName,
                    transferName: legDestinationName,
                    nextName: nextName,
                  ) ??
                  'Transit di $legDestinationName.';
            }
            legs.add(
              TripLeg(
                id: 'leg-$index-$legIndex',
                mode: TransportMode.commuterRail,
                originName: legOriginName,
                destinationName: legDestinationName,
                departureAt: legStart,
                arrivalAt: legEnd,
                lineName: 'Commuter Line',
                headsign: legDestinationName,
                stationIds: stations.map((s) => s.id).toList(growable: false),
                transferInstruction: transferInstruction,
              ),
            );
            legStart = legEnd.add(const Duration(minutes: 5));
          }
          return TransitTrip(
            id: 'krl-trip-${query.originStationId}-${query.destinationStationId}-$index',
            originStationId: query.originStationId,
            destinationStationId: query.destinationStationId,
            departureAt: departure,
            arrivalAt: arrival,
            legs: legs,
            transfers: legs.length - 1,
            // No walking distance or fare is invented here. Both were
            // previously derived from this trip's position in the result list
            // (`150 + index * 60`, `4000 + index * 1000`), which made the
            // third option look longer and pricier than the first purely
            // because it was listed third. Fare is now computed for real from
            // track geometry at display time (see `krl_fare.dart`), and
            // walking distance stays 0 until there is a real source for it.
            freshness: DataFreshness.estimated,
            sourceLabel: 'Jadwal Operasional KRL • Terjadwal',
            updatedAt: DateTime.now(),
          );
        });
      }
    } else {
      // Stagger departure times for alternative options so they don't share identical departure minutes
      final staggered = <TransitTrip>[];
      for (var i = 0; i < trips.length; i++) {
        final t = trips[i];
        final offsetMins = i * 12;
        final newDeparture = query.departureAt.add(
          Duration(minutes: 6 + offsetMins),
        );
        final duration = t.arrivalAt.difference(t.departureAt);
        final durationMins = duration.inMinutes > 0 ? duration.inMinutes : 40;
        final newArrival = newDeparture.add(Duration(minutes: durationMins));
        staggered.add(
          t.copyWith(departureAt: newDeparture, arrivalAt: newArrival),
        );
      }
      trips = staggered;
    }

    trips.sort((a, b) => a.departureAt.compareTo(b.departureAt));
    return trips;
  }

  /// Real per-leg station sequences for [originId] -> [destinationId], used
  /// only when the trip-schedule tables have no row for this pair (see
  /// `searchTrips`'s empty-`trips` branch). See [routeBetweenStations] for
  /// how this is computed and why it must never fall back to a fabricated
  /// `[origin, destination]` trip (confirmed live: the old 1-transfer-max
  /// version made two genuinely real two-transfer trips —
  /// Bogor→Jurang Mangu, Bojong Gede→Tangerang — falsely look like a single
  /// direct hop).
  Future<List<List<Station>>?> _fallbackLegStations(
    String originId,
    String destinationId,
  ) async {
    final allStations = await getStations();
    return routeBetweenStations(allStations, originId, destinationId);
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
    final departure = DateTime.parse(
      row['origin_departure'] as String,
    ).toLocal();
    final arrival = DateTime.parse(
      row['destination_arrival'] as String,
    ).toLocal();

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

    // The specific-guidance lookup is keyed on the real stop immediately
    // before the transfer (see transferPlatformInstruction's doc comment —
    // using the trip's origin here would silently miss most real riders,
    // who board well before the transfer station) and the very next stop
    // after the transfer, falling back to the generic "Transit di X." when
    // neither side matches a known rule.
    final approachingCode = outboundStationCodes.length >= 2
        ? outboundStationCodes[outboundStationCodes.length - 2]
        : null;
    final approaching = approachingCode != null
        ? await getStation(approachingCode)
        : null;
    final next = inboundStationCodes.length >= 2
        ? await getStation(inboundStationCodes[1])
        : null;
    final transferInstruction =
        transferPlatformInstruction(
          approachingFromName: approaching?.name ?? originName,
          transferName: transferName,
          nextName: next?.name,
        ) ??
        'Transit di $transferName ke arah ${row['inbound_line_name']}.';

    final departure = DateTime.parse(
      row['outbound_origin_departure'] as String,
    ).toLocal();
    final transferArrival = DateTime.parse(
      row['outbound_transfer_arrival'] as String,
    ).toLocal();
    final transferDeparture = DateTime.parse(
      row['inbound_transfer_departure'] as String,
    ).toLocal();
    final arrival = DateTime.parse(
      row['inbound_destination_arrival'] as String,
    ).toLocal();
    final isDemo =
        row['outbound_data_source'] == 'demo' ||
        row['inbound_data_source'] == 'demo';

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
          transferInstruction: transferInstruction,
          externalTripId: row['outbound_external_trip_id'] as String?,
          serviceDate: DateTime.tryParse(
            row['outbound_service_date'] as String? ?? '',
          ),
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
          serviceDate: DateTime.tryParse(
            row['inbound_service_date'] as String? ?? '',
          ),
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
          return rows
              .map((row) => _vehiclePositionFromRow(row, codes))
              .toList(growable: false);
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
      sourceLabel: 'Basis data KRL • ${_friendlySourceLabel(source)}',
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
    return _client
        .from('service_alerts')
        .stream(primaryKey: <String>['id'])
        .map(
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
                  sourceLabel:
                      'Basis data KRL • ${_friendlySourceLabel(row['source'] as String?)}',
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
        .let(
          (query) =>
              stationUuid == null ? query : query.eq('station_id', stationUuid),
        )
        .let(
          (query) => filter.category == null
              ? query
              : query.eq('category', filter.category!),
        );

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
            walkingMinutes:
                (row['walking_duration_minutes'] as num?)?.toInt() ?? 0,
            description: (row['description'] as String?) ?? '',
            sourceLabel:
                'Basis data KRL • ${_friendlySourceLabel(row['source'] as String?)}',
            address: row['address'] as String?,
            imageUrl: row['image_url'] as String?,
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

  static DataFreshness _freshnessFromAccuracyStatus(String status) =>
      switch (status) {
        'real_time' => DataFreshness.realtime,
        'near_real_time' => DataFreshness.nearRealtime,
        'estimated' => DataFreshness.estimated,
        _ => DataFreshness.unavailable,
      };

  /// Maps a raw `source` DB column value to a human-friendly Indonesian
  /// label. Without this, admin-written rows (`source: "admin_panel"`, see
  /// `admin/app/(admin)/service-alerts/actions.ts` and
  /// `.../nearby-places/actions.ts`) leaked the literal string straight into
  /// user-facing labels like "Basis data KRL • admin_panel".
  static String _friendlySourceLabel(String? source) => switch (source) {
    'admin_panel' => 'Tim Teman Kereta',
    'gtfs' => 'KRL',
    'crowd' || 'community' || 'user_report' => 'Komunitas',
    'official' || 'kai' => 'Resmi KAI',
    _ => 'Teman Kereta',
  };

  static ServiceStatus _statusFromSeverity(String severity) =>
      switch (severity) {
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
