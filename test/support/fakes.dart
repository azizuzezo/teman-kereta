import 'package:teman_kereta/core/notifications/local_notification_service.dart';
import 'package:teman_kereta/core/platform/native_trip_service.dart';
import 'package:teman_kereta/domain/entities/ride_detection.dart';

class FakeNotificationService implements LocalNotificationService {
  int stopAlerts = 0;
  int transferAlerts = 0;
  int missedAlerts = 0;
  int rideDetectedAlerts = 0;

  @override
  void Function(String type, String title, String body)? get onShown => null;

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<void> showStopAlert({
    required int remainingStops,
    required String destination,
    required bool isDemo,
    bool vibrate = true,
    bool sound = true,
  }) async {
    stopAlerts += 1;
  }

  @override
  Future<void> showTransferAlert({
    required String stationName,
    required String? instruction,
    required bool isDemo,
    bool vibrate = true,
    bool sound = true,
  }) async {
    transferAlerts += 1;
  }

  @override
  Future<void> showMissedDestinationAlert({
    required String destination,
    required bool isDemo,
    bool vibrate = true,
    bool sound = true,
  }) async {
    missedAlerts += 1;
  }

  @override
  Future<void> showRideDetectedAlert({
    required String stationName,
    required bool isStrongMatch,
  }) async {
    rideDetectedAlerts += 1;
  }
}

/// Stands in for the platform channel in tests: [getLastGeofenceEvent] and
/// [getLastActivityEvent] return whatever was last assigned instead of
/// hitting a real channel (which would just resolve to null via
/// [MissingPluginException] in a test environment).
class FakeNativeTripService extends NativeTripService {
  GeofenceEvent? geofenceEvent;
  ActivityEvent? activityEvent;

  @override
  Future<GeofenceEvent?> getLastGeofenceEvent() async => geofenceEvent;

  @override
  Future<ActivityEvent?> getLastActivityEvent() async => activityEvent;

  @override
  Future<bool> requestActivityRecognitionUpdates() async => true;

  @override
  Future<bool> stopActivityRecognitionUpdates() async => true;

  @override
  Future<void> registerStationGeofences(
    List<Map<String, Object?>> stations,
  ) async {}

  @override
  Future<void> unregisterStationGeofences() async {}
}
