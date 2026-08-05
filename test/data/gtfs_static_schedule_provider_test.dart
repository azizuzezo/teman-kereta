import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teman_kereta/core/database/app_database.dart';
import 'package:teman_kereta/data/providers/gtfs_static_schedule_provider.dart';
import 'package:teman_kereta/data/providers/mock_transit_provider.dart';
import 'package:teman_kereta/domain/entities/transit_models.dart';

/// A weekday-independent reference date (matters only via its own
/// `.weekday`, computed below rather than assumed).
final _referenceDay = DateTime(2026, 3, 2);

void main() {
  late AppDatabase database;
  late GtfsStaticScheduleProvider provider;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    provider = GtfsStaticScheduleProvider(
      database: database,
      fallback: MockTransitProvider(),
    );
  });

  tearDown(() => database.close());

  Future<void> seedStops() async {
    await database.into(database.gtfsStops).insert(
      const GtfsStopsCompanion(
        id: Value('A'),
        name: Value('Stasiun A'),
        latitude: Value(-6.1),
        longitude: Value(106.8),
      ),
    );
    await database.into(database.gtfsStops).insert(
      const GtfsStopsCompanion(
        id: Value('B'),
        name: Value('Stasiun B'),
        latitude: Value(-6.2),
        longitude: Value(106.9),
      ),
    );
    await database.into(database.gtfsStops).insert(
      const GtfsStopsCompanion(
        id: Value('C'),
        name: Value('Stasiun C'),
        latitude: Value(-6.3),
        longitude: Value(107.0),
      ),
    );
  }

  Future<void> seedTrip({
    required String serviceId,
    required List<bool> weekdays,
  }) async {
    await database.into(database.gtfsRoutes).insert(
      const GtfsRoutesCompanion(
        id: Value('R1'),
        shortName: Value('Lin Utama'),
      ),
    );
    await database.into(database.gtfsTrips).insert(
      GtfsTripsCompanion(
        id: const Value('T1'),
        routeId: const Value('R1'),
        serviceId: Value(serviceId),
        headsign: const Value('Menuju C'),
      ),
    );
    await database.batch((b) {
      b.insertAll(database.gtfsStopTimes, <GtfsStopTimesCompanion>[
        const GtfsStopTimesCompanion(
          tripId: Value('T1'),
          stopId: Value('A'),
          stopSequence: Value(1),
          arrivalSeconds: Value(6 * 3600),
          departureSeconds: Value(6 * 3600),
        ),
        const GtfsStopTimesCompanion(
          tripId: Value('T1'),
          stopId: Value('B'),
          stopSequence: Value(2),
          arrivalSeconds: Value(6 * 3600 + 900),
          departureSeconds: Value(6 * 3600 + 900),
        ),
        const GtfsStopTimesCompanion(
          tripId: Value('T1'),
          stopId: Value('C'),
          stopSequence: Value(3),
          arrivalSeconds: Value(7 * 3600),
          departureSeconds: Value(7 * 3600),
        ),
      ]);
    });
    await database.into(database.gtfsCalendarEntries).insert(
      GtfsCalendarEntriesCompanion(
        serviceId: Value(serviceId),
        monday: Value(weekdays[0]),
        tuesday: Value(weekdays[1]),
        wednesday: Value(weekdays[2]),
        thursday: Value(weekdays[3]),
        friday: Value(weekdays[4]),
        saturday: Value(weekdays[5]),
        sunday: Value(weekdays[6]),
        startDate: Value(_referenceDay.subtract(const Duration(days: 30))),
        endDate: Value(_referenceDay.add(const Duration(days: 30))),
      ),
    );
  }

  List<bool> weekdaysAllTrue() => List<bool>.filled(7, true);

  List<bool> weekdaysAllFalse() => List<bool>.filled(7, false);

  test('getStations falls back to Data Demo when nothing has been imported', () async {
    final stations = await provider.getStations();
    expect(stations.map((s) => s.id), contains('BOO'));
  });

  test('getStations returns imported stops once a feed exists', () async {
    await seedStops();
    final stations = await provider.getStations();
    expect(stations.map((s) => s.id), <String>['A', 'B', 'C']);
  });

  test('getStationDepartures returns a scheduled departure on an active service day', () async {
    await seedStops();
    await seedTrip(serviceId: 'ALWAYS', weekdays: weekdaysAllTrue());

    final departures = await provider.getStationDepartures(
      'A',
      _referenceDay.add(const Duration(hours: 5, minutes: 50)),
    );

    // A daily service means the 3-day lookahead window legitimately finds
    // both today's and tomorrow's occurrence — that's correct, not a bug:
    // it's what lets the list roll over to "tomorrow's first train" once
    // today's are exhausted, instead of ever going empty.
    expect(departures, hasLength(2));
    expect(departures.first.scheduledAt, _referenceDay.add(const Duration(hours: 6)));
    expect(departures.first.destination, 'Menuju C');
    expect(departures.first.lineName, 'Lin Utama');
    expect(
      departures.last.scheduledAt,
      _referenceDay.add(const Duration(days: 1, hours: 6)),
    );
  });

  test('getStationDepartures omits a service that never runs (no active weekday)', () async {
    await seedStops();
    await seedTrip(serviceId: 'NEVER', weekdays: weekdaysAllFalse());

    final departures = await provider.getStationDepartures(
      'A',
      _referenceDay.add(const Duration(hours: 5, minutes: 50)),
    );

    expect(departures, isEmpty);
  });

  test('getStationDepartures resolves a departure that rolls past midnight', () async {
    await seedStops();
    await database.into(database.gtfsRoutes).insert(
      const GtfsRoutesCompanion(id: Value('R1'), shortName: Value('Lin Malam')),
    );
    await database.into(database.gtfsTrips).insert(
      const GtfsTripsCompanion(
        id: Value('T-night'),
        routeId: Value('R1'),
        serviceId: Value('ALWAYS'),
        headsign: Value('Menuju B'),
      ),
    );
    await database.into(database.gtfsStopTimes).insert(
      const GtfsStopTimesCompanion(
        tripId: Value('T-night'),
        stopId: Value('A'),
        stopSequence: Value(1),
        arrivalSeconds: Value(25 * 3600), // 25:00:00 -> 01:00 the next day
        departureSeconds: Value(25 * 3600),
      ),
    );
    await database.into(database.gtfsCalendarEntries).insert(
      GtfsCalendarEntriesCompanion(
        serviceId: const Value('ALWAYS'),
        monday: const Value(true),
        tuesday: const Value(true),
        wednesday: const Value(true),
        thursday: const Value(true),
        friday: const Value(true),
        saturday: const Value(true),
        sunday: const Value(true),
        startDate: Value(_referenceDay.subtract(const Duration(days: 30))),
        endDate: Value(_referenceDay.add(const Duration(days: 30))),
      ),
    );

    final departures = await provider.getStationDepartures(
      'A',
      _referenceDay.add(const Duration(days: 1, minutes: 30)),
    );

    // Same rolling-window effect as above: a daily service run through a
    // 3-day lookahead legitimately surfaces 3 future occurrences here.
    expect(departures, hasLength(3));
    expect(
      departures.first.scheduledAt,
      _referenceDay.add(const Duration(days: 1, hours: 1)),
    );
  });

  test('searchTrips finds a direct trip and resolves the full station sequence', () async {
    await seedStops();
    await seedTrip(serviceId: 'ALWAYS', weekdays: weekdaysAllTrue());

    final trips = await provider.searchTrips(
      TripSearchQuery(
        originStationId: 'A',
        destinationStationId: 'C',
        departureAt: _referenceDay.add(const Duration(hours: 5, minutes: 50)),
      ),
    );

    // Same rolling-window effect as getStationDepartures above: a daily
    // service surfaces both today's and tomorrow's run.
    expect(trips, hasLength(2));
    final trip = trips.first;
    expect(trip.departureAt, _referenceDay.add(const Duration(hours: 6)));
    expect(trip.arrivalAt, _referenceDay.add(const Duration(hours: 7)));
    expect(trip.legs.single.stationIds, <String>['A', 'B', 'C']);
    expect(trip.legs.single.mode, TransportMode.commuterRail);
  });

  test('searchTrips finds a one-transfer trip via a shared stop between two trips', () async {
    await seedStops(); // A, B, C
    await seedTrip(serviceId: 'ALWAYS', weekdays: weekdaysAllTrue()); // T1: A(6:00)->B(6:15)->C(7:00)

    // A second trip departing B after T1 arrives there, with a real
    // transfer buffer (5 min, above the 180s minimum), so A -> D has no
    // direct trip and requires exactly one transfer via B.
    await database.into(database.gtfsStops).insert(
      const GtfsStopsCompanion(
        id: Value('D'),
        name: Value('Stasiun D'),
        latitude: Value(-6.4),
        longitude: Value(107.1),
      ),
    );
    await database.into(database.gtfsRoutes).insert(
      const GtfsRoutesCompanion(id: Value('R2'), shortName: Value('Lin Kedua')),
    );
    await database.into(database.gtfsTrips).insert(
      const GtfsTripsCompanion(
        id: Value('T2'),
        routeId: Value('R2'),
        serviceId: Value('ALWAYS'),
        headsign: Value('Menuju D'),
      ),
    );
    await database.batch((b) {
      b.insertAll(database.gtfsStopTimes, <GtfsStopTimesCompanion>[
        const GtfsStopTimesCompanion(
          tripId: Value('T2'),
          stopId: Value('B'),
          stopSequence: Value(1),
          arrivalSeconds: Value(6 * 3600 + 1200), // 06:20
          departureSeconds: Value(6 * 3600 + 1200),
        ),
        const GtfsStopTimesCompanion(
          tripId: Value('T2'),
          stopId: Value('D'),
          stopSequence: Value(2),
          arrivalSeconds: Value(6 * 3600 + 2400), // 06:40
          departureSeconds: Value(6 * 3600 + 2400),
        ),
      ]);
    });

    final trips = await provider.searchTrips(
      TripSearchQuery(
        originStationId: 'A',
        destinationStationId: 'D',
        departureAt: _referenceDay.add(const Duration(hours: 5, minutes: 50)),
      ),
    );

    // Same daily-service rolling-window effect as the direct-trip test
    // above (today's + tomorrow's occurrence both qualify).
    expect(trips, hasLength(2));
    final trip = trips.first;
    expect(trip.transfers, 1);
    expect(trip.legs, hasLength(2));
    expect(trip.departureAt, _referenceDay.add(const Duration(hours: 6)));
    expect(trip.arrivalAt, _referenceDay.add(const Duration(hours: 6, minutes: 40)));
    expect(trip.legs[0].destinationName, 'Stasiun B');
    expect(trip.legs[1].originName, 'Stasiun B');
    expect(trip.legs[0].stationIds, <String>['A', 'B']);
    expect(trip.legs[1].stationIds, <String>['B', 'D']);
    expect(trip.transferBoundaries, hasLength(1));
  });

  test('searchTrips does not offer a transfer when the connecting trip departs before the buffer elapses', () async {
    await seedStops();
    await seedTrip(serviceId: 'ALWAYS', weekdays: weekdaysAllTrue()); // T1 arrives B at 06:15

    await database.into(database.gtfsStops).insert(
      const GtfsStopsCompanion(
        id: Value('D'),
        name: Value('Stasiun D'),
        latitude: Value(-6.4),
        longitude: Value(107.1),
      ),
    );
    await database.into(database.gtfsRoutes).insert(
      const GtfsRoutesCompanion(id: Value('R2'), shortName: Value('Lin Kedua')),
    );
    await database.into(database.gtfsTrips).insert(
      const GtfsTripsCompanion(
        id: Value('T2'),
        routeId: Value('R2'),
        serviceId: Value('ALWAYS'),
        headsign: Value('Menuju D'),
      ),
    );
    await database.batch((b) {
      b.insertAll(database.gtfsStopTimes, <GtfsStopTimesCompanion>[
        const GtfsStopTimesCompanion(
          tripId: Value('T2'),
          stopId: Value('B'),
          stopSequence: Value(1),
          arrivalSeconds: Value(6 * 3600 + 900 + 60), // 06:16 — only 1 min after T1
          departureSeconds: Value(6 * 3600 + 900 + 60),
        ),
        const GtfsStopTimesCompanion(
          tripId: Value('T2'),
          stopId: Value('D'),
          stopSequence: Value(2),
          arrivalSeconds: Value(6 * 3600 + 2400),
          departureSeconds: Value(6 * 3600 + 2400),
        ),
      ]);
    });

    final trips = await provider.searchTrips(
      TripSearchQuery(
        originStationId: 'A',
        destinationStationId: 'D',
        departureAt: _referenceDay.add(const Duration(hours: 5, minutes: 50)),
      ),
    );

    expect(trips, isEmpty);
  });

  test('searchTrips returns nothing when the stations are in the wrong order on the trip', () async {
    await seedStops();
    await seedTrip(serviceId: 'ALWAYS', weekdays: weekdaysAllTrue());

    final trips = await provider.searchTrips(
      TripSearchQuery(
        originStationId: 'C',
        destinationStationId: 'A',
        departureAt: _referenceDay.add(const Duration(hours: 5, minutes: 50)),
      ),
    );

    expect(trips, isEmpty);
  });
}
