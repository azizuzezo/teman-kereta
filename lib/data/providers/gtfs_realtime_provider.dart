import 'package:dio/dio.dart';

import '../../domain/entities/transit_models.dart';
import '../../domain/providers/transit_providers.dart';
import 'gtfs_realtime_adapter.dart';
import 'polling_stream.dart';

/// Wires the (already-decoding) [GtfsRealtimeAdapter] to a live feed by
/// polling the configured GTFS-Realtime endpoints over HTTP. GTFS-Realtime
/// is a pull protocol (protobuf snapshots, not a push socket), so periodic
/// polling is the correct integration shape, not a workaround.
class GtfsRealtimeTransitProvider implements TransitRealtimeProvider {
  GtfsRealtimeTransitProvider({
    required this._dio,
    required String vehiclePositionsUrl,
    required this._tripUpdatesUrl,
    required this._alertsUrl,
    Duration pollInterval = const Duration(seconds: 30),
    this._adapter = const GtfsRealtimeAdapter(),
  }) : _vehiclePositionsUrl = vehiclePositionsUrl {
    _vehicles = PollingBroadcaster<List<VehiclePosition>>(
      fetch: _fetchVehiclePositions,
      interval: pollInterval,
      onError: (_, _) {},
    );
    _tripUpdates = PollingBroadcaster<List<TripUpdate>>(
      fetch: () => _fetchSnapshot(_tripUpdatesUrl).then((s) => s.tripUpdates),
      interval: pollInterval,
      onError: (_, _) {},
    );
    _alerts = PollingBroadcaster<List<ServiceAlert>>(
      fetch: () => _fetchSnapshot(_alertsUrl).then((s) => s.alerts),
      interval: pollInterval,
      onError: (_, _) {},
    );
  }

  final Dio _dio;
  final String _vehiclePositionsUrl;
  final String _tripUpdatesUrl;
  final String _alertsUrl;
  final GtfsRealtimeAdapter _adapter;
  late final PollingBroadcaster<List<VehiclePosition>> _vehicles;
  late final PollingBroadcaster<List<TripUpdate>> _tripUpdates;
  late final PollingBroadcaster<List<ServiceAlert>> _alerts;

  List<VehiclePosition> _lastVehicles = <VehiclePosition>[];

  /// Fetches vehicle positions and, when the feed is temporarily
  /// unreachable, still re-emits the last known positions with their
  /// freshness recomputed against the current time so a stale "real-time"
  /// badge decays to "estimasi"/"tidak tersedia" instead of freezing.
  Future<List<VehiclePosition>> _fetchVehiclePositions() async {
    try {
      final snapshot = await _fetchSnapshot(_vehiclePositionsUrl);
      _lastVehicles = snapshot.vehicles;
      return _lastVehicles;
    } on Object {
      final now = DateTime.now().toUtc();
      _lastVehicles = _lastVehicles
          .map(
            (vehicle) => vehicle.copyWith(
              freshness: GtfsRealtimeAdapter.freshnessFor(
                vehicle.recordedAt,
                now,
              ),
            ),
          )
          .toList(growable: false);
      return _lastVehicles;
    }
  }

  /// Publishers may expose one combined feed for all entity types or three
  /// separate feed URLs. Each stream fetches its own configured URL
  /// independently; when all three env vars point at the same combined
  /// feed, the bytes are simply fetched once per stream per poll tick,
  /// which is negligible bandwidth for typical GTFS-RT payload sizes.
  Future<GtfsRealtimeSnapshot> _fetchSnapshot(String url) async {
    if (url.isEmpty) {
      return const GtfsRealtimeSnapshot(
        vehicles: <VehiclePosition>[],
        tripUpdates: <TripUpdate>[],
        alerts: <ServiceAlert>[],
      );
    }
    final response = await _dio.get<List<int>>(
      url,
      options: Options(responseType: ResponseType.bytes),
    );
    return _adapter.decode(
      response.data ?? const <int>[],
      receivedAt: DateTime.now().toUtc(),
    );
  }

  @override
  Stream<List<VehiclePosition>> watchVehiclePositions() => _vehicles.stream;

  @override
  Stream<List<TripUpdate>> watchTripUpdates() => _tripUpdates.stream;

  @override
  Stream<List<ServiceAlert>> watchServiceAlerts() => _alerts.stream;

  Future<void> dispose() async {
    await _vehicles.dispose();
    await _tripUpdates.dispose();
    await _alerts.dispose();
  }
}
