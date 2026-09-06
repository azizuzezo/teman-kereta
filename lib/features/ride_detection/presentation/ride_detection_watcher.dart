import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/notifications/local_notification_service.dart';
import '../../../core/updates/update_checker.dart';
import '../../../data/providers/demo_data.dart';
import '../../../data/providers/provider_registry.dart';
import '../../../domain/entities/active_trip.dart';
import '../../../domain/entities/ride_detection.dart';
import '../../active_trip/presentation/active_trip_controller.dart';
import '../../active_trip/presentation/trip_signal_gap_prompt.dart';
import '../../settings/presentation/settings_controller.dart';
import 'ride_detection_controller.dart';

/// Polls on a low-cost timer (a SharedPreferences read via platform
/// channel, never a continuous GPS stream — PRD §31) for
/// [RideDetectionController]'s pre-boarding detection while the setting is
/// on. Stands down entirely once a trip is confirmed — that trip's own
/// progress tracking runs continuously via native GPS instead (see
/// `ActiveTripController._refreshFromNative`), unrelated to this poll.
/// Routes to the confirmation page as soon as a new ride-detection
/// assessment appears. Wraps the whole app shell so it keeps watching
/// across every tab.
class RideDetectionWatcher extends ConsumerStatefulWidget {
  const RideDetectionWatcher({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<RideDetectionWatcher> createState() =>
      _RideDetectionWatcherState();
}

class _RideDetectionWatcherState extends ConsumerState<RideDetectionWatcher>
    with WidgetsBindingObserver, TripSignalGapPromptMixin {
  static const _pollInterval = Duration(seconds: 25);

  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _reschedule(enabled: _shouldPoll());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  bool _shouldPoll() {
    return ref.read(settingsControllerProvider).rideDetectionEnabled &&
        ref.read(activeTripControllerProvider) == null;
  }

  Future<void> _tick() async {
    if (ref.read(activeTripControllerProvider) != null) {
      return;
    }
    await ref.read(rideDetectionControllerProvider.notifier).checkNow();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_tick());
      // Pull whatever native decided while we were away, immediately
      // rather than on the next 4s sync — this is what makes the
      // "masih di kereta?" prompt appear as the app opens, and what
      // repaints a trip that advanced several stations in the background.
      unawaited(
        ref.read(activeTripControllerProvider.notifier).syncFromNativeNow(),
      );
      // Re-run the update check on every resume too, not just cold start —
      // so the "pembaruan tersedia" popup keeps reappearing on re-entry
      // until the user actually updates, rather than only being checked
      // once per app process lifetime.
      ref.invalidate(updateCheckerControllerProvider);
    }
  }

  void _reschedule({required bool enabled}) {
    _timer?.cancel();
    _timer = null;
    if (!enabled) {
      return;
    }
    _timer = Timer.periodic(_pollInterval, (_) => unawaited(_tick()));
  }

  @override
  Widget build(BuildContext context) {
    listenForSignalGapPrompts();
    ref.listen(updateCheckerControllerProvider, (previous, next) {
      if (next != null) {
        unawaited(showUpdateAvailableDialog(context, next));
      }
    });
    ref.listen(
      settingsControllerProvider.select((settings) => settings.rideDetectionEnabled),
      (previous, enabled) => _reschedule(enabled: _shouldPoll()),
    );
    ref.listen(activeTripControllerProvider, (previous, next) {
      _reschedule(enabled: _shouldPoll());
      // A trip now finishes itself the moment it reaches the destination
      // (`ActiveTripController._refreshFromNative`), which can happen while
      // the rider is on any screen — or not looking at all. Routing from
      // here, rather than from the button that used to be the only way to
      // complete a trip, is what makes the recap actually get shown.
      if (previous?.state != ActiveTripState.completed &&
          next?.state == ActiveTripState.completed) {
        GoRouter.of(context).go('/trip-complete');
      }
    });
    ref.listen(rideDetectionControllerProvider, (previous, next) {
      final assessment = next?.assessment;
      if (next?.state != ActiveTripState.confirmingTrip || assessment == null) {
        return;
      }
      if (previous?.assessment?.exitedAt == assessment.exitedAt) {
        return;
      }
      final stationName = ref
              .read(stationListProvider)
              .value
              ?.where((station) => station.id == assessment.stationId)
              .firstOrNull
              ?.name ??
          demoStations
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
