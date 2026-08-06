import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/location/crowd_position_reporter.dart';
import '../../../core/notifications/local_notification_service.dart';
import '../../../core/platform/native_trip_service.dart';
import '../../../core/preferences/preferences_store.dart';
import '../../../data/providers/demo_data.dart';
import '../../../data/providers/provider_registry.dart';
import '../../../domain/entities/active_trip.dart';
import '../../../domain/entities/ride_detection.dart';
import '../../../domain/entities/transit_models.dart';
import '../../premium/presentation/subscription_controller.dart';
import '../../ride_detection/presentation/ride_detection_controller.dart';
import '../../settings/presentation/settings_controller.dart';

/// Maximum stations tracked ahead of the current position — mirrors
/// `StationGeofenceManager.MAX_STATION_GEOFENCES` (native side); this is
/// never the app's own arbitrary limit, just staying under the platform's.
const _maxTrackedStationsAhead = 20;

/// How often the rider's own position is reported while onBoard, when
/// "Deteksi Otomatis Naik KRL" is enabled — see [CrowdPositionReporter].
const _crowdReportInterval = Duration(seconds: 20);

class ActiveTripController extends Notifier<ActiveTripSession?> {
  late final PreferencesStore _store;
  DateTime? _lastProcessedGeofenceEnterAt;
  Timer? _crowdReportTimer;

  @override
  ActiveTripSession? build() {
    _store = ref.watch(preferencesStoreProvider);
    ref.onDispose(_stopCrowdReporting);
    final encoded = _store.snapshot.activeTripSnapshot;
    if (encoded == null) {
      return null;
    }
    try {
      final restored = ActiveTripSession.fromJson(
        jsonDecode(encoded) as Map<String, Object?>,
      );
      // A restart mid-trip (app killed/relaunched) must not silently stop
      // crowd reporting until the next advanceStop() — resume it here too.
      if (_isGeofenceTrackedState(restored.state)) {
        _startCrowdReporting();
      }
      return restored;
    } on Object {
      unawaited(_store.setActiveTripSnapshot(null));
      return null;
    }
  }

  /// Checks whether the phone has genuinely entered the next station along
  /// this trip's route (a real, native Android geofence ENTER event — same
  /// mechanism `RideDetectionController` uses pre-boarding, see PRD §31: no
  /// continuous GPS stream, just event-driven geofences) and, if so, calls
  /// [advanceStop] automatically. Station sequence/schedule stays the
  /// source of truth either way — a missed or stale geofence event just
  /// means the rider taps "Lanjut" manually, never a wrong destination
  /// count (PRD §37 Skenario 3: GPS being unreliable must never produce
  /// false information).
  Future<void> checkGeofenceProgress() async {
    final current = state;
    if (current == null || !_isGeofenceTrackedState(current.state)) {
      return;
    }
    final nextStationId = current.nextStationId;
    if (nextStationId == null) {
      return;
    }

    final geofence = await ref.read(nativeTripServiceProvider).getLastGeofenceEvent();
    if (geofence == null || geofence.transition != GeofenceTransition.enter) {
      return;
    }
    final lastProcessed = _lastProcessedGeofenceEnterAt;
    if (lastProcessed != null && !geofence.occurredAt.isAfter(lastProcessed)) {
      return;
    }
    if (!geofence.stationIds.contains(nextStationId)) {
      return;
    }
    _lastProcessedGeofenceEnterAt = geofence.occurredAt;
    await advanceStop();
  }

  bool _isGeofenceTrackedState(ActiveTripState state) => switch (state) {
    ActiveTripState.onBoard ||
    ActiveTripState.approachingTransfer ||
    ActiveTripState.transferring ||
    ActiveTripState.approachingDestination => true,
    _ => false,
  };

  /// Starts the periodic crowd-position-report timer. The timer itself
  /// always runs while a trackable trip exists, but [rideDetectionEnabled]
  /// is re-read fresh on every tick (not watched) — bundling this into that
  /// setting per an explicit product decision, rather than a separate
  /// toggle. Re-reading live means turning the setting off mid-trip stops
  /// reports on the very next tick without needing to rebuild this
  /// controller.
  void _startCrowdReporting() {
    _crowdReportTimer?.cancel();
    _crowdReportTimer = Timer.periodic(_crowdReportInterval, (_) {
      unawaited(_reportCrowdPositionIfEligible());
    });
  }

  void _stopCrowdReporting() {
    _crowdReportTimer?.cancel();
    _crowdReportTimer = null;
  }

