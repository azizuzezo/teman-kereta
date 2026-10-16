import '../../core/utils/geo.dart';
import '../entities/transit_models.dart';
import 'travel_estimate.dart';

class StationDistance {
  const StationDistance({
    required this.station,
    required this.distanceMeters,
    required this.walkingMinutes,
    this.rideMinutes = 1,
  });

  final Station station;
  final double distanceMeters;
  final int walkingMinutes;

  /// Perkiraan naik kendaraan (ojek/motor) dalam kota. See [TravelSpeeds].
  final int rideMinutes;

  TravelEstimate get estimate => TravelEstimate(
    distanceMeters: distanceMeters,
    walkMinutes: walkingMinutes,
    rideMinutes: rideMinutes,
  );
}

/// Ranks stations by straight-line (haversine) distance from a position.
/// Walk and vehicle times come from [estimateTravel]: rough estimates, since
/// real routed directions would need a routing engine this app doesn't have.
class NearestStationFinder {
  const NearestStationFinder();

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
    final estimate = estimateTravel(meters);
    return StationDistance(
      station: station,
      distanceMeters: meters,
      walkingMinutes: estimate.walkMinutes,
      rideMinutes: estimate.rideMinutes,
    );
  }
}
