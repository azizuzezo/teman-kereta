import 'dart:math' as math;

import '../entities/transit_models.dart';

class StationDistance {
  const StationDistance({
    required this.station,
    required this.distanceMeters,
    required this.walkingMinutes,
  });

  final Station station;
  final double distanceMeters;
  final int walkingMinutes;
}

/// Ranks stations by straight-line (haversine) distance from a position.
/// Walking time is a rough estimate from an average pace — real routed
/// walking directions would need a routing engine this app doesn't have.
class NearestStationFinder {
  const NearestStationFinder({this.averageWalkingMetersPerMinute = 83.3});

  final double averageWalkingMetersPerMinute;

  List<StationDistance> rank(
    List<Station> stations,
    double latitude,
    double longitude,
  ) {
    final ranked = stations
        .map(
          (station) => _distanceTo(station, latitude, longitude),
        )
        .toList(growable: false);
    ranked.sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));
    return ranked;
  }

  StationDistance _distanceTo(Station station, double latitude, double longitude) {
    final meters = _haversineMeters(
      latitude,
      longitude,
      station.latitude,
      station.longitude,
    );
    final minutes = (meters / averageWalkingMetersPerMinute).ceil();
    return StationDistance(
      station: station,
      distanceMeters: meters,
      walkingMinutes: minutes < 1 ? 1 : minutes,
    );
  }

  static double _haversineMeters(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const earthRadiusMeters = 6371000.0;
    final dLat = _degToRad(lat2 - lat1);
    final dLon = _degToRad(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degToRad(lat1)) *
            math.cos(_degToRad(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusMeters * c;
  }

  static double _degToRad(double degrees) => degrees * (math.pi / 180);
}
