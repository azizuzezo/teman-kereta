import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:teman_kereta/app/theme/app_theme.dart';
import 'package:teman_kereta/data/providers/provider_registry.dart';
import 'package:teman_kereta/domain/entities/transit_models.dart';
import 'package:teman_kereta/features/live_map/presentation/live_map_page.dart';
import 'package:teman_kereta/features/live_map/presentation/live_trip_position_controller.dart';
import 'package:teman_kereta/features/live_map/presentation/map_points_layer.dart';
import 'package:teman_kereta/features/live_map/presentation/map_tiles.dart';

final _transparentPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
);

class _FakeTileProvider extends TileProvider {
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) =>
      MemoryImage(_transparentPng);
}

class _FailingTileProvider extends TileProvider {
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) =>
      _ThrowingImage();
}

class _ThrowingImage extends ImageProvider<_ThrowingImage> {
  @override
  Future<_ThrowingImage> obtainKey(ImageConfiguration configuration) async =>
      this;

  @override
  ImageStreamCompleter loadImage(_ThrowingImage key, ImageDecoderCallback decode) {
    return OneFrameImageStreamCompleter(
      Future<ImageInfo>.error(StateError('tile offline')),
    );
  }
}

class _NoTrip extends LiveTripPositionController {
  @override
  LatLng? build() => null;
}

const _stations = <Station>[
  Station(
    id: 'MRI',
    code: 'MRI',
    name: 'Manggarai',
    latitude: -6.2100,
    longitude: 106.8500,
    lineIds: <String>['BOGOR', 'CIKARANG'],
  ),
  Station(
    id: 'SUD',
    code: 'SUD',
    name: 'Sudirman',
    latitude: -6.2020,
    longitude: 106.8230,
    lineIds: <String>['BOGOR'],
  ),
  Station(
    id: 'BKS',
    code: 'BKS',
    name: 'Bekasi',
    latitude: -6.2360,
    longitude: 106.9990,
    lineIds: <String>['CIKARANG'],
  ),
];

Departure _departure(String id, DateTime at, String destination) => Departure(
  id: id,
  stationId: 'SUD',
  destination: destination,
  lineName: 'Lintas Bogor',
  scheduledAt: at,
  expectedAt: at,
  freshness: DataFreshness.estimated,
  sourceLabel: 'Jadwal',
);

Widget _app({
  required TileProvider tiles,
  List<Station> stations = _stations,
  Object? stationsError,
  Stream<List<VehiclePosition>>? vehicles,
}) {
  return ProviderScope(
    overrides: [
      stationListProvider.overrideWith((ref) async {
        if (stationsError != null) {
          throw stationsError;
        }
        return stations;
      }),
      lineColorsProvider.overrideWith(
        (ref) async => const <String, Color>{
          'BOGOR': Color(0xFFD01F26),
          'CIKARANG': Color(0xFF1E6FD0),
        },
      ),
      vehiclePositionsProvider.overrideWith(
        (ref) => vehicles ?? Stream.value(const <VehiclePosition>[]),
      ),
      liveTripPositionControllerProvider.overrideWith(_NoTrip.new),
      mapTileProviderProvider.overrideWithValue(tiles),
      departuresProvider.overrideWith((ref, stationId) async {
        final now = ref.read(clockProvider).now();
        return <Departure>[
          _departure('a', now.add(const Duration(minutes: 4)), 'Bogor'),
          _departure('b', now.add(const Duration(minutes: 12)), 'Jatinegara'),
        ];
      }),
    ],
    child: MaterialApp(theme: AppTheme.light(), home: const LiveMapPage()),
  );
}

Future<Offset> _screenPositionOf(WidgetTester tester, Station s) async {
  final context = tester.element(find.byType(MapPointsLayer));
  final camera = MapCamera.of(context);
  return projectToScreen(camera, LatLng(s.latitude, s.longitude));
}

