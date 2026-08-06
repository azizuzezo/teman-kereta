import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/platform/native_trip_service.dart';
import '../../../core/preferences/preferences_store.dart';
import '../../../data/providers/provider_registry.dart';
import '../../../domain/entities/active_trip.dart';
import '../../../domain/entities/ride_detection.dart';
import '../../../domain/entities/transit_models.dart';
import '../../../domain/usecases/ride_detection_engine.dart';
import '../../../domain/usecases/route_ranker.dart';
import '../../active_trip/presentation/active_trip_controller.dart';
import '../../favorites/presentation/favorite_route_controller.dart';
import '../../schedule/presentation/trip_search_controller.dart';
import '../../settings/presentation/settings_controller.dart';

/// Watches native geofence/Activity Recognition signals (via cheap polling
/// of already-collected state — never a new continuous GPS stream, see
/// PRD §31) and drives the pre-boarding portion of the Active Trip state
/// machine (PRD §30): idle → nearStation → atStation → possibleBoarding →
/// confirmingTrip. Only `confirmingTrip` is ever surfaced to the user as a
/// prompt (PRD §9: below score 50, stay silent even while tracking a
/// phase internally). Never starts a trip on its own: [confirmStart] is the
/// only path that calls [ActiveTripController.start], and only after the
/// user taps "Ya, mulai".
class RideDetectionController extends Notifier<RideDetectionPhase?> {
  DateTime? _lastProcessedEnterAt;
  DateTime? _lastProcessedDwellAt;
  DateTime? _lastProcessedExitAt;
  GeofenceEvent? _pendingExit;

  @override
  RideDetectionPhase? build() {
    ref.watch(
      settingsControllerProvider.select((s) => s.rideDetectionEnabled),
    );
    return null;
  }

  /// Requests the Activity Recognition permission/updates and registers
  /// geofences for the user's saved stations, then flips the setting on.
  /// Returns false (leaving the setting off) if permission was refused.
  Future<bool> enable() async {
    final native = ref.read(nativeTripServiceProvider);
    final started = await native.requestActivityRecognitionUpdates();
    if (!started) {
      return false;
    }

    await ref
        .read(settingsControllerProvider.notifier)
        .setRideDetectionEnabled(true);
    await reregisterSavedStationGeofences();
    state = const RideDetectionPhase(state: ActiveTripState.idle);
    return true;
  }

  Future<void> disable() async {
    final native = ref.read(nativeTripServiceProvider);
    await native.unregisterStationGeofences();
    await native.stopActivityRecognitionUpdates();
    await ref
        .read(settingsControllerProvider.notifier)
        .setRideDetectionEnabled(false);
    state = null;
  }

  /// Re-registers the saved home/work/favorite station geofences, a no-op
  /// if the setting is off. Native geofence registration always *replaces*
  /// the whole scope (see `StationGeofenceManager`'s doc comment), so an
  /// active trip taking over the scope for its own route stations means
  /// this has to be called again once that trip ends, or ride detection
  /// would silently end up with no geofences at all — see
  /// `ActiveTripController._releaseRouteGeofences`.
  Future<void> reregisterSavedStationGeofences() async {
    if (!ref.read(settingsControllerProvider).rideDetectionEnabled) {
      return;
    }
    final stationIds = _candidateStationIds();
    if (stationIds.isEmpty) {
      return;
    }
    final stations = await ref.read(stationProvider).getStations();
    final geofenceStations = stations
        .where((station) => stationIds.contains(station.id))
        .map(
          (station) => <String, Object?>{
            'stationId': station.id,
            'latitude': station.latitude,
            'longitude': station.longitude,
          },
        )
        .toList(growable: false);
    if (geofenceStations.isEmpty) {
      return;
    }
    await ref.read(nativeTripServiceProvider).registerStationGeofences(geofenceStations);
  }

  Set<String> _candidateStationIds() {
    final settings = ref.read(settingsControllerProvider);
    final favorite = ref.read(favoriteRouteControllerProvider)?.split('|');
    return <String>{
      if (settings.homeStationId != null) settings.homeStationId!,
      if (settings.workStationId != null) settings.workStationId!,
      if (favorite != null && favorite.length == 2) ...favorite,
    };
  }

  Future<void> checkNow() async {
    if (!ref.read(settingsControllerProvider).rideDetectionEnabled) {
      return;
    }
    if (ref.read(activeTripControllerProvider) != null) {
      // A confirmed trip already owns the user's journey state.
      state = null;
      return;
    }
    if (await _isSuppressedToday()) {
      return;
    }
    state ??= const RideDetectionPhase(state: ActiveTripState.idle);

    final geofence = await ref
        .read(nativeTripServiceProvider)
        .getLastGeofenceEvent();
    if (geofence == null || geofence.stationIds.isEmpty) {
      return;
    }
    final stationId = geofence.stationIds.first;

    switch (geofence.transition) {
      case GeofenceTransition.enter:
        if (_isNew(geofence.occurredAt, _lastProcessedEnterAt)) {
          _lastProcessedEnterAt = geofence.occurredAt;
          final pending = _pendingExit;
          if (pending != null &&
              geofence.occurredAt.difference(pending.occurredAt) <=
                  const Duration(minutes: 90) &&
              stationId != pending.stationIds.first) {
            // A later station's ENTER while an exit is still pending is the
            // strongest signal: the user is moving along a rail corridor.
            await _evaluate(pending, subsequentStationId: stationId);
          } else if (_isPreBoardPhase) {
            state = RideDetectionPhase(
              state: ActiveTripState.nearStation,
              stationId: stationId,
            );
          }
        }
      case GeofenceTransition.dwell:
        if (_isNew(geofence.occurredAt, _lastProcessedDwellAt) &&
            _isPreBoardPhase) {
          _lastProcessedDwellAt = geofence.occurredAt;
          state = RideDetectionPhase(
            state: ActiveTripState.atStation,
            stationId: stationId,
          );
        }
      case GeofenceTransition.exit:
        if (_isNew(geofence.occurredAt, _lastProcessedExitAt)) {
          _lastProcessedExitAt = geofence.occurredAt;
          _pendingExit = geofence;
          await _evaluate(geofence);
        }
      case GeofenceTransition.unknown:
        break;
    }
  }

