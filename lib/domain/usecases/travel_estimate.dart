/// Assumptions behind every "berapa menit ke stasiun" number in the app.
///
/// These are estimates from straight-line distance, not routed directions
/// (the app has no routing engine), so the constants are explicit and the UI
/// words them as "perkiraan".
abstract final class TravelSpeeds {
  /// Average adult walking pace.
  static const double walkKmh = 4.8;

  /// Door-to-door city speed of a motorbike taxi or car in Jabodetabek
  /// traffic, including slow streets. Deliberately conservative.
  static const double vehicleKmh = 25;

  /// Real streets are longer than the straight line between two points.
  /// 1.25 is a common urban detour index; applied to both modes.
  static const double detourFactor = 1.25;

  /// Beyond this straight-line distance an estimate is not meaningful (the
  /// rider is not "near" any station, or the GPS fix is wrong).
  static const double maxEstimateMeters = 30000;

  /// Walking shorter than this is quicker than waiting for any vehicle, so
  /// the vehicle estimate is hidden.
  static const int rideWorthWalkMinutes = 8;
}

class TravelEstimate {
  const TravelEstimate({
    required this.distanceMeters,
    required this.walkMinutes,
    required this.rideMinutes,
  });

  /// Straight-line distance the estimate was computed from.
  final double distanceMeters;
  final int walkMinutes;
  final int rideMinutes;

  bool get isReliable => distanceMeters <= TravelSpeeds.maxEstimateMeters;

  bool get showRide => walkMinutes >= TravelSpeeds.rideWorthWalkMinutes;
}

TravelEstimate estimateTravel(double straightLineMeters) {
  final meters = straightLineMeters.isNaN || straightLineMeters < 0
      ? 0.0
      : straightLineMeters;
  final road = meters * TravelSpeeds.detourFactor;
  final walkPerMinute = TravelSpeeds.walkKmh * 1000 / 60;
  final ridePerMinute = TravelSpeeds.vehicleKmh * 1000 / 60;
  int atLeastOne(double minutes) {
    final rounded = minutes.ceil();
    return rounded < 1 ? 1 : rounded;
  }

  return TravelEstimate(
    distanceMeters: meters,
    walkMinutes: atLeastOne(road / walkPerMinute),
    rideMinutes: atLeastOne(road / ridePerMinute),
  );
}

/// "37 mnt", "1 j 5 mnt". Short on purpose: it sits on one line next to
/// other text and is recomputed every few seconds.
String formatMinutes(int minutes) {
  if (minutes < 60) {
    return '$minutes mnt';
  }
  final hours = minutes ~/ 60;
  final rest = minutes % 60;
  return rest == 0 ? '$hours j' : '$hours j $rest mnt';
}

/// "37 mnt jalan kaki · 5 mnt naik kendaraan", or null when the distance is
/// too large to estimate honestly.
String? formatEstimateLine(TravelEstimate estimate) {
  if (!estimate.isReliable) {
    return null;
  }
  final walk = '${formatMinutes(estimate.walkMinutes)} jalan kaki';
  if (!estimate.showRide) {
    return walk;
  }
  return '$walk · ${formatMinutes(estimate.rideMinutes)} naik kendaraan';
}

/// "450 m", "3,1 km", "48 km" (decimal comma, no decimals past 10 km).
String formatDistance(double meters) {
  if (meters < 1000) {
    return '${meters.round()} m';
  }
  final km = meters / 1000;
  if (km >= 10) {
    return '${km.round()} km';
  }
  return '${km.toStringAsFixed(1).replaceAll('.', ',')} km';
}
