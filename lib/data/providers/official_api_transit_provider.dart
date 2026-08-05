import 'package:dio/dio.dart';

import '../../core/network/api_client.dart';
import '../../domain/entities/transit_models.dart';
import '../../domain/providers/transit_providers.dart';
import 'polling_stream.dart';

/// Backs the app entirely with a self-hosted REST API (e.g. a Supabase Edge
/// Function or partner backend) rather than raw GTFS-Realtime protobuf.
/// Realtime endpoints are polled rather than pushed since there is no
/// WebSocket client in this codebase yet; this keeps behaviour identical to
/// [GtfsRealtimeTransitProvider] from the UI's point of view.
class OfficialApiTransitProvider
    implements
        TransitScheduleProvider,
        StationProvider,
        PlacesProvider,
        TransitRealtimeProvider {
  OfficialApiTransitProvider(
    this._client, {
    Duration pollInterval = const Duration(seconds: 30),
  }) {
    _vehicles = PollingBroadcaster<List<VehiclePosition>>(
      fetch: () => _getList('/vehicle-positions', VehiclePosition.fromJson),
      interval: pollInterval,
      onError: (_, _) {},
    );
    _tripUpdates = PollingBroadcaster<List<TripUpdate>>(
      fetch: () => _getList('/trip-updates', _tripUpdateFromJson),
      interval: pollInterval,
      onError: (_, _) {},
    );
    _alerts = PollingBroadcaster<List<ServiceAlert>>(
      fetch: () => _getList('/service-alerts', ServiceAlert.fromJson),
      interval: pollInterval,
      onError: (_, _) {},
    );
  }

  final ApiClient _client;
  late final PollingBroadcaster<List<VehiclePosition>> _vehicles;
  late final PollingBroadcaster<List<TripUpdate>> _tripUpdates;
  late final PollingBroadcaster<List<ServiceAlert>> _alerts;

  @override
  Future<List<Departure>> getStationDepartures(
    String stationId,
    DateTime time,
  ) {
    return _getList(
      '/departures',
      Departure.fromJson,
      queryParameters: <String, Object?>{
        'station_id': stationId,
        'at': time.toUtc().toIso8601String(),
      },
    );
  }

  @override
  Future<List<TransitTrip>> searchTrips(TripSearchQuery query) async {
    final response = await _client.dio.post<List<Object?>>(
      '/trips/search',
      data: query.toJson(),
    );
    return (response.data ?? <Object?>[])
        .whereType<Map<String, Object?>>()
        .map(TransitTrip.fromJson)
        .toList(growable: false);
  }

  @override
  Future<List<Station>> getStations() => _getList('/stations', Station.fromJson);

  @override
  Future<Station?> getStation(String stationId) async {
    try {
      final response = await _client.dio.get<Map<String, Object?>>(
        '/stations/$stationId',
      );
      final data = response.data;
      return data == null ? null : Station.fromJson(data);
    } on DioException catch (error) {
      if (error.response?.statusCode == 404) {
        return null;
      }
      rethrow;
    }
  }

  @override
  Future<List<NearbyPlace>> getNearbyPlaces(
    double latitude,
    double longitude,
    PlaceFilter filter,
  ) {
    return _getList(
      '/places',
      NearbyPlace.fromJson,
      queryParameters: <String, Object?>{
        'lat': latitude,
        'lon': longitude,
        if (filter.stationId != null) 'station_id': filter.stationId,
        if (filter.category != null) 'category': filter.category,
        'radius_meters': filter.radiusMeters,
      },
    );
  }

  @override
  Stream<List<VehiclePosition>> watchVehiclePositions() => _vehicles.stream;

  @override
  Stream<List<TripUpdate>> watchTripUpdates() => _tripUpdates.stream;

  @override
  Stream<List<ServiceAlert>> watchServiceAlerts() => _alerts.stream;

  Future<List<T>> _getList<T>(
    String path,
    T Function(Map<String, Object?> json) fromJson, {
    Map<String, Object?>? queryParameters,
  }) async {
    final response = await _client.dio.get<List<Object?>>(
      path,
      queryParameters: queryParameters,
    );
    return (response.data ?? <Object?>[])
        .whereType<Map<String, Object?>>()
        .map(fromJson)
        .toList(growable: false);
  }

  static TripUpdate _tripUpdateFromJson(Map<String, Object?> json) {
    return TripUpdate(
      tripId: json['tripId'] as String,
      stationId: json['stationId'] as String,
      arrivalDelaySeconds: json['arrivalDelaySeconds'] as int? ?? 0,
      departureDelaySeconds: json['departureDelaySeconds'] as int? ?? 0,
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  Future<void> dispose() async {
    await _vehicles.dispose();
    await _tripUpdates.dispose();
    await _alerts.dispose();
  }
}