  bool _isNew(DateTime occurredAt, DateTime? lastProcessed) {
    return lastProcessed == null || occurredAt.isAfter(lastProcessed);
  }

  /// Only overwrite the visible phase with a lighter nearStation/atStation
  /// signal while nothing more advanced is already showing — a confirmation
  /// prompt must never be silently replaced by "mendekati stasiun".
  bool get _isPreBoardPhase {
    final current = state?.state;
    return current == null ||
        current == ActiveTripState.idle ||
        current == ActiveTripState.nearStation ||
        current == ActiveTripState.atStation;
  }

  Future<void> _evaluate(
    GeofenceEvent exit, {
    String? subsequentStationId,
  }) async {
    final stationId = exit.stationIds.first;
    final activity = await ref
        .read(nativeTripServiceProvider)
        .getLastActivityEvent();

    var hasNearbyDeparture = false;
    try {
      final departures = await ref
          .read(transitScheduleProvider)
          .getStationDepartures(stationId, exit.occurredAt);
      hasNearbyDeparture = departures.any(
        (departure) =>
            departure.scheduledAt.difference(exit.occurredAt).abs() <=
            const Duration(minutes: 6),
      );
    } on Object {
      hasNearbyDeparture = false;
    }

    final assessment = const RideDetectionEngine().assess(
      RideDetectionSignals(
        exitedStationId: stationId,
        exitedAt: exit.occurredAt,
        latestActivity: activity,
        hasNearbyScheduledDeparture: hasNearbyDeparture,
        matchingSavedDestinationId: _savedDestinationFrom(stationId),
        subsequentStationId: subsequentStationId,
      ),
    );

    state = RideDetectionPhase(
      state: assessment.level == RideDetectionLevel.none
          ? ActiveTripState.possibleBoarding
          : ActiveTripState.confirmingTrip,
      stationId: stationId,
      assessment: assessment.level == RideDetectionLevel.none ? null : assessment,
    );
  }

  String? _savedDestinationFrom(String stationId) {
    final favorite = ref.read(favoriteRouteControllerProvider);
    if (favorite != null) {
      final parts = favorite.split('|');
      if (parts.length == 2 && parts[0] == stationId) {
        return parts[1];
      }
    }
    final settings = ref.read(settingsControllerProvider);
    if (settings.homeStationId == stationId) {
      return settings.workStationId;
    }
    if (settings.workStationId == stationId) {
      return settings.homeStationId;
    }
    return null;
  }

  Future<void> confirmStart() async {
    final assessment = state?.assessment;
    final destination = assessment?.suggestedDestinationId;
    if (assessment == null || destination == null) {
      chooseAnother();
      return;
    }

    try {
      final trips = await ref.read(transitScheduleProvider).searchTrips(
        TripSearchQuery(
          originStationId: assessment.stationId,
          destinationStationId: destination,
          departureAt: assessment.exitedAt,
        ),
      );
      final best = const RouteRanker()
          .rank(trips, assessment.exitedAt)
          .firstOrNull;
      if (best == null) {
        chooseAnother();
        return;
      }
      await ref.read(activeTripControllerProvider.notifier).start(best);
      state = null;
    } on Object {
      chooseAnother();
    }
  }

  void chooseAnother() {
    final assessment = state?.assessment;
    if (assessment != null) {
      ref
          .read(tripSearchControllerProvider.notifier)
          .setOrigin(assessment.stationId);
    }
    state = const RideDetectionPhase(state: ActiveTripState.idle);
  }

  void dismiss() {
    state = const RideDetectionPhase(state: ActiveTripState.idle);
  }

  Future<void> dismissForToday() async {
    final today = _isoDate(ref.read(clockProvider).now());
    await ref
        .read(preferencesStoreProvider)
        .setRideDetectionSuppressedUntil(today);
    state = const RideDetectionPhase(state: ActiveTripState.idle);
  }

  Future<bool> _isSuppressedToday() async {
    final suppressedUntil = ref
        .read(preferencesStoreProvider)
        .snapshot
        .rideDetectionSuppressedUntil;
    if (suppressedUntil == null) {
      return false;
    }
    return suppressedUntil.compareTo(_isoDate(ref.read(clockProvider).now())) >=
        0;
  }

  String _isoDate(DateTime value) {
    final year = value.year.toString().padLeft(4, '0');
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }
}

final rideDetectionControllerProvider =
    NotifierProvider<RideDetectionController, RideDetectionPhase?>(
      RideDetectionController.new,
    );
