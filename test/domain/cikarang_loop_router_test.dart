import 'package:flutter_test/flutter_test.dart';
import 'package:teman_kereta/domain/entities/transit_models.dart';
import 'package:teman_kereta/domain/usecases/estimated_trip_builder.dart';
import 'package:teman_kereta/domain/usecases/line_transfer_router.dart';

// The Cikarang line exactly as `station_lines.stop_order` stores it.
const _loopOrder = <(String, String)>[
  ('CKR', 'Cikarang'),
  ('TLM', 'Metland Telagamurni'),
  ('CIT', 'Cibitung'),
  ('TB', 'Tambun'),
  ('BKST', 'Bekasi Timur'),
  ('BKS', 'Bekasi'),
  ('KRI', 'Kranji'),
  ('CUK', 'Cakung'),
  ('KLDB', 'Klender Baru'),
  ('BUA', 'Buaran'),
  ('KLD', 'Klender'),
  ('JNG', 'Jatinegara'),
  ('MTR', 'Matraman'),
  ('MRI', 'Manggarai'),
  ('SUD', 'Sudirman'),
  ('SUDB', 'BNI City'),
  ('KAT', 'Karet'),
  ('THB', 'Tanah Abang'),
  ('DU', 'Duri'),
  ('AK', 'Angke'),
  ('KPB', 'Kampung Bandan'),
  ('RJW', 'Rajawali'),
  ('KMO', 'Kemayoran'),
  ('PSE', 'Pasar Senen'),
  ('GST', 'Gang Sentiong'),
  ('KMT', 'Kramat'),
  ('POK', 'Pondok Jati'),
];

final _stations = <Station>[
  for (final (i, (code, name)) in _loopOrder.indexed)
    Station(
      id: code,
      code: code,
      name: name,
      latitude: 0,
      longitude: 0,
      lineIds: <String>[
        'CIKARANG',
        if (code == 'MRI' || code == 'JNG') 'BOGOR',
      ],
      stopOrderByLine: <String, int>{
        'CIKARANG': i + 1,
        if (code == 'MRI') 'BOGOR': 9,
        if (code == 'JNG') 'BOGOR': 99,
      },
    ),
  const Station(
    id: 'DP',
    code: 'DP',
    name: 'Depok',
    latitude: 0,
    longitude: 0,
    lineIds: <String>['BOGOR'],
    stopOrderByLine: <String, int>{'BOGOR': 2},
  ),
];

List<List<String>> _codes(RouteOption option) => <List<String>>[
  for (final leg in option.legs) <String>[for (final s in leg) s.id],
];

