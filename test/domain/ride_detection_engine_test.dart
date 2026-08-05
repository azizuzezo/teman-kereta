import 'package:flutter_test/flutter_test.dart';
import 'package:teman_kereta/domain/entities/ride_detection.dart';
import 'package:teman_kereta/domain/usecases/ride_detection_engine.dart';

void main() {
  const engine = RideDetectionEngine();
  final exitedAt = DateTime.utc(2026, 1, 1, 7);

  RideDetectionSignals signals({
    ActivityEvent? activity,
    bool hasNearbyScheduledDeparture = false,
    String? matchingSavedDestinationId,
    String? subsequentStationId,
  }) {
    return RideDetectionSignals(
      exitedStationId: 'BOO',
      exitedAt: exitedAt,
      latestActivity: activity,
      hasNearbyScheduledDeparture: hasNearbyScheduledDeparture,
      matchingSavedDestinationId: matchingSavedDestinationId,
      subsequentStationId: subsequentStationId,
    );
  }

  test('no signals at all stays below the ask threshold', () {
    final assessment = engine.assess(signals());
    expect(assessment.level, RideDetectionLevel.none);
    expect(assessment.score, 0);
  });

  test('contradicting activity (on foot) pulls the score down, never negative', () {
    final assessment = engine.assess(
      signals(
        activity: ActivityEvent(
          type: RideActivityType.onFoot,
          confidencePercent: 90,
          occurredAt: exitedAt,
        ),
      ),
    );
    expect(assessment.level, RideDetectionLevel.none);
    expect(assessment.score, 0); // clamped, not negative
  });

  test('in-vehicle alone is a real signal but not enough on its own to ask', () {
    final assessment = engine.assess(
      signals(
        activity: ActivityEvent(
          type: RideActivityType.inVehicle,
          confidencePercent: 100,
          occurredAt: exitedAt,
        ),
      ),
    );
    expect(assessment.score, 45);
    expect(assessment.level, RideDetectionLevel.none);
  });

  test('in-vehicle plus a nearby scheduled departure crosses into the soft "ask" tier', () {
    final assessment = engine.assess(
      signals(
        activity: ActivityEvent(
          type: RideActivityType.inVehicle,
          confidencePercent: 100,
          occurredAt: exitedAt,
        ),
        hasNearbyScheduledDeparture: true,
      ),
    );
    expect(assessment.score, 70);
    expect(assessment.level, RideDetectionLevel.soft);
    expect(assessment.suggestedDestinationId, isNull);
  });

  test(
    'in-vehicle + schedule match + saved route crosses the strong threshold '
    'and carries the suggested destination through',
    () {
      final assessment = engine.assess(
        signals(
          activity: ActivityEvent(
            type: RideActivityType.inVehicle,
            confidencePercent: 100,
            occurredAt: exitedAt,
          ),
          hasNearbyScheduledDeparture: true,
          matchingSavedDestinationId: 'SUD',
        ),
      );
      expect(assessment.score, 90);
      expect(assessment.level, RideDetectionLevel.strong);
      expect(assessment.suggestedDestinationId, 'SUD');
      expect(assessment.reasons, isNotEmpty);
    },
  );

  test('a confirmed subsequent station is enough on its own to reach the soft tier', () {
    final assessment = engine.assess(signals(subsequentStationId: 'CLT'));
    expect(assessment.score, 30);
    expect(assessment.level, RideDetectionLevel.none);
  });

  test('schedule match plus sequential station together cross the soft threshold', () {
    final assessment = engine.assess(
      signals(hasNearbyScheduledDeparture: true, subsequentStationId: 'CLT'),
    );
    expect(assessment.score, 55);
    expect(assessment.level, RideDetectionLevel.soft);
  });

  test('score never exceeds 100 even when every bonus stacks', () {
    final assessment = engine.assess(
      signals(
        activity: ActivityEvent(
          type: RideActivityType.inVehicle,
          confidencePercent: 100,
          occurredAt: exitedAt,
        ),
        hasNearbyScheduledDeparture: true,
        matchingSavedDestinationId: 'SUD',
        subsequentStationId: 'CLT',
      ),
    );
    expect(assessment.score, 100);
    expect(assessment.level, RideDetectionLevel.strong);
  });
}
