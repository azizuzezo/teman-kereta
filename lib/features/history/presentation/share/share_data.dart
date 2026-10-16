import 'dart:ui' show Size;

import '../../../../core/database/app_database.dart';
import '../../../../core/utils/geo.dart';
import '../../../../domain/usecases/trip_recap.dart';
import '../../domain/history_stats.dart';

/// Output shapes of a share card. The logical size times the renderer's pixel
/// ratio of 3 gives the exported PNG: 1080x1350 and 1080x1920.
enum ShareAspect {
  portrait('4:5', Size(360, 450)),
  story('9:16', Size(360, 640));

  const ShareAspect(this.label, this.size);

  final String label;

  /// Logical size the card is laid out at.
  final Size size;

  bool get isStory => this == ShareAspect.story;
}

const _appSuffix = 'Dicatat dengan Teman Kereta.';

/// Real values behind the "Perjalanan selesai" card. Every field except the
/// two station names is optional; the card omits a block whose value is null.
class TripShareData {
  const TripShareData({
    required this.originName,
    required this.destinationName,
    required this.date,
    this.duration,
    this.stationCount,
    this.lineName,
  });

  /// From a row of the local trip log. The log stores no station count, so it
  /// stays null here rather than being estimated.
  factory TripShareData.fromCompleted(CompletedTrip trip) {
    return TripShareData(
      originName: trip.originName,
      destinationName: trip.destinationName,
      date: trip.departedAt,
      duration: tripDuration(trip),
      lineName: trip.lineName,
    );
  }

  final String originName;
  final String destinationName;
  final DateTime date;
  final Duration? duration;
  final int? stationCount;
  final String? lineName;

  /// Station count worth printing: a trip between two stations passes at
  /// least two, anything lower is missing data.
  int? get visibleStationCount {
    final count = stationCount;
    return count != null && count >= 2 ? count : null;
  }

  String get caption {
    final d = duration;
    final time = d == null ? '' : ' dalam ${formatDuration(d)}';
    return 'Perjalanan $originName → $destinationName selesai$time. '
        '$_appSuffix';
  }
}

/// Real values behind the "Rekap perjalanan" card.
class RecapShareData {
  const RecapShareData({
    required this.periodLabel,
    required this.periodPhrase,
    required this.tripCount,
    required this.totalTime,
    required this.tripsByWeekday,
    this.rangeLabel,
    this.topRouteLabel,
    this.topRouteCount,
  });

  factory RecapShareData.fromRecap(
    TripRecap recap,
    RecapPeriod period,
    DateTime now,
  ) {
    return RecapShareData(
      periodLabel: period.label,
      periodPhrase: period.phrase,
      rangeLabel: periodRangeLabel(period, now, recap.firstTripAt),
      tripCount: recap.tripCount,
      totalTime: recap.totalRideTime,
      topRouteLabel: recap.topRoute?.label,
      topRouteCount: recap.topRoute?.count,
      tripsByWeekday: recap.tripsByWeekday,
    );
  }

  final String periodLabel;

  /// Lower-case phrase for sentences, e.g. "minggu ini".
  final String periodPhrase;
  final String? rangeLabel;
  final int tripCount;
  final Duration totalTime;
  final String? topRouteLabel;
  final int? topRouteCount;

  /// Trip count per `DateTime.weekday`; absent days mean zero.
  final Map<int, int> tripsByWeekday;

  /// A "favourite" route needs repetition; one trip is not a pattern.
  String? get visibleTopRoute {
    final count = topRouteCount ?? 0;
    return count >= 2 ? topRouteLabel : null;
  }

  /// Total time is dropped when it is zero (every stored clock was invalid).
  Duration? get visibleTotalTime =>
      totalTime > Duration.zero ? totalTime : null;

  String get caption {
    final time = visibleTotalTime;
    final timePart = time == null ? '' : ', ${formatDuration(time)} di kereta';
    return 'Rekap perjalananku $periodPhrase: $tripCount perjalanan'
        '$timePart. $_appSuffix';
  }
}
