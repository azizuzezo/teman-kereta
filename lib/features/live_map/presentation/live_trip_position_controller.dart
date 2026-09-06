import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/utils/geo.dart';
import '../../../data/providers/provider_registry.dart';
import '../../../domain/entities/active_trip.dart';
import '../../../domain/entities/transit_models.dart';
import '../../active_trip/presentation/active_trip_controller.dart';
import 'native_gps_fix.dart';

/// GPS fixes older than this are treated stale enough to switch from
/// "project the raw fix onto the track" to dead reckoning (extrapolate from
/// the fix's last known speed/bearing) — e.g. a tunnel section. Set
/// comfortably above the ~4s native sync tick this is fed from, so a single
/// missed poll doesn't immediately fall back.
const _gpsStaleAfter = Duration(seconds: 45);

/// Beyond this much staleness, even dead reckoning is no longer trusted
/// (too much accumulated drift) — falls through to schedule interpolation.
const _deadReckoningStaleAfter = Duration(seconds: 90);

/// Purely local recompute tick (never a GPS call) so the schedule-based
/// fallback keeps cosmetically advancing between GPS fixes instead of
/// sitting frozen at the last confirmed station until the next tick.
const _fallbackRefreshInterval = Duration(seconds: 10);

class _GpsFix {
  const _GpsFix(this.point, this.at, {this.speedMetersPerSecond, this.bearingDegrees});
  final LatLng point;
  final DateTime at;
  final double? speedMetersPerSecond;
  final double? bearingDegrees;
}

/// Drives the "you are here" marker on the live map while an Active Trip is
/// on board (`onBoard`/`approachingTransfer`/`transferring`/
/// `approachingDestination`). Never advances the trip's own station index —
/// this is a cosmetic map position only; real progress is decided natively
/// by `TripProgressEngine` from continuous GPS proximity (see
/// `ActiveTripController._refreshFromNative`), never from this controller.
///
/// Fed by [latestNativeGpsFixProvider], written by `ActiveTripController`'s
/// native-sync poll (~4s) with the same continuous fix the trip's
/// distance/speed are tracked from — so this marker moves as smoothly as the
/// odometer does. Watching that provider (rather than `ActiveTripController`
/// calling a method on this controller's notifier directly) is deliberate:
/// this controller already `ref.watch`es `activeTripControllerProvider`, so
/// the reverse call would form a circular dependency — see
/// `latestNativeGpsFixProvider`'s doc comment for the concrete crash that
/// shipped before this was caught live on-device. A monotonic-timestamp
/// guard drops any out-of-order emission.
class LiveTripPositionController extends Notifier<LatLng?> {
  Timer? _fallbackTimer;
  _GpsFix? _lastGpsFix;

  @override
  LatLng? build() {
    final session = ref.watch(activeTripControllerProvider);
    final stationsAsync = ref.watch(stationListProvider);
    final nativeFix = ref.watch(latestNativeGpsFixProvider);
    ref.onDispose(() {
      _fallbackTimer?.cancel();
    });

    if (session == null || !_isOnBoardPhase(session.state)) {
      _lastGpsFix = null;
      _fallbackTimer?.cancel();
      _fallbackTimer = null;
      return null;
    }

    if (nativeFix != null) {
      final existing = _lastGpsFix;
      if (existing == null || nativeFix.at.isAfter(existing.at)) {
        _lastGpsFix = _GpsFix(
          LatLng(nativeFix.latitude, nativeFix.longitude),
          nativeFix.at,
          speedMetersPerSecond: nativeFix.speedMetersPerSecond,
          bearingDegrees: nativeFix.bearingDegrees,
        );
      }
    }

    _fallbackTimer ??= Timer.periodic(_fallbackRefreshInterval, (_) {
      final current = ref.read(activeTripControllerProvider);
      if (current == null || !_isOnBoardPhase(current.state)) {
        return;
      }
      state = _computePosition(current, ref.read(stationListProvider).value);
    });

    return _computePosition(session, stationsAsync.value);
  }

  bool _isOnBoardPhase(ActiveTripState state) => switch (state) {
    ActiveTripState.onBoard ||
    ActiveTripState.approachingTransfer ||
    ActiveTripState.transferring ||
    ActiveTripState.approachingDestination => true,
    _ => false,
  };

