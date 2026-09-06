import '../../core/utils/geo.dart';
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
    final meters = haversineMeters(
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
}
