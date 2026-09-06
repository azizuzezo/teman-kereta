import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A raw GPS fix from the native continuous tracker (`TripProgressEngine`),
/// as read by `ActiveTripController._refreshFromNative`.
class NativeGpsFix {
  const NativeGpsFix({
    required this.latitude,
    required this.longitude,
    required this.at,
    this.speedMetersPerSecond,
    this.bearingDegrees,
  });

  final double latitude;
  final double longitude;
  final DateTime at;
  final double? speedMetersPerSecond;
  final double? bearingDegrees;
}

/// Standalone, dependency-free holder for the latest native GPS fix —
/// written by `ActiveTripController`, watched by `LiveTripPositionController`.
///
/// Deliberately not a method call from one controller's notifier into the
/// other's (that was the original design): `LiveTripPositionController`
/// already `ref.watch`es `activeTripControllerProvider` for the session, so
/// `ActiveTripController` turning around and calling
/// `ref.read(liveTripPositionControllerProvider.notifier)` forms A→B→A —
/// Riverpod's `_debugAssertCanDependOn` throws `CircularDependencyError` on
/// every such call (confirmed live on-device: fired on every ~4s native-sync
/// tick, silently discarding every GPS update the live map should have
/// gotten). Routing the fix through this neutral provider — written by one
/// side, watched by the other — removes the cycle entirely.
class LatestNativeGpsFixController extends Notifier<NativeGpsFix?> {
  @override
  NativeGpsFix? build() => null;

  void set(NativeGpsFix fix) {
    state = fix;
  }
}

final latestNativeGpsFixProvider =
    NotifierProvider<LatestNativeGpsFixController, NativeGpsFix?>(
      LatestNativeGpsFixController.new,
    );

/// The native tracker's own view of its GPS health, mirrored from
/// `NativeStateStore.ACTIVE_LOCATION_STATUS`: `"tracking"` while fixes are
/// arriving, `"waiting_for_location"` right after (re)subscribing,
/// `"signal_lost"` once the service's watchdog has gone 90s without one,
/// `"permission_missing"` if location access was revoked mid-trip.
///
/// Surfaced on the active-trip screen so "the app is stuck" is visibly
/// distinguishable from "the train hasn't reached the next station yet" —
/// the two used to look identical.
class TripLocationStatusController extends Notifier<String?> {
  @override
  String? build() => null;

  void set(String? status) {
    state = status;
  }
}

final tripLocationStatusProvider =
    NotifierProvider<TripLocationStatusController, String?>(
      TripLocationStatusController.new,
    );
