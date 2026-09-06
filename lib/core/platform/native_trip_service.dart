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

  Future<void> start(
    ActiveTripSession session, {
    required List<Station> stations,
    required int stopAlertThreshold,
    required bool vibrationEnabled,
    required bool soundEnabled,
  }) async {
    await _invoke(
      'startActiveTrip',
      _payload(
        session,
        stations: stations,
        stopAlertThreshold: stopAlertThreshold,
        vibrationEnabled: vibrationEnabled,
        soundEnabled: soundEnabled,
      ),
    );
  }

  Future<void> stop() async {
    await _invoke('stopActiveTrip');
  }

  /// Rider-initiated "Perbarui lokasi": tells the foreground service to
  /// rebuild its location subscription and fetch one immediate
  /// high-accuracy fix. The result of that fix arrives through the normal
  /// [getActiveTripFullState] poll like any other, so this deliberately
  /// returns nothing — the manual button can only ever make automatic
  /// tracking conclude sooner, never assert progress by itself.
  Future<void> refreshLocation() async {
    await _invoke('refreshActiveTripLocation');
  }

  /// Clears the pending signal-gap prompt after the rider has answered it
  /// — or dismissed it, which clears it just the same. The trip stays
  /// active regardless; see [ActiveTripController.acknowledgeLocationGap].
  Future<void> acknowledgeLocationGap() async {
    await _invoke('acknowledgeLocationGap');
  }

  Future<void> update(
    ActiveTripSession session, {
    required List<Station> stations,
    required int stopAlertThreshold,
    required bool vibrationEnabled,
    required bool soundEnabled,
  }) async {
    final payload = _payload(
      session,
      stations: stations,
      stopAlertThreshold: stopAlertThreshold,
      vibrationEnabled: vibrationEnabled,
      soundEnabled: soundEnabled,
    );
    await _invoke('updateActiveTrip', payload);
    await _invoke('updateWidget', payload);
  }

  /// Pushes just the live alert-preference fields to native, without a full
  /// trip-state update — used when the user changes a notification setting
  /// mid-trip, so `TripProgressEngine` (native) picks it up on its very next
  /// decision even though the Dart side of the trip hasn't otherwise changed.
  Future<void> updateSettings({
    required int stopAlertThreshold,
    required bool vibrationEnabled,
    required bool soundEnabled,
  }) async {
    await _invoke('updateSettings', <String, Object?>{
      'stopAlertThreshold': stopAlertThreshold,
      'vibrationEnabled': vibrationEnabled,
      'soundEnabled': soundEnabled,
    });
  }

  /// The continuously-tracked trip state `TripProgressEngine` (native) owns
  /// once a trip starts — station index/state, cumulative distance/speed,
  /// and the latest raw GPS fix. Polled by `ActiveTripController` to keep
  /// the Dart-side session and the live map in sync with whatever native
  /// has already decided (including while the app was backgrounded).
  Future<Map<String, Object?>> getActiveTripFullState() async {
    return await _invokeMap('getActiveTripFullState') ?? <String, Object?>{};
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

  Map<String, Object?> _payload(
    ActiveTripSession session, {
    required List<Station> stations,
    required int stopAlertThreshold,
    required bool vibrationEnabled,
    required bool soundEnabled,
  }) {
    final stationIds = session.trip.stationIds;
    final lineName = session.trip.legs
        .where((leg) => leg.mode == TransportMode.commuterRail)
        .map((leg) => leg.lineName)
        .whereType<String>()
        .firstOrNull;
    final stationsById = {for (final station in stations) station.id: station};
    // Prefer the real (Supabase) station list passed in from the caller —
    // demoStations alone doesn't know real codes like 'KLDB'/'CUK', so a
    // real trip's notification/widget text would otherwise show the raw
    // station code instead of its name.
    String? resolvedName(String? id) =>
        id == null ? null : stationsById[id]?.name ?? _stationName(id);
    return <String, Object?>{
      'sessionId': session.id,
      'startedAtEpochMs': session.startedAt.millisecondsSinceEpoch,
      'tripId': session.trip.id,
      'state': session.state.name,
      'currentStationId': session.currentStationId,
      'nextStationId': session.nextStationId,
      'destinationStationId': session.trip.destinationStationId,
      'currentStation': resolvedName(session.currentStationId),
      'nextStation': resolvedName(session.nextStationId),
      'destinationName': resolvedName(session.trip.destinationStationId),
      'lineName': lineName ?? 'Commuter Line',
      'remainingStops': session.remainingStops,
      'stationIds': stationIds,
      'currentStationIndex': session.currentStationIndex,
      'etaEpochMillis': session.trip.arrivalAt.millisecondsSinceEpoch,
      'eta': session.trip.arrivalAt.toIso8601String(),
      'isDemo': session.trip.isDemo,
      'sourceLabel': session.trip.sourceLabel,
      'lowBatteryMode': session.lowBatteryMode,
      'distanceMeters': session.distanceMeters,
      'stopAlertThreshold': stopAlertThreshold,
      'vibrationEnabled': vibrationEnabled,
      'soundEnabled': soundEnabled,
      'stations': <Map<String, Object?>>[
        for (final id in stationIds)
          if (stationsById[id] case final station?)
            <String, Object?>{
              'id': station.id,
              'name': station.name,
              'latitude': station.latitude,
              'longitude': station.longitude,
            },
      ],
      'transferBoundaries': <Map<String, Object?>>[
        for (final boundary in session.trip.transferBoundaries)
          <String, Object?>{
            'index': boundary.index,
            'instruction': boundary.instruction,
          },
      ],
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
