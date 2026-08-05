import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:drift/drift.dart' show Value;

import '../../core/database/app_database.dart';
import 'gtfs_schedule_parser.dart';

/// Imports a GTFS Schedule (static) feed into the local Drift database, so
/// `GtfsStaticScheduleProvider` can answer schedule/station queries from a
/// real feed instead of Data Demo. This is intentionally decoupled from
/// where the feed bytes come from — call [importFiles] directly if the
/// caller already has the individual `.txt` file contents, or
/// [importZipBytes] if it has a raw GTFS `.zip`.
///
/// Required files: `stops.txt`, `routes.txt`, `trips.txt`, `stop_times.txt`,
/// `calendar.txt`. `calendar_dates.txt` is optional (many feeds only use
/// service-date exceptions, or only the weekly calendar — both are valid
/// GTFS, so this tolerates either being absent, but at least one of the two
/// must be present or no service would ever be considered active).
class GtfsStaticImporter {
  GtfsStaticImporter({
    required this._database,
    GtfsScheduleParser parser = const GtfsScheduleParser(),
  }) : _parser = parser;

  final AppDatabase _database;
  final GtfsScheduleParser _parser;

  static const List<String> requiredFiles = <String>[
    'stops.txt',
    'routes.txt',
    'trips.txt',
    'stop_times.txt',
  ];

  /// Extracts a raw GTFS `.zip` into filename -> UTF-8 text content, then
  /// delegates to [importFiles].
  Future<GtfsImportSummary> importZipBytes(List<int> zipBytes) async {
    final archive = ZipDecoder().decodeBytes(zipBytes);
    final files = <String, String>{};
    for (final file in archive.files) {
      if (!file.isFile) {
        continue;
      }
      final name = file.name.split('/').last;
      files[name] = utf8.decode(file.content);
    }
    return importFiles(files);
  }

  /// [files] is keyed by the bare GTFS filename (e.g. `'stops.txt'`), not a
  /// full path — matches what [importZipBytes] extracts.
  Future<GtfsImportSummary> importFiles(Map<String, String> files) async {
    final missing = requiredFiles.where((name) => !files.containsKey(name));
    if (missing.isNotEmpty) {
      throw FormatException(
        'Berkas GTFS wajib tidak ada: ${missing.join(', ')}.',
      );
    }
    if (!files.containsKey('calendar.txt') &&
        !files.containsKey('calendar_dates.txt')) {
      throw const FormatException(
        'Feed GTFS harus memiliki calendar.txt dan/atau calendar_dates.txt.',
      );
    }

    final stops = _parser.parseStops(files['stops.txt']!);
    final routes = _parser.parseRoutes(files['routes.txt']!);
    final trips = _parser.parseTrips(files['trips.txt']!);
    final stopTimes = _parser.parseStopTimes(files['stop_times.txt']!);
    final calendar = files.containsKey('calendar.txt')
        ? _parser.parseCalendar(files['calendar.txt']!)
        : const <GtfsCalendarRecord>[];
    final calendarDates = files.containsKey('calendar_dates.txt')
        ? _parser.parseCalendarDates(files['calendar_dates.txt']!)
        : const <GtfsCalendarDateRecord>[];

    await _database.replaceGtfsSchedule(
      stops: stops
          .map(
            (s) => GtfsStopsCompanion.insert(
              id: s.stopId,
              name: s.name,
              latitude: s.latitude,
              longitude: s.longitude,
            ),
          )
          .toList(growable: false),
      routes: routes
          .map(
            (r) => GtfsRoutesCompanion.insert(
              id: r.routeId,
              shortName: Value(r.shortName),
              longName: Value(r.longName),
              color: Value(r.color),
            ),
          )
          .toList(growable: false),
      trips: trips
          .map(
            (t) => GtfsTripsCompanion.insert(
              id: t.tripId,
              routeId: t.routeId,
              serviceId: t.serviceId,
              headsign: Value(t.headsign),
              tripShortName: Value(t.tripShortName),
            ),
          )
          .toList(growable: false),
      stopTimes: stopTimes
          .map(
            (st) => GtfsStopTimesCompanion.insert(
              tripId: st.tripId,
              stopId: st.stopId,
              stopSequence: st.stopSequence,
              arrivalSeconds: st.arrivalSeconds,
              departureSeconds: st.departureSeconds,
            ),
          )
          .toList(growable: false),
      calendar: calendar
          .map(
            (c) => GtfsCalendarEntriesCompanion.insert(
              serviceId: c.serviceId,
              monday: c.weekdays[0],
              tuesday: c.weekdays[1],
              wednesday: c.weekdays[2],
              thursday: c.weekdays[3],
              friday: c.weekdays[4],
              saturday: c.weekdays[5],
              sunday: c.weekdays[6],
              startDate: c.startDate,
              endDate: c.endDate,
            ),
          )
          .toList(growable: false),
      calendarDates: calendarDates
          .map(
            (c) => GtfsCalendarDateEntriesCompanion.insert(
              serviceId: c.serviceId,
              date: c.date,
              exceptionType: c.exceptionType == GtfsCalendarExceptionType.added
                  ? 1
                  : 2,
            ),
          )
          .toList(growable: false),
    );

    return GtfsImportSummary(
      stopCount: stops.length,
      routeCount: routes.length,
      tripCount: trips.length,
      stopTimeCount: stopTimes.length,
      serviceCount: calendar.length,
    );
  }
}

class GtfsImportSummary {
  const GtfsImportSummary({
    required this.stopCount,
    required this.routeCount,
    required this.tripCount,
    required this.stopTimeCount,
    required this.serviceCount,
  });

  final int stopCount;
  final int routeCount;
  final int tripCount;
  final int stopTimeCount;
  final int serviceCount;
}
