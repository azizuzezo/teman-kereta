import 'package:archive/archive.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teman_kereta/core/database/app_database.dart';
import 'package:teman_kereta/data/providers/gtfs_static_importer.dart';

const _stopsCsv = 'stop_id,stop_name,stop_lat,stop_lon\n'
    'A,Stasiun A,-6.1,106.8\n'
    'B,Stasiun B,-6.2,106.9\n';
const _routesCsv = 'route_id,route_short_name,route_long_name,route_color\n'
    'R1,Lin Utama,Lin Utama Penuh,FF0000\n';
const _tripsCsv = 'trip_id,route_id,service_id,trip_headsign,trip_short_name\n'
    'T1,R1,WEEKDAY,Menuju B,101\n';
const _stopTimesCsv =
    'trip_id,stop_id,stop_sequence,arrival_time,departure_time\n'
    'T1,A,1,06:00:00,06:00:00\n'
    'T1,B,2,06:30:00,06:30:00\n';
const _calendarCsv =
    'service_id,monday,tuesday,wednesday,thursday,friday,saturday,sunday,start_date,end_date\n'
    'WEEKDAY,1,1,1,1,1,0,0,20260101,20261231\n';

Map<String, String> _minimalFeed() => <String, String>{
  'stops.txt': _stopsCsv,
  'routes.txt': _routesCsv,
  'trips.txt': _tripsCsv,
  'stop_times.txt': _stopTimesCsv,
  'calendar.txt': _calendarCsv,
};

void main() {
  late AppDatabase database;
  late GtfsStaticImporter importer;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    importer = GtfsStaticImporter(database: database);
  });

  tearDown(() => database.close());

  test('importFiles populates every GTFS table from a minimal feed', () async {
    final summary = await importer.importFiles(_minimalFeed());

    expect(summary.stopCount, 2);
    expect(summary.routeCount, 1);
    expect(summary.tripCount, 1);
    expect(summary.stopTimeCount, 2);
    expect(summary.serviceCount, 1);

    expect(await database.gtfsStopCount(), 2);
    final stops = await database.allGtfsStops();
    expect(stops.map((s) => s.id), containsAll(<String>['A', 'B']));

    final calendar = await database.allGtfsCalendar();
    expect(calendar.single.serviceId, 'WEEKDAY');
    expect(calendar.single.monday, isTrue);
    expect(calendar.single.saturday, isFalse);
  });

  test('importFiles throws when a required file is missing', () async {
    final feed = _minimalFeed()..remove('stop_times.txt');
    expect(() => importer.importFiles(feed), throwsFormatException);
  });

  test(
    'importFiles throws when neither calendar file is present',
    () async {
      final feed = _minimalFeed()..remove('calendar.txt');
      expect(() => importer.importFiles(feed), throwsFormatException);
    },
  );

  test('a second import fully replaces the first feed', () async {
    await importer.importFiles(_minimalFeed());
    expect(await database.gtfsStopCount(), 2);

    await importer.importFiles(<String, String>{
      'stops.txt': 'stop_id,stop_name,stop_lat,stop_lon\nC,Stasiun C,-6.3,107.0\n',
      'routes.txt': _routesCsv,
      'trips.txt': _tripsCsv,
      'stop_times.txt': 'trip_id,stop_id,stop_sequence,arrival_time,departure_time\n'
          'T1,C,1,06:00:00,06:00:00\n',
      'calendar.txt': _calendarCsv,
    });

    final stops = await database.allGtfsStops();
    expect(stops, hasLength(1));
    expect(stops.single.id, 'C');
  });

  test('importZipBytes extracts a real GTFS zip archive', () async {
    final archive = Archive();
    for (final entry in _minimalFeed().entries) {
      archive.addFile(
        ArchiveFile.string(entry.key, entry.value),
      );
    }
    final zipBytes = ZipEncoder().encode(archive);

    final summary = await importer.importZipBytes(zipBytes);

    expect(summary.stopCount, 2);
    expect(await database.gtfsStopCount(), 2);
  });
}
