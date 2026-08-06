import 'dart:async';

import '../../domain/entities/transit_models.dart';
import '../../domain/providers/transit_providers.dart';

/// Merges vehicle positions from two [TransitRealtimeProvider]s — a
/// `primary` (a real GTFS-Realtime feed, when one is ever configured) and
/// `supplementalPositions` (Supabase's `vehicle_positions` table, which
/// includes both the schedule-based `estimated` fallback and real
/// crowd-sourced rider positions). This is what lets `TRANSIT_PROVIDER=gtfs`
/// — the schedule/station data source actually selected today — show a
/// genuinely real, non-schedule-derived position the moment any rider with
/// "Deteksi Otomatis Naik KRL" enabled reports one, without switching the
/// whole app over to `local_supabase` for schedule data too.
///
/// Trip updates and service alerts are NOT merged — those still come
/// strictly from `primary`, since there is no crowd-sourced equivalent for
/// either (a delay/alert isn't something a rider's own GPS position can
/// stand in for) — see ENGINEERING.md.
class HybridTransitRealtimeProvider implements TransitRealtimeProvider {
  HybridTransitRealtimeProvider({
    required this._primary,
    required TransitRealtimeProvider supplementalPositions,
  }) : _supplemental = supplementalPositions {
    _positions = StreamController<List<VehiclePosition>>.broadcast(
      onListen: _startMerging,
      onCancel: _stopMerging,
    );
  }

  final TransitRealtimeProvider _primary;
  final TransitRealtimeProvider _supplemental;
  late final StreamController<List<VehiclePosition>> _positions;
  StreamSubscription<List<VehiclePosition>>? _primarySub;
  StreamSubscription<List<VehiclePosition>>? _supplementalSub;
  var _latestPrimary = const <VehiclePosition>[];
  var _latestSupplemental = const <VehiclePosition>[];

  void _startMerging() {
    _primarySub = _primary.watchVehiclePositions().listen((positions) {
      _latestPrimary = positions;
      _emit();
    });
    _supplementalSub = _supplemental.watchVehiclePositions().listen((
      positions,
    ) {
      _latestSupplemental = positions;
      _emit();
    });
  }

  void _stopMerging() {
    unawaited(_primarySub?.cancel());
    unawaited(_supplementalSub?.cancel());
    _primarySub = null;
    _supplementalSub = null;
  }

  void _emit() {
    if (!_positions.isClosed) {
      _positions.add(<VehiclePosition>[
        ..._latestPrimary,
        ..._latestSupplemental,
      ]);
    }
  }

  @override
  Stream<List<VehiclePosition>> watchVehiclePositions() => _positions.stream;

  @override
  Stream<List<TripUpdate>> watchTripUpdates() => _primary.watchTripUpdates();

  @override
  Stream<List<ServiceAlert>> watchServiceAlerts() =>
      _primary.watchServiceAlerts();

  Future<void> dispose() async {
    _stopMerging();
    await _positions.close();
  }
}
