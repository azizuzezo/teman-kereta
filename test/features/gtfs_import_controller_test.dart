import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teman_kereta/core/database/app_database.dart';
import 'package:teman_kereta/core/database/database_provider.dart';
import 'package:teman_kereta/data/providers/gtfs_static_importer.dart';
import 'package:teman_kereta/features/settings/presentation/gtfs_import_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase database;
  late ProviderContainer container;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(database)],
    );
  });

  tearDown(() {
    container.dispose();
    database.close();
  });

  test('build() reports no imported data when the GTFS tables are empty', () async {
    final status = await container.read(gtfsImportControllerProvider.future);
    expect(status.hasImportedData, isFalse);
    expect(status.stopCount, 0);
  });

  test('build() reflects a feed that was already imported via GtfsStaticImporter', () async {
    await GtfsStaticImporter(database: database).importFiles(<String, String>{
      'stops.txt': 'stop_id,stop_name,stop_lat,stop_lon\nA,Stasiun A,-6.1,106.8\n',
      'routes.txt': 'route_id,route_short_name\nR1,Lin Utama\n',
      'trips.txt': 'trip_id,route_id,service_id\nT1,R1,WEEKDAY\n',
      'stop_times.txt':
          'trip_id,stop_id,stop_sequence,arrival_time,departure_time\nT1,A,1,06:00:00,06:00:00\n',
      'calendar.txt':
          'service_id,monday,tuesday,wednesday,thursday,friday,saturday,sunday,start_date,end_date\n'
          'WEEKDAY,1,1,1,1,1,0,0,20260101,20261231\n',
    });

    final status = await container.read(gtfsImportControllerProvider.future);
    expect(status.hasImportedData, isTrue);
    expect(status.stopCount, 1);
  });
}
