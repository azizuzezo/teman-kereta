import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teman_kereta/core/notifications/local_notification_service.dart';
import 'package:teman_kereta/core/preferences/preferences_store.dart';
import 'package:teman_kereta/domain/entities/active_trip.dart';
import 'package:teman_kereta/domain/entities/transit_models.dart';
import 'package:teman_kereta/features/active_trip/presentation/active_trip_controller.dart';

import '../support/fakes.dart';

const _nativeChannel = MethodChannel('id.temankereta.teman_kereta/native');

/// A → B → C → D (transfer) → E → F → G → H → I → J (destination), matching
/// the shape produced by MockTransitProvider for a Bogor-Manggarai-Sudirman
/// style trip: two rail legs joined at a shared transfer station.
TransitTrip _transferTrip() {
  final now = DateTime.utc(2026, 1, 1, 8);
  return TransitTrip(
    id: 'trip-transfer',
    originStationId: 'A',
    destinationStationId: 'J',
    departureAt: now,
    arrivalAt: now.add(const Duration(minutes: 60)),
    freshness: DataFreshness.estimated,
    sourceLabel: 'test',
    updatedAt: now,
    isDemo: true,
    legs: <TripLeg>[
      TripLeg(
        id: 'rail-1',
        mode: TransportMode.commuterRail,
        originName: 'A',
        destinationName: 'D',
        departureAt: now,
        arrivalAt: now.add(const Duration(minutes: 20)),
        lineName: 'Bogor Line',
        stationIds: const <String>['A', 'B', 'C', 'D'],
        transferInstruction: 'Transit di D ke Cikarang Line.',
      ),
      TripLeg(
        id: 'rail-2',
        mode: TransportMode.commuterRail,
        originName: 'D',
        destinationName: 'J',
        departureAt: now.add(const Duration(minutes: 26)),
        arrivalAt: now.add(const Duration(minutes: 55)),
        lineName: 'Cikarang Line',
        stationIds: const <String>['D', 'E', 'F', 'G', 'H', 'I', 'J'],
      ),
    ],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer container;
  late FakeNotificationService notifications;
  Map<String, Object?>? queuedGeofenceEvent;

  setUp(() {
    notifications = FakeNotificationService();
    queuedGeofenceEvent = null;
    container = ProviderContainer(
      overrides: [
        preferencesStoreProvider.overrideWithValue(MemoryPreferencesStore()),
        localNotificationServiceProvider.overrideWithValue(notifications),
      ],
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_nativeChannel, (call) async {
      if (call.method == 'getLastGeofenceEvent') {
        return queuedGeofenceEvent;
      }
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_nativeChannel, null);
    container.dispose();
  });

  test(
    'advanceStop walks through approaching-transfer, transferring, '
    'approaching-destination, arrived, then missed-destination',
    () async {
      final notifier = container.read(activeTripControllerProvider.notifier);
      await notifier.start(_transferTrip());

      final expectedStates = <ActiveTripState>[
        ActiveTripState.approachingTransfer, // B
        ActiveTripState.approachingTransfer, // C
        ActiveTripState.transferring, // D
        ActiveTripState.onBoard, // E
        ActiveTripState.onBoard, // F
        ActiveTripState.approachingDestination, // G
        ActiveTripState.approachingDestination, // H
        ActiveTripState.approachingDestination, // I
        ActiveTripState.arrived, // J
      ];

      for (final expected in expectedStates) {
        await notifier.advanceStop();
        expect(container.read(activeTripControllerProvider)?.state, expected);
      }

      // Train keeps moving past the destination without the user ending
      // the trip: this must surface as missedDestination, not silently
      // stay clamped at "arrived".
      await notifier.advanceStop();
      expect(
        container.read(activeTripControllerProvider)?.state,
        ActiveTripState.missedDestination,
      );

      expect(notifications.transferAlerts, 1);
      expect(notifications.missedAlerts, 1);
      expect(notifications.stopAlerts, 4); // remaining 3, 2, 1, 0
    },
  );

  test('cancel clears the session and stops the trip', () async {
    final notifier = container.read(activeTripControllerProvider.notifier);
    await notifier.start(_transferTrip());
    expect(container.read(activeTripControllerProvider), isNotNull);

    await notifier.cancel();
    expect(container.read(activeTripControllerProvider), isNull);
  });

  group('checkGeofenceProgress (real geofence ENTER auto-advances the trip)', () {
    test('advances when the phone enters the next station along the route', () async {
      final notifier = container.read(activeTripControllerProvider.notifier);
      await notifier.start(_transferTrip()); // currentStationIndex 0 (A), next = B

      queuedGeofenceEvent = <String, Object?>{
        'stationIds': <String>['B'],
        'transition': 'enter',
        'occurredAtEpochMs': DateTime.utc(2026, 1, 1, 8, 5).millisecondsSinceEpoch,
      };
      await notifier.checkGeofenceProgress();

      final session = container.read(activeTripControllerProvider);
      expect(session?.currentStationIndex, 1);
      expect(session?.state, ActiveTripState.approachingTransfer);
    });

    test('does nothing when the geofence event is for a different station', () async {
      final notifier = container.read(activeTripControllerProvider.notifier);
      await notifier.start(_transferTrip());

      queuedGeofenceEvent = <String, Object?>{
        'stationIds': <String>['C'], // not the next station (B)
        'transition': 'enter',
        'occurredAtEpochMs': DateTime.utc(2026, 1, 1, 8, 5).millisecondsSinceEpoch,
      };
      await notifier.checkGeofenceProgress();

      expect(container.read(activeTripControllerProvider)?.currentStationIndex, 0);
    });

    test('does nothing on an exit/dwell transition, only enter', () async {
      final notifier = container.read(activeTripControllerProvider.notifier);
      await notifier.start(_transferTrip());

      queuedGeofenceEvent = <String, Object?>{
        'stationIds': <String>['B'],
        'transition': 'dwell',
        'occurredAtEpochMs': DateTime.utc(2026, 1, 1, 8, 5).millisecondsSinceEpoch,
      };
      await notifier.checkGeofenceProgress();

      expect(container.read(activeTripControllerProvider)?.currentStationIndex, 0);
    });

    test('does not double-advance on a repeated (already-processed) event', () async {
      final notifier = container.read(activeTripControllerProvider.notifier);
      await notifier.start(_transferTrip());

      queuedGeofenceEvent = <String, Object?>{
        'stationIds': <String>['B'],
        'transition': 'enter',
        'occurredAtEpochMs': DateTime.utc(2026, 1, 1, 8, 5).millisecondsSinceEpoch,
      };
      await notifier.checkGeofenceProgress();
      expect(container.read(activeTripControllerProvider)?.currentStationIndex, 1);

      // Same event polled again (native side hasn't produced a new one yet).
      await notifier.checkGeofenceProgress();
      expect(container.read(activeTripControllerProvider)?.currentStationIndex, 1);
    });

    test('does nothing before a trip is confirmed onBoard', () async {
      final notifier = container.read(activeTripControllerProvider.notifier);
      queuedGeofenceEvent = <String, Object?>{
        'stationIds': <String>['B'],
        'transition': 'enter',
        'occurredAtEpochMs': DateTime.utc(2026, 1, 1, 8, 5).millisecondsSinceEpoch,
      };
      await notifier.checkGeofenceProgress();
      expect(container.read(activeTripControllerProvider), isNull);
    });
  });
}
