import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

part 'app_database.g.dart';

class CachedStations extends Table {
  TextColumn get id => text()();

  TextColumn get code => text()();

  TextColumn get name => text()();

  RealColumn get latitude => real()();

  RealColumn get longitude => real()();

  TextColumn get payloadJson => text()();

  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

class FavoriteRoutes extends Table {
  TextColumn get id => text()();

  TextColumn get originStationId => text()();

  TextColumn get destinationStationId => text()();

  TextColumn get label => text()();

  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

class ActiveTripSnapshots extends Table {
  TextColumn get id => text()();

  TextColumn get payloadJson => text()();

  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

/// A locally-kept summary of a finished trip, for the "Riwayat perjalanan"
/// page (PRD §21 page 18). This is intentionally a summary, not the full
/// `TransitTrip` graph — enough to show history and re-search a similar
/// trip, without keeping raw location traces around indefinitely.
class CompletedTrips extends Table {
  TextColumn get id => text()();

  TextColumn get originStationId => text()();

  TextColumn get originName => text()();

  TextColumn get destinationStationId => text()();

  TextColumn get destinationName => text()();

  TextColumn get lineName => text().nullable()();

  DateTimeColumn get departedAt => dateTime()();

  DateTimeColumn get arrivedAt => dateTime()();

  BoolColumn get isDemo => boolean().withDefault(const Constant(false))();

  DateTimeColumn get completedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

/// Local log of notifications TK has shown, backing "Pusat notifikasi"
/// (PRD §21 page 29). Mirrors the shape of the `notification_logs` Supabase
/// table (§27) but kept device-side since there is no signed-in sync yet.
class NotificationLogEntries extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get notificationType => text()();

  TextColumn get title => text()();

  TextColumn get body => text()();

  DateTimeColumn get sentAt => dateTime()();
}

/// Local-only "Kirim laporan" submissions (PRD §18). Never uploaded — this
/// app has no backend endpoint to receive them yet — but kept so the report
/// flow does something real instead of only validating and discarding.
class UserReports extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get category => text()();

  TextColumn get description => text()();

  DateTimeColumn get createdAt => dateTime()();

  @override
  String? get tableName => 'local_user_reports';
}

/// GTFS Schedule (static) tables imported by `GtfsStaticImporter` from a
/// user-supplied `.zip`/directory of `stops.txt`/`routes.txt`/etc. These are
/// the source of truth for `GtfsStaticScheduleProvider` — a real feed, not a
/// cache of another provider's data (unlike [CachedStations]).
class GtfsStops extends Table {
  TextColumn get id => text()();

  TextColumn get name => text()();

  RealColumn get latitude => real()();

  RealColumn get longitude => real()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

class GtfsRoutes extends Table {
  TextColumn get id => text()();

  TextColumn get shortName => text().nullable()();

  TextColumn get longName => text().nullable()();

  TextColumn get color => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

class GtfsTrips extends Table {
  TextColumn get id => text()();

  TextColumn get routeId => text()();

  TextColumn get serviceId => text()();

  TextColumn get headsign => text().nullable()();

  TextColumn get tripShortName => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

/// `arrivalSeconds`/`departureSeconds` are seconds since midnight of the
/// trip's service day and may exceed 86400 for a service that runs past
/// midnight — deliberately not wrapped to a 24h clock (see
/// `GtfsScheduleParser`'s doc comment on the same convention).
class GtfsStopTimes extends Table {
  TextColumn get tripId => text()();

  TextColumn get stopId => text()();

  IntColumn get stopSequence => integer()();

  IntColumn get arrivalSeconds => integer()();

  IntColumn get departureSeconds => integer()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{tripId, stopSequence};
}

class GtfsCalendarEntries extends Table {
  TextColumn get serviceId => text()();

  BoolColumn get monday => boolean()();

  BoolColumn get tuesday => boolean()();

  BoolColumn get wednesday => boolean()();

  BoolColumn get thursday => boolean()();

  BoolColumn get friday => boolean()();

  BoolColumn get saturday => boolean()();

  BoolColumn get sunday => boolean()();

