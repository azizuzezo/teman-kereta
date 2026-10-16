import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import 'device_status.dart';

class GpsSnapshot {
  const GpsSnapshot({required this.serviceEnabled, required this.permission});

  final bool serviceEnabled;
  final GpsPermission permission;
}

typedef GpsProbe = Future<GpsSnapshot> Function();

/// Reads (never requests) the location service and permission state.
final gpsProbeProvider = Provider<GpsProbe>((ref) {
  return () async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    final permission = await Geolocator.checkPermission();
    return GpsSnapshot(
      serviceEnabled: serviceEnabled,
      permission: switch (permission) {
        LocationPermission.always ||
        LocationPermission.whileInUse => GpsPermission.granted,
        LocationPermission.deniedForever => GpsPermission.deniedForever,
        _ => GpsPermission.denied,
      },
    );
  };
});

class GpsStatus {
  const GpsStatus({this.level});

  /// Null until the first read finishes.
  final GpsLevel? level;
}

/// Whether location services are on and the app may use them. Read-only:
/// asking for permission stays in the explained flow of
/// `NearestStationController.requestPermissionAndRefresh`.
class GpsStatusController extends Notifier<GpsStatus> {
  @override
  GpsStatus build() => const GpsStatus();

  Future<void> refresh() async {
    GpsLevel level;
    try {
      final snapshot = await ref.read(gpsProbeProvider)();
      level = classifyGps(
        serviceEnabled: snapshot.serviceEnabled,
        permission: snapshot.permission,
      );
    } on Object {
      level = GpsLevel.servicesOff;
    }
    if (ref.mounted && level != state.level) {
      state = GpsStatus(level: level);
    }
  }
}

final gpsStatusProvider = NotifierProvider<GpsStatusController, GpsStatus>(
  GpsStatusController.new,
);
