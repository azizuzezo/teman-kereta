import 'package:flutter_test/flutter_test.dart';
import 'package:teman_kereta/core/database/app_database.dart';
import 'package:teman_kereta/data/providers/demo_data.dart';
import 'package:teman_kereta/domain/entities/transit_models.dart';
import 'package:teman_kereta/domain/usecases/trip_recap.dart';

CompletedTrip _trip({
  required String id,
  required String originId,
  required String originName,
  required String destinationId,
  required String destinationName,
  required DateTime departedAt,
  required Duration duration,
}) {
  final arrived = departedAt.add(duration);
  return CompletedTrip(
    id: id,
    originStationId: originId,
    originName: originName,
    destinationStationId: destinationId,
    destinationName: destinationName,
    departedAt: departedAt,
    arrivedAt: arrived,
    isDemo: false,
    completedAt: arrived,
  );
}

Map<String, Station> get _stations => <String, Station>{
      for (final station in demoStations) station.id: station,
    };

void main() {
  group('TripRecap', () {
    test('an empty history recaps to nothing', () {
      final recap = TripRecap.from(const <CompletedTrip>[], _stations);
      expect(recap.isEmpty, isTrue);
      expect(recap.tripCount, 0);
      expect(recap.topRoute, isNull);
      expect(recap.totalRideTime, Duration.zero);
    });

    test('counts trips and sums time on board', () {
      final recap = TripRecap.from(
        <CompletedTrip>[
          _trip(
            id: '1',
            originId: 'DP',
            originName: 'Depok',
            destinationId: 'MRI',
            destinationName: 'Manggarai',
            departedAt: DateTime(2026, 3, 2, 7),
            duration: const Duration(minutes: 40),
          ),
          _trip(
            id: '2',
            originId: 'MRI',
            originName: 'Manggarai',
            destinationId: 'DP',
            destinationName: 'Depok',
            departedAt: DateTime(2026, 3, 2, 18),
            duration: const Duration(minutes: 45),
          ),
        ],
        _stations,
      );
      expect(recap.tripCount, 2);
      expect(recap.totalRideTime, const Duration(minutes: 85));
      // Both trips fell on the same calendar day.
      expect(recap.activeDayCount, 1);
    });

    test('picks the most frequent route and station', () {
      final recap = TripRecap.from(
        <CompletedTrip>[
          _trip(
            id: '1',
            originId: 'DP',
            originName: 'Depok',
            destinationId: 'MRI',
            destinationName: 'Manggarai',
            departedAt: DateTime(2026, 3, 2, 7),
            duration: const Duration(minutes: 40),
          ),
          _trip(
            id: '2',
            originId: 'DP',
            originName: 'Depok',
            destinationId: 'MRI',
            destinationName: 'Manggarai',
            departedAt: DateTime(2026, 3, 3, 7),
            duration: const Duration(minutes: 42),
          ),
          _trip(
            id: '3',
            originId: 'BOO',
            originName: 'Bogor',
            destinationId: 'MRI',
            destinationName: 'Manggarai',
            departedAt: DateTime(2026, 3, 4, 7),
            duration: const Duration(minutes: 90),
          ),
        ],
        _stations,
      );
      expect(recap.topRoute?.label, 'Depok → Manggarai');
      expect(recap.topRoute?.count, 2);
      // Manggarai is an endpoint of all three trips.
      expect(recap.topStation?.label, 'Manggarai');
      expect(recap.topStation?.count, 3);
      expect(recap.longestTrip?.id, '3');
      expect(recap.activeDayCount, 3);
    });

    test('sums distance and fare only over measurable trips', () {
      final recap = TripRecap.from(
        <CompletedTrip>[
          _trip(
            id: '1',
            originId: 'DP',
            originName: 'Depok',
            destinationId: 'MRI',
            destinationName: 'Manggarai',
            departedAt: DateTime(2026, 3, 2, 7),
            duration: const Duration(minutes: 40),
          ),
          // Unknown station ids: nothing to measure, but the trip itself
          // still counts.
          _trip(
            id: '2',
            originId: 'ZZZ',
            originName: 'Entah',
            destinationId: 'YYY',
            destinationName: 'Entah Juga',
            departedAt: DateTime(2026, 3, 3, 7),
            duration: const Duration(minutes: 30),
          ),
        ],
        _stations,
      );
      expect(recap.tripCount, 2);
      expect(recap.measuredTripCount, 1);
      expect(recap.hasUnmeasuredTrips, isTrue);
      expect(recap.totalDistanceMeters, greaterThan(0));
      // Depok - Manggarai is inside the first 25 km band.
      expect(recap.totalFareRupiah, 3000);
    });

    test('a trip whose clock ran backwards never subtracts from the total',
        () {
      final departed = DateTime(2026, 3, 2, 7);
      final recap = TripRecap.from(
        <CompletedTrip>[
          CompletedTrip(
            id: 'broken',
            originStationId: 'DP',
            originName: 'Depok',
            destinationStationId: 'MRI',
            destinationName: 'Manggarai',
            departedAt: departed,
            arrivedAt: departed.subtract(const Duration(minutes: 20)),
            isDemo: false,
            completedAt: departed,
          ),
          _trip(
            id: 'good',
            originId: 'DP',
            originName: 'Depok',
            destinationId: 'MRI',
            destinationName: 'Manggarai',
            departedAt: DateTime(2026, 3, 3, 7),
            duration: const Duration(minutes: 40),
          ),
        ],
        _stations,
      );
      expect(recap.totalRideTime, const Duration(minutes: 40));
      expect(recap.longestTrip?.id, 'good');
    });

    test('tracks which weekday the rider travels on most', () {
      final recap = TripRecap.from(
        <CompletedTrip>[
          // 2 March 2026 is a Monday.
          _trip(
            id: '1',
            originId: 'DP',
            originName: 'Depok',
            destinationId: 'MRI',
            destinationName: 'Manggarai',
            departedAt: DateTime(2026, 3, 2, 7),
            duration: const Duration(minutes: 40),
          ),
          _trip(
            id: '2',
            originId: 'DP',
            originName: 'Depok',
            destinationId: 'MRI',
            destinationName: 'Manggarai',
            departedAt: DateTime(2026, 3, 9, 7),
            duration: const Duration(minutes: 40),
          ),
          _trip(
            id: '3',
            originId: 'DP',
            originName: 'Depok',
            destinationId: 'MRI',
            destinationName: 'Manggarai',
            departedAt: DateTime(2026, 3, 3, 7),
            duration: const Duration(minutes: 40),
          ),
        ],
        _stations,
      );
      expect(recap.tripsByWeekday[DateTime.monday], 2);
      expect(recap.tripsByWeekday[DateTime.tuesday], 1);
      expect(recap.tripsByWeekday[DateTime.sunday], isNull);
    });
  });
}
