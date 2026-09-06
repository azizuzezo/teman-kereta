import 'dart:math' as math;

/// Straight-line (haversine) distance in meters between two coordinates.
double haversineMeters(double lat1, double lon1, double lat2, double lon2) {
  const earthRadiusMeters = 6371000.0;
  final dLat = _degToRad(lat2 - lat1);
  final dLon = _degToRad(lon2 - lon1);
  final a =
      math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_degToRad(lat1)) *
          math.cos(_degToRad(lat2)) *
          math.sin(dLon / 2) *
          math.sin(dLon / 2);
  final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  return earthRadiusMeters * c;
}

double _degToRad(double degrees) => degrees * (math.pi / 180);
double _radToDeg(double radians) => radians * (180 / math.pi);

/// Initial great-circle bearing from point 1 to point 2, in degrees [0, 360).
double bearingDegrees(double lat1, double lon1, double lat2, double lon2) {
  final phi1 = _degToRad(lat1);
  final phi2 = _degToRad(lat2);
  final dLon = _degToRad(lon2 - lon1);
  final y = math.sin(dLon) * math.cos(phi2);
  final x =
      math.cos(phi1) * math.sin(phi2) -
      math.sin(phi1) * math.cos(phi2) * math.cos(dLon);
  final theta = math.atan2(y, x);
  return (_radToDeg(theta) + 360) % 360;
}

/// Projects a point [distanceMeters] along [bearingDeg] from (lat, lon) —
/// used for dead-reckoning extrapolation when a fresh GPS fix isn't
/// available. Returns (latitude, longitude).
(double, double) destinationPoint(
  double lat,
  double lon,
  double bearingDeg,
  double distanceMeters,
) {
  const earthRadiusMeters = 6371000.0;
  final angularDistance = distanceMeters / earthRadiusMeters;
  final bearingRad = _degToRad(bearingDeg);
  final phi1 = _degToRad(lat);
  final lambda1 = _degToRad(lon);

  final phi2 = math.asin(
    math.sin(phi1) * math.cos(angularDistance) +
        math.cos(phi1) * math.sin(angularDistance) * math.cos(bearingRad),
  );
  final lambda2 =
      lambda1 +
      math.atan2(
        math.sin(bearingRad) * math.sin(angularDistance) * math.cos(phi1),
        math.cos(angularDistance) - math.sin(phi1) * math.sin(phi2),
      );
  return (_radToDeg(phi2), _radToDeg(lambda2));
}

String formatDistanceMeters(double meters) {
  if (meters >= 1000) {
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }
  return '${meters.round()} m';
}

String formatSpeedKmh(double? kmh) {
  if (kmh == null || kmh.isNaN || kmh < 0) {
    return '-';
  }
  return '${kmh.round()} km/j';
}

String formatDuration(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  final seconds = duration.inSeconds.remainder(60);
  if (hours > 0) {
    return '${hours}j ${minutes.toString().padLeft(2, '0')}m';
  }
  if (minutes > 0) {
    return '$minutes menit';
  }
  return '$seconds detik';
}
