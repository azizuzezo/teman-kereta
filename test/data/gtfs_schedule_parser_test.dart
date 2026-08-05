import 'package:flutter_test/flutter_test.dart';
import 'package:teman_kereta/data/providers/gtfs_schedule_parser.dart';

void main() {
  const parser = GtfsScheduleParser();

  test('parseStops reads id/name/lat/lon', () {
    final stops = parser.parseStops(
      'stop_id,stop_name,stop_lat,stop_lon\n'
      'A,Stasiun A,-6.1,106.8\n'
      'B,Stasiun B,-6.2,106.9\n',
    );

    expect(stops, hasLength(2));
    expect(stops.first.stopId, 'A');
    expect(stops.first.name, 'Stasiun A');
    expect(stops.first.latitude, -6.1);
    expect(stops.first.longitude, 106.8);
  });

  test('parseStops throws on an invalid coordinate', () {
    expect(
      () => parser.parseStops(
        'stop_id,stop_name,stop_lat,stop_lon\nA,Stasiun A,not-a-number,106.8\n',
      ),
      throwsFormatException,
    );
  });

  test('parseStops throws when a required column is missing', () {
    expect(
      () => parser.parseStops('stop_id,stop_name\nA,Stasiun A\n'),
      throwsFormatException,
    );
  });

  test('parseRoutes treats blank optional fields as null', () {
    final routes = parser.parseRoutes(
      'route_id,route_short_name,route_long_name,route_color\n'
      'R1,,Lin Utama,\n',
    );

    expect(routes.single.routeId, 'R1');
    expect(routes.single.shortName, isNull);
    expect(routes.single.longName, 'Lin Utama');
    expect(routes.single.color, isNull);
  });

  test('parseTrips reads headsign and short name', () {
    final trips = parser.parseTrips(
      'trip_id,route_id,service_id,trip_headsign,trip_short_name\n'
      'T1,R1,WEEKDAY,Menuju C,101\n',
    );

    expect(trips.single.tripId, 'T1');
    expect(trips.single.routeId, 'R1');
    expect(trips.single.serviceId, 'WEEKDAY');
    expect(trips.single.headsign, 'Menuju C');
    expect(trips.single.tripShortName, '101');
  });

  test('parseStopTimes keeps seconds past 24h for a post-midnight service', () {
    final stopTimes = parser.parseStopTimes(
      'trip_id,stop_id,stop_sequence,arrival_time,departure_time\n'
      'T1,A,1,23:50:00,23:50:00\n'
      'T1,B,2,25:10:00,25:10:00\n',
    );

    expect(stopTimes[0].departureSeconds, 23 * 3600 + 50 * 60);
    expect(stopTimes[1].arrivalSeconds, 25 * 3600 + 10 * 60);
  });

  test('parseCalendar reads weekday flags and date range', () {
    final calendar = parser.parseCalendar(
      'service_id,monday,tuesday,wednesday,thursday,friday,saturday,sunday,start_date,end_date\n'
      'WEEKDAY,1,1,1,1,1,0,0,20260101,20261231\n',
    );

    final entry = calendar.single;
    expect(entry.serviceId, 'WEEKDAY');
    expect(entry.weekdays, <bool>[true, true, true, true, true, false, false]);
    expect(entry.startDate, DateTime(2026, 1, 1));
    expect(entry.endDate, DateTime(2026, 12, 31));
  });

  test('parseCalendarDates maps exception_type 1/2 to added/removed', () {
    final exceptions = parser.parseCalendarDates(
      'service_id,date,exception_type\n'
      'WEEKDAY,20260101,2\n'
      'WEEKEND,20260103,1\n',
    );

    expect(exceptions[0].exceptionType, GtfsCalendarExceptionType.removed);
    expect(exceptions[1].exceptionType, GtfsCalendarExceptionType.added);
    expect(exceptions[1].date, DateTime(2026, 1, 3));
  });
}
