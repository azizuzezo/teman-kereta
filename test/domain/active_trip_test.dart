import 'package:flutter_test/flutter_test.dart';
import 'package:teman_kereta/domain/entities/active_trip.dart';
import 'package:teman_kereta/domain/entities/transit_models.dart';

/// A -> B -> C -> D (transfer) -> E -> F -> G, mirroring the fixture shape
/// used in active_trip_controller_test.dart: two rail legs joined at D.
TransitTrip _transferTrip() {
  final now = DateTime.utc(2026, 1, 1, 8);
  return TransitTrip(
    id: 'trip-transfer',
    originStationId: 'A',
    destinationStationId: 'G',
    departureAt: now,
    arrivalAt: now.add(const Duration(minutes: 40)),
    freshness: DataFreshness.estimated,
    sourceLabel: 'test',
    updatedAt: now,
    legs: <TripLeg>[
      TripLeg(
        id: 'rail-1',
        mode: TransportMode.commuterRail,
        originName: 'A',
        destinationName: 'D',
        departureAt: now,
        arrivalAt: now.add(const Duration(minutes: 15)),
        stationIds: const <String>['A', 'B', 'C', 'D'],
        externalTripId: 'OUTBOUND_TRIP_1',
        serviceDate: DateTime.utc(2026, 1, 1),
      ),
      TripLeg(
        id: 'rail-2',
        mode: TransportMode.commuterRail,
        originName: 'D',
        destinationName: 'G',
        departureAt: now.add(const Duration(minutes: 20)),
        arrivalAt: now.add(const Duration(minutes: 40)),
        stationIds: const <String>['D', 'E', 'F', 'G'],
        externalTripId: 'INBOUND_TRIP_2',
        serviceDate: DateTime.utc(2026, 1, 1),
      ),
    ],
  );
}

TransitTrip _directTrip() {
  final now = DateTime.utc(2026, 1, 1, 8);
  return TransitTrip(
    id: 'trip-direct',
    originStationId: 'A',
    destinationStationId: 'C',
    departureAt: now,
    arrivalAt: now.add(const Duration(minutes: 10)),
    freshness: DataFreshness.estimated,
    sourceLabel: 'test',
    updatedAt: now,
    legs: <TripLeg>[
      TripLeg(
        id: 'rail-1',
        mode: TransportMode.commuterRail,
        originName: 'A',
        destinationName: 'C',
        departureAt: now,
        arrivalAt: now.add(const Duration(minutes: 10)),
        stationIds: const <String>['A', 'B', 'C'],
        externalTripId: 'DIRECT_TRIP_1',
        serviceDate: DateTime.utc(2026, 1, 1),
      ),
    ],
  );
}

ActiveTripSession _sessionAt(TransitTrip trip, int index) {
  final now = DateTime.utc(2026, 1, 1, 8);
  return ActiveTripSession(
    id: 'session-1',
    trip: trip,
    state: ActiveTripState.onBoard,
    currentStationIndex: index,
    startedAt: now,
    updatedAt: now,
  );
}

void main() {
  group('ActiveTripSession.currentRailLeg', () {
    test('a direct (single-leg) trip always reports that one leg', () {
      final trip = _directTrip();
      expect(_sessionAt(trip, 0).currentRailLeg?.externalTripId, 'DIRECT_TRIP_1');
      expect(_sessionAt(trip, 1).currentRailLeg?.externalTripId, 'DIRECT_TRIP_1');
      expect(_sessionAt(trip, 2).currentRailLeg?.externalTripId, 'DIRECT_TRIP_1');
    });

    test('before the transfer boundary, reports the outbound leg', () {
      final trip = _transferTrip();
      // stationIds (collapsed): [A, B, C, D, E, F, G] -> D is index 3.
      expect(_sessionAt(trip, 0).currentRailLeg?.externalTripId, 'OUTBOUND_TRIP_1');
      expect(_sessionAt(trip, 2).currentRailLeg?.externalTripId, 'OUTBOUND_TRIP_1');
    });

    test('exactly at the transfer boundary, still reports the outbound leg', () {
      final trip = _transferTrip();
      expect(_sessionAt(trip, 3).currentRailLeg?.externalTripId, 'OUTBOUND_TRIP_1');
    });

    test('after the transfer boundary, reports the inbound leg', () {
      final trip = _transferTrip();
      expect(_sessionAt(trip, 4).currentRailLeg?.externalTripId, 'INBOUND_TRIP_2');
      expect(_sessionAt(trip, 6).currentRailLeg?.externalTripId, 'INBOUND_TRIP_2');
    });
  });
}
