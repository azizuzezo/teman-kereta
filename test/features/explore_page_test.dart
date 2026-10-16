import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:teman_kereta/app/theme/app_theme.dart';
import 'package:teman_kereta/data/providers/provider_registry.dart';
import 'package:teman_kereta/domain/entities/transit_models.dart';
import 'package:teman_kereta/domain/usecases/nearest_station_finder.dart';
import 'package:teman_kereta/features/nearby_places/presentation/explore_page.dart';
import 'package:teman_kereta/features/nearby_places/presentation/place_actions.dart';
import 'package:teman_kereta/features/stations/presentation/nearest_station_controller.dart';

class _Recents extends ExploreRecentsController {
  _Recents(this.initial);
  final List<String> initial;
  final List<String> added = <String>[];

  @override
  Future<List<String>> build() async => initial;

  @override
  Future<void> add(String stationId) async {
    added.add(stationId);
    state = AsyncData<List<String>>(<String>[stationId, ...initial]);
  }
}

class _Nearest extends NearestStationController {
  _Nearest(this.items);
  final List<StationDistance> items;

  @override
  Future<List<StationDistance>> build() async => items;
}

const _sud = Station(
  id: 'SUD',
  code: 'SUD',
  name: 'Sudirman',
  latitude: -6.2,
  longitude: 106.82,
  lineIds: <String>['BOGOR'],
);
const _mri = Station(
  id: 'MRI',
  code: 'MRI',
  name: 'Manggarai',
  latitude: -6.21,
  longitude: 106.85,
  lineIds: <String>['BOGOR', 'CIKARANG'],
);

NearbyPlace _p(String name, String cat, int m, int min) => NearbyPlace(
  id: name,
  stationId: 'x',
  name: name,
  category: cat,
  distanceMeters: m,
  walkingMinutes: min,
  description: '',
  sourceLabel: 'Tim Teman Kereta',
);

