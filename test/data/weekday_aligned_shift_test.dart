import 'package:flutter_test/flutter_test.dart';
import 'package:teman_kereta/data/providers/supabase_transit_provider.dart';

void main() {
  // The imported feed covers Fri 2026-08-07 .. Thu 2026-08-13: one of each weekday.
  final start = DateTime(2026, 8, 7);
  final end = DateTime(2026, 8, 13);

  test('a date inside the window needs no shift', () {
    expect(
      weekdayAlignedShift(DateTime(2026, 8, 10, 6, 30), start, end),
      Duration.zero,
    );
  });

  test('a later Friday lands on the Friday inside the window', () {
    final friday = DateTime(2026, 10, 16, 6, 30);
    final shift = weekdayAlignedShift(friday, start, end)!;
    expect(shift.inDays % 7, 0);
    final shifted = friday.subtract(shift);
    expect(shifted.weekday, DateTime.friday);
    expect(shifted.year, 2026);
    expect(shifted.month, 8);
    expect(shifted.day, 7);
  });

  test('every weekday maps to the same weekday inside the window', () {
    for (var offset = 0; offset < 14; offset += 1) {
      final day = DateTime(2026, 10, 12 + offset, 12);
      final shift = weekdayAlignedShift(day, start, end)!;
      final shifted = day.subtract(shift);
      expect(shifted.weekday, day.weekday, reason: '$day');
      expect(shifted.isBefore(DateTime(2026, 8, 7)), isFalse);
      expect(shifted.isAfter(DateTime(2026, 8, 13, 23, 59)), isFalse);
    }
  });

  test('a date before the window is moved forward by whole weeks', () {
    final day = DateTime(2026, 7, 31, 9);
    final shift = weekdayAlignedShift(day, start, end)!;
    expect(shift.isNegative, isTrue);
    expect(day.subtract(shift).day, 7);
  });

  test('a window shorter than a week cannot cover every weekday', () {
    expect(
      weekdayAlignedShift(
        DateTime(2026, 10, 16),
        DateTime(2026, 8, 7),
        DateTime(2026, 8, 10),
      ),
      isNull,
    );
  });
}
