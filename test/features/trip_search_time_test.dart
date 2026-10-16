import 'package:flutter_test/flutter_test.dart';
import 'package:teman_kereta/features/schedule/presentation/departure_countdown.dart';
import 'package:teman_kereta/features/schedule/presentation/trip_search_controller.dart';

void main() {
  group('formatCountdown', () {
    test('says "Sekarang" under a minute and for past times', () {
      expect(formatCountdown(const Duration(seconds: 30)), 'Sekarang');
      expect(formatCountdown(const Duration(seconds: -5)), 'Sekarang');
    });

    test('uses minutes under an hour', () {
      expect(formatCountdown(const Duration(minutes: 1)), '1 mnt');
      expect(formatCountdown(const Duration(minutes: 59, seconds: 59)), '59 mnt');
    });

    test('uses hours and minutes from an hour up', () {
      expect(formatCountdown(const Duration(minutes: 60)), '1 j');
      expect(formatCountdown(const Duration(minutes: 65)), '1 j 5 mnt');
    });
  });

  group('resolveDepartureTime', () {
    final now = DateTime(2026, 10, 15, 8, 30);

    test('keeps a later time today', () {
      expect(resolveDepartureTime(now, 17, 45), DateTime(2026, 10, 15, 17, 45));
    });

    test('moves a time that already passed to tomorrow', () {
      expect(resolveDepartureTime(now, 5, 10), DateTime(2026, 10, 16, 5, 10));
    });

    test('treats the current minute as now, not tomorrow', () {
      expect(resolveDepartureTime(now, 8, 30), DateTime(2026, 10, 15, 8, 30));
    });

    test('rolls over month end', () {
      expect(
        resolveDepartureTime(DateTime(2026, 10, 31, 23, 0), 6, 0),
        DateTime(2026, 11, 1, 6, 0),
      );
    });
  });
}
