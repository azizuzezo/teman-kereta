import '../../core/database/app_database.dart';
import '../../domain/entities/transit_models.dart';
import '../../domain/providers/transit_providers.dart';
import 'mock_transit_provider.dart';

/// Real schedule/station data sourced from a GTFS Schedule (static) feed
/// imported via `GtfsStaticImporter`. Falls back to [_fallback] (Data Demo)
/// for any capability that has no imported data yet, so `TRANSIT_PROVIDER=
/// gtfs` never silently shows an empty app before an import has been run —
/// same "Data Demo until real data exists" posture as the offline station
/// cache in `provider_registry.dart`.
///
/// **Scope limit** (same as `SupabaseTransitProvider`): [searchTrips] finds
/// direct trips (same `trip_id`, right stop order) and single-transfer
/// trips (exactly one line change, via [_oneTransferTrips]) — still no
/// *general* multi-transfer router. See ENGINEERING.md.
class GtfsStaticScheduleProvider
    implements StationProvider, TransitScheduleProvider {
  GtfsStaticScheduleProvider({
    required this._database,
    required MockTransitProvider fallback,
  }) : _fallback = fallback;

  final AppDatabase _database;
  final MockTransitProvider _fallback;

  static const String _sourceLabel = 'Jadwal GTFS statis (impor lokal)';
  static const int _transferBufferSeconds = 180;

  Future<bool> _hasImportedData() async =>
      (await _database.gtfsStopCount()) > 0;

  @override
  Future<List<Station>> getStations() async {
    if (!await _hasImportedData()) {
      return _fallback.getStations();
    }
    final rows = await _database.allGtfsStops();
    return rows.map(_stationFromRow).toList(growable: false);
  }

  @override
  Future<Station?> getStation(String stationId) async {
    if (!await _hasImportedData()) {
      return _fallback.getStation(stationId);
    }
    final row = await _database.gtfsStopById(stationId);
    return row == null ? null : _stationFromRow(row);
  }

  @override
  Future<List<Departure>> getStationDepartures(
    String stationId,
    DateTime time,
  ) async {
    if (!await _hasImportedData()) {
      return _fallback.getStationDepartures(stationId, time);
    }

    final stopTimes = await _database.stopTimesForStation(stationId);
    if (stopTimes.isEmpty) {
      return const <Departure>[];
    }

    final calendar = await _ServiceCalendar.load(_database);
    final candidates = <Departure>[];
    for (final entry in stopTimes) {
      for (final day in _candidateServiceDays(time)) {
        if (!calendar.runsOn(entry.trip.serviceId, day)) {
          continue;
        }
        final departureAt = _resolveTimeOfDay(
          day,
          entry.stopTime.departureSeconds,
        );
        if (departureAt.isBefore(time)) {
          continue;
        }
        candidates.add(
          Departure(
            id: '${entry.trip.id}-${entry.stopTime.stopSequence}',
            stationId: stationId,
            destination:
                entry.trip.headsign ?? entry.route.longName ?? entry.route.id,
            lineName:
                entry.route.shortName ?? entry.route.longName ?? entry.route.id,
            scheduledAt: departureAt,
            expectedAt: departureAt,
            freshness: DataFreshness.estimated,
            sourceLabel: _sourceLabel,
            tripNumber: entry.trip.tripShortName,
          ),
        );
      }
    }
    candidates.sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    return candidates.take(20).toList(growable: false);
  }

  @override
  Future<List<TransitTrip>> searchTrips(TripSearchQuery query) async {
    if (!await _hasImportedData()) {
      return _fallback.searchTrips(query);
    }

    final calendar = await _ServiceCalendar.load(_database);
    final origin = await _database.gtfsStopById(query.originStationId);
    final destination = await _database.gtfsStopById(
      query.destinationStationId,
    );
    final originName = origin?.name ?? query.originStationId;
    final destinationName = destination?.name ?? query.destinationStationId;

    final trips = <TransitTrip>[
      ...await _directTrips(query, calendar, originName, destinationName),
      ...await _oneTransferTrips(query, calendar, originName, destinationName),
    ];
    trips.sort((a, b) {
      final byDeparture = a.departureAt.compareTo(b.departureAt);
      return byDeparture != 0 ? byDeparture : a.arrivalAt.compareTo(b.arrivalAt);
    });
    return trips.take(8).toList(growable: false);
  }

  Future<List<TransitTrip>> _directTrips(
    TripSearchQuery query,
    _ServiceCalendar calendar,
    String originName,
    String destinationName,
  ) async {
    final candidates = await _database.directTripCandidates(
      originStopId: query.originStationId,
      destinationStopId: query.destinationStationId,
    );
    if (candidates.isEmpty) {
      return const <TransitTrip>[];
    }

    final trips = <TransitTrip>[];
    for (final candidate in candidates) {
      for (final day in _candidateServiceDays(query.departureAt)) {
        if (!calendar.runsOn(candidate.trip.serviceId, day)) {
          continue;
        }
        final departureAt = _resolveTimeOfDay(
          day,
          candidate.origin.departureSeconds,
        );
        if (departureAt.isBefore(query.departureAt)) {
          continue;
        }
        final arrivalAt = _resolveTimeOfDay(
          day,
          candidate.destination.arrivalSeconds,
        );
        final stationIds = await _database.tripStopIdsBetween(
          candidate.trip.id,
          candidate.origin.stopSequence,
          candidate.destination.stopSequence,
        );
        final lineName =
            candidate.route.shortName ??
            candidate.route.longName ??
            candidate.route.id;
        trips.add(
          TransitTrip(
            id: '${candidate.trip.id}-${day.toIso8601String()}',
            originStationId: query.originStationId,
            destinationStationId: query.destinationStationId,
            departureAt: departureAt,
            arrivalAt: arrivalAt,
            legs: <TripLeg>[
              TripLeg(
                id: '${candidate.trip.id}-leg',
                mode: TransportMode.commuterRail,
                originName: originName,
                destinationName: destinationName,
                departureAt: departureAt,
                arrivalAt: arrivalAt,
                lineName: lineName,
                headsign: candidate.trip.headsign,
                stationIds: stationIds,
              ),
            ],
            freshness: DataFreshness.estimated,
            sourceLabel: _sourceLabel,
            updatedAt: DateTime.now(),
          ),
        );
      }
    }
    return trips;
  }

  /// Single-transfer candidates — exactly one line change, at a stop
  /// reachable directly from both the origin and the destination. Mirrors
  /// `search_one_transfer_trips` (see `AppDatabase.transferCandidatesFrom
  /// Origin`'s doc comment) but resolved against this provider's own
  /// recurring GTFS calendar (`_ServiceCalendar`) rather than concrete
  /// dated trips, since that's how this provider's schedule data is stored.
  /// Not a general multi-transfer router — same scope limit as the SQL
  /// version, see ENGINEERING.md.
  Future<List<TransitTrip>> _oneTransferTrips(
    TripSearchQuery query,
    _ServiceCalendar calendar,
    String originName,
    String destinationName,
  ) async {
    final outboundCandidates = await _database.transferCandidatesFromOrigin(
      originStopId: query.originStationId,
      destinationStopId: query.destinationStationId,
    );
    if (outboundCandidates.isEmpty) {
      return const <TransitTrip>[];
    }
    final inboundCandidates = await _database.transferCandidatesToDestination(
      originStopId: query.originStationId,
      destinationStopId: query.destinationStationId,
    );
    if (inboundCandidates.isEmpty) {
      return const <TransitTrip>[];
    }

    final inboundByTransferStop = <String, List<GtfsTransferLegCandidate>>{};
    for (final candidate in inboundCandidates) {
      inboundByTransferStop
          .putIfAbsent(candidate.boarding.stopId, () => <GtfsTransferLegCandidate>[])
          .add(candidate);
    }

    final transferStationCache = <String, GtfsStop?>{};
    Future<GtfsStop?> transferStation(String stopId) async {
      if (transferStationCache.containsKey(stopId)) {
        return transferStationCache[stopId];
      }
      final station = await _database.gtfsStopById(stopId);
      transferStationCache[stopId] = station;
      return station;
    }

    final trips = <TransitTrip>[];
    for (final outbound in outboundCandidates) {
      final matches = inboundByTransferStop[outbound.alighting.stopId];
      if (matches == null) {
        continue;
      }
      for (final inbound in matches) {
        if (inbound.trip.id == outbound.trip.id) {
          continue;
        }
        for (final day in _candidateServiceDays(query.departureAt)) {
          if (!calendar.runsOn(outbound.trip.serviceId, day) ||
              !calendar.runsOn(inbound.trip.serviceId, day)) {
            continue;
          }
          final departureAt = _resolveTimeOfDay(
            day,
            outbound.boarding.departureSeconds,
          );
          if (departureAt.isBefore(query.departureAt)) {
            continue;
          }
          final transferArrival = _resolveTimeOfDay(
            day,
            outbound.alighting.arrivalSeconds,
          );
          final transferDeparture = _resolveTimeOfDay(
            day,
            inbound.boarding.departureSeconds,
          );
          if (transferDeparture.isBefore(
            transferArrival.add(const Duration(seconds: _transferBufferSeconds)),
          )) {
            continue;
          }
          final arrivalAt = _resolveTimeOfDay(
            day,
            inbound.alighting.arrivalSeconds,
          );

          final transferStop = await transferStation(outbound.alighting.stopId);
          final transferName = transferStop?.name ?? outbound.alighting.stopId;

          final outboundStationIds = await _database.tripStopIdsBetween(
            outbound.trip.id,
            outbound.boarding.stopSequence,
            outbound.alighting.stopSequence,
          );
          final inboundStationIds = await _database.tripStopIdsBetween(
            inbound.trip.id,
            inbound.boarding.stopSequence,
            inbound.alighting.stopSequence,
          );

          trips.add(
            TransitTrip(
              id: '${outbound.trip.id}-${inbound.trip.id}-${day.toIso8601String()}',
              originStationId: query.originStationId,
              destinationStationId: query.destinationStationId,
              departureAt: departureAt,
              arrivalAt: arrivalAt,
              transfers: 1,
              legs: <TripLeg>[
                TripLeg(
                  id: '${outbound.trip.id}-leg',
                  mode: TransportMode.commuterRail,
                  originName: originName,
                  destinationName: transferName,
                  departureAt: departureAt,
                  arrivalAt: transferArrival,
                  lineName:
                      outbound.route.shortName ??
                      outbound.route.longName ??
                      outbound.route.id,
                  headsign: outbound.trip.headsign,
                  stationIds: outboundStationIds,
                  transferInstruction:
                      'Transit di $transferName ke arah '
                      '${inbound.route.shortName ?? inbound.route.longName ?? inbound.route.id}.',
                ),
                TripLeg(
                  id: '${inbound.trip.id}-leg',
                  mode: TransportMode.commuterRail,
                  originName: transferName,
                  destinationName: destinationName,
                  departureAt: transferDeparture,
                  arrivalAt: arrivalAt,
                  lineName:
                      inbound.route.shortName ??
                      inbound.route.longName ??
                      inbound.route.id,
                  headsign: inbound.trip.headsign,
                  stationIds: inboundStationIds,
                ),
              ],
              freshness: DataFreshness.estimated,
              sourceLabel: '$_sourceLabel, satu kali transit',
              updatedAt: DateTime.now(),
            ),
          );
        }
      }
    }
    return trips;
  }

  Station _stationFromRow(GtfsStop row) {
    return Station(
      id: row.id,
      code: row.id,
      name: row.name,
      latitude: row.latitude,
      longitude: row.longitude,
    );
  }

  /// Yesterday/today/tomorrow (relative to [time]'s date) — wide enough to
  /// catch a service that started yesterday and is still running past
  /// midnight (GTFS `departure_time` >= 24:00:00) as well as one whose next
  /// occurrence is tomorrow.
  List<DateTime> _candidateServiceDays(DateTime time) {
    final today = DateTime(time.year, time.month, time.day);
    return <DateTime>[
      today.subtract(const Duration(days: 1)),
      today,
      today.add(const Duration(days: 1)),
    ];
  }

  DateTime _resolveTimeOfDay(DateTime serviceDay, int secondsSinceMidnight) {
    return serviceDay.add(Duration(seconds: secondsSinceMidnight));
  }
}

