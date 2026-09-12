import 'package:flutter_test/flutter_test.dart';
import 'package:teman_kereta/core/utils/geo.dart';
import 'package:teman_kereta/data/providers/demo_data.dart';
import 'package:teman_kereta/domain/entities/transit_models.dart';
import 'package:teman_kereta/features/active_trip/presentation/trip_progress_math.dart';
import 'package:teman_kereta/features/live_map/presentation/native_gps_fix.dart';

Station _station(String id) =>
    demoStations.firstWhere((station) => station.id == id);

NativeGpsFix _fixAt(double lat, double lon) =>
    NativeGpsFix(latitude: lat, longitude: lon, at: DateTime.utc(2026));

TransitTrip _trip(List<String> stationIds) {
  final now = DateTime.utc(2026, 1, 1, 8);
  return TransitTrip(
    id: 'trip-test',
    originStationId: stationIds.first,
    destinationStationId: stationIds.last,
    departureAt: now,
    arrivalAt: now.add(const Duration(minutes: 30)),
    freshness: DataFreshness.estimated,
    sourceLabel: 'test',
    updatedAt: now,
    isDemo: true,
    legs: <TripLeg>[
      TripLeg(
        id: 'rail-1',
        mode: TransportMode.commuterRail,
        originName: stationIds.first,
        destinationName: stationIds.last,
        departureAt: now,
        arrivalAt: now.add(const Duration(minutes: 30)),
        lineName: 'Bogor Line',
        stationIds: stationIds,
      ),
    ],
  );
}

void main() {
  group('hopFractionFromGps', () {
    test('is 0 without a fix', () {
      expect(
        hopFractionFromGps(from: _station('BOO'), to: _station('CLT'), fix: null),
        0,
      );
    });

    test('is 0 when either station is unknown', () {
      expect(
        hopFractionFromGps(from: null, to: _station('CLT'), fix: _fixAt(0, 0)),
        0,
      );
    });

    test('is roughly 0.5 at the midpoint between two stations', () {
      final from = _station('BOO');
      final to = _station('CLT');
      final midFix = _fixAt(
        (from.latitude + to.latitude) / 2,
        (from.longitude + to.longitude) / 2,
      );
      final fraction = hopFractionFromGps(from: from, to: to, fix: midFix);
      expect(fraction, closeTo(0.5, 0.05));
    });

    test('clamps to 1 once the fix is past the next station', () {
      final from = _station('BOO');
      final to = _station('CLT');
      // Keep going the same direction well beyond `to`.
      final overshotLat = to.latitude + (to.latitude - from.latitude) * 3;
      final overshotLon = to.longitude + (to.longitude - from.longitude) * 3;
      final fraction = hopFractionFromGps(
        from: from,
        to: to,
        fix: _fixAt(overshotLat, overshotLon),
      );
      expect(fraction, 1.0);
    });
  });

  group('remainingDistanceMeters', () {
    final stationIds = <String>['BOO', 'CLT', 'BJD', 'CTA', 'DP'];
    final stationsById = <String, Station>{
      for (final id in stationIds) id: _station(id),
    };

    test('sums every remaining hop when standing at the current station', () {
      final total = remainingDistanceMeters(
        trip: _trip(stationIds),
        currentStationIndex: 0,
        hopFraction: 0,
        stationsById: stationsById,
      );
      final expected =
          haversineMeters(
            _station('BOO').latitude,
            _station('BOO').longitude,
            _station('CLT').latitude,
            _station('CLT').longitude,
          ) +
          haversineMeters(
            _station('CLT').latitude,
            _station('CLT').longitude,
            _station('BJD').latitude,
            _station('BJD').longitude,
          ) +
          haversineMeters(
            _station('BJD').latitude,
            _station('BJD').longitude,
            _station('CTA').latitude,
            _station('CTA').longitude,
          ) +
          haversineMeters(
            _station('CTA').latitude,
            _station('CTA').longitude,
            _station('DP').latitude,
            _station('DP').longitude,
          );
      expect(total, closeTo(expected, 1));
    });

    test('shrinks the first hop by how far into it the rider already is', () {
      final atStart = remainingDistanceMeters(
        trip: _trip(stationIds),
        currentStationIndex: 0,
        hopFraction: 0,
        stationsById: stationsById,
      )!;
      final halfway = remainingDistanceMeters(
        trip: _trip(stationIds),
        currentStationIndex: 0,
        hopFraction: 0.5,
        stationsById: stationsById,
      )!;
      expect(halfway, lessThan(atStart));
    });

    test('is 0 once standing at the last station', () {
      final total = remainingDistanceMeters(
        trip: _trip(stationIds),
        currentStationIndex: stationIds.length - 1,
        hopFraction: 0,
        stationsById: stationsById,
      );
      expect(total, 0);
    });

    test('is null when a remaining station has no known coordinates', () {
      final total = remainingDistanceMeters(
        trip: _trip(stationIds),
        currentStationIndex: 0,
        hopFraction: 0,
        stationsById: <String, Station>{'BOO': _station('BOO')},
      );
      expect(total, isNull);
    });
  });

  group('liveEta', () {
    final startedAt = DateTime.utc(2026, 1, 1, 8);

    test('is null too soon after departure', () {
      expect(
        liveEta(
          startedAt: startedAt,
          distanceMeters: 5000,
          remainingMeters: 5000,
          now: startedAt.add(const Duration(seconds: 10)),
        ),
        isNull,
      );
    });

    test('is null when barely any distance has been covered', () {
      expect(
        liveEta(
          startedAt: startedAt,
          distanceMeters: 10,
          remainingMeters: 5000,
          now: startedAt.add(const Duration(minutes: 5)),
        ),
        isNull,
      );
    });

    test('is null when remaining distance is unknown', () {
      expect(
        liveEta(
          startedAt: startedAt,
          distanceMeters: 5000,
          remainingMeters: null,
          now: startedAt.add(const Duration(minutes: 5)),
        ),
        isNull,
      );
    });

    test('projects arrival from average pace so far', () {
      final now = startedAt.add(const Duration(minutes: 10));
      // 6000 m covered in 600 s → 10 m/s average pace.
      final eta = liveEta(
        startedAt: startedAt,
        distanceMeters: 6000,
        remainingMeters: 3000,
        now: now,
      );
      // 3000 m left at 10 m/s → 300 more seconds.
      expect(eta, now.add(const Duration(seconds: 300)));
    });
  });
}
