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

@DriftDatabase(
  tables: <Type>[
    CachedStations,
    FavoriteRoutes,
    ActiveTripSnapshots,
    CompletedTrips,
    NotificationLogEntries,
    UserReports,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      // Schema 2 added GTFS Schedule tables; schema 3 drops them again now
      // that the mobile-side GTFS provider has been removed.
      if (from < 3) {
        await m.database.customStatement('DROP TABLE IF EXISTS gtfs_stops');
        await m.database.customStatement('DROP TABLE IF EXISTS gtfs_routes');
        await m.database.customStatement('DROP TABLE IF EXISTS gtfs_trips');
        await m.database.customStatement(
          'DROP TABLE IF EXISTS gtfs_stop_times',
        );
        await m.database.customStatement(
          'DROP TABLE IF EXISTS gtfs_calendar_entries',
        );
        await m.database.customStatement(
          'DROP TABLE IF EXISTS gtfs_calendar_date_entries',
        );
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
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final documents = await getApplicationDocumentsDirectory();
    final file = File(path.join(documents.path, 'teman_kereta.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
