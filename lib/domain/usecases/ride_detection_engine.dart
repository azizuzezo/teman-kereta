import '../entities/ride_detection.dart';

/// Scores how likely it is that the user just boarded a train after leaving
/// a station's geofence, per PRD §9. This is a pure function over signals
/// the app can honestly observe — it never invents certainty it doesn't
/// have, which is why the result is a graded confidence score rather than a
/// yes/no answer, and why the two lowest confidence tiers stay silent or ask
/// rather than assert a boarding as fact.
class RideDetectionEngine {
  const RideDetectionEngine({
    this.inVehicleBonus = 45,
    this.contradictingActivityPenalty = 30,
    this.scheduleMatchBonus = 25,
    this.savedRouteMatchBonus = 20,
    this.sequentialStationBonus = 30,
    this.softThreshold = 50,
    this.strongThreshold = 80,
  });

  final int inVehicleBonus;
  final int contradictingActivityPenalty;
  final int scheduleMatchBonus;
  final int savedRouteMatchBonus;
  final int sequentialStationBonus;
  final int softThreshold;
  final int strongThreshold;

  RideDetectionAssessment assess(RideDetectionSignals signals) {
    var score = 0;
    final reasons = <String>[];

    switch (signals.latestActivity?.type) {
      case RideActivityType.inVehicle:
        score += inVehicleBonus;
        reasons.add('Sensor gerak mendeteksi berada di kendaraan.');
      case RideActivityType.onFoot:
      case RideActivityType.still:
        score -= contradictingActivityPenalty;
        reasons.add('Sensor gerak mendeteksi masih berjalan kaki atau diam.');
      case RideActivityType.unknown:
      case null:
        break;
    }

    if (signals.hasNearbyScheduledDeparture) {
      score += scheduleMatchBonus;
      reasons.add('Ada jadwal keberangkatan di sekitar waktu ini.');
    }

    if (signals.matchingSavedDestinationId != null) {
      score += savedRouteMatchBonus;
      reasons.add('Cocok dengan rute favorit dari stasiun ini.');
    }

    if (signals.subsequentStationId != null) {
      score += sequentialStationBonus;
      reasons.add('Urutan stasiun berikutnya di jalur ini terdeteksi.');
    }

    final clamped = score.clamp(0, 100);
    final level = switch (clamped) {
      final s when s >= strongThreshold => RideDetectionLevel.strong,
      final s when s >= softThreshold => RideDetectionLevel.soft,
      _ => RideDetectionLevel.none,
    };

    return RideDetectionAssessment(
      score: clamped,
      level: level,
      stationId: signals.exitedStationId,
      exitedAt: signals.exitedAt,
      reasons: reasons,
      suggestedDestinationId: signals.matchingSavedDestinationId,
    );
  }
}
