import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/notifications/local_notification_service.dart';
import '../../../data/providers/demo_data.dart';
import '../../../domain/entities/active_trip.dart';
import '../../../domain/entities/ride_detection.dart';
import '../../settings/presentation/settings_controller.dart';
import 'ride_detection_controller.dart';

/// Polls [RideDetectionController] on a low-cost timer (a SharedPreferences
/// read via platform channel, never GPS) while the feature is enabled, and
/// routes to the confirmation page as soon as a new assessment appears.
/// Wraps the whole app shell so it keeps watching across every tab.
class RideDetectionWatcher extends ConsumerStatefulWidget {
  const RideDetectionWatcher({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<RideDetectionWatcher> createState() =>
      _RideDetectionWatcherState();
}

class _RideDetectionWatcherState extends ConsumerState<RideDetectionWatcher>
    with WidgetsBindingObserver {
  static const _pollInterval = Duration(seconds: 25);

  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _reschedule(enabled: ref.read(settingsControllerProvider).rideDetectionEnabled);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(ref.read(rideDetectionControllerProvider.notifier).checkNow());
    }
  }

  void _reschedule({required bool enabled}) {
    _timer?.cancel();
    _timer = null;
    if (!enabled) {
      return;
    }
    _timer = Timer.periodic(_pollInterval, (_) {
      unawaited(ref.read(rideDetectionControllerProvider.notifier).checkNow());
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(
      settingsControllerProvider.select((settings) => settings.rideDetectionEnabled),
      (previous, enabled) => _reschedule(enabled: enabled),
    );
    ref.listen(rideDetectionControllerProvider, (previous, next) {
      final assessment = next?.assessment;
      if (next?.state != ActiveTripState.confirmingTrip || assessment == null) {
        return;
      }
      if (previous?.assessment?.exitedAt == assessment.exitedAt) {
        return;
      }
      final stationName = demoStations
              .where((station) => station.id == assessment.stationId)
              .firstOrNull
              ?.name ??
          assessment.stationId;
      unawaited(
        ref.read(localNotificationServiceProvider).showRideDetectedAlert(
          stationName: stationName,
          isStrongMatch: assessment.level == RideDetectionLevel.strong,
        ),
      );
      GoRouter.of(context).push('/ride-detection');
    });
    return widget.child;
  }
}
