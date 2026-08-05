import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../../data/providers/provider_registry.dart';
import '../../../domain/usecases/nearest_station_finder.dart';

/// Ranks stations by real distance from the device's current position. A
/// single one-shot fix, not a continuous stream — PRD §7/§31 reserve
/// continuous high-frequency GPS for an active trip, not passive "what's
/// nearby" lookups. Never calls [Geolocator.requestPermission] itself: PRD
/// §10 requires every permission dialog to be explained first, and that
/// explanation already lives in onboarding/settings, not here.
class NearestStationController extends AsyncNotifier<List<StationDistance>> {
  @override
  Future<List<StationDistance>> build() async {
    final stations = await ref.watch(stationListProvider.future);
    final position = await _currentPosition();
    if (position == null) {
      return const <StationDistance>[];
    }
    return const NearestStationFinder().rank(
      stations,
      position.latitude,
      position.longitude,
    );
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => build());
  }

  /// Explicitly requests the location permission — only call this from a
  /// button whose label/subtitle already explains why, matching the
  /// onboarding location step's pattern.
  Future<bool> requestPermissionAndRefresh() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return false;
      }
      final permission = await Geolocator.requestPermission();
      final granted = permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse;
      if (granted) {
        await refresh();
      }
      return granted;
    } on Object {
      return false;
    }
  }

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
}

final nearestStationControllerProvider =
    AsyncNotifierProvider<NearestStationController, List<StationDistance>>(
      NearestStationController.new,
    );
