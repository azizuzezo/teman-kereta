// Pure classification for the Home "Status perangkat" tiles. No I/O here so
// the thresholds are unit-tested; the probes live in
// `internet_status_controller.dart` and `gps_status_controller.dart`.

/// How good the internet connection is, from a measured round trip.
enum LatencyLevel { good, slow, bad, offline }

/// Round trips below this are "baik" (hijau).
const int latencyGoodBelowMs = 300;

/// Round trips up to and including this are "lambat" (kuning); above is red.
const int latencySlowUpToMs = 800;

LatencyLevel classifyLatency({required bool hasConnection, int? latencyMs}) {
  if (!hasConnection) {
    return LatencyLevel.offline;
  }
  if (latencyMs == null || latencyMs < 0) {
    // Connected to a network but the probe timed out or failed.
    return LatencyLevel.bad;
  }
  if (latencyMs < latencyGoodBelowMs) {
    return LatencyLevel.good;
  }
  if (latencyMs <= latencySlowUpToMs) {
    return LatencyLevel.slow;
  }
  return LatencyLevel.bad;
}

String latencyLabel(LatencyLevel level) => switch (level) {
  LatencyLevel.good => 'Baik',
  LatencyLevel.slow => 'Lambat',
  LatencyLevel.bad => 'Buruk',
  LatencyLevel.offline => 'Tidak ada koneksi',
};

String formatLatency(int? latencyMs) =>
    latencyMs == null ? 'Tidak merespons' : '$latencyMs ms';

/// Location permission, reduced to what the UI can act on.
enum GpsPermission { granted, denied, deniedForever }

enum GpsLevel { ready, servicesOff, permissionDenied, permissionBlocked }

GpsLevel classifyGps({
  required bool serviceEnabled,
  required GpsPermission permission,
}) {
  if (!serviceEnabled) {
    return GpsLevel.servicesOff;
  }
  return switch (permission) {
    GpsPermission.granted => GpsLevel.ready,
    GpsPermission.denied => GpsLevel.permissionDenied,
    GpsPermission.deniedForever => GpsLevel.permissionBlocked,
  };
}

bool gpsNeedsAction(GpsLevel level) => level != GpsLevel.ready;