  LatLng? _computePosition(ActiveTripSession session, List<Station>? stations) {
    if (stations == null || stations.isEmpty) {
      return null;
    }
    final currentId = session.currentStationId;
    final nextId = session.nextStationId;
    if (currentId == null || nextId == null) {
      // Last station on the route (e.g. about to arrive) — nothing to
      // project onto, just show the last confirmed station itself.
      final byId = {for (final s in stations) s.id: s};
      final current = currentId != null ? byId[currentId] : null;
      return current == null ? null : LatLng(current.latitude, current.longitude);
    }
    final byId = {for (final s in stations) s.id: s};
    final current = byId[currentId];
    final next = byId[nextId];
    if (current == null || next == null) {
      return null;
    }
    final a = LatLng(current.latitude, current.longitude);
    final b = LatLng(next.latitude, next.longitude);

    final now = ref.read(clockProvider).now();
    final fix = _lastGpsFix;
    if (fix != null) {
      final age = now.difference(fix.at);
      if (age <= _gpsStaleAfter) {
        return _projectOntoSegment(fix.point, a, b);
      }
      if (age <= _deadReckoningStaleAfter &&
          fix.speedMetersPerSecond != null &&
          fix.speedMetersPerSecond! > 0 &&
          fix.bearingDegrees != null) {
        final extrapolatedMeters = fix.speedMetersPerSecond! * age.inSeconds;
        final projected = destinationPoint(
          fix.point.latitude,
          fix.point.longitude,
          fix.bearingDegrees!,
          extrapolatedMeters,
        );
        return _projectOntoSegment(
          LatLng(projected.$1, projected.$2),
          a,
          b,
        );
      }
    }

    // Fallback: schedule-based interpolation, never GPS-derived, purely
    // cosmetic — real station progress stays native-GPS-driven regardless.
    final elapsed = now.difference(session.updatedAt);
    final hopDuration = _scheduledHopDuration(session);
    final fraction = hopDuration.inMilliseconds <= 0
        ? 0.0
        : (elapsed.inMilliseconds / hopDuration.inMilliseconds).clamp(0.0, 1.0);
    return LatLng(
      a.latitude + (b.latitude - a.latitude) * fraction,
      a.longitude + (b.longitude - a.longitude) * fraction,
    );
  }

  /// Approximates the scheduled travel time for the current station→next
  /// hop as the current rail leg's total duration spread evenly across its
  /// hops — the schedule data available doesn't carry a per-intermediate
  /// stop timetable, and this fallback is cosmetic UI only (never used to
  /// advance the trip), so a uniform average is an accepted approximation.
  Duration _scheduledHopDuration(ActiveTripSession session) {
    final leg = session.currentRailLeg;
    if (leg == null || leg.stationIds.length < 2) {
      return const Duration(minutes: 3);
    }
    final totalDuration = leg.arrivalAt.difference(leg.departureAt);
    final hops = leg.stationIds.length - 1;
    if (hops <= 0 || totalDuration.inMilliseconds <= 0) {
      return const Duration(minutes: 3);
    }
    return Duration(milliseconds: totalDuration.inMilliseconds ~/ hops);
  }

  /// Simple point-to-segment linear projection in lat/lng space, clamped to
  /// the segment (0-1) — a documented flat-plane approximation, adequate at
  /// the scale of adjacent-station distances on this network.
  LatLng _projectOntoSegment(LatLng point, LatLng a, LatLng b) {
    final dx = b.longitude - a.longitude;
    final dy = b.latitude - a.latitude;
    final lengthSquared = dx * dx + dy * dy;
    if (lengthSquared == 0) {
      return a;
    }
    final t =
        (((point.longitude - a.longitude) * dx) +
            ((point.latitude - a.latitude) * dy)) /
        lengthSquared;
    final clamped = t.clamp(0.0, 1.0);
    return LatLng(a.latitude + clamped * dy, a.longitude + clamped * dx);
  }
}

final liveTripPositionControllerProvider =
    NotifierProvider<LiveTripPositionController, LatLng?>(
      LiveTripPositionController.new,
    );
