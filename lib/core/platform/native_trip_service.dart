import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers/demo_data.dart';
import '../../domain/entities/active_trip.dart';
import '../../domain/entities/ride_detection.dart';
import '../../domain/entities/transit_models.dart';

class NativeTripService {
  const NativeTripService();

  static const _channel = MethodChannel(
    'id.temankereta.teman_kereta/native',
  );

  Future<Map<String, Object?>> getCapabilities() async {
    try {
      return await _channel.invokeMapMethod<String, Object?>(
            'getNativeCapabilities',
          ) ??
          <String, Object?>{};
    } on MissingPluginException {
      return <String, Object?>{};
    }
  }

  Future<void> start(ActiveTripSession session) async {
    await _invoke('startActiveTrip', _payload(session));
  }

  Future<void> stop() async {
    await _invoke('stopActiveTrip');
  }

  Future<void> update(ActiveTripSession session) async {
    await _invoke('updateActiveTrip', _payload(session));
    await _invoke('updateWidget', _payload(session));
  }

  Future<void> registerStationGeofences(
    List<Map<String, Object?>> stations,
  ) async {
    await _invoke(
      'registerStationGeofences',
      <String, Object?>{'stations': stations},
    );
  }

  Future<void> unregisterStationGeofences() async {
    await _invoke('unregisterStationGeofences');
  }

