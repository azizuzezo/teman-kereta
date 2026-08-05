import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/notifications/local_notification_service.dart';
import '../../../core/platform/native_trip_service.dart';
import '../../../core/preferences/preferences_store.dart';
import '../../../data/providers/demo_data.dart';
import '../../../data/providers/provider_registry.dart';
import '../../../domain/entities/active_trip.dart';
import '../../../domain/entities/transit_models.dart';
import '../../settings/presentation/settings_controller.dart';

class ActiveTripController extends Notifier<ActiveTripSession?> {
  late final PreferencesStore _store;

  @override
  ActiveTripSession? build() {
    _store = ref.watch(preferencesStoreProvider);
    final encoded = _store.snapshot.activeTripSnapshot;
    if (encoded == null) {
      return null;
    }
    try {
      return ActiveTripSession.fromJson(
        jsonDecode(encoded) as Map<String, Object?>,
      );
    } on Object {
      unawaited(_store.setActiveTripSnapshot(null));
      return null;
    }
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
    } else if (boundary == null && remaining <= settings.stopAlertThreshold) {
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

  Future<void> _markMissedDestination(ActiveTripSession current) async {
    final updated = current.copyWith(
      state: ActiveTripState.missedDestination,
      updatedAt: ref.read(clockProvider).now(),
    );
    state = updated;
    await _persistAndSync(updated);
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
    await _store.setActiveTripSnapshot(null);
    await _logHistory(current);
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