Widget _app({
  String? station,
  Map<String, List<NearbyPlace>> places = const <String, List<NearbyPlace>>{},
  List<String> recents = const <String>[],
  List<StationDistance> nearest = const <StationDistance>[],
  bool placesFail = false,
  _Recents? recentsFake,
  double textScale = 1,
}) {
  return ProviderScope(
    overrides: [
      stationListProvider.overrideWith(
        (ref) async => const <Station>[_sud, _mri],
      ),
      exploreRecentsProvider.overrideWith(
        () => recentsFake ?? _Recents(recents),
      ),
      nearestStationControllerProvider.overrideWith(() => _Nearest(nearest)),
      nearbyPlacesProvider.overrideWith((ref, id) async {
        if (placesFail) {
          throw StateError('down');
        }
        return places[id] ?? const <NearbyPlace>[];
      }),
    ],
    child: MaterialApp.router(
      theme: AppTheme.light(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      routerConfig: GoRouter(
        routes: <RouteBase>[
          GoRoute(
            path: '/',
            builder: (_, _) => ExplorePage(initialStationId: station),
          ),
          GoRoute(
            path: '/station/:id',
            builder: (_, state) =>
                Scaffold(body: Text('detail ${state.pathParameters['id']}')),
          ),
        ],
      ),
    ),
  );
}

final _sudPlaces = <NearbyPlace>[
  _p('Soto Dekat', 'Kuliner', 120, 2),
  _p('Bakso Jauh', 'Kuliner', 600, 8),
  _p('Warung C', 'Kuliner', 700, 9),
  _p('Warung D', 'Kuliner', 800, 10),
  _p('Masjid Al Ikhlas', 'Masjid', 90, 2),
  _p('Mal Kota', 'Belanja', 900, 11),
];

void main() {
  testWidgets('shows plain-language header, station and real category counts', (
    tester,
  ) async {
    await tester.pumpWidget(_app(station: 'SUD', places: {'SUD': _sudPlaces}));
    await tester.pumpAndSettle();

    expect(find.text('Apa yang ada di sekitar stasiun?'), findsOneWidget);
    expect(find.text('Sudirman'), findsWidgets);
    expect(find.text('Semua'), findsOneWidget);
    expect(find.text('6 tempat'), findsOneWidget);
    expect(find.text('Makan'), findsWidgets);
    expect(find.text('4 tempat'), findsWidgets);
    expect(find.text('Ibadah'), findsWidgets);
    expect(find.text('Belanja'), findsWidgets);
    // No category the data does not have.
    expect(find.text('Kesehatan'), findsNothing);
    // Nearest group first: Ibadah (90 m) leads Makan (120 m).
    final ibadahY = tester.getTopLeft(find.text('Masjid Al Ikhlas')).dy;
    final sotoY = tester.getTopLeft(find.text('Soto Dekat')).dy;
    expect(ibadahY, lessThan(sotoY));
    expect(find.text('90 m • 2 menit jalan'), findsOneWidget);
  });

  testWidgets('a group shows three places and expands on request', (
    tester,
  ) async {
    await tester.pumpWidget(_app(station: 'SUD', places: {'SUD': _sudPlaces}));
    await tester.pumpAndSettle();
    expect(find.text('Warung D'), findsNothing);
    await tester.ensureVisible(find.text('Lihat semua 4 tempat'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lihat semua 4 tempat'));
    await tester.pumpAndSettle();
    expect(find.text('Warung D'), findsOneWidget);
  });

  testWidgets('choosing a category lists only that category', (tester) async {
    await tester.pumpWidget(_app(station: 'SUD', places: {'SUD': _sudPlaces}));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ibadah').first);
    await tester.pumpAndSettle();
    expect(find.text('Masjid Al Ikhlas'), findsOneWidget);
    expect(find.text('Soto Dekat'), findsNothing);
    await tester.tap(find.text('Semua'));
    await tester.pumpAndSettle();
    expect(find.text('Soto Dekat'), findsOneWidget);
  });

  testWidgets('place detail offers directions, map and ride-hailing', (
    tester,
  ) async {
    await tester.pumpWidget(_app(station: 'SUD', places: {'SUD': _sudPlaces}));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Masjid Al Ikhlas'));
    await tester.pumpAndSettle();
    expect(find.text('Petunjuk jalan'), findsOneWidget);
    expect(find.text('Buka di peta'), findsOneWidget);
    expect(find.text('Buka Gojek'), findsOneWidget);
    expect(find.text('Buka Grab'), findsOneWidget);
    expect(find.textContaining('dari Stasiun Sudirman'), findsOneWidget);
  });

  testWidgets('honest empty state when the station has no places', (
    tester,
  ) async {
    await tester.pumpWidget(_app(station: 'MRI'));
    await tester.pumpAndSettle();
    expect(
      find.text('Belum ada data tempat di sekitar stasiun ini'),
      findsOneWidget,
    );
    expect(find.text('Tambah tempat'), findsWidgets);
    await tester.tap(find.text('Lihat detail stasiun'));
    await tester.pumpAndSettle();
    expect(find.text('detail MRI'), findsOneWidget);
  });

  testWidgets('error state offers a retry', (tester) async {
    await tester.pumpWidget(_app(station: 'SUD', placesFail: true));
    await tester.pumpAndSettle();
    expect(find.text('Daftar tempat belum bisa dimuat'), findsOneWidget);
    expect(find.text('Coba lagi'), findsOneWidget);
  });

  testWidgets('picker lists nearest and recents and switches station', (
    tester,
  ) async {
    final fake = _Recents(const <String>['MRI']);
    await tester.pumpWidget(
      _app(
        station: 'SUD',
        places: {'SUD': _sudPlaces},
        nearest: const <StationDistance>[
          StationDistance(
            station: _mri,
            distanceMeters: 450,
            walkingMinutes: 6,
          ),
          StationDistance(
            station: _sud,
            distanceMeters: 2300,
            walkingMinutes: 28,
          ),
        ],
        recentsFake: fake,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Terdekat: Manggarai'), findsOneWidget);

    await tester.tap(find.text('Ganti'));
    await tester.pumpAndSettle();
    expect(find.text('Terdekat dari kamu'), findsOneWidget);
    expect(find.text('450 m • 6 menit jalan'), findsOneWidget);
    expect(find.text('Terakhir dilihat'), findsOneWidget);
    expect(find.text('Semua stasiun'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'mang');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Manggarai'));
    await tester.pumpAndSettle();

    expect(fake.added, <String>['MRI']);
    expect(
      find.text('Belum ada data tempat di sekitar stasiun ini'),
      findsOneWidget,
    );
  });

  testWidgets('no route parameter opens on the last station looked at', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(recents: const <String>['MRI'], places: {'SUD': _sudPlaces}),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Belum ada data tempat di sekitar stasiun ini'),
      findsOneWidget,
    );
  });

  testWidgets('survives 1.3x text on a narrow screen', (tester) async {
    tester.view.physicalSize = const Size(360 * 2, 740 * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      _app(station: 'SUD', places: {'SUD': _sudPlaces}, textScale: 1.3),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
