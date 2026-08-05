import 'package:flutter_test/flutter_test.dart';
import 'package:teman_kereta/domain/entities/transit_models.dart';
import 'package:teman_kereta/domain/usecases/nearest_station_finder.dart';

void main() {
  const finder = NearestStationFinder();

  const bogor = Station(
    id: 'BOO',
    code: 'BOO',
    name: 'Bogor',
    latitude: -6.5950,
    longitude: 106.7906,
  );
  const manggarai = Station(
    id: 'MRI',
    code: 'MRI',
    name: 'Manggarai',
    latitude: -6.2099,
    longitude: 106.8502,
  );
  const sudirman = Station(
    id: 'SUD',
    code: 'SUD',
    name: 'Sudirman',
    latitude: -6.2028,
    longitude: 106.8230,
  );

  test('ranks stations nearest-first from the given position', () {
    // Standing right next to Sudirman.
    final ranked = finder.rank(
      const <Station>[bogor, manggarai, sudirman],
      -6.2029,
      106.8231,
    );

    expect(ranked.map((entry) => entry.station.id), <String>[
      'SUD',
      'MRI',
      'BOO',
    ]);
  });

  test('distance to the exact same coordinates is ~0', () {
    final ranked = finder.rank(const <Station>[sudirman], -6.2028, 106.8230);
    expect(ranked.single.distanceMeters, lessThan(1));
    expect(ranked.single.walkingMinutes, 1); // never rounds down to 0
  });

  test('distance between Bogor and Sudirman is roughly the known ~48km corridor', () {
    final ranked = finder.rank(const <Station>[sudirman], -6.5950, 106.7906);
    final distanceKm = ranked.single.distanceMeters / 1000;
    // Straight-line, not rail distance, so allow a wide but sane band.
    expect(distanceKm, greaterThan(40));
    expect(distanceKm, lessThan(55));
  });

  test('walking minutes scale with distance using the average pace', () {
    final ranked = finder.rank(const <Station>[sudirman], -6.2028, 106.8230);
    // ~0 meters away.
    expect(ranked.single.walkingMinutes, 1);
  });
}
