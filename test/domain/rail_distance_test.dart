import 'package:flutter_test/flutter_test.dart';
import 'package:teman_kereta/core/utils/geo.dart';
import 'package:teman_kereta/data/providers/demo_data.dart';
import 'package:teman_kereta/domain/entities/transit_models.dart';
import 'package:teman_kereta/domain/usecases/rail_distance.dart';

Station _station(String id) =>
    demoStations.firstWhere((station) => station.id == id);

double _straightLine(List<Station> path) {
  var total = 0.0;
  for (var i = 0; i < path.length - 1; i += 1) {
    total += haversineMeters(
      path[i].latitude,
      path[i].longitude,
      path[i + 1].latitude,
      path[i + 1].longitude,
    );
  }
  return total;
}

void main() {
  group('railPathDistanceMeters', () {
    test('a single station has no distance', () {
      expect(railPathDistanceMeters(<Station>[_station('BOO')]), 0);
      expect(railPathDistanceMeters(const <Station>[]), 0);
    });

    test('following real track is never shorter than the straight line', () {
      final path = <Station>[
        _station('BOO'),
        _station('CLT'),
        _station('BJD'),
        _station('CTA'),
        _station('DP'),
      ];
      final track = railPathDistanceMeters(path);
      expect(track, greaterThanOrEqualTo(_straightLine(path)));
    });

    test('Bogor to Depok measures in the right physical ballpark', () {
      // ~21-24 km of track in reality. A result far outside that means the
      // projection latched onto the wrong stretch of line, which is exactly
      // the failure that would quote a wrong fare.
      final track = railPathDistanceMeters(<Station>[
        _station('BOO'),
        _station('CLT'),
        _station('BJD'),
        _station('CTA'),
        _station('DP'),
      ]);
      expect(track, greaterThan(18000));
      expect(track, lessThan(28000));
    });

    test('adjacent stations stay close to their straight-line distance', () {
      final a = _station('DP');
      final b = _station('DPB');
      final straight = haversineMeters(
        a.latitude,
        a.longitude,
        b.latitude,
        b.longitude,
      );
      final track = railPathDistanceMeters(<Station>[a, b]);
      expect(track, greaterThanOrEqualTo(straight));
      expect(track, lessThan((straight * 2) + 500));
    });

    test('stations with no usable geometry fall back to straight line', () {
      // Coordinates in the middle of the Java Sea, on no line we have track
      // geometry for — the offset guard must reject every shape and leave
      // the straight-line distance rather than inventing a track length.
      const a = Station(
        id: 'X1',
        code: 'X1',
        name: 'Nowhere 1',
        latitude: -5.0,
        longitude: 107.0,
      );
      const b = Station(
        id: 'X2',
        code: 'X2',
        name: 'Nowhere 2',
        latitude: -5.1,
        longitude: 107.1,
      );
      final straight = haversineMeters(-5.0, 107.0, -5.1, 107.1);
      expect(
        railPathDistanceMeters(const <Station>[a, b]),
        closeTo(straight, 1),
      );
    });
  });
}
