import 'package:flutter_test/flutter_test.dart';
import 'package:teman_kereta/core/database/app_database.dart';
import 'package:teman_kereta/domain/usecases/trip_recap.dart';
import 'package:teman_kereta/features/history/domain/history_stats.dart';
import 'package:teman_kereta/features/history/presentation/share/share_data.dart';

CompletedTrip _trip(String id, DateTime departedAt, {int minutes = 40}) {
  final arrived = departedAt.add(Duration(minutes: minutes));
  return CompletedTrip(
    id: id,
    originStationId: 'DP',
    originName: 'Depok',
    destinationStationId: 'MRI',
    destinationName: 'Manggarai',
    lineName: 'Commuter Line Bogor',
    departedAt: departedAt,
    arrivedAt: arrived,
    isDemo: false,
    completedAt: arrived,
  );
}

void main() {
  group('ShareAspect', () {
    test('renders 1080x1350 and 1080x1920 at pixel ratio 3', () {
      expect(ShareAspect.portrait.size.width * 3, 1080);
      expect(ShareAspect.portrait.size.height * 3, 1350);
      expect(ShareAspect.story.size.width * 3, 1080);
      expect(ShareAspect.story.size.height * 3, 1920);
    });
  });

  group('TripShareData', () {
    test('builds from a stored trip using only stored values', () {
      final data = TripShareData.fromCompleted(
        _trip('1', DateTime(2026, 10, 15, 7)),
      );
      expect(data.originName, 'Depok');
      expect(data.destinationName, 'Manggarai');
      expect(data.duration, const Duration(minutes: 40));
      expect(data.lineName, 'Commuter Line Bogor');
      // The log stores no station count, so none is invented.
      expect(data.stationCount, isNull);
    });

    test('a backwards clock leaves the duration out instead of faking it', () {
      final data = TripShareData.fromCompleted(
        _trip('1', DateTime(2026, 10, 15, 7), minutes: -10),
      );
      expect(data.duration, isNull);
      expect(data.caption, isNot(contains('dalam')));
    });

    test('caption names the route, duration and the app', () {
      final data = TripShareData.fromCompleted(
        _trip('1', DateTime(2026, 10, 15, 7)),
      );
      expect(
        data.caption,
        'Perjalanan Depok → Manggarai selesai dalam 40 menit. '
        'Dicatat dengan Teman Kereta.',
      );
    });

    test('a station count under two is dropped', () {
      final data = TripShareData(
        originName: 'A',
        destinationName: 'B',
        date: DateTime(2026, 1, 1),
        stationCount: 1,
      );
      expect(data.visibleStationCount, isNull);
      expect(
        TripShareData(
          originName: 'A',
          destinationName: 'B',
          date: DateTime(2026, 1, 1),
          stationCount: 7,
        ).visibleStationCount,
        7,
      );
    });
  });

  group('RecapShareData', () {
    final now = DateTime(2026, 10, 15, 10);
    final recap = TripRecap.from(<CompletedTrip>[
      _trip('1', DateTime(2026, 10, 12, 7)),
      _trip('2', DateTime(2026, 10, 13, 7)),
      _trip('3', DateTime(2026, 10, 14, 7)),
      _trip('4', DateTime(2026, 10, 19, 7)),
    ], const {});

    test('carries the recap numbers unchanged', () {
      final data = RecapShareData.fromRecap(recap, RecapPeriod.week, now);
      expect(data.tripCount, 4);
      expect(data.totalTime, const Duration(minutes: 160));
      expect(data.topRouteLabel, 'Depok → Manggarai');
      expect(data.topRouteCount, 4);
      expect(data.periodLabel, 'Minggu ini');
      expect(data.rangeLabel, '12 Okt - 18 Okt 2026');
      // 12 and 19 October 2026 are both Mondays.
      expect(data.tripsByWeekday[DateTime.monday], 2);
    });

    test('caption states the period, count and time', () {
      final data = RecapShareData.fromRecap(recap, RecapPeriod.week, now);
      expect(
        data.caption,
        'Rekap perjalananku minggu ini: 4 perjalanan, 2j 40m di kereta. '
        'Dicatat dengan Teman Kereta.',
      );
    });

    test('a single route is not called a favourite', () {
      final single = TripRecap.from(<CompletedTrip>[
        _trip('1', DateTime(2026, 10, 12, 7)),
      ], const {});
      final data = RecapShareData.fromRecap(single, RecapPeriod.all, now);
      expect(data.visibleTopRoute, isNull);
    });

    test('a repeated route is shown', () {
      final data = RecapShareData.fromRecap(recap, RecapPeriod.all, now);
      expect(data.visibleTopRoute, 'Depok → Manggarai');
    });
  });
}
