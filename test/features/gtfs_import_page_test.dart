import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teman_kereta/core/database/app_database.dart';
import 'package:teman_kereta/core/database/database_provider.dart';
import 'package:teman_kereta/data/providers/gtfs_static_importer.dart';
import 'package:teman_kereta/features/settings/presentation/gtfs_import_controller.dart';
import 'package:teman_kereta/features/settings/presentation/gtfs_import_page.dart';

class _ThrowingGtfsImportController extends GtfsImportController {
  @override
  Future<GtfsImportStatus> build() async {
    throw StateError('gagal membaca berkas');
  }
}

void main() {
  testWidgets('shows the empty state and an enabled pick-file button before any import', (
    tester,
  ) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(database)],
        child: const MaterialApp(home: GtfsImportPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Belum ada jadwal GTFS statis yang diimpor.'), findsOneWidget);
    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNotNull);
  });

  testWidgets('shows the stored stop count once a feed has already been imported', (
    tester,
  ) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    await GtfsStaticImporter(database: database).importFiles(<String, String>{
      'stops.txt': 'stop_id,stop_name,stop_lat,stop_lon\nA,Stasiun A,-6.1,106.8\n',
      'routes.txt': 'route_id\nR1\n',
      'trips.txt': 'trip_id,route_id,service_id\nT1,R1,WEEKDAY\n',
      'stop_times.txt':
          'trip_id,stop_id,stop_sequence,arrival_time,departure_time\nT1,A,1,06:00:00,06:00:00\n',
      'calendar.txt':
          'service_id,monday,tuesday,wednesday,thursday,friday,saturday,sunday,start_date,end_date\n'
          'WEEKDAY,1,1,1,1,1,0,0,20260101,20261231\n',
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(database)],
        child: const MaterialApp(home: GtfsImportPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('1 stasiun GTFS statis tersimpan.'), findsOneWidget);
    expect(find.text('Belum ada jadwal GTFS statis yang diimpor.'), findsNothing);
  });

  testWidgets('shows an error message when the controller fails to load', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          gtfsImportControllerProvider.overrideWith(_ThrowingGtfsImportController.new),
        ],
        child: const MaterialApp(home: GtfsImportPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Impor gagal'), findsOneWidget);
  });
}
