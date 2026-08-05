import 'package:flutter_test/flutter_test.dart';
import 'package:teman_kereta/domain/entities/transit_models.dart';

TripLeg _railLeg({
  required String id,
  required List<String> stationIds,
  String? lineName,
  String? transferInstruction,
}) {
  final now = DateTime.utc(2026, 1, 1, 8);
  return TripLeg(
    id: id,
    mode: TransportMode.commuterRail,
    originName: stationIds.first,
    destinationName: stationIds.last,
    departureAt: now,
    arrivalAt: now.add(const Duration(minutes: 30)),
    lineName: lineName,
    stationIds: stationIds,
    transferInstruction: transferInstruction,
  );
}

TransitTrip _tripWithLegs(List<TripLeg> legs) {
  final now = DateTime.utc(2026, 1, 1, 8);
  return TransitTrip(
    id: 'trip-test',
    originStationId: 'A',
    destinationStationId: 'Z',
    departureAt: now,
    arrivalAt: now.add(const Duration(minutes: 60)),
    legs: legs,
    freshness: DataFreshness.estimated,
    sourceLabel: 'test',
    updatedAt: now,
  );
}

void main() {
  group('TransitTrip.stationIds', () {
    test('flattens a single rail leg as-is', () {
      final trip = _tripWithLegs(<TripLeg>[
        _railLeg(id: 'rail-1', stationIds: <String>['A', 'B', 'C']),
      ]);

      expect(trip.stationIds, <String>['A', 'B', 'C']);
      expect(trip.transferBoundaries, isEmpty);
    });

    test('collapses the shared transfer station between two rail legs', () {
      final trip = _tripWithLegs(<TripLeg>[
        _railLeg(
          id: 'rail-1',
          stationIds: <String>['A', 'B', 'C', 'D'],
          lineName: 'Bogor Line',
          transferInstruction: 'Transit di D.',
        ),
        _railLeg(
          id: 'rail-2',
          stationIds: <String>['D', 'E', 'F'],
          lineName: 'Cikarang Line',
        ),
      ]);

      // D must appear exactly once even though both legs list it.
      expect(trip.stationIds, <String>['A', 'B', 'C', 'D', 'E', 'F']);
    });

    test('reports a transfer boundary at the shared station index', () {
      final trip = _tripWithLegs(<TripLeg>[
        _railLeg(
          id: 'rail-1',
          stationIds: <String>['A', 'B', 'C', 'D'],
          lineName: 'Bogor Line',
          transferInstruction: 'Transit di D.',
        ),
        _railLeg(
          id: 'rail-2',
          stationIds: <String>['D', 'E', 'F'],
          lineName: 'Cikarang Line',
        ),
      ]);

      expect(trip.transferBoundaries, hasLength(1));
      final boundary = trip.transferBoundaries.single;
      expect(boundary.index, 3);
      expect(boundary.fromLineName, 'Bogor Line');
      expect(boundary.toLineName, 'Cikarang Line');
      expect(boundary.instruction, 'Transit di D.');
    });

    test('ignores walking legs when building the rail station sequence', () {
      final now = DateTime.utc(2026, 1, 1, 8);
      final walk = TripLeg(
        id: 'walk-1',
        mode: TransportMode.walk,
        originName: 'Rumah',
        destinationName: 'A',
        departureAt: now,
        arrivalAt: now.add(const Duration(minutes: 5)),
      );
      final trip = _tripWithLegs(<TripLeg>[
        walk,
        _railLeg(id: 'rail-1', stationIds: <String>['A', 'B']),
      ]);

      expect(trip.stationIds, <String>['A', 'B']);
    });
  });
}
