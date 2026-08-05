import '../entities/transit_models.dart';

abstract interface class TransitScheduleProvider {
  Future<List<TransitTrip>> searchTrips(TripSearchQuery query);

  Future<List<Departure>> getStationDepartures(
    String stationId,
    DateTime time,
  );
}

abstract interface class TransitRealtimeProvider {
  Stream<List<VehiclePosition>> watchVehiclePositions();

  Stream<List<TripUpdate>> watchTripUpdates();

  Stream<List<ServiceAlert>> watchServiceAlerts();
}

abstract interface class PlacesProvider {
  Future<List<NearbyPlace>> getNearbyPlaces(
    double latitude,
    double longitude,
    PlaceFilter filter,
  );
}

class TripUpdate {
  const TripUpdate({
    required this.tripId,
    required this.stationId,
    required this.updatedAt,
    this.arrivalDelaySeconds = 0,
    this.departureDelaySeconds = 0,
  });

  final String tripId;
  final String stationId;
  final int arrivalDelaySeconds;
  final int departureDelaySeconds;
  final DateTime updatedAt;
}

abstract interface class StationProvider {
  Future<List<Station>> getStations();

  Future<Station?> getStation(String stationId);
}
