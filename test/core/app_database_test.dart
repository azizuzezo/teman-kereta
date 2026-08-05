import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teman_kereta/core/database/app_database.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() => database.close());

  test('logCompletedTrip + watchCompletedTrips round-trips a trip summary', () async {
    await database.logCompletedTrip(
      CompletedTripsCompanion.insert(
        id: 'trip-1',
        originStationId: 'BOO',
        originName: 'Bogor',
        destinationStationId: 'SUD',
        destinationName: 'Sudirman',
        departedAt: DateTime.utc(2026, 1, 1, 6),
        arrivedAt: DateTime.utc(2026, 1, 1, 7),
        completedAt: DateTime.utc(2026, 1, 1, 7, 1),
      ),
    );

    final rows = await database.watchCompletedTrips().first;
    expect(rows, hasLength(1));
    expect(rows.single.originName, 'Bogor');
    expect(rows.single.destinationName, 'Sudirman');
    expect(rows.single.isDemo, isFalse);

    await database.clearCompletedTrips();
    expect(await database.watchCompletedTrips().first, isEmpty);
  });

  test('watchCompletedTrips orders newest-completed first', () async {
    await database.logCompletedTrip(
      CompletedTripsCompanion.insert(
        id: 'trip-older',
        originStationId: 'BOO',
        originName: 'Bogor',
        destinationStationId: 'SUD',
        destinationName: 'Sudirman',
        departedAt: DateTime.utc(2026, 1, 1),
        arrivedAt: DateTime.utc(2026, 1, 1, 1),
        completedAt: DateTime.utc(2026, 1, 1, 1),
      ),
    );
    await database.logCompletedTrip(
      CompletedTripsCompanion.insert(
        id: 'trip-newer',
        originStationId: 'SUD',
        originName: 'Sudirman',
        destinationStationId: 'BOO',
        destinationName: 'Bogor',
        departedAt: DateTime.utc(2026, 1, 2),
        arrivedAt: DateTime.utc(2026, 1, 2, 1),
        completedAt: DateTime.utc(2026, 1, 2, 1),
      ),
    );

    final rows = await database.watchCompletedTrips().first;
    expect(rows.map((r) => r.id), <String>['trip-newer', 'trip-older']);
  });

  test('logNotification + watchNotificationLog round-trips and clears', () async {
    await database.logNotification(
      NotificationLogEntriesCompanion.insert(
        notificationType: 'stop_alert',
        title: '3 stasiun lagi',
        body: 'Bersiap menuju Sudirman.',
        sentAt: DateTime.utc(2026, 1, 1, 8),
      ),
    );

    final rows = await database.watchNotificationLog().first;
    expect(rows, hasLength(1));
    expect(rows.single.notificationType, 'stop_alert');

    await database.clearNotificationLog();
    expect(await database.watchNotificationLog().first, isEmpty);
  });

  test('saveUserReport persists a local report row', () async {
    await database.saveUserReport(
      UserReportsCompanion.insert(
        category: 'Masalah jadwal',
        description: 'Jadwal demo tidak sesuai urutan stasiun.',
        createdAt: DateTime.utc(2026, 1, 1),
      ),
    );

    final rows = await database.select(database.userReports).get();
    expect(rows, hasLength(1));
    expect(rows.single.category, 'Masalah jadwal');
  });

  test('replaceStationCache replaces the previous cache wholesale', () async {
    await database.replaceStationCache(<CachedStationsCompanion>[
      CachedStationsCompanion.insert(
        id: 'BOO',
        code: 'BOO',
        name: 'Bogor',
        latitude: -6.595,
        longitude: 106.7906,
        payloadJson: '{}',
        updatedAt: DateTime.utc(2026, 1, 1),
      ),
    ]);
    expect(await database.allCachedStations(), hasLength(1));

    await database.replaceStationCache(<CachedStationsCompanion>[
      CachedStationsCompanion.insert(
        id: 'SUD',
        code: 'SUD',
        name: 'Sudirman',
        latitude: -6.2028,
        longitude: 106.823,
        payloadJson: '{}',
        updatedAt: DateTime.utc(2026, 1, 2),
      ),
    ]);
    final rows = await database.allCachedStations();
    expect(rows, hasLength(1));
    expect(rows.single.id, 'SUD');
    final latest = await database.latestStationCacheUpdate();
    expect(latest?.toUtc(), DateTime.utc(2026, 1, 2));
  });
}
