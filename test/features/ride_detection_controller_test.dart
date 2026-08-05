import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teman_kereta/core/notifications/local_notification_service.dart';
import 'package:teman_kereta/core/platform/native_trip_service.dart';
import 'package:teman_kereta/core/preferences/preferences_store.dart';
import 'package:teman_kereta/domain/entities/active_trip.dart';
import 'package:teman_kereta/domain/entities/ride_detection.dart';
import 'package:teman_kereta/features/active_trip/presentation/active_trip_controller.dart';
import 'package:teman_kereta/features/ride_detection/presentation/ride_detection_controller.dart';
import 'package:teman_kereta/features/settings/presentation/settings_controller.dart';

import '../support/fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer container;
  late FakeNativeTripService native;
  late FakeNotificationService notifications;

  setUp(() {
    native = FakeNativeTripService();
    notifications = FakeNotificationService();
    container = ProviderContainer(
      overrides: [
        preferencesStoreProvider.overrideWithValue(MemoryPreferencesStore()),
        nativeTripServiceProvider.overrideWithValue(native),
        localNotificationServiceProvider.overrideWithValue(notifications),
      ],
    );
  });

  tearDown(() => container.dispose());

  test('checkNow does nothing while the feature is disabled', () async {
    native.geofenceEvent = GeofenceEvent(
      stationIds: const ['BOO'],
      transition: GeofenceTransition.exit,
      occurredAt: DateTime.now(),
    );

    await container.read(rideDetectionControllerProvider.notifier).checkNow();

    expect(container.read(rideDetectionControllerProvider), isNull);
  });

  test(
    'a station exit + in-vehicle activity + a saved home->work route '
    'crosses the strong threshold and can start a matching trip',
    () async {
      final settings = container.read(settingsControllerProvider.notifier);
      await settings.setRideDetectionEnabled(true);
      await settings.setHomeStation('BOO');
      await settings.setWorkStation('SUD');

      final exitedAt = DateTime.now();
      native.geofenceEvent = GeofenceEvent(
        stationIds: const ['BOO'],
        transition: GeofenceTransition.exit,
        occurredAt: exitedAt,
      );
      native.activityEvent = ActivityEvent(
        type: RideActivityType.inVehicle,
        confidencePercent: 100,
        occurredAt: exitedAt,
      );

      final detection = container.read(rideDetectionControllerProvider.notifier);
      await detection.checkNow();

      final phase = container.read(rideDetectionControllerProvider);
      expect(phase, isNotNull);
      expect(phase!.state, ActiveTripState.confirmingTrip);
      final assessment = phase.assessment;
      expect(assessment, isNotNull);
      expect(assessment!.level, RideDetectionLevel.strong);
      expect(assessment.suggestedDestinationId, 'SUD');
      expect(notifications.rideDetectedAlerts, 0); // watcher owns the alert, not the controller

      await detection.confirmStart();

      // A real trip now owns the journey state, so ride detection steps aside.
      expect(container.read(rideDetectionControllerProvider), isNull);
      final activeTrip = container.read(activeTripControllerProvider);
      expect(activeTrip, isNotNull);
      expect(activeTrip!.state, ActiveTripState.onBoard);
      expect(activeTrip.trip.originStationId, 'BOO');
      expect(activeTrip.trip.destinationStationId, 'SUD');
    },
  );

  test('a station ENTER without a pending exit is a subtle nearStation phase', () async {
    final settings = container.read(settingsControllerProvider.notifier);
    await settings.setRideDetectionEnabled(true);

    native.geofenceEvent = GeofenceEvent(
      stationIds: const ['BOO'],
      transition: GeofenceTransition.enter,
      occurredAt: DateTime.now(),
    );

    final detection = container.read(rideDetectionControllerProvider.notifier);
    await detection.checkNow();

    final phase = container.read(rideDetectionControllerProvider);
    expect(phase, isNotNull);
    expect(phase!.state, ActiveTripState.nearStation);
    expect(phase.stationId, 'BOO');
    expect(phase.assessment, isNull); // never a user-visible prompt at this phase
  });

  test('the same exit event is not re-processed on a later poll', () async {
    final settings = container.read(settingsControllerProvider.notifier);
    await settings.setRideDetectionEnabled(true);
    await settings.setHomeStation('BOO');
    await settings.setWorkStation('SUD');

    final exitedAt = DateTime.now();
    native.geofenceEvent = GeofenceEvent(
      stationIds: const ['BOO'],
      transition: GeofenceTransition.exit,
      occurredAt: exitedAt,
    );
    native.activityEvent = ActivityEvent(
      type: RideActivityType.inVehicle,
      confidencePercent: 100,
      occurredAt: exitedAt,
    );

    final detection = container.read(rideDetectionControllerProvider.notifier);
    await detection.checkNow();
    detection.dismiss();
    await detection.checkNow(); // same stale event, must not resurface

    final phase = container.read(rideDetectionControllerProvider);
    expect(phase, isNotNull);
    expect(phase!.state, ActiveTripState.idle);
  });

  test('dismissForToday suppresses even a brand-new exit event today', () async {
    final settings = container.read(settingsControllerProvider.notifier);
    await settings.setRideDetectionEnabled(true);
    await settings.setHomeStation('BOO');
    await settings.setWorkStation('SUD');

    final detection = container.read(rideDetectionControllerProvider.notifier);
    native.geofenceEvent = GeofenceEvent(
      stationIds: const ['BOO'],
      transition: GeofenceTransition.exit,
      occurredAt: DateTime.now(),
    );
    native.activityEvent = ActivityEvent(
      type: RideActivityType.inVehicle,
      confidencePercent: 100,
      occurredAt: DateTime.now(),
    );
    await detection.checkNow();
    expect(
      container.read(rideDetectionControllerProvider)?.state,
      ActiveTripState.confirmingTrip,
    );

    await detection.dismissForToday();
    expect(
      container.read(rideDetectionControllerProvider)?.state,
      ActiveTripState.idle,
    );

    native.geofenceEvent = GeofenceEvent(
      stationIds: const ['BOO'],
      transition: GeofenceTransition.exit,
      occurredAt: DateTime.now().add(const Duration(minutes: 5)),
    );
    await detection.checkNow();
    // Still idle, not re-promoted to confirmingTrip while suppressed today.
    expect(
      container.read(rideDetectionControllerProvider)?.state,
      ActiveTripState.idle,
    );
  });
}
