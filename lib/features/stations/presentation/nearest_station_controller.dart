import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../../data/providers/provider_registry.dart';
import '../../../domain/entities/transit_models.dart';
import '../../../domain/usecases/nearest_station_finder.dart';

enum FixStatus {
  /// A position was read.
  ok,

  /// Location services are off or permission is not granted: nothing to read.
  unavailable,

  /// Services and permission are fine but this attempt got no fix (timeout,
  /// no signal indoors). A later attempt may succeed.
  failed,
}

class FixReading {
  const FixReading.ok(this.latitude, this.longitude) : status = FixStatus.ok;
  const FixReading.unavailable()
    : status = FixStatus.unavailable,
      latitude = null,
      longitude = null;
  const FixReading.failed()
    : status = FixStatus.failed,
      latitude = null,
      longitude = null;

  final FixStatus status;
  final double? latitude;
  final double? longitude;
}

typedef FixReader = Future<FixReading> Function();

/// One-shot position read. Never calls [Geolocator.requestPermission].
final fixReaderProvider = Provider<FixReader>((ref) {
  return () async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return const FixReading.unavailable();
      }
      final permission = await Geolocator.checkPermission();
      final granted =
          permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse;
      if (!granted) {
        return const FixReading.unavailable();
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 8),
        ),
      );
      return FixReading.ok(position.latitude, position.longitude);
    } on Object {
      return const FixReading.failed();
    }
  };
});

/// Ranks stations by real distance from the device's current position. A
/// single one-shot fix, not a continuous stream — PRD §7/§31 reserve
/// continuous high-frequency GPS for an active trip, not passive "what's
/// nearby" lookups. Never calls [Geolocator.requestPermission] itself: PRD
/// §10 requires every permission dialog to be explained first, and that
/// explanation already lives in onboarding/settings, not here.
///
/// Home calls [refreshQuietly] every 10 s, but only while the Home tab is
/// visible and the app is in the foreground; nothing here schedules anything.
class NearestStationController extends AsyncNotifier<List<StationDistance>> {
  bool _quietBusy = false;

  @override
  Future<List<StationDistance>> build() async {
    final stations = await ref.watch(stationListProvider.future);
    final reading = await ref.read(fixReaderProvider)();
    if (reading.status != FixStatus.ok) {
      return const <StationDistance>[];
    }
    return _rank(stations, reading);
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => build());
  }

  /// Re-reads the position and re-ranks without ever showing a loading state,
  /// so the Home card does not flicker every 10 s. A failed attempt keeps the
  /// last known ranking; losing permission clears it; an unchanged ranking
  /// emits nothing.
  Future<void> refreshQuietly() async {
    if (_quietBusy || state.isLoading || state.hasError) {
      return;
    }
    final stations = ref.read(stationListProvider).value;
    if (stations == null) {
      return;
    }
    _quietBusy = true;
    try {
      final reading = await ref.read(fixReaderProvider)();
      if (!ref.mounted) {
        return;
      }
      switch (reading.status) {
        case FixStatus.failed:
          return;
        case FixStatus.unavailable:
          if (state.value?.isNotEmpty ?? false) {
            state = const AsyncValue.data(<StationDistance>[]);
          }
        case FixStatus.ok:
          final ranked = _rank(stations, reading);
          if (_signature(ranked) != _signature(state.value)) {
            state = AsyncValue.data(ranked);
          }
      }
    } finally {
      _quietBusy = false;
    }
  }

  List<StationDistance> _rank(List<Station> stations, FixReading reading) {
    return const NearestStationFinder().rank(
      stations,
      reading.latitude!,
      reading.longitude!,
    );
  }

  /// Nearest five stations with distances rounded to 10 m: GPS jitter below
  /// that is noise and must not rebuild the UI.
  String _signature(List<StationDistance>? ranked) {
    if (ranked == null) {
      return '';
    }
    return ranked
        .take(5)
        .map((e) => '${e.station.id}:${(e.distanceMeters / 10).round()}')
        .join(',');
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
      final granted =
          permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse;
      if (granted) {
        await refresh();
      }
      return granted;
    } on Object {
      return false;
    }
  }
}

final nearestStationControllerProvider =
    AsyncNotifierProvider<NearestStationController, List<StationDistance>>(
      NearestStationController.new,
    );
