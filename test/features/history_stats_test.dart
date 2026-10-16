import 'package:flutter_test/flutter_test.dart';
import 'package:teman_kereta/core/database/app_database.dart';
import 'package:teman_kereta/features/history/domain/history_stats.dart';

CompletedTrip _trip(
  String id,
  DateTime departedAt, {
  Duration duration = const Duration(minutes: 30),
  String origin = 'Depok',
  String destination = 'Manggarai',
}) {
  final arrived = departedAt.add(duration);
  return CompletedTrip(
    id: id,
    originStationId: 'o-$origin',
    originName: origin,
    destinationStationId: 'd-$destination',
    destinationName: destination,
    departedAt: departedAt,
    arrivedAt: arrived,
    isDemo: false,
    completedAt: arrived,
  );
}

void main() {
  // Thursday 15 October 2026, 10:00.
  final now = DateTime(2026, 10, 15, 10);

  group('startOfWeek', () {
    test('returns the Monday 00:00 of the same week', () {
      expect(startOfWeek(now), DateTime(2026, 10, 12));
      expect(startOfWeek(DateTime(2026, 10, 12, 0, 1)), DateTime(2026, 10, 12));
    });

    test('a Sunday still belongs to the week that started the Monday before',
        () {
      expect(startOfWeek(DateTime(2026, 10, 18, 23, 59)), DateTime(2026, 10, 12));
    });
  });

  group('tripsInPeriod', () {
    final trips = <CompletedTrip>[
      _trip('today', DateTime(2026, 10, 15, 7)),
      _trip('monday', DateTime(2026, 10, 12, 7)),
      _trip('lastSunday', DateTime(2026, 10, 11, 22)),
      _trip('earlyOct', DateTime(2026, 10, 1, 7)),
      _trip('september', DateTime(2026, 9, 30, 7)),
    ];

    test('week keeps only trips since this Monday', () {
      final ids = tripsInPeriod(trips, RecapPeriod.week, now).map((t) => t.id);
      expect(ids, <String>['today', 'monday']);
    });

    test('month keeps only trips in the current calendar month', () {
      final ids = tripsInPeriod(trips, RecapPeriod.month, now).map((t) => t.id);
      expect(ids, <String>['today', 'monday', 'lastSunday', 'earlyOct']);
    });

    test('all keeps everything', () {
      expect(tripsInPeriod(trips, RecapPeriod.all, now), hasLength(5));
    });

    test('the same month number in a different year is not this month', () {
      final other = <CompletedTrip>[_trip('last-year', DateTime(2025, 10, 15))];
      expect(tripsInPeriod(other, RecapPeriod.month, now), isEmpty);
    });
  });

  group('tripDuration', () {
    test('returns the arrival minus departure', () {
      expect(
        tripDuration(_trip('a', DateTime(2026, 10, 1, 7))),
        const Duration(minutes: 30),
      );
    });

    test('is null when the clock ran backwards', () {
      expect(
        tripDuration(
          _trip('a', DateTime(2026, 10, 1, 7), duration: const Duration(minutes: -5)),
        ),
        isNull,
      );
    });
  });

  group('groupTripsByDay', () {
    test('groups by departure day, newest day and newest trip first', () {
      final groups = groupTripsByDay(<CompletedTrip>[
        _trip('a', DateTime(2026, 10, 14, 7)),
        _trip('b', DateTime(2026, 10, 15, 7)),
        _trip('c', DateTime(2026, 10, 15, 18)),
        _trip('d', DateTime(2026, 9, 2, 7)),
      ]);
      expect(groups.map((g) => g.day), <DateTime>[
        DateTime(2026, 10, 15),
        DateTime(2026, 10, 14),
        DateTime(2026, 9, 2),
      ]);
      expect(groups.first.trips.map((t) => t.id), <String>['c', 'b']);
    });

    test('an empty history has no groups', () {
      expect(groupTripsByDay(const <CompletedTrip>[]), isEmpty);
    });
  });

  group('dayGroupLabel', () {
    test('names today and yesterday', () {
      expect(dayGroupLabel(DateTime(2026, 10, 15), now), 'Hari ini');
      expect(dayGroupLabel(DateTime(2026, 10, 14), now), 'Kemarin');
    });

    test('writes weekday, day and month, adding the year only when it differs',
        () {
      expect(dayGroupLabel(DateTime(2026, 10, 12), now), 'Senin, 12 Okt');
      expect(dayGroupLabel(DateTime(2025, 12, 31), now), 'Rabu, 31 Des 2025');
    });
  });

  group('formatClock', () {
    test('pads hours and minutes', () {
      expect(formatClock(DateTime(2026, 1, 1, 7, 5)), '07:05');
      expect(formatClock(DateTime(2026, 1, 1, 18, 40)), '18:40');
    });
  });

  group('busiestWeekday', () {
    test('picks the weekday with most trips', () {
      expect(busiestWeekday(<int, int>{1: 2, 3: 5, 5: 1}), DateTime.wednesday);
    });

    test('ties resolve to the earlier weekday', () {
      expect(busiestWeekday(<int, int>{4: 2, 2: 2}), DateTime.tuesday);
    });

    test('no trips means no busiest day', () {
      expect(busiestWeekday(const <int, int>{}), isNull);
    });
  });

  group('periodRangeLabel', () {
    test('week spans Monday to Sunday', () {
      expect(periodRangeLabel(RecapPeriod.week, now, null), '12 Okt - 18 Okt 2026');
    });

    test('week crossing a month boundary names both months', () {
      expect(
        periodRangeLabel(RecapPeriod.week, DateTime(2026, 10, 29), null),
        '26 Okt - 1 Nov 2026',
      );
    });

    test('month names the month and year', () {
      expect(periodRangeLabel(RecapPeriod.month, now, null), 'Oktober 2026');
    });

    test('all starts at the first trip, or is null with no trips', () {
      expect(
        periodRangeLabel(RecapPeriod.all, now, DateTime(2026, 3, 2, 7)),
        'Sejak 2 Mar 2026',
      );
      expect(periodRangeLabel(RecapPeriod.all, now, null), isNull);
    });
  });

  group('weekdaySummary', () {
    test('states the busiest day with its share of all trips', () {
      expect(
        weekdaySummary(<int, int>{1: 2, 3: 5, 5: 1}),
        'Rabu paling sering: 5 dari 8 perjalanan (63%)',
      );
    });

    test('is null without trips', () {
      expect(weekdaySummary(const <int, int>{}), isNull);
    });
  });

  group('weekdayChartLabel', () {
    test('lists every weekday so the chart reads without colour', () {
      expect(
        weekdayChartLabel(<int, int>{1: 2, 3: 1}),
        'Perjalanan per hari. Senin 2, Selasa 0, Rabu 1, Kamis 0, Jumat 0, '
        'Sabtu 0, Minggu 0.',
      );
    });
  });
}
