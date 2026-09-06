import 'package:geolocator/geolocator.dart';
import 'package:teman_kereta/core/notifications/local_notification_service.dart';
import 'package:teman_kereta/core/platform/native_trip_service.dart';
import 'package:teman_kereta/domain/entities/ride_detection.dart';

class FakeNotificationService implements LocalNotificationService {
  int stopAlerts = 0;
  int transferAlerts = 0;
  int transferApproachingAlerts = 0;
  int missedAlerts = 0;
  int arrivalAlerts = 0;
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
    bool log = true,
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
    bool log = true,
  }) async {
    transferAlerts += 1;
  }

  @override
  Future<void> showTransferApproachingAlert({
    required int remainingStops,
    required String stationName,
    required bool isDemo,
    bool vibrate = true,
    bool sound = true,
    bool log = true,
  }) async {
    transferApproachingAlerts += 1;
  }

  @override
  Future<void> showRemotePush({
    required String title,
    required String body,
  }) async {
    stopAlerts += 1;
  }

  @override
  Future<void> showMissedDestinationAlert({
    required String destination,
    required bool isDemo,
    bool vibrate = true,
    bool sound = true,
    bool log = true,
  }) async {
    missedAlerts += 1;
  }

  @override
  Future<void> showArrivalAlert({
    required String destination,
    required Duration duration,
    required double distanceMeters,
    bool vibrate = true,
    bool sound = true,
    bool log = true,
  }) async {
    arrivalAlerts += 1;
  }

  @override
  Future<void> showRideDetectedAlert({
    required String stationName,
    required bool isStrongMatch,
  }) async {
    rideDetectedAlerts += 1;
  }

  @override
  Future<void> showServiceDisruptionAlert({
    required String title,
    required String description,
  }) async {
    stopAlerts += 1;
  }
}

/// Stands in for the platform channel in tests: [getLastActivityEvent]
/// returns whatever was last assigned instead of hitting a real channel
/// (which would just resolve to null via [MissingPluginException] in a
/// test environment).
class FakeNativeTripService extends NativeTripService {
  ActivityEvent? activityEvent;

  @override
  Future<ActivityEvent?> getLastActivityEvent() async => activityEvent;

  @override
  Future<bool> requestActivityRecognitionUpdates() async => true;

  @override
  Future<bool> stopActivityRecognitionUpdates() async => true;
}

/// Stands in for `GeolocatorPlatform.instance` in tests: [position] is
/// returned by `getCurrentPosition` instead of hitting a real platform
/// channel (which would just throw `MissingPluginException`). Used to
/// simulate the rider being near/far from a station for
/// `RideDetectionController`'s real-time-GPS proximity checks (see
/// `checkNow` — this replaced the old native geofence ENTER/EXIT signal).
class FakeGeolocatorPlatform extends GeolocatorPlatform {
  bool serviceEnabled = true;
  LocationPermission permission = LocationPermission.whileInUse;
  Position? position;

  @override
  Future<bool> isLocationServiceEnabled() async => serviceEnabled;

  @override
  Future<LocationPermission> checkPermission() async => permission;

  @override
  Future<Position> getCurrentPosition({
    LocationSettings? locationSettings,
  }) async {
    final current = position;
    if (current == null) {
      throw StateError('FakeGeolocatorPlatform.position was never set');
    }
    return current;
  }
}

Position fakePosition(double latitude, double longitude) => Position(
  latitude: latitude,
  longitude: longitude,
  timestamp: DateTime.now(),
  accuracy: 5,
  altitude: 0,
  altitudeAccuracy: 0,
  heading: 0,
  headingAccuracy: 0,
  speed: 0,
  speedAccuracy: 0,
);