  Future<void> updateNextDepartureWidget(Departure departure) async {
    await _invoke('updateNextDepartureWidget', <String, Object?>{
      'station': _stationName(departure.stationId),
      'departureTime': _formatClock(departure.expectedAt),
      'destination': departure.destination,
      'status': _delayLabel(departure.scheduledAt, departure.expectedAt),
      'isDemo': departure.isDemo,
      'updatedAtEpochMs': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> updateDailyRouteWidget({
    required String originStationId,
    required String destinationStationId,
    required List<Departure> upcomingDepartures,
    required String lineStatusLabel,
    required bool isDemo,
  }) async {
    await _invoke('updateWidget', <String, Object?>{
      'widget': 'dailyRoute',
      'data': <String, Object?>{
        'label':
            '${_stationName(originStationId)} → ${_stationName(destinationStationId)}',
        'lineStatus': lineStatusLabel,
        'isDemo': isDemo,
        'updatedAtEpochMs': DateTime.now().millisecondsSinceEpoch,
        'departures': <Map<String, Object?>>[
          for (final departure in upcomingDepartures.take(3))
            <String, Object?>{
              'time': _formatClock(departure.expectedAt),
              'destination': departure.destination,
            },
        ],
      },
    });
  }

  Future<void> updateServiceStatusWidget({
    required List<ServiceAlert> alerts,
    required bool isDemo,
  }) async {
    await _invoke('updateWidget', <String, Object?>{
      'widget': 'serviceStatus',
      'data': <String, Object?>{
        'isDemo': isDemo,
        'updatedAtEpochMs': DateTime.now().millisecondsSinceEpoch,
        'lines': <Map<String, Object?>>[
          for (final alert in alerts.take(4))
            <String, Object?>{
              // `alert.title` is already the human-readable line/alert name
              // from the provider — there's no separate lineId→name lookup
              // available client-side (demoStations only maps station ids).
              'name': alert.title,
              'status': _serviceStatusLabel(alert.status),
            },
        ],
      },
    });
  }

  String _formatClock(DateTime value) {
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String _delayLabel(DateTime scheduled, DateTime expected) {
    final diff = expected.difference(scheduled).inMinutes;
    if (diff <= 0) {
      return 'Tepat waktu';
    }
    return 'Terlambat $diff menit';
  }

  String _serviceStatusLabel(ServiceStatus status) => switch (status) {
    ServiceStatus.normal => 'Normal',
    ServiceStatus.delayed => 'Terlambat',
    ServiceStatus.limited => 'Terbatas',
    ServiceStatus.disrupted => 'Gangguan',
    ServiceStatus.unavailable => 'Belum tersedia',
  };

  Future<bool> requestActivityRecognitionUpdates() async {
    final map = await _invokeMap('requestActivityRecognitionUpdates');
    return map?['started'] == true;
  }

  Future<bool> stopActivityRecognitionUpdates() async {
    final map = await _invokeMap('stopActivityRecognitionUpdates');
    return map?['stopped'] == true;
  }

  Future<Map<String, Object?>> getPermissionStatus() async {
    return await _invokeMap('getPermissionStatus') ?? <String, Object?>{};
  }

  Future<GeofenceEvent?> getLastGeofenceEvent() async {
    final map = await _invokeMap('getLastGeofenceEvent');
    final occurredAtMs = map?['occurredAtEpochMs'] as int?;
    if (map == null || occurredAtMs == null) {
      return null;
    }
    return GeofenceEvent(
      stationIds: (map['stationIds'] as List<Object?>? ?? const <Object?>[])
          .whereType<String>()
          .toList(growable: false),
      transition: _parseTransition(map['transition'] as String?),
      occurredAt: DateTime.fromMillisecondsSinceEpoch(occurredAtMs),
    );
  }

  Future<ActivityEvent?> getLastActivityEvent() async {
    final map = await _invokeMap('getLastActivityEvent');
    final occurredAtMs = map?['occurredAtEpochMs'] as int?;
    if (map == null || occurredAtMs == null) {
      return null;
    }
    return ActivityEvent(
      type: _parseActivityType(map['type'] as String?),
      confidencePercent: (map['confidencePercent'] as num?)?.toInt() ?? 0,
      occurredAt: DateTime.fromMillisecondsSinceEpoch(occurredAtMs),
    );
  }

  GeofenceTransition _parseTransition(String? value) => switch (value) {
    'enter' => GeofenceTransition.enter,
    'exit' => GeofenceTransition.exit,
    'dwell' => GeofenceTransition.dwell,
    _ => GeofenceTransition.unknown,
  };

  RideActivityType _parseActivityType(String? value) => switch (value) {
    'in_vehicle' => RideActivityType.inVehicle,
    'on_foot' => RideActivityType.onFoot,
    'still' => RideActivityType.still,
    _ => RideActivityType.unknown,
  };

  Future<void> _invoke(String method, [Map<String, Object?>? arguments]) async {
    try {
      await _channel.invokeMethod<void>(method, arguments);
    } on MissingPluginException {
      // Native services are unavailable in headless widget/unit tests.
    } on PlatformException {
      // The Flutter journey stays usable even when background capability fails.
    }
  }

  Future<Map<String, Object?>?> _invokeMap(
    String method, [
    Map<String, Object?>? arguments,
  ]) async {
    try {
      return await _channel.invokeMapMethod<String, Object?>(
        method,
        arguments,
      );
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  Map<String, Object?> _payload(ActiveTripSession session) {
    final stationIds = session.trip.stationIds;
    final lineName = session.trip.legs
        .where((leg) => leg.mode == TransportMode.commuterRail)
        .map((leg) => leg.lineName)
        .whereType<String>()
        .firstOrNull;
    return <String, Object?>{
      'sessionId': session.id,
      'tripId': session.trip.id,
      'state': session.state.name,
      'currentStationId': session.currentStationId,
      'nextStationId': session.nextStationId,
      'destinationStationId': session.trip.destinationStationId,
      'currentStation': _stationName(session.currentStationId),
      'nextStation': _stationName(session.nextStationId),
      'destinationName': _stationName(session.trip.destinationStationId),
      'lineName': lineName ?? 'Commuter Line',
      'remainingStops': session.remainingStops,
      'stationIds': stationIds,
      'etaEpochMillis': session.trip.arrivalAt.millisecondsSinceEpoch,
      'eta': session.trip.arrivalAt.toIso8601String(),
      'isDemo': session.trip.isDemo,
      'sourceLabel': session.trip.sourceLabel,
    };
  }

  String? _stationName(String? id) {
    if (id == null) {
      return null;
    }
    return demoStations.where((station) => station.id == id).firstOrNull?.name ??
        id;
  }
}

final nativeTripServiceProvider = Provider<NativeTripService>((Ref ref) {
  return const NativeTripService();
});
