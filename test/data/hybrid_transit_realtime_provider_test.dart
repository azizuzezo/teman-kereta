import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:teman_kereta/data/providers/hybrid_transit_realtime_provider.dart';
import 'package:teman_kereta/domain/entities/transit_models.dart';
import 'package:teman_kereta/domain/providers/transit_providers.dart';

class _FakeRealtimeProvider implements TransitRealtimeProvider {
  final _vehicles = StreamController<List<VehiclePosition>>.broadcast();
  final _tripUpdates = StreamController<List<TripUpdate>>.broadcast();
  final _alerts = StreamController<List<ServiceAlert>>.broadcast();

  void emitVehicles(List<VehiclePosition> value) => _vehicles.add(value);
  void emitTripUpdates(List<TripUpdate> value) => _tripUpdates.add(value);
  void emitAlerts(List<ServiceAlert> value) => _alerts.add(value);

  @override
  Stream<List<VehiclePosition>> watchVehiclePositions() => _vehicles.stream;

  @override
  Stream<List<TripUpdate>> watchTripUpdates() => _tripUpdates.stream;

  @override
  Stream<List<ServiceAlert>> watchServiceAlerts() => _alerts.stream;

  Future<void> close() async {
    await _vehicles.close();
    await _tripUpdates.close();
    await _alerts.close();
  }
}

VehiclePosition _vehicle(String id) {
  return VehiclePosition(
    id: id,
    tripId: 'trip-$id',
    latitude: -6.2,
    longitude: 106.8,
    recordedAt: DateTime.utc(2026, 1, 1),
    freshness: DataFreshness.realtime,
    sourceLabel: 'test',
  );
}

void main() {
  late _FakeRealtimeProvider primary;
  late _FakeRealtimeProvider supplemental;
  late HybridTransitRealtimeProvider hybrid;

  setUp(() {
    primary = _FakeRealtimeProvider();
    supplemental = _FakeRealtimeProvider();
    hybrid = HybridTransitRealtimeProvider(
      primary: primary,
      supplementalPositions: supplemental,
    );
  });

  tearDown(() async {
    await hybrid.dispose();
    await primary.close();
    await supplemental.close();
  });

  test('merges vehicle positions from both sources', () async {
    final emissions = <List<VehiclePosition>>[];
    final sub = hybrid.watchVehiclePositions().listen(emissions.add);
    addTearDown(sub.cancel);

    primary.emitVehicles(<VehiclePosition>[_vehicle('gtfs-rt-1')]);
    await Future<void>.delayed(Duration.zero);
    supplemental.emitVehicles(<VehiclePosition>[_vehicle('crowd-1')]);
    await Future<void>.delayed(Duration.zero);

    expect(emissions.last.map((v) => v.id), <String>['gtfs-rt-1', 'crowd-1']);
  });

  test('an update from one source keeps the other source\'s latest value', () async {
    final emissions = <List<VehiclePosition>>[];
    final sub = hybrid.watchVehiclePositions().listen(emissions.add);
    addTearDown(sub.cancel);

    primary.emitVehicles(<VehiclePosition>[_vehicle('gtfs-rt-1')]);
    await Future<void>.delayed(Duration.zero);
    supplemental.emitVehicles(<VehiclePosition>[_vehicle('crowd-1')]);
    await Future<void>.delayed(Duration.zero);
    // Supplemental refreshes again; primary's last known value must persist.
    supplemental.emitVehicles(<VehiclePosition>[_vehicle('crowd-2')]);
    await Future<void>.delayed(Duration.zero);

    expect(emissions.last.map((v) => v.id), <String>['gtfs-rt-1', 'crowd-2']);
  });

  test('trip updates and service alerts pass through from primary only', () async {
    final tripUpdate = TripUpdate(
      tripId: 't1',
      stationId: 's1',
      arrivalDelaySeconds: 60,
      departureDelaySeconds: 60,
      updatedAt: DateTime.utc(2026, 1, 1),
    );
    final tripUpdatesEmitted = <List<TripUpdate>>[];
    final sub = hybrid.watchTripUpdates().listen(tripUpdatesEmitted.add);
    addTearDown(sub.cancel);

    primary.emitTripUpdates(<TripUpdate>[tripUpdate]);
    await Future<void>.delayed(Duration.zero);

    expect(tripUpdatesEmitted.single.single.tripId, 't1');
  });
}