  Future<void> _reportCrowdPositionIfEligible() async {
    if (!ref.read(settingsControllerProvider).rideDetectionEnabled) {
      return;
    }
    final current = state;
    if (current == null || !_isGeofenceTrackedState(current.state)) {
      return;
    }
    final leg = current.currentRailLeg;
    final externalTripId = leg?.externalTripId;
    final serviceDate = leg?.serviceDate;
    if (externalTripId == null || serviceDate == null) {
      return; // Mock/demo data, or a provider that never populated these.
    }
    await ref
        .read(crowdPositionReporterProvider)
        .reportOnce(externalTripId: externalTripId, serviceDate: serviceDate);
  }

  /// Re-scopes the native geofence set to the stations still ahead on this
  /// trip (never the whole route — a passed station is dropped so the
  /// scope both shrinks over the journey and stays under the native
  /// `MAX_STATION_GEOFENCES` cap on long multi-transfer routes). Unregisters
  /// entirely once nothing remains (arrived/last stop).
  Future<void> _syncRouteGeofences(ActiveTripSession session) async {
    final native = ref.read(nativeTripServiceProvider);
    final remainingIds = session.trip.stationIds
        .skip(session.currentStationIndex + 1)
        .take(_maxTrackedStationsAhead)
        .toList(growable: false);
    if (remainingIds.isEmpty) {
      await native.unregisterStationGeofences();
      return;
    }

    final stations = await ref.read(stationProvider).getStations();
    final stationsById = <String, Station>{
      for (final station in stations) station.id: station,
    };
    final geofenceStations = <Map<String, Object?>>[
      for (final id in remainingIds)
        if (stationsById[id] case final station?)
          <String, Object?>{
            'stationId': station.id,
            'latitude': station.latitude,
            'longitude': station.longitude,
          },
    ];
    if (geofenceStations.isEmpty) {
      return;
    }
    await native.registerStationGeofences(geofenceStations);
  }

  Future<void> advanceStop() async {
    final current = state;
    if (current == null || current.trip.stationIds.isEmpty) {
      return;
    }

    final lastIndex = current.trip.stationIds.length - 1;

    if (current.state == ActiveTripState.arrived ||
        current.currentStationIndex >= lastIndex) {
      await _markMissedDestination(current);
      return;
    }

    final nextIndex = current.currentStationIndex + 1;
    final remaining = lastIndex - nextIndex;
    final boundary = current.trip.transferBoundaries
        .where((candidate) => candidate.index >= nextIndex)
        .firstOrNull;
    final nextState = switch (boundary) {
      final b? when b.index == nextIndex => ActiveTripState.transferring,
      final b? when b.index - nextIndex <= 2 => ActiveTripState.approachingTransfer,
      _ when remaining <= 0 => ActiveTripState.arrived,
      _ when remaining <= 3 => ActiveTripState.approachingDestination,
      _ => ActiveTripState.onBoard,
    };
    final updated = current.copyWith(
      currentStationIndex: nextIndex,
      state: nextState,
      updatedAt: ref.read(clockProvider).now(),
    );
    state = updated;
    await _persistAndSync(updated);
    unawaited(_syncRouteGeofences(updated));

    final settings = ref.read(settingsControllerProvider);
    if (nextState == ActiveTripState.transferring) {
      unawaited(
        ref.read(localNotificationServiceProvider).showTransferAlert(
          stationName: _stationName(current.trip.stationIds[nextIndex]),
          instruction: boundary?.instruction,
          isDemo: current.trip.isDemo,
          vibrate: settings.vibrationEnabled,
          sound: settings.soundEnabled,
        ),
      );
    } else if (boundary == null &&
        remaining <= settings.stopAlertThreshold &&
        _hasPremiumReminderEntitlement()) {
      unawaited(
        ref.read(localNotificationServiceProvider).showStopAlert(
          remainingStops: remaining,
          destination: _stationName(current.trip.destinationStationId),
          isDemo: current.trip.isDemo,
          vibrate: settings.vibrationEnabled,
          sound: settings.soundEnabled,
        ),
      );
    }
  }

  /// Gates the "N stasiun sebelum tujuan" reminder — a premium feature
  /// (see `subscriptions` table/`PremiumPaywallPage`). The transfer and
  /// missed-destination alerts stay free; only this specific convenience
  /// reminder is paywalled, matching the user's own scoping of the feature.
  bool _hasPremiumReminderEntitlement() {
    final entitlement = ref.read(subscriptionControllerProvider);
    return entitlement.isEntitledAt(ref.read(clockProvider).now());
  }

