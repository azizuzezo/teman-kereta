import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teman_kereta/core/database/app_database.dart';
import 'package:teman_kereta/core/database/database_provider.dart';
import 'package:teman_kereta/core/notifications/local_notification_service.dart';
import 'package:teman_kereta/core/preferences/preferences_store.dart';
import 'package:teman_kereta/data/providers/provider_registry.dart';
import 'package:teman_kereta/domain/entities/active_trip.dart';
import 'package:teman_kereta/domain/entities/transit_models.dart';
import 'package:teman_kereta/domain/providers/transit_providers.dart';
import 'package:teman_kereta/features/active_trip/presentation/active_trip_controller.dart';

import '../support/fakes.dart';

const _nativeChannel = MethodChannel('id.temankereta.teman_kereta/native');

/// Stands in for a dead network: every call fails exactly like a live
/// Supabase station fetch would with no signal, so tests can check that
/// [stationListProvider]'s cache fallback is what actually gets used.
class _OfflineStationProvider implements StationProvider {
  @override
  Future<List<Station>> getStations() => Future.error(Exception('no network'));

  @override
  Future<Station?> getStation(String stationId) =>
      Future.error(Exception('no network'));
}

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
  late AppDatabase database;
  Map<String, Object?>? queuedGeofenceEvent;
  Map<String, Object?>? nativeFullState;

  setUp(() {
    notifications = FakeNotificationService();
    database = AppDatabase.forTesting(NativeDatabase.memory());
    queuedGeofenceEvent = null;
    nativeFullState = null;
    container = ProviderContainer(
      overrides: [
        preferencesStoreProvider.overrideWithValue(MemoryPreferencesStore()),
        localNotificationServiceProvider.overrideWithValue(notifications),
        stationListProvider.overrideWith((ref) async => const <Station>[]),
        appDatabaseProvider.overrideWithValue(database),
      ],
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_nativeChannel, (call) async {
          if (call.method == 'getLastGeofenceEvent') {
            return queuedGeofenceEvent;
          }
          if (call.method == 'getActiveTripFullState') {
            return nativeFullState;
          }
          return null;
        });
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_nativeChannel, null);
    container.dispose();
    await database.close();
  });

  test('advanceStop walks through approaching-transfer, transferring, '
      'approaching-destination, then auto-finishes on arrival', () async {
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
    ];

    for (final expected in expectedStates) {
      await notifier.advanceStop();
      expect(container.read(activeTripControllerProvider)?.state, expected);
    }

    // Reaching the destination ends the trip on its own — no "Selesai"
    // tap. The session stays readable (as `completed`) so the recap
    // screen can render travel time / distance / average speed from it;
    // `dismissCompleted()` is what finally clears it.
    await notifier.advanceStop(); // J, the destination
    expect(
      container.read(activeTripControllerProvider)?.state,
      ActiveTripState.completed,
    );

    expect(notifications.transferAlerts, 1);
    expect(notifications.transferApproachingAlerts, 2); // remaining 2, 1
    // Arrival gets its own summary alert, so the countdown only covers
    // remaining 3, 2 and 1.
    expect(notifications.stopAlerts, 3);
    expect(notifications.arrivalAlerts, 1);
  });

  test('starting a trip with no live network still reaches native tracking, '
      'from the cached station list', () async {
    // Seed the offline cache as if an earlier successful fetch (e.g. at
    // the schedule-search step, while there was still signal) already
    // populated it — this is what `stationListProvider` falls back to.
    await database.replaceStationCache(
      <String>['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J']
          .map(
            (id) => CachedStationsCompanion.insert(
              id: id,
              code: id,
              name: 'Station $id',
              latitude: -6.0,
              longitude: 106.0,
              payloadJson: jsonEncode(
                Station(
                  id: id,
                  code: id,
                  name: 'Station $id',
                  latitude: -6.0,
                  longitude: 106.0,
                ).toJson(),
              ),
              updatedAt: DateTime.now(),
            ),
          )
          .toList(growable: false),
    );

    Map<Object?, Object?>? startArguments;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_nativeChannel, (call) async {
          if (call.method == 'startActiveTrip') {
            startArguments = call.arguments as Map<Object?, Object?>;
          }
          if (call.method == 'getLastGeofenceEvent') return queuedGeofenceEvent;
          if (call.method == 'getActiveTripFullState') return nativeFullState;
          return null;
        });

    final offlineContainer = ProviderContainer(
      overrides: [
        preferencesStoreProvider.overrideWithValue(MemoryPreferencesStore()),
        localNotificationServiceProvider.overrideWithValue(notifications),
        appDatabaseProvider.overrideWithValue(database),
        stationProvider.overrideWithValue(_OfflineStationProvider()),
      ],
    );
    addTearDown(offlineContainer.dispose);

    final notifier = offlineContainer.read(
      activeTripControllerProvider.notifier,
    );
    await notifier.start(_transferTrip());

    // The trip starts either way (Dart's own state never depended on
    // this fetch) — what used to silently break offline is native
    // tracking never being told to start at all.
    expect(offlineContainer.read(activeTripControllerProvider), isNotNull);
    expect(startArguments, isNotNull);
    final stationsArg = startArguments!['stations'] as List<Object?>;
    expect(stationsArg, isNotEmpty);
  });

  test('cancel clears the session and stops the trip', () async {
    final notifier = container.read(activeTripControllerProvider.notifier);
    await notifier.start(_transferTrip());
    expect(container.read(activeTripControllerProvider), isNotNull);

    await notifier.cancel();
    expect(container.read(activeTripControllerProvider), isNull);
  });

  group(
    'native GPS reconciliation (TripProgressEngine drives real progress)',
    () {
      // Station advancement/notifications are now decided natively (see
      // `TripProgressEngine.kt`) from continuous GPS proximity, since that's
      // the only thing guaranteed to keep running once the Flutter engine is
      // torn down (app swiped from Recents — this app has no headless Dart
      // execution). `ActiveTripController` just reconciles whatever native
      // already decided via `getActiveTripFullState` — these tests cover that
      // reconciliation, not the native proximity logic itself (untestable
      // from Dart).
      ProviderContainer containerWithSnapshot(ActiveTripSession session) {
        return ProviderContainer(
          overrides: [
            preferencesStoreProvider.overrideWithValue(
              MemoryPreferencesStore(
                initial: StoredPreferences(
                  activeTripSnapshot: jsonEncode(session.toJson()),
                ),
              ),
            ),
            localNotificationServiceProvider.overrideWithValue(notifications),
            stationListProvider.overrideWith((ref) async => const <Station>[]),
            appDatabaseProvider.overrideWithValue(database),
          ],
        );
      }

      test(
        'adopts a more-advanced index/state/distance/speed from native on restore',
        () async {
          final session = ActiveTripSession(
            id: 'sess-1',
            trip: _transferTrip(),
            state: ActiveTripState.onBoard,
            currentStationIndex: 0,
            startedAt: DateTime.utc(2026, 1, 1, 8),
            updatedAt: DateTime.utc(2026, 1, 1, 8),
            confirmedByUser: true,
          );
          nativeFullState = <String, Object?>{
            'currentStationIndex': 1,
            'state': 'approachingTransfer',
            'distanceMeters': 1200.0,
            'speedKmh': 42.0,
          };
          container.dispose();
          container = containerWithSnapshot(session);

          final restored = container.read(activeTripControllerProvider);
          expect(
            restored?.currentStationIndex,
            0,
          ); // synchronous restore, before reconcile lands

          await Future<void>.delayed(const Duration(milliseconds: 10));

          final reconciled = container.read(activeTripControllerProvider);
          expect(reconciled?.currentStationIndex, 1);
          expect(reconciled?.state, ActiveTripState.approachingTransfer);
          expect(reconciled?.distanceMeters, 1200.0);
          expect(reconciled?.currentSpeedKmh, 42.0);
        },
      );

      test(
        'mirrors a missedDestination decided natively (overshoot watch)',
        () async {
          // The rider slept through their stop: native's overshoot watch
          // (`TripProgressEngine.markMissedDestination`) saw the destination
          // approached and then left behind without an arrival ever firing.
          // Auto-finish-on-arrival never triggers here precisely because
          // arrival never happened, so this path has to keep working.
          final session = ActiveTripSession(
            id: 'sess-3',
            trip: _transferTrip(),
            state: ActiveTripState.approachingDestination,
            currentStationIndex: 8,
            startedAt: DateTime.utc(2026, 1, 1, 8),
            updatedAt: DateTime.utc(2026, 1, 1, 8),
            confirmedByUser: true,
          );
          nativeFullState = <String, Object?>{
            'currentStationIndex': 8,
            'state': 'missedDestination',
          };
          container.dispose();
          container = containerWithSnapshot(session);
          container.read(
            activeTripControllerProvider,
          ); // instantiate, so build() runs

          await Future<void>.delayed(const Duration(milliseconds: 10));

          expect(
            container.read(activeTripControllerProvider)?.state,
            ActiveTripState.missedDestination,
          );
        },
      );

      test('auto-finishes a trip native reports as arrived', () async {
        final session = ActiveTripSession(
          id: 'sess-4',
          trip: _transferTrip(),
          state: ActiveTripState.approachingDestination,
          currentStationIndex: 8,
          startedAt: DateTime.utc(2026, 1, 1, 8),
          updatedAt: DateTime.utc(2026, 1, 1, 8),
          confirmedByUser: true,
        );
        nativeFullState = <String, Object?>{
          'currentStationIndex': 9,
          'state': 'arrived',
          'distanceMeters': 24000.0,
        };
        container.dispose();
        container = containerWithSnapshot(session);
        container.read(
          activeTripControllerProvider,
        ); // instantiate, so build() runs

        await Future<void>.delayed(const Duration(milliseconds: 10));

        final finished = container.read(activeTripControllerProvider);
        expect(finished?.state, ActiveTripState.completed);
        // Kept for the recap screen rather than cleared.
        expect(finished?.distanceMeters, 24000.0);
      });

      test('never regresses currentStationIndex backward', () async {
        final session = ActiveTripSession(
          id: 'sess-2',
          trip: _transferTrip(),
          state: ActiveTripState.onBoard,
          currentStationIndex: 3,
          startedAt: DateTime.utc(2026, 1, 1, 8),
          updatedAt: DateTime.utc(2026, 1, 1, 8),
          confirmedByUser: true,
        );
        // Native hasn't caught up yet with a manual "Lanjut" advance that
        // already pushed Dart ahead.
        nativeFullState = <String, Object?>{
          'currentStationIndex': 1,
          'state': 'approachingTransfer',
        };
        container.dispose();
        container = containerWithSnapshot(session);

        await Future<void>.delayed(const Duration(milliseconds: 10));

        expect(
          container.read(activeTripControllerProvider)?.currentStationIndex,
          3,
        );
      });
    },
  );
}
