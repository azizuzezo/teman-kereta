import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:teman_kereta/app/theme/app_theme.dart';
import 'package:teman_kereta/core/network/device_status.dart';
import 'package:teman_kereta/core/network/gps_status_controller.dart';
import 'package:teman_kereta/core/preferences/preferences_store.dart';
import 'package:teman_kereta/data/providers/provider_registry.dart';
import 'package:teman_kereta/domain/entities/transit_models.dart';
import 'package:teman_kereta/features/stations/presentation/nearby_stations_page.dart';
import 'package:teman_kereta/features/stations/presentation/nearest_station_controller.dart';
import 'package:teman_kereta/features/stations/presentation/station_detail_page.dart';

final _now = DateTime(2026, 10, 15, 8, 0, 0);

const _bogor = Station(
  id: 'BOO',
  code: 'BOO',
  name: 'Bogor',
  latitude: -6.5950,
  longitude: 106.7906,
  lineIds: <String>['BOGOR'],
  facilities: <String>['Toilet', 'Musala'],
);
const _cilebut = Station(
  id: 'CLT',
  code: 'CLT',
  name: 'Cilebut',
  latitude: -6.5309,
  longitude: 106.8005,
);

Departure _dep(String id, int minutes, {String? platform}) => Departure(
  id: id,
  stationId: 'BOO',
  destination: 'Jakarta Kota',
  lineName: 'Commuter Line Bogor',
  scheduledAt: _now.add(Duration(minutes: minutes)),
  expectedAt: _now.add(Duration(minutes: minutes)),
  freshness: DataFreshness.estimated,
  sourceLabel: 'Jadwal statis',
  platform: platform,
);

List<Override> _overrides({
  FixReading reading = const FixReading.ok(-6.5949, 106.7907),
  GpsSnapshot gps = const GpsSnapshot(
    serviceEnabled: true,
    permission: GpsPermission.granted,
  ),
  Future<List<Departure>> Function()? departures,
}) => [
  preferencesStoreProvider.overrideWithValue(MemoryPreferencesStore()),
  clockProvider.overrideWithValue(Clock.fixed(_now)),
  stationListProvider.overrideWith(
    (ref) async => const <Station>[_bogor, _cilebut],
  ),
  fixReaderProvider.overrideWithValue(() async => reading),
  gpsProbeProvider.overrideWithValue(() async => gps),
  departuresProvider.overrideWith(
    (ref, id) =>
        departures?.call() ??
        Future.value(<Departure>[
          _dep('a', 4, platform: 'Peron belum tersedia'),
          _dep('b', 16, platform: '2'),
          _dep('past', -10),
        ]),
  ),
];

Future<void> _pump(
  WidgetTester tester,
  Widget page,
  List<Override> overrides, {
  double textScale = 1.0,
  Size size = const Size(390, 844),
}) async {
  tester.view.physicalSize = size * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      retry: (retryCount, error) => null,
      overrides: overrides,
      child: MaterialApp(
        theme: AppTheme.light(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: page,
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('id_ID');
  });

  group('NearbyStationsPage', () {
    testWidgets('lists stations nearest first with a walking estimate', (
      tester,
    ) async {
      await _pump(tester, const NearbyStationsPage(), _overrides());

      expect(find.text('Paling dekat'), findsOneWidget);
      expect(find.text('Bogor'), findsOneWidget);
      expect(find.text('Cilebut'), findsOneWidget);
      expect(find.textContaining('jalan kaki'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('without a location it explains and offers to enable it', (
      tester,
    ) async {
      await _pump(
        tester,
        const NearbyStationsPage(),
        _overrides(reading: const FixReading.unavailable()),
      );

      expect(find.text('Lokasi belum aktif'), findsOneWidget);
      expect(find.text('Aktifkan lokasi'), findsOneWidget);
    });

    testWidgets('location services off points to settings', (tester) async {
      await _pump(
        tester,
        const NearbyStationsPage(),
        _overrides(
          reading: const FixReading.unavailable(),
          gps: const GpsSnapshot(
            serviceEnabled: false,
            permission: GpsPermission.granted,
          ),
        ),
      );

      expect(find.text('Buka pengaturan lokasi'), findsOneWidget);
    });

    testWidgets('survives 1.3x text on a 360 dp screen', (tester) async {
      await _pump(
        tester,
        const NearbyStationsPage(),
        _overrides(),
        textScale: 1.3,
        size: const Size(360, 780),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('StationDetailPage', () {
    testWidgets('shows upcoming departures only, with no placeholder platform', (
      tester,
    ) async {
      await _pump(
        tester,
        const StationDetailPage(stationId: 'BOO'),
        _overrides(),
      );

      expect(find.text('Stasiun Bogor'), findsOneWidget);
      expect(find.text('Keberangkatan berikutnya'), findsOneWidget);
      expect(find.text('Jakarta Kota'), findsNWidgets(2));
      expect(find.textContaining('4 mnt lagi'), findsOneWidget);
      expect(find.textContaining('Peron 2'), findsOneWidget);
      expect(find.textContaining('belum tersedia'), findsNothing);
      expect(find.textContaining('dari kamu'), findsOneWidget);
    });

    testWidgets('empty schedule gets an explanation', (tester) async {
      await _pump(
        tester,
        const StationDetailPage(stationId: 'BOO'),
        _overrides(departures: () async => <Departure>[]),
      );
      expect(find.text('Tidak ada keberangkatan'), findsOneWidget);
    });

    testWidgets('a failing schedule has a retry button', (tester) async {
      await _pump(
        tester,
        const StationDetailPage(stationId: 'BOO'),
        _overrides(departures: () async => throw Exception('offline')),
      );
      expect(find.text('Jadwal belum dimuat'), findsOneWidget);
      expect(find.text('Coba lagi'), findsOneWidget);
    });

    testWidgets('unknown station code says so', (tester) async {
      await _pump(
        tester,
        const StationDetailPage(stationId: 'ZZZ'),
        _overrides(),
      );
      expect(find.text('Stasiun tidak ditemukan'), findsOneWidget);
    });

    testWidgets('survives 1.3x text on a 360 dp screen', (tester) async {
      await _pump(
        tester,
        const StationDetailPage(stationId: 'BOO'),
        _overrides(),
        textScale: 1.3,
        size: const Size(360, 780),
      );
      expect(tester.takeException(), isNull);
    });
  });
}
