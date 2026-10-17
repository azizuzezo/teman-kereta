import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/notifications/local_notification_service.dart';
import '../../../domain/entities/active_trip.dart';
import '../../active_trip/presentation/active_trip_controller.dart';
import '../../live_map/presentation/native_gps_fix.dart';
import '../../settings/presentation/settings_controller.dart';
import '../data/intercity_repository.dart';
import '../domain/intercity_eta.dart';
import '../domain/intercity_reminder_planner.dart';
import '../domain/intercity_trip.dart';

class IntercityRideState {
  const IntercityRideState({
    this.tripId,
    this.serviceName,
    this.destinationName,
    this.eta,
    this.firedKm = const <int>{},
  });

  /// The active intercity trip this belongs to, or null when none is running.
  final String? tripId;
  final String? serviceName;
  final String? destinationName;

  /// The latest estimate, or null until the first GPS fix has been placed.
  final IntercityEta? eta;

  /// The "[n] kilometer lagi" reminders already announced on this ride.
  final Set<int> firedKm;

  bool get isActive => tripId != null;

  IntercityRideState copyWith({IntercityEta? eta, Set<int>? firedKm}) =>
      IntercityRideState(
        tripId: tripId,
        serviceName: serviceName,
        destinationName: destinationName,
        eta: eta ?? this.eta,
        firedKm: firedKm ?? this.firedKm,
      );
}

/// Runs the live estimate and the 30 / 15 / 10 km reminders of an
/// intercity ride.
///
/// It follows the active trip session and the GPS fixes the native tracker
/// already delivers (about every 4 s); it adds no second location stream. It
/// is mounted for the whole app (see `MainShell`) so the reminders keep firing
/// whichever screen is open.
class IntercityRideController extends Notifier<IntercityRideState> {
  IntercityEtaEstimator? _estimator;
  IntercityReminderPlanner? _planner;
  String? _tripId;
  DateTime? _lastFixAt;
  int _generation = 0;

  @override
  IntercityRideState build() {
    ref.listen<ActiveTripSession?>(
      activeTripControllerProvider,
      (previous, next) => unawaited(_onSession(next)),
      fireImmediately: true,
    );
    ref.listen<NativeGpsFix?>(latestNativeGpsFixProvider, (previous, fix) {
      if (fix != null) _onFix(fix);
    });
    return const IntercityRideState();
  }

  bool _tracks(ActiveTripSession session) => switch (session.state) {
    ActiveTripState.onBoard ||
    ActiveTripState.approachingTransfer ||
    ActiveTripState.transferring ||
    ActiveTripState.approachingDestination => true,
    _ => false,
  };

  Future<void> _onSession(ActiveTripSession? session) async {
    final tripId = session?.trip.id;
    if (session == null ||
        !_tracks(session) ||
        !tripId!.startsWith(IntercityTripRef.prefix)) {
      // `state` is not readable yet while build() is still running (this is
      // called with fireImmediately), so decide from the fields.
      if (_estimator != null) _reset();
      return;
    }
    if (tripId == _tripId && _estimator != null) return;
    final ref0 = IntercityTripRef.tryParse(tripId);
    if (ref0 == null) return;

    final generation = ++_generation;
    final catalog = await ref.read(intercityCatalogProvider.future);
    if (!ref.mounted || generation != _generation) return;
    final service = ref0.isCustom
        ? (catalog.stations.containsKey(ref0.boardingCode) &&
                  catalog.stations.containsKey(ref0.destinationCode)
              ? catalog.serviceForCustomRide(
                  ref0.boardingCode,
                  ref0.destinationCode,
                )
              : null)
        : catalog.serviceById(ref0.serviceId);
    final destination = catalog.stations[ref0.destinationCode];
    if (service == null ||
        destination == null ||
        !service.connects(ref0.boardingCode, ref0.destinationCode)) {
      return;
    }
    _estimator = IntercityEtaEstimator(
      service: service,
      boardingCode: ref0.boardingCode,
      destinationCode: ref0.destinationCode,
      destinationLatitude: destination.latitude,
      destinationLongitude: destination.longitude,
    );
    _planner = IntercityReminderPlanner();
    _tripId = tripId;
    _lastFixAt = null;
    state = IntercityRideState(
      tripId: tripId,
      serviceName: ref0.customName ?? service.name,
      destinationName: destination.name,
    );
    // A fix may already be waiting (restored trip, or the app was reopened).
    final waiting = ref.read(latestNativeGpsFixProvider);
    if (waiting != null) _onFix(waiting);
  }

  void _reset() {
    _generation += 1;
    _estimator = null;
    _planner = null;
    _tripId = null;
    _lastFixAt = null;
    state = const IntercityRideState();
  }

  void _onFix(NativeGpsFix fix) {
    final estimator = _estimator;
    final planner = _planner;
    if (estimator == null || planner == null) return;
    // The tracker is polled more often than it produces fixes.
    if (_lastFixAt != null && !fix.at.isAfter(_lastFixAt!)) return;
    _lastFixAt = fix.at;

    final speed = fix.speedMetersPerSecond;
    final eta = estimator.update(
      latitude: fix.latitude,
      longitude: fix.longitude,
      at: fix.at,
      speedKmh: speed == null || speed < 0 ? null : speed * 3.6,
    );
    // Rail distance left (the fix is projected onto the train's own track),
    // not the straight line and not a guessed time.
    final due = planner.onRemainingKm(eta.remainingKm);
    var fired = state.firedKm;
    if (due != null) {
      fired = <int>{...fired, ...planner.thresholds.where(planner.hasFired)};
      final settings = ref.read(settingsControllerProvider);
      unawaited(
        ref
            .read(localNotificationServiceProvider)
            .showIntercityDistanceAlert(
              km: due,
              destination: state.destinationName ?? 'tujuan',
              vibrate: settings.vibrationEnabled,
              sound: settings.soundEnabled,
            ),
      );
    }
    state = state.copyWith(eta: eta, firedKm: fired);
  }
}

final intercityRideControllerProvider =
    NotifierProvider<IntercityRideController, IntercityRideState>(
      IntercityRideController.new,
    );