  DateTimeColumn get startDate => dateTime()();

  DateTimeColumn get endDate => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{serviceId};
}

class GtfsCalendarDateEntries extends Table {
  TextColumn get serviceId => text()();

  DateTimeColumn get date => dateTime()();

  /// 1 = service added on this date, 2 = service removed on this date
  /// (matches the raw GTFS `exception_type` values).
  IntColumn get exceptionType => integer()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{serviceId, date};
}

@DriftDatabase(
  tables: <Type>[
    CachedStations,
    FavoriteRoutes,
    ActiveTripSnapshots,
    CompletedTrips,
    NotificationLogEntries,
    UserReports,
    GtfsStops,
    GtfsRoutes,
    GtfsTrips,
    GtfsStopTimes,
    GtfsCalendarEntries,
    GtfsCalendarDateEntries,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.createTable(gtfsStops);
        await m.createTable(gtfsRoutes);
        await m.createTable(gtfsTrips);
        await m.createTable(gtfsStopTimes);
        await m.createTable(gtfsCalendarEntries);
        await m.createTable(gtfsCalendarDateEntries);
      }
    },
  );

  Future<void> replaceStationCache(
    List<CachedStationsCompanion> stations,
  ) async {
    await transaction(() async {
      await delete(cachedStations).go();
      await batch((batch) {
        batch.insertAll(cachedStations, stations);
      });
    });
  }

  Future<List<CachedStation>> allCachedStations() => select(cachedStations).get();

  Future<DateTime?> latestStationCacheUpdate() async {
    final rows = await allCachedStations();
    if (rows.isEmpty) {
      return null;
    }
    return rows
        .map((row) => row.updatedAt)
        .reduce((a, b) => a.isAfter(b) ? a : b);
  }

  Future<void> logCompletedTrip(CompletedTripsCompanion trip) async {
    await into(completedTrips).insert(trip);
  }

  Stream<List<CompletedTrip>> watchCompletedTrips() {
    return (select(completedTrips)
          ..orderBy(<OrderingTerm Function($CompletedTripsTable)>[
            (table) =>
                OrderingTerm(expression: table.completedAt, mode: OrderingMode.desc),
          ]))
        .watch();
  }

  Future<void> clearCompletedTrips() => delete(completedTrips).go();

  Future<void> logNotification(NotificationLogEntriesCompanion entry) async {
    await into(notificationLogEntries).insert(entry);
  }

  Stream<List<NotificationLogEntry>> watchNotificationLog() {
    return (select(notificationLogEntries)
          ..orderBy(<OrderingTerm Function($NotificationLogEntriesTable)>[
            (table) =>
                OrderingTerm(expression: table.sentAt, mode: OrderingMode.desc),
          ])
          ..limit(50))
        .watch();
  }

  Future<void> clearNotificationLog() => delete(notificationLogEntries).go();

  Future<void> saveUserReport(UserReportsCompanion report) async {
    await into(userReports).insert(report);
  }

  /// Replaces the entire imported GTFS Schedule with a fresh feed. A full
  /// replace (not a merge) mirrors how GTFS static feeds are actually
  /// published — a new feed supersedes the old one rather than patching it.
  Future<void> replaceGtfsSchedule({
    required List<GtfsStopsCompanion> stops,
    required List<GtfsRoutesCompanion> routes,
    required List<GtfsTripsCompanion> trips,
    required List<GtfsStopTimesCompanion> stopTimes,
    required List<GtfsCalendarEntriesCompanion> calendar,
    required List<GtfsCalendarDateEntriesCompanion> calendarDates,
  }) async {
    await transaction(() async {
      await delete(gtfsStopTimes).go();
      await delete(gtfsCalendarDateEntries).go();
      await delete(gtfsCalendarEntries).go();
      await delete(gtfsTrips).go();
      await delete(gtfsRoutes).go();
      await delete(gtfsStops).go();
      await batch((b) {
        b.insertAll(gtfsStops, stops);
        b.insertAll(gtfsRoutes, routes);
        b.insertAll(gtfsTrips, trips);
        b.insertAll(gtfsCalendarEntries, calendar);
        b.insertAll(gtfsCalendarDateEntries, calendarDates);
        b.insertAll(gtfsStopTimes, stopTimes);
      });
    });
  }