void main() {
  testWidgets('shows search, line chips and the map once stations load', (
    tester,
  ) async {
    await tester.pumpWidget(_app(tiles: _FakeTileProvider()));
    await tester.pumpAndSettle();

    expect(find.text('Cari stasiun'), findsOneWidget);
    expect(find.text('Semua'), findsOneWidget);
    expect(find.text('Bogor'), findsOneWidget);
    expect(find.text('Cikarang'), findsOneWidget);
    expect(find.byType(FlutterMap), findsOneWidget);
    expect(find.byType(MapPointsLayer), findsOneWidget);
    expect(find.byTooltip('Lokasi saya'), findsOneWidget);
    expect(find.text('© OpenStreetMap contributors'), findsOneWidget);
    // No panel until something is selected.
    expect(find.text('Detail stasiun'), findsNothing);
  });

  testWidgets('tapping a station opens its panel with the next departures', (
    tester,
  ) async {
    await tester.pumpWidget(_app(tiles: _FakeTileProvider()));
    await tester.pumpAndSettle();

    final at = await _screenPositionOf(tester, _stations[1]);
    await tester.tapAt(at);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(find.text('Sudirman'), findsOneWidget);
    expect(find.text('Kereta berikutnya'), findsOneWidget);
    expect(find.text('Ke Bogor'), findsOneWidget);
    // 4 minutes minus the few ms the test took, shown rounded down.
    expect(find.text('3 menit'), findsOneWidget);
    expect(find.text('11 menit'), findsOneWidget);
    expect(find.text('Detail stasiun'), findsOneWidget);
    expect(find.text('Sekitar stasiun'), findsOneWidget);

    await tester.tap(find.byTooltip('Tutup'));
    await tester.pumpAndSettle();
    expect(find.text('Detail stasiun'), findsNothing);
  });

  testWidgets('tapping empty map does not select anything', (tester) async {
    await tester.pumpWidget(_app(tiles: _FakeTileProvider()));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(60, 520));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Detail stasiun'), findsNothing);
  });

  testWidgets('a fresh train can be selected and says its position is estimated', (
    tester,
  ) async {
    final vehicle = VehiclePosition(
      id: 'v1',
      tripId: 't1',
      latitude: -6.2040,
      longitude: 106.8360,
      recordedAt: DateTime.now(),
      freshness: DataFreshness.estimated,
      sourceLabel: 'Perkiraan jadwal',
      nextStationId: 'MRI',
    );
    await tester.pumpWidget(
      _app(
        tiles: _FakeTileProvider(),
        vehicles: Stream.value(<VehiclePosition>[vehicle]),
      ),
    );
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(MapPointsLayer));
    final at = projectToScreen(
      MapCamera.of(context),
      LatLng(vehicle.latitude, vehicle.longitude),
    );
    await tester.tapAt(at);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(find.text('Menuju Manggarai'), findsOneWidget);
    expect(
      find.text('Posisi ini dihitung dari jadwal, bukan dari GPS kereta.'),
      findsOneWidget,
    );
  });

  testWidgets('choosing a line chip keeps the page alive and can be cleared', (
    tester,
  ) async {
    await tester.pumpWidget(_app(tiles: _FakeTileProvider()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cikarang'));
    await tester.pumpAndSettle();
    expect(find.byType(MapPointsLayer), findsOneWidget);
    await tester.tap(find.text('Semua'));
    await tester.pumpAndSettle();
    expect(find.byType(MapPointsLayer), findsOneWidget);
  });

  testWidgets('search sheet finds a station and selects it', (tester) async {
    await tester.pumpWidget(_app(tiles: _FakeTileProvider()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cari stasiun'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'bek');
    await tester.pumpAndSettle();
    expect(find.text('Bekasi'), findsOneWidget);
    expect(find.text('Sudirman'), findsNothing);

    await tester.tap(find.text('Bekasi'));
    await tester.pumpAndSettle();
    expect(find.text('Detail stasiun'), findsOneWidget);
  });

  testWidgets('search sheet says so when nothing matches', (tester) async {
    await tester.pumpWidget(_app(tiles: _FakeTileProvider()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cari stasiun'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'zzzz');
    await tester.pumpAndSettle();
    expect(find.textContaining('Tidak ada stasiun'), findsOneWidget);
  });

  testWidgets('failing tiles show a clear message but keep lines and stations', (
    tester,
  ) async {
    await tester.pumpWidget(_app(tiles: _FailingTileProvider()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));

    expect(
      find.text('Peta dasar belum bisa dimuat. Jalur dan stasiun tetap tampil.'),
      findsOneWidget,
    );
    expect(find.byType(MapPointsLayer), findsOneWidget);
    expect(find.text('Coba lagi'), findsOneWidget);
    // Let the tracker's quiet-period timer finish.
    await tester.pump(const Duration(seconds: 20));
  });

  testWidgets('station data failing shows an error with a retry', (tester) async {
    await tester.pumpWidget(
      _app(tiles: _FakeTileProvider(), stationsError: StateError('down')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Peta belum bisa dibuka'), findsOneWidget);
    expect(find.text('Coba lagi'), findsOneWidget);
  });

  testWidgets('no stations shows an honest empty state', (tester) async {
    await tester.pumpWidget(
      _app(tiles: _FakeTileProvider(), stations: const <Station>[]),
    );
    await tester.pumpAndSettle();
    expect(find.text('Peta belum tersedia'), findsOneWidget);
  });

  testWidgets('renders in dark mode and at 1.3x text without overflow', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          stationListProvider.overrideWith((ref) async => _stations),
          lineColorsProvider.overrideWith(
            (ref) async => const <String, Color>{},
          ),
          vehiclePositionsProvider.overrideWith(
            (ref) => Stream.value(const <VehiclePosition>[]),
          ),
          liveTripPositionControllerProvider.overrideWith(_NoTrip.new),
          mapTileProviderProvider.overrideWithValue(_FakeTileProvider()),
        ],
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(360, 740),
              textScaler: TextScaler.linear(1.3),
            ),
            child: const LiveMapPage(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(MapPointsLayer), findsOneWidget);
  });
}
