import 'package:flutter_test/flutter_test.dart';
import 'package:teman_kereta/domain/entities/transit_models.dart';
import 'package:teman_kereta/features/nearby_places/presentation/place_actions.dart';
import 'package:teman_kereta/features/nearby_places/presentation/place_categories.dart';

NearbyPlace _place(
  String name,
  String category, {
  int meters = 0,
  int minutes = 0,
}) => NearbyPlace(
  id: name,
  stationId: 'SUD',
  name: name,
  category: category,
  distanceMeters: meters,
  walkingMinutes: minutes,
  description: '',
  sourceLabel: 'Tim Teman Kereta',
);

void main() {
  group('categoryOf', () {
    test('maps the wordings the data really uses', () {
      expect(categoryOf('Kuliner').key, 'makan');
      expect(categoryOf('Museum').key, 'wisata');
      expect(categoryOf('Taman').key, 'taman');
      expect(categoryOf('Ruang publik').key, 'taman');
      expect(categoryOf('Masjid').key, 'ibadah');
      expect(categoryOf('Rumah Sakit').key, 'kesehatan');
      expect(categoryOf('ATM & Bank').key, 'uang');
      expect(categoryOf('Transportasi').key, 'transportasi');
      expect(categoryOf('  belanja ').key, 'belanja');
    });

    test('matches whole words only', () {
      expect(categoryOf('Business center').key, isNot('transportasi'));
    });

    test('an unknown category keeps its own name instead of being hidden', () {
      final c = categoryOf('olahraga');
      expect(c.label, 'Olahraga');
      expect(c.key, 'lain:olahraga');
      expect(categoryOf('').label, 'Lainnya');
    });
  });

  group('groupPlaces', () {
    final places = <NearbyPlace>[
      _place('Bakso Far', 'Kuliner', meters: 400, minutes: 5),
      _place('Masjid Dekat', 'Masjid', meters: 90, minutes: 2),
      _place('Soto Dekat', 'Kuliner', meters: 120, minutes: 2),
      _place('Mal Jauh', 'Belanja', meters: 900, minutes: 11),
      _place('Warung Tanpa Jarak', 'Kuliner'),
    ];

    test('groups are ordered by their nearest place, places by distance', () {
      final groups = groupPlaces(places);
      expect(groups.map((g) => g.category.key), <String>[
        'ibadah',
        'makan',
        'belanja',
      ]);
      expect(groups[1].places.map((p) => p.name), <String>[
        'Soto Dekat',
        'Bakso Far',
        'Warung Tanpa Jarak',
      ]);
    });

    test('counts add up to the number of places', () {
      final groups = groupPlaces(places);
      expect(groups.fold<int>(0, (sum, g) => sum + g.count), places.length);
      expect(groups[1].count, 3);
    });

    test('placesInCategory returns one group, or nothing', () {
      expect(placesInCategory(places, 'ibadah').single.name, 'Masjid Dekat');
      expect(placesInCategory(places, 'kesehatan'), isEmpty);
    });

    test('empty input gives no groups', () {
      expect(groupPlaces(const <NearbyPlace>[]), isEmpty);
    });
  });

  group('distance text', () {
    test('uses stored walking time and the shared distance formatter', () {
      expect(
        walkingSummary(_place('a', 'Kuliner', meters: 350, minutes: 4)),
        '350 m • 4 menit jalan',
      );
      expect(
        walkingSummary(_place('a', 'Kuliner', meters: 1250, minutes: 15)),
        '1.3 km • 15 menit jalan',
      );
    });

    test('derives minutes when only the distance is recorded', () {
      expect(
        walkingSummary(_place('a', 'Kuliner', meters: 500)),
        '500 m • 7 menit jalan',
      );
      expect(walkingMinutesFor(1), 1);
      expect(walkingMinutesFor(0), 0);
    });

    test('says nothing rather than "0 m" when there is no distance', () {
      expect(walkingSummary(_place('a', 'Kuliner')), isNull);
    });

    test('count label', () {
      expect(placeCountLabel(12), '12 tempat');
    });
  });

  test('pushRecent puts the newest first, removes duplicates, caps length', () {
    expect(pushRecent(<String>['A', 'B'], 'C'), <String>['C', 'A', 'B']);
    expect(pushRecent(<String>['A', 'B', 'C'], 'B'), <String>['B', 'A', 'C']);
    expect(
      pushRecent(<String>['A', 'B', 'C', 'D'], 'E'),
      <String>['E', 'A', 'B', 'C'],
    );
  });

  group('map links', () {
    const withCoords = PlaceTarget(
      name: 'Soto Pak Haji',
      stationName: 'Sudirman',
      latitude: -6.2,
      longitude: 106.8,
    );
    const withoutCoords = PlaceTarget(
      name: 'Soto Pak Haji',
      stationName: 'Sudirman',
    );

    test('coordinates win when known', () {
      expect(
        buildOpenInMapUri(withCoords).toString(),
        'geo:-6.2,106.8?q=-6.2,106.8(Soto%20Pak%20Haji)',
      );
      final dir = buildWalkingDirectionsUri(
        withCoords,
        stationLatitude: -6.21,
        stationLongitude: 106.82,
      );
      expect(dir.queryParameters['destination'], '-6.2,106.8');
      expect(dir.queryParameters['origin'], '-6.21,106.82');
      expect(dir.queryParameters['travelmode'], 'walking');
    });

    test('without coordinates it searches the name next to the station', () {
      expect(
        buildOpenInMapUri(withoutCoords).toString(),
        'geo:0,0?q=Soto%20Pak%20Haji%2C%20Stasiun%20Sudirman',
      );
      final dir = buildWalkingDirectionsUri(
        withoutCoords,
        stationLatitude: -6.21,
        stationLongitude: 106.82,
      );
      expect(
        dir.queryParameters['destination'],
        'Soto Pak Haji, Stasiun Sudirman',
      );
    });
  });
}
