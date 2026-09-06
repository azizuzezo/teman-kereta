import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:teman_kereta/core/notifications/local_notification_service.dart';
import 'package:teman_kereta/core/platform/native_trip_service.dart';
import 'package:teman_kereta/core/preferences/preferences_store.dart';
import 'package:teman_kereta/data/providers/provider_registry.dart';
import 'package:teman_kereta/domain/entities/active_trip.dart';
import 'package:teman_kereta/domain/entities/ride_detection.dart';
import 'package:teman_kereta/features/active_trip/presentation/active_trip_controller.dart';
import 'package:teman_kereta/features/ride_detection/presentation/ride_detection_controller.dart';
import 'package:teman_kereta/features/settings/presentation/settings_controller.dart';

import '../support/fakes.dart';

// BOO (Bogor) coordinates, matching demo_data.dart — used to simulate the
// rider's GPS position relative to their saved home station.
const _booLat = -6.5950;
const _booLng = 106.7906;

// Far enough from BOO to clear the exit radius (`_nearRadiusMeters * 1.4`
// in ride_detection_controller.dart) — roughly 1.1km north.
const _farFromBooLat = -6.585;
const _farFromBooLng = 106.7906;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer container;
  late FakeNativeTripService native;
  late FakeNotificationService notifications;
  late FakeGeolocatorPlatform geolocator;

  setUp(() {
    native = FakeNativeTripService();
    notifications = FakeNotificationService();
    geolocator = FakeGeolocatorPlatform();
    GeolocatorPlatform.instance = geolocator;
    container = ProviderContainer(
      overrides: [
        preferencesStoreProvider.overrideWithValue(MemoryPreferencesStore()),
        nativeTripServiceProvider.overrideWithValue(native),
        localNotificationServiceProvider.overrideWithValue(notifications),
        // Real-time-GPS ride detection needs station coordinates and
        // published departures — route both through the deterministic mock
        // provider instead of the app's real default (Supabase-backed),
        // which isn't initialized in a unit-test process.
        stationProvider.overrideWith((ref) => ref.watch(mockTransitProvider)),
        transitScheduleProvider.overrideWith((ref) => ref.watch(mockTransitProvider)),
      ],
    );
  });

  tearDown(() => container.dispose());

  test('checkNow does nothing while the feature is disabled', () async {
    geolocator.position = fakePosition(_booLat, _booLng);

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

      final detection = container.read(rideDetectionControllerProvider.notifier);

      // Near BOO first (ENTER-equivalent) so the controller has a station to
      // register an exit from.
      geolocator.position = fakePosition(_booLat, _booLng);
      await detection.checkNow();
      expect(container.read(rideDetectionControllerProvider)?.state, ActiveTripState.nearStation);

      // Now far from BOO (EXIT-equivalent) with in-vehicle activity — should
      // cross the strong threshold via the saved home->work route match.
      native.activityEvent = ActivityEvent(
        type: RideActivityType.inVehicle,
        confidencePercent: 100,
        occurredAt: DateTime.now(),
      );
      geolocator.position = fakePosition(_farFromBooLat, _farFromBooLng);
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

  test('newly near a station without a pending exit is a subtle nearStation phase', () async {
    final settings = container.read(settingsControllerProvider.notifier);
    await settings.setRideDetectionEnabled(true);
    await settings.setHomeStation('BOO');

    geolocator.position = fakePosition(_booLat, _booLng);

    final detection = container.read(rideDetectionControllerProvider.notifier);
    await detection.checkNow();

    final phase = container.read(rideDetectionControllerProvider);
    expect(phase, isNotNull);
    expect(phase!.state, ActiveTripState.nearStation);
    expect(phase.stationId, 'BOO');
    expect(phase.assessment, isNull); // never a user-visible prompt at this phase
  });

  test('the same exit is not re-evaluated on a later poll at the same distance', () async {
    final settings = container.read(settingsControllerProvider.notifier);
    await settings.setRideDetectionEnabled(true);
    await settings.setHomeStation('BOO');
    await settings.setWorkStation('SUD');

    native.activityEvent = ActivityEvent(
      type: RideActivityType.inVehicle,
      confidencePercent: 100,
      occurredAt: DateTime.now(),
    );

    final detection = container.read(rideDetectionControllerProvider.notifier);
    geolocator.position = fakePosition(_booLat, _booLng);
    await detection.checkNow();
    geolocator.position = fakePosition(_farFromBooLat, _farFromBooLng);
    await detection.checkNow(); // triggers the exit evaluation
    detection.dismiss();
    await detection.checkNow(); // still far away, must not re-evaluate

    final phase = container.read(rideDetectionControllerProvider);
    expect(phase, isNotNull);
    expect(phase!.state, ActiveTripState.idle);
  });

  test('dismissForToday suppresses even a brand-new exit today', () async {
    final settings = container.read(settingsControllerProvider.notifier);
    await settings.setRideDetectionEnabled(true);
    await settings.setHomeStation('BOO');
    // Deliberately no saved work station here: with one set, this scenario
    // reaches the `strong` + matched-destination combo that fires
    // `_autoStartRecognizedTrip` in the background (unawaited), which would
    // race this test's own assertions once a route genuinely resolves via
    // the mocked schedule provider above. Suppression itself doesn't depend
    // on that path, so avoiding it keeps this test deterministic.

    native.activityEvent = ActivityEvent(
      type: RideActivityType.inVehicle,
      confidencePercent: 100,
      occurredAt: DateTime.now(),
    );

    final detection = container.read(rideDetectionControllerProvider.notifier);
    geolocator.position = fakePosition(_booLat, _booLng);
    await detection.checkNow();
    geolocator.position = fakePosition(_farFromBooLat, _farFromBooLng);
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

    // Suppression is checked before GPS is even read, so a brand-new
    // near->far sequence today still can't resurface a prompt.
    geolocator.position = fakePosition(_booLat, _booLng);
    await detection.checkNow();
    geolocator.position = fakePosition(_farFromBooLat, _farFromBooLng);
    await detection.checkNow();
    expect(
      container.read(rideDetectionControllerProvider)?.state,
      ActiveTripState.idle,
    );
  });
}
