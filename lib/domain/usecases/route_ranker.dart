import '../entities/transit_models.dart';

class RouteWeights {
  const RouteWeights({
    this.waitingPenalty = 1.0,
    this.transferPenalty = 12.0,
    this.walkingPenalty = 0.015,
    this.disruptionPenalty = 30.0,
  });

  final double waitingPenalty;
  final double transferPenalty;
  final double walkingPenalty;
  final double disruptionPenalty;
}

class RouteRanker {
  const RouteRanker({this.weights = const RouteWeights()});

  final RouteWeights weights;

  List<TransitTrip> rank(List<TransitTrip> trips, DateTime requestedAt) {
    final ranked = List<TransitTrip>.of(trips);
    ranked.sort((a, b) {
      return cost(a, requestedAt).compareTo(cost(b, requestedAt));
    });
    return ranked;
  }

  double cost(TransitTrip trip, DateTime requestedAt) {
    final travelTime = trip.durationMinutes.toDouble();
    final waitingMinutes = trip.departureAt
        .difference(requestedAt)
        .inMinutes
        .clamp(0, 24 * 60)
        .toDouble();
    final disruption = trip.serviceStatus == ServiceStatus.normal ? 0 : 1;

    return travelTime +
        (waitingMinutes * weights.waitingPenalty) +
        (trip.transfers * weights.transferPenalty) +
        (trip.walkingMeters * weights.walkingPenalty) +
        (disruption * weights.disruptionPenalty);
  }
}
