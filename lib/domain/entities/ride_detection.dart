import 'active_trip.dart';

/// Coarse activity classification reported by Android Activity Recognition.
/// Only the states relevant to boarding detection are modeled; anything else
/// reported by the platform collapses to [unknown] rather than being guessed.
enum RideActivityType { inVehicle, onFoot, still, unknown }

class ActivityEvent {
  const ActivityEvent({
    required this.type,
    required this.confidencePercent,
    required this.occurredAt,
  });

  final RideActivityType type;
  final int confidencePercent;
  final DateTime occurredAt;
}

enum GeofenceTransition { enter, exit, dwell, unknown }

class GeofenceEvent {
  const GeofenceEvent({
    required this.stationIds,
    required this.transition,
    required this.occurredAt,
  });

  final List<String> stationIds;
  final GeofenceTransition transition;
  final DateTime occurredAt;
}

/// Inputs the confidence engine combines into a single [RideDetectionAssessment].
/// Every field here must come from a signal the app already has honest access
/// to (geofence transitions, Activity Recognition, published schedules, the
/// user's own saved routes) — never a value the app has to guess or fabricate.
class RideDetectionSignals {
  const RideDetectionSignals({
    required this.exitedStationId,
    required this.exitedAt,
    this.latestActivity,
    this.hasNearbyScheduledDeparture = false,
    this.matchingSavedDestinationId,
    this.subsequentStationId,
  });

  final String exitedStationId;
  final DateTime exitedAt;
  final ActivityEvent? latestActivity;

  /// Whether a published departure from [exitedStationId] falls close to
  /// [exitedAt] — i.e. the exit is plausibly timed with an actual train.
  final bool hasNearbyScheduledDeparture;

  /// A destination station id from the user's favorite route or home/work
  /// stations, when [exitedStationId] matches that route's origin.
  final String? matchingSavedDestinationId;

  /// A later geofence ENTER at a different, plausible-next station — the
  /// strongest signal, since it confirms the user is actually moving along a
  /// rail corridor rather than just having wandered out of one station's
  /// radius.
  final String? subsequentStationId;
}

enum RideDetectionLevel {
  /// Below the "ask" threshold — say nothing (PRD: <50).
  none,

  /// Ask a soft confirmation question (PRD: 50-79).
  soft,

  /// Propose a specific matched trip (PRD: >=80).
  strong,
}

class RideDetectionAssessment {
  const RideDetectionAssessment({
    required this.score,
    required this.level,
    required this.stationId,
    required this.exitedAt,
    required this.reasons,
    this.suggestedDestinationId,
  });

  final int score;
  final RideDetectionLevel level;
  final String stationId;
  final DateTime exitedAt;
  final List<String> reasons;
  final String? suggestedDestinationId;
}

/// The pre-boarding portion of PRD §30's single Active Trip state machine
/// (`idle` → `nearStation` → `atStation` → `possibleBoarding` →
/// `confirmingTrip`), reusing [ActiveTripState] rather than a parallel enum
/// since the PRD describes one continuous state machine, not two. Only
/// [ActiveTripState.confirmingTrip] carries a non-null [assessment] — that's
/// the point at which the app is allowed to actually prompt the user
/// (PRD §9: below score 50, stay silent even if internally tracking a phase).
class RideDetectionPhase {
  const RideDetectionPhase({
    required this.state,
    this.stationId,
    this.assessment,
  });

  final ActiveTripState state;
  final String? stationId;
  final RideDetectionAssessment? assessment;
}