  Future<int> gtfsStopCount() async {
    final countExpression = gtfsStops.id.count();
    final query = selectOnly(gtfsStops)..addColumns(<Expression<Object>>[countExpression]);
    final row = await query.getSingle();
    return row.read(countExpression) ?? 0;
  }

  Future<List<GtfsStop>> allGtfsStops() => select(gtfsStops).get();

  Future<GtfsStop?> gtfsStopById(String id) =>
      (select(gtfsStops)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<List<GtfsCalendarEntry>> allGtfsCalendar() =>
      select(gtfsCalendarEntries).get();

  Future<List<GtfsCalendarDateEntry>> allGtfsCalendarDates() =>
      select(gtfsCalendarDateEntries).get();

  Future<List<GtfsStopTimeWithTrip>> stopTimesForStation(String stopId) async {
    final query = select(gtfsStopTimes).join(<Join<HasResultSet, dynamic>>[
      innerJoin(gtfsTrips, gtfsTrips.id.equalsExp(gtfsStopTimes.tripId)),
      innerJoin(gtfsRoutes, gtfsRoutes.id.equalsExp(gtfsTrips.routeId)),
    ])..where(gtfsStopTimes.stopId.equals(stopId));
    final rows = await query.get();
    return rows
        .map(
          (row) => GtfsStopTimeWithTrip(
            stopTime: row.readTable(gtfsStopTimes),
            trip: row.readTable(gtfsTrips),
            route: row.readTable(gtfsRoutes),
          ),
        )
        .toList(growable: false);
  }

  /// Trip candidates that serve both stations on the SAME trip, origin
  /// before destination in stop sequence — a direct (no-transfer) match.
  /// Mirrors `search_direct_trips` in
  /// `supabase/migrations/20260805090000_transit_query_functions.sql`; keep
  /// the two in sync if the direct-trip definition ever changes.
  Future<List<GtfsDirectTripCandidate>> directTripCandidates({
    required String originStopId,
    required String destinationStopId,
  }) async {
    final origin = alias(gtfsStopTimes, 'origin_stop_time');
    final destination = alias(gtfsStopTimes, 'destination_stop_time');
    final query = select(gtfsTrips).join(<Join<HasResultSet, dynamic>>[
      innerJoin(gtfsRoutes, gtfsRoutes.id.equalsExp(gtfsTrips.routeId)),
      innerJoin(
        origin,
        origin.tripId.equalsExp(gtfsTrips.id) &
            origin.stopId.equals(originStopId),
      ),
      innerJoin(
        destination,
        destination.tripId.equalsExp(gtfsTrips.id) &
            destination.stopId.equals(destinationStopId),
      ),
    ])..where(origin.stopSequence.isSmallerThan(destination.stopSequence));
    final rows = await query.get();
    return rows
        .map(
          (row) => GtfsDirectTripCandidate(
            trip: row.readTable(gtfsTrips),
            route: row.readTable(gtfsRoutes),
            origin: row.readTable(origin),
            destination: row.readTable(destination),
          ),
        )
        .toList(growable: false);
  }

  /// Legs from the origin to some third stop reachable directly (same trip,
  /// origin before it in stop sequence) — candidate first halves of a
  /// single-transfer journey. Excludes the origin/destination themselves so
  /// a genuine direct trip isn't double-counted as a "transfer". Mirrors
  /// `search_one_transfer_trips` in
  /// `supabase/migrations/20260805180000_one_transfer_trips.sql` — keep the
  /// two in sync if the transfer-search definition ever changes.
  Future<List<GtfsTransferLegCandidate>> transferCandidatesFromOrigin({
    required String originStopId,
    required String destinationStopId,
  }) async {
    final origin = alias(gtfsStopTimes, 'origin_stop_time');
    final transfer = alias(gtfsStopTimes, 'transfer_stop_time');
    final query = select(gtfsTrips).join(<Join<HasResultSet, dynamic>>[
      innerJoin(gtfsRoutes, gtfsRoutes.id.equalsExp(gtfsTrips.routeId)),
      innerJoin(
        origin,
        origin.tripId.equalsExp(gtfsTrips.id) &
            origin.stopId.equals(originStopId),
      ),
      innerJoin(transfer, transfer.tripId.equalsExp(gtfsTrips.id)),
    ])..where(
      origin.stopSequence.isSmallerThan(transfer.stopSequence) &
          transfer.stopId.equals(originStopId).not() &
          transfer.stopId.equals(destinationStopId).not(),
    );
    final rows = await query.get();
    return rows
        .map(
          (row) => GtfsTransferLegCandidate(
            trip: row.readTable(gtfsTrips),
            route: row.readTable(gtfsRoutes),
            boarding: row.readTable(origin),
            alighting: row.readTable(transfer),
          ),
        )
        .toList(growable: false);
  }

  /// Legs from some third stop reachable directly on to the destination —
  /// candidate second halves of a single-transfer journey. See
  /// [transferCandidatesFromOrigin]'s doc comment.
  Future<List<GtfsTransferLegCandidate>> transferCandidatesToDestination({
    required String originStopId,
    required String destinationStopId,
  }) async {
    final transfer = alias(gtfsStopTimes, 'transfer_stop_time');
    final destination = alias(gtfsStopTimes, 'destination_stop_time');
    final query = select(gtfsTrips).join(<Join<HasResultSet, dynamic>>[
      innerJoin(gtfsRoutes, gtfsRoutes.id.equalsExp(gtfsTrips.routeId)),
      innerJoin(
        destination,
        destination.tripId.equalsExp(gtfsTrips.id) &
            destination.stopId.equals(destinationStopId),
      ),
      innerJoin(transfer, transfer.tripId.equalsExp(gtfsTrips.id)),
    ])..where(
      transfer.stopSequence.isSmallerThan(destination.stopSequence) &
          transfer.stopId.equals(originStopId).not() &
          transfer.stopId.equals(destinationStopId).not(),
    );
    final rows = await query.get();
    return rows
        .map(
          (row) => GtfsTransferLegCandidate(
            trip: row.readTable(gtfsTrips),
            route: row.readTable(gtfsRoutes),
            boarding: row.readTable(transfer),
            alighting: row.readTable(destination),
          ),
        )
        .toList(growable: false);
  }

  /// Ordered stop ids for one trip between two stop-sequence positions
  /// (inclusive) — builds a `TripLeg.stationIds` list for a matched trip.
  Future<List<String>> tripStopIdsBetween(
    String tripId,
    int fromSequence,
    int toSequence,
  ) async {
    final query = select(gtfsStopTimes)
      ..where(
        (t) =>
            t.tripId.equals(tripId) &
            t.stopSequence.isBetweenValues(fromSequence, toSequence),
      )
      ..orderBy(<OrderingTerm Function($GtfsStopTimesTable)>[
        (t) => OrderingTerm(expression: t.stopSequence),
      ]);
    final rows = await query.get();
    return rows.map((row) => row.stopId).toList(growable: false);
  }
}

class GtfsStopTimeWithTrip {
  const GtfsStopTimeWithTrip({
    required this.stopTime,
    required this.trip,
    required this.route,
  });

  final GtfsStopTime stopTime;
  final GtfsTrip trip;
  final GtfsRoute route;
}

class GtfsDirectTripCandidate {
  const GtfsDirectTripCandidate({
    required this.trip,
    required this.route,
    required this.origin,
    required this.destination,
  });

  final GtfsTrip trip;
  final GtfsRoute route;
  final GtfsStopTime origin;
  final GtfsStopTime destination;
}

class GtfsTransferLegCandidate {
  const GtfsTransferLegCandidate({
    required this.trip,
    required this.route,
    required this.boarding,
    required this.alighting,
  });

  final GtfsTrip trip;
  final GtfsRoute route;
  final GtfsStopTime boarding;
  final GtfsStopTime alighting;
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final documents = await getApplicationDocumentsDirectory();
    final file = File(path.join(documents.path, 'teman_kereta.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
