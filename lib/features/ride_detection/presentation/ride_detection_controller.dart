import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/platform/native_trip_service.dart';
import '../../../core/preferences/preferences_store.dart';
import '../../../core/utils/geo.dart';
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

/// A station the rider is close enough to for [_nearRadiusMeters] to
/// consider them "near" it — the real-time-GPS replacement for what a
/// geofence ENTER used to signal.
const _nearRadiusMeters = 250.0;

/// Once near, how long the rider must stay near before this counts as
/// genuinely "at" the station (mirrors the old geofence DWELL delay) rather
/// than just passing close by.
const _dwellDelay = Duration(seconds: 90);

/// A later ENTER-equivalent within this long of an exit still counts toward
/// the "moving along a rail corridor" bonus signal below.
const _corridorWindow = Duration(minutes: 90);

/// Watches real-time GPS proximity to the rider's saved stations (home/work/
/// favorite/daily-route) plus Activity Recognition, on a cheap ~25s poll
/// (never a continuous stream — see `ride_detection_watcher.dart`), and
/// drives the pre-boarding portion of the Active Trip state machine
/// (PRD §30): idle → nearStation → atStation → possibleBoarding →
/// confirmingTrip. Only `confirmingTrip` is ever surfaced to the user as a
/// prompt (PRD §9: below score 50, stay silent even while tracking a
/// phase internally). Never starts a trip on its own: [confirmStart] is the
/// only path that calls [ActiveTripController.start], and only after the
/// user taps "Ya, mulai".
class RideDetectionController extends Notifier<RideDetectionPhase?> {
  String? _nearStationId;
  DateTime? _nearSince;
  bool _dwellFired = false;
  String? _pendingExitStationId;
  DateTime? _pendingExitAt;

  @override
  RideDetectionPhase? build() {
    ref.watch(
      settingsControllerProvider.select((s) => s.rideDetectionEnabled),
    );
    return null;
  }

  /// Requests the Activity Recognition permission/updates, then flips the
  /// setting on. Returns false (leaving the setting off) if permission was
  /// refused.
  Future<bool> enable() async {
    final native = ref.read(nativeTripServiceProvider);
    final started = await native.requestActivityRecognitionUpdates();
    if (!started) {
      return false;
    }

    await ref
        .read(settingsControllerProvider.notifier)
        .setRideDetectionEnabled(true);
    state = const RideDetectionPhase(state: ActiveTripState.idle);
    return true;
  }

  Future<void> disable() async {
    final native = ref.read(nativeTripServiceProvider);
    await native.stopActivityRecognitionUpdates();
    await ref
        .read(settingsControllerProvider.notifier)
        .setRideDetectionEnabled(false);
    _resetProximityTracking();
    state = null;
  }

  void _resetProximityTracking() {
    _nearStationId = null;
    _nearSince = null;
    _dwellFired = false;
    _pendingExitStationId = null;
    _pendingExitAt = null;
  }