void main() {
  test('Bekasi to Kemayoran: via Pasar Senen direct, or via Manggarai '
      'changing at Kampung Bandan', () {
    final options = routeOptionsBetweenStations(_stations, 'BKS', 'KMO');
    expect(options, hasLength(2));

    final senen = options.first;
    expect(senen.viaName, 'Pasar Senen');
    expect(_codes(senen), <List<String>>[
      <String>[
        'BKS', 'KRI', 'CUK', 'KLDB', 'BUA', 'KLD', 'JNG', //
        'POK', 'KMT', 'GST', 'PSE', 'KMO',
      ],
    ]);

    final manggarai = options[1];
    expect(manggarai.viaName, 'Manggarai');
    expect(_codes(manggarai), hasLength(2));
    expect(_codes(manggarai)[0].first, 'BKS');
    expect(
      _codes(manggarai)[0],
      containsAllInOrder(<String>['JNG', 'MTR', 'MRI']),
    );
    expect(_codes(manggarai)[0].last, 'KPB');
    expect(_codes(manggarai)[1], <String>['KPB', 'RJW', 'KMO']);
  });

  test('Angke to Jatinegara offers both ways round', () {
    final options = routeOptionsBetweenStations(_stations, 'AK', 'JNG');
    final vias = options.map((o) => o.viaName).toSet();
    expect(vias, <String>{'Manggarai', 'Pasar Senen'});
    final viaSenen = options.firstWhere((o) => o.viaName == 'Pasar Senen');
    expect(_codes(viaSenen).first, <String>['AK', 'KPB']);
  });

  test('Angke to Kemayoran keeps only the short way', () {
    final options = routeOptionsBetweenStations(_stations, 'AK', 'KMO');
    expect(options, hasLength(1));
    expect(_codes(options.single), <List<String>>[
      <String>['AK', 'KPB'],
      <String>['KPB', 'RJW', 'KMO'],
    ]);
  });

  test('Matraman to Pondok Jati changes at Jatinegara', () {
    final options = routeOptionsBetweenStations(_stations, 'MTR', 'POK');
    expect(_codes(options.first), <List<String>>[
      <String>['MTR', 'JNG'],
      <String>['JNG', 'POK'],
    ]);
  });

  test('Bekasi to Cikarang stays a single straight ride', () {
    final options = routeOptionsBetweenStations(_stations, 'BKS', 'CKR');
    expect(options, hasLength(1));
    expect(_codes(options.single).single.first, 'BKS');
    expect(_codes(options.single).single.last, 'CKR');
  });

  test('routeBetweenStations still returns the best route', () {
    final legs = routeBetweenStations(_stations, 'BKS', 'KMO')!;
    expect(legs.single.map((s) => s.id), contains('PSE'));
  });

  test('estimated trips are labelled by route and timed by stops', () {
    final options = routeOptionsBetweenStations(_stations, 'BKS', 'KMO');
    final query = TripSearchQuery(
      originStationId: 'BKS',
      destinationStationId: 'KMO',
      departureAt: DateTime(2026, 11, 9, 7),
    );
    final trips = <TransitTrip>[
      for (final (i, option) in options.indexed)
        ...buildEstimatedTrips(
          option: option,
          optionIndex: i,
          query: query,
          originName: 'Bekasi',
          destinationName: 'Kemayoran',
          labelRouteVia: true,
        ),
    ];
    expect(trips.map((t) => t.id).toSet(), hasLength(trips.length));
    final senen = trips.firstWhere((t) => t.routeVia == 'Pasar Senen');
    expect(senen.transfers, 0);
    // 11 stops at 3.5 minutes each.
    expect(senen.durationMinutes, 39);
    final manggarai = trips.firstWhere((t) => t.routeVia == 'Manggarai');
    expect(manggarai.transfers, 1);
    expect(manggarai.stationIds.where((id) => id == 'KPB'), hasLength(1));
  });

  group('legService names the real train', () {
    LegService svc(List<String> codes) => legService(_stations, <Station>[
      for (final c in codes) _stations.firstWhere((s) => s.id == c),
    ])!;

    test('Bekasi into the ring via Pasar Senen heads to Kampung Bandan', () {
      final s = svc(<String>[
        'BKS',
        'KRI',
        'CUK',
        'KLDB',
        'BUA',
        'KLD',
        'JNG',
        'POK',
        'KMT',
      ]);
      expect(s.headsign, 'Kampung Bandan');
      expect(s.relation, 'Cikarang – Kampung Bandan via Pasar Senen');
    });

    test('Kampung Bandan to Kemayoran heads back to Cikarang', () {
      final s = svc(<String>['KPB', 'RJW', 'KMO']);
      expect(s.headsign, 'Cikarang');
      expect(s.relation, contains('via Pasar Senen'));
    });

    test('Manggarai side towards Kampung Bandan', () {
      final s = svc(<String>['MRI', 'SUD', 'SUDB', 'KAT', 'THB']);
      expect(s.headsign, 'Kampung Bandan');
      expect(s.relation, contains('via Manggarai'));
    });

    test('Angke to Duri heads to Cikarang via Manggarai', () {
      final s = svc(<String>['AK', 'DU']);
      expect(s.headsign, 'Cikarang');
      expect(s.relation, contains('via Manggarai'));
    });
  });

  test('alternativeEstimatedTrip switches the way round', () {
    final options = routeOptionsBetweenStations(_stations, 'BKS', 'KMO');
    final trip = buildEstimatedTrips(
      option: options.first,
      optionIndex: 0,
      query: TripSearchQuery(
        originStationId: 'BKS',
        destinationStationId: 'KMO',
        departureAt: DateTime(2026, 11, 9, 7),
      ),
      originName: 'Bekasi',
      destinationName: 'Kemayoran',
      labelRouteVia: true,
      allStations: _stations,
    ).first;
    expect(otherRouteVias(trip, _stations), <String>['Manggarai']);
    final alt = alternativeEstimatedTrip(
      trip: trip,
      allStations: _stations,
      viaName: 'Manggarai',
    )!;
    expect(alt.routeVia, 'Manggarai');
    expect(alt.departureAt, trip.departureAt);
    expect(alt.stationIds, contains('MRI'));
    expect(alt.legs.first.headsign, 'Kampung Bandan');
  });
}
