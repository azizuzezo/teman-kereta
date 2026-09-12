import 'package:flutter_riverpod/flutter_riverpod.dart';

/// One-shot "your phone's battery settings might stop tracking mid-trip"
/// nudge — set when [ActiveTripController.start] sees native's
/// `NativeTripService.batteryOptimizationWarning`, cleared as soon as it's
/// been shown once so it never repeats for the rest of that trip.
///
/// The trip itself never depends on this: it's purely informational, a
/// chance to send the rider to Settings before an OEM battery manager kills
/// `ActiveTripLocationService` outright, rather than a trip going silently
/// quiet with no explanation.
class TripBatteryWarningController extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool value) => state = value;
}

final tripBatteryWarningProvider =
    NotifierProvider<TripBatteryWarningController, bool>(
      TripBatteryWarningController.new,
    );