class _ServiceCalendar {
  _ServiceCalendar(this._weekly, this._exceptions);

  final Map<String, GtfsCalendarEntry> _weekly;
  final Map<String, Map<DateTime, int>> _exceptions;

  static Future<_ServiceCalendar> load(AppDatabase database) async {
    final weekly = <String, GtfsCalendarEntry>{
      for (final entry in await database.allGtfsCalendar())
        entry.serviceId: entry,
    };
    final exceptions = <String, Map<DateTime, int>>{};
    for (final exception in await database.allGtfsCalendarDates()) {
      final byDate = exceptions.putIfAbsent(
        exception.serviceId,
        () => <DateTime, int>{},
      );
      byDate[exception.date] = exception.exceptionType;
    }
    return _ServiceCalendar(weekly, exceptions);
  }

  bool runsOn(String serviceId, DateTime day) {
    final normalizedDay = DateTime(day.year, day.month, day.day);
    final exceptionType = _exceptions[serviceId]?[normalizedDay];
    if (exceptionType == 1) {
      return true;
    }
    if (exceptionType == 2) {
      return false;
    }

    final calendarEntry = _weekly[serviceId];
    if (calendarEntry == null) {
      return false;
    }
    if (normalizedDay.isBefore(calendarEntry.startDate) ||
        normalizedDay.isAfter(calendarEntry.endDate)) {
      return false;
    }
    return <bool>[
      calendarEntry.monday,
      calendarEntry.tuesday,
      calendarEntry.wednesday,
      calendarEntry.thursday,
      calendarEntry.friday,
      calendarEntry.saturday,
      calendarEntry.sunday,
    ][normalizedDay.weekday - 1];
  }
}