  Set<String> _candidateStationIds() {
    final settings = ref.read(settingsControllerProvider);
    final prefs = ref.read(preferencesStoreProvider).snapshot;
    final favorite = ref.read(favoriteRouteControllerProvider)?.split('|');
    return <String>{
      if (settings.homeStationId != null) settings.homeStationId!,
      if (settings.workStationId != null) settings.workStationId!,
      if (favorite != null && favorite.length == 2) ...favorite,
      // Always include daily route stations when enabled.
      if (prefs.dailyRouteEnabled && prefs.dailyRouteFromStationId != null)
        prefs.dailyRouteFromStationId!,
      if (prefs.dailyRouteEnabled && prefs.dailyRouteToStationId != null)
        prefs.dailyRouteToStationId!,
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

    final position = await _currentPosition();
    if (position == null) {
      return;
    }
    final candidates = await _candidateStations();
    if (candidates.isEmpty) {
      return;
    }

    Station? nearest;
    var nearestDistance = double.infinity;
    for (final station in candidates) {
      final distance = haversineMeters(
        position.latitude,
        position.longitude,
        station.latitude,
        station.longitude,
      );
      if (distance < nearestDistance) {
        nearest = station;
        nearestDistance = distance;
      }
    }
    if (nearest == null) {
      return;
    }
    final now = ref.read(clockProvider).now();

    if (nearestDistance <= _nearRadiusMeters) {
      if (_nearStationId != nearest.id) {
        // ENTER-equivalent: the rider is newly near this station.
        final pendingStationId = _pendingExitStationId;
        final pendingAt = _pendingExitAt;
        if (pendingStationId != null &&
            pendingAt != null &&
            now.difference(pendingAt) <= _corridorWindow &&
            nearest.id != pendingStationId) {
          // Newly near a *different* station while an exit is still
          // pending is the strongest signal: the user is moving along a
          // rail corridor, not just wandering back to the same platform.
          await _evaluate(pendingStationId, pendingAt, subsequentStationId: nearest.id);
          _pendingExitStationId = null;
          _pendingExitAt = null;
        } else if (_isPreBoardPhase) {
          state = RideDetectionPhase(
            state: ActiveTripState.nearStation,
            stationId: nearest.id,
          );
        }
        _nearStationId = nearest.id;
        _nearSince = now;
        _dwellFired = false;
      } else if (!_dwellFired &&
          _nearSince != null &&
          now.difference(_nearSince!) >= _dwellDelay &&
          _isPreBoardPhase) {
        // DWELL-equivalent: stayed near long enough to count as genuinely
        // "at" the station, not just passing close by.
        _dwellFired = true;
        state = RideDetectionPhase(
          state: ActiveTripState.atStation,
          stationId: nearest.id,
        );
      }
      return;
    }

    // EXIT-equivalent: was near a station, GPS now shows meaningfully
    // farther away than the entry radius (a little slack over
    // `_nearRadiusMeters` avoids flapping right at the boundary).
    final exitedStationId = _nearStationId;
    if (exitedStationId != null && nearestDistance > _nearRadiusMeters * 1.4) {
      _nearStationId = null;
      _nearSince = null;
      _dwellFired = false;
      _pendingExitStationId = exitedStationId;
      _pendingExitAt = now;
      await _evaluate(exitedStationId, now);
    }
  }

  Future<List<Station>> _candidateStations() async {
    final ids = _candidateStationIds();
    if (ids.isEmpty) {
      return const <Station>[];
    }
    final stations = await ref.read(stationProvider).getStations();
    return stations.where((station) => ids.contains(station.id)).toList(growable: false);
  }

  /// Same permission posture as `NearestStationController`/
  /// `CrowdPositionReporter`: never requests the location permission itself
  /// (PRD §10 — that's explained and requested from Settings via [enable]),
  /// a one-shot fix on this controller's existing ~25s poll rather than a
  /// continuous stream (PRD §31).
  Future<Position?> _currentPosition() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return null;
      }
      final permission = await Geolocator.checkPermission();
      final granted = permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse;
      if (!granted) {
        return null;
      }
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 8),
        ),
      );
    } on Object {
      return null;
    }
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
    String stationId,
    DateTime exitedAt, {
    String? subsequentStationId,
  }) async {
    final activity = await ref
        .read(nativeTripServiceProvider)
        .getLastActivityEvent();

    var hasNearbyDeparture = false;
    try {
      final departures = await ref
          .read(transitScheduleProvider)
          .getStationDepartures(stationId, exitedAt);
      hasNearbyDeparture = departures.any(
        (departure) =>
            departure.scheduledAt.difference(exitedAt).abs() <=
            const Duration(minutes: 6),
      );
    } on Object {
      hasNearbyDeparture = false;
    }

    final assessment = const RideDetectionEngine().assess(
      RideDetectionSignals(
        exitedStationId: stationId,
        exitedAt: exitedAt,
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

    // Auto-start without confirmation for ANY strong-confidence assessment
    // that also resolved a matched saved destination (daily route, home/work,
    // or favorite — see `_savedDestinationFrom`). `soft` level, or `strong`
    // without a matched destination, still falls through to the
    // `confirmingTrip` manual-tap prompt set above as the conservative
    // fallback — this deliberately does not lower `strongThreshold` or add
    // new signals.
    if (assessment.level == RideDetectionLevel.strong &&
        assessment.suggestedDestinationId != null) {
      unawaited(_autoStartRecognizedTrip(
        fromStationId: stationId,
        toStationId: assessment.suggestedDestinationId!,
        exitedAt: exitedAt,
      ));
    }
  }

  /// Directly starts a recognized trip (daily route, home/work, or favorite
  /// match) — no user confirmation needed.
  Future<void> _autoStartRecognizedTrip({
    required String fromStationId,
    required String toStationId,
    required DateTime exitedAt,
  }) async {
    try {
      final trips = await ref.read(transitScheduleProvider).searchTrips(
        TripSearchQuery(
          originStationId: fromStationId,
          destinationStationId: toStationId,
          departureAt: exitedAt,
        ),
      );
      final best = const RouteRanker().rank(trips, exitedAt).firstOrNull;
      if (best == null) return;
      if (!ref.mounted) return;
      await ref.read(activeTripControllerProvider.notifier).start(best);
      if (!ref.mounted) return;
      state = null;
    } on Object {
      // Silent fail — will show normal confirmation prompt if this fails.
    }
  }

  String? _savedDestinationFrom(String stationId) {
    // Check daily route first: if at origin → go to destination; if at destination → return to origin.
    final prefs = ref.read(preferencesStoreProvider).snapshot;
    if (prefs.dailyRouteEnabled) {
      if (prefs.dailyRouteFromStationId == stationId) {
        return prefs.dailyRouteToStationId;
      }
      // Smart return: when at the daily destination, suggest going back home.
      if (prefs.dailyRouteToStationId == stationId) {
        return prefs.dailyRouteFromStationId;
      }
    }
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
