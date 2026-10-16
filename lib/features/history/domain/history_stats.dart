import '../../../core/database/app_database.dart';

/// Window a recap is computed over. Only periods that the local trip log can
/// answer honestly: the log keeps no cloud history, so there is no "tahun ini"
/// beyond what the device has recorded; [all] covers everything stored.
enum RecapPeriod {
  week('Minggu ini', 'minggu ini'),
  month('Bulan ini', 'bulan ini'),
  all('Semua', 'sejauh ini');

  const RecapPeriod(this.label, this.phrase);

  /// Segment label.
  final String label;

  /// Lower-case phrase for sentences ("... minggu ini").
  final String phrase;
}

const _weekdayNames = <int, String>{
  DateTime.monday: 'Senin',
  DateTime.tuesday: 'Selasa',
  DateTime.wednesday: 'Rabu',
  DateTime.thursday: 'Kamis',
  DateTime.friday: 'Jumat',
  DateTime.saturday: 'Sabtu',
  DateTime.sunday: 'Minggu',
};

const _monthNames = <String>[
  'Januari',
  'Februari',
  'Maret',
  'April',
  'Mei',
  'Juni',
  'Juli',
  'Agustus',
  'September',
  'Oktober',
  'November',
  'Desember',
];

const _monthShort = <String>[
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'Mei',
  'Jun',
  'Jul',
  'Agu',
  'Sep',
  'Okt',
  'Nov',
  'Des',
];

/// Full Indonesian weekday name for a `DateTime.weekday` value.
String weekdayName(int weekday) => _weekdayNames[weekday] ?? '-';

/// Full Indonesian month name for a 1-based month.
String monthName(int month) => _monthNames[month - 1];

/// Short Indonesian month name for a 1-based month.
String monthShortName(int month) => _monthShort[month - 1];

/// Local midnight of the day that contains [value].
DateTime dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

/// Monday 00:00 (local) of the week that contains [value]. Weeks run Monday to
/// Sunday, matching how the weekday chart is laid out.
DateTime startOfWeek(DateTime value) {
  final day = dateOnly(value);
  return DateTime(
    day.year,
    day.month,
    day.day - (day.weekday - DateTime.monday),
  );
}

/// The subset of [trips] whose departure falls inside [period] relative to
/// [now]. Order is preserved.
List<CompletedTrip> tripsInPeriod(
  List<CompletedTrip> trips,
  RecapPeriod period,
  DateTime now,
) {
  switch (period) {
    case RecapPeriod.all:
      return List<CompletedTrip>.of(trips);
    case RecapPeriod.week:
      final start = startOfWeek(now);
      return trips.where((trip) => !trip.departedAt.isBefore(start)).toList();
    case RecapPeriod.month:
      return trips
          .where(
            (trip) =>
                trip.departedAt.year == now.year &&
                trip.departedAt.month == now.month,
          )
          .toList();
  }
}

/// Human range for the period headline, or null when there is nothing honest
/// to say (an "all" period with no trips has no start date).
String? periodRangeLabel(
  RecapPeriod period,
  DateTime now,
  DateTime? firstTripAt,
) {
  switch (period) {
    case RecapPeriod.week:
      final start = startOfWeek(now);
      final end = DateTime(start.year, start.month, start.day + 6);
      return '${start.day} ${monthShortName(start.month)} - '
          '${end.day} ${monthShortName(end.month)} ${end.year}';
    case RecapPeriod.month:
      return '${monthName(now.month)} ${now.year}';
    case RecapPeriod.all:
      if (firstTripAt == null) {
        return null;
      }
      return 'Sejak ${firstTripAt.day} ${monthShortName(firstTripAt.month)} '
          '${firstTripAt.year}';
  }
}

/// Scheduled duration of a stored trip, or null when the stored clock ran
/// backwards (device time change) so callers never show a negative figure.
Duration? tripDuration(CompletedTrip trip) {
  final duration = trip.arrivedAt.difference(trip.departedAt);
  return duration.isNegative ? null : duration;
}

/// Trips that departed on the same calendar day.
class TripDayGroup {
  const TripDayGroup({required this.day, required this.trips});

  /// Local midnight of the day.
  final DateTime day;

  /// Newest departure first.
  final List<CompletedTrip> trips;
}

/// Groups [trips] by departure day. Days and the trips inside them are both
/// ordered newest first.
List<TripDayGroup> groupTripsByDay(List<CompletedTrip> trips) {
  final sorted = List<CompletedTrip>.of(trips)
    ..sort((a, b) => b.departedAt.compareTo(a.departedAt));
  final groups = <TripDayGroup>[];
  for (final trip in sorted) {
    final day = dateOnly(trip.departedAt);
    if (groups.isNotEmpty && groups.last.day == day) {
      groups.last.trips.add(trip);
    } else {
      groups.add(TripDayGroup(day: day, trips: <CompletedTrip>[trip]));
    }
  }
  return groups;
}

/// "Hari ini", "Kemarin", or "Senin, 12 Okt" (year appended when it differs
/// from [now]'s year).
String dayGroupLabel(DateTime day, DateTime now) {
  final today = dateOnly(now);
  final target = dateOnly(day);
  final difference = today.difference(target).inDays;
  if (difference == 0) {
    return 'Hari ini';
  }
  if (difference == 1) {
    return 'Kemarin';
  }
  final base =
      '${weekdayName(target.weekday)}, ${target.day} '
      '${monthShortName(target.month)}';
  return target.year == today.year ? base : '$base ${target.year}';
}

/// 24-hour clock, "07:05". Avoids locale initialisation so it is safe in
/// tests and before `initializeDateFormatting` has run.
String formatClock(DateTime value) =>
    '${value.hour.toString().padLeft(2, '0')}:'
    '${value.minute.toString().padLeft(2, '0')}';

/// "12 Okt 2026".
String formatShortDate(DateTime value) =>
    '${value.day} ${monthShortName(value.month)} ${value.year}';

/// Weekday (1 = Monday ... 7 = Sunday) with the most trips; ties resolve to
/// the earlier weekday so the answer is stable. Null when there are no trips.
int? busiestWeekday(Map<int, int> counts) {
  int? best;
  var bestCount = 0;
  for (var day = DateTime.monday; day <= DateTime.sunday; day++) {
    final count = counts[day] ?? 0;
    if (count > bestCount) {
      best = day;
      bestCount = count;
    }
  }
  return best;
}

/// "Rabu paling sering: 5 dari 8 perjalanan (63%)", or null with no trips.
String? weekdaySummary(Map<int, int> counts) {
  final busiest = busiestWeekday(counts);
  if (busiest == null) {
    return null;
  }
  final total = counts.values.fold<int>(0, (a, b) => a + b);
  final top = counts[busiest] ?? 0;
  final percent = ((top / total) * 100).round();
  return '${weekdayName(busiest)} paling sering: $top dari $total '
      'perjalanan ($percent%)';
}

/// Screen-reader text for the weekday chart: every day with its count.
String weekdayChartLabel(Map<int, int> counts) {
  final parts = <String>[
    for (var day = DateTime.monday; day <= DateTime.sunday; day++)
      '${weekdayName(day)} ${counts[day] ?? 0}',
  ];
  return 'Perjalanan per hari. ${parts.join(', ')}.';
}