  Future<void> _markMissedDestination(ActiveTripSession current) async {
    final updated = current.copyWith(
      state: ActiveTripState.missedDestination,
      updatedAt: ref.read(clockProvider).now(),
    );
    state = updated;
    await _persistAndSync(updated);
    unawaited(ref.read(nativeTripServiceProvider).unregisterStationGeofences());
    _stopCrowdReporting();
    final settings = ref.read(settingsControllerProvider);
    unawaited(
      ref.read(localNotificationServiceProvider).showMissedDestinationAlert(
        destination: _stationName(current.trip.destinationStationId),
        isDemo: current.trip.isDemo,
        vibrate: settings.vibrationEnabled,
        sound: settings.soundEnabled,
      ),
    );
  }

  Future<void> cancel() async {
    final current = state;
    if (current != null) {
      state = current.copyWith(
        state: ActiveTripState.cancelled,
        updatedAt: ref.read(clockProvider).now(),
      );
    }
    await ref.read(nativeTripServiceProvider).stop();
    await _releaseRouteGeofences();
    _stopCrowdReporting();
    await _store.setActiveTripSnapshot(null);
    state = null;
  }

  Future<void> complete() async {
    final current = state;
    if (current == null) {
      return;
    }
    final completed = current.copyWith(
      state: ActiveTripState.completed,
      updatedAt: ref.read(clockProvider).now(),
    );
    state = completed;
    await ref.read(nativeTripServiceProvider).stop();
    await _releaseRouteGeofences();
    _stopCrowdReporting();
    await _store.setActiveTripSnapshot(null);
    await _logHistory(current);
  }

  /// Drops this trip's route geofences and, if ride detection is still
  /// enabled, restores its own saved-station geofences (home/work/favorite)
  /// — otherwise finishing a trip would silently leave ride detection with
  /// no geofences at all until the user re-toggles the setting.
  Future<void> _releaseRouteGeofences() async {
    await ref.read(nativeTripServiceProvider).unregisterStationGeofences();
    await ref
        .read(rideDetectionControllerProvider.notifier)
        .reregisterSavedStationGeofences();
  }

  Future<void> _logHistory(ActiveTripSession session) async {
    final trip = session.trip;
    final lineName = trip.legs
        .where((leg) => leg.mode == TransportMode.commuterRail)
        .map((leg) => leg.lineName)
        .whereType<String>()
        .firstOrNull;
    try {
      await ref.read(appDatabaseProvider).logCompletedTrip(
        CompletedTripsCompanion.insert(
          id: session.id,
          originStationId: trip.originStationId,
          originName: _stationName(trip.originStationId),
          destinationStationId: trip.destinationStationId,
          destinationName: _stationName(trip.destinationStationId),
          lineName: Value(lineName),
          departedAt: trip.departureAt,
          arrivedAt: trip.arrivalAt,
          isDemo: Value(trip.isDemo),
          completedAt: ref.read(clockProvider).now(),
        ),
      );
    } on Object {
      // History is a convenience, not load-bearing — losing one row must
      // never block the user from finishing their trip.
    }
  }

  void dismissCompleted() {
    if (state?.state == ActiveTripState.completed) {
      state = null;
    }
  }

  Future<void> start(TransitTrip trip) async {
    final now = ref.read(clockProvider).now();
    final session = ActiveTripSession(
      id: const Uuid().v4(),
      trip: trip,
      state: ActiveTripState.onBoard,
      currentStationIndex: 0,
      startedAt: now,
      updatedAt: now,
      confirmedByUser: true,
    );
    state = session;
    await _store.setActiveTripSnapshot(jsonEncode(session.toJson()));
    await ref.read(nativeTripServiceProvider).start(session);
    unawaited(_syncRouteGeofences(session));
    _startCrowdReporting();
  }

  Future<void> toggleLowBatteryMode() async {
    final current = state;
    if (current == null) {
      return;
    }
    final updated = current.copyWith(
      lowBatteryMode: !current.lowBatteryMode,
      updatedAt: ref.read(clockProvider).now(),
    );
    state = updated;
    await _persistAndSync(updated);
  }

  Future<void> _persistAndSync(ActiveTripSession session) async {
    await _store.setActiveTripSnapshot(jsonEncode(session.toJson()));
    await ref.read(nativeTripServiceProvider).update(session);
  }

  String _stationName(String stationId) {
    return demoStations
            .where((station) => station.id == stationId)
            .firstOrNull
            ?.name ??
        stationId;
  }
}

final activeTripControllerProvider =
    NotifierProvider<ActiveTripController, ActiveTripSession?>(
      ActiveTripController.new,
    );
