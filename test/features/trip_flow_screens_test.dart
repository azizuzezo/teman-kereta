import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:teman_kereta/app/theme/app_theme.dart';
import 'package:teman_kereta/core/preferences/preferences_store.dart';
import 'package:teman_kereta/data/providers/demo_data.dart';
import 'package:teman_kereta/data/providers/provider_registry.dart';
import 'package:teman_kereta/domain/entities/active_trip.dart';
import 'package:teman_kereta/domain/entities/transit_models.dart';
import 'package:teman_kereta/features/active_trip/presentation/active_trip_controller.dart';
import 'package:teman_kereta/features/active_trip/presentation/active_trip_page.dart';
import 'package:teman_kereta/features/multimodal/presentation/multimodal_route_page.dart';
import 'package:teman_kereta/features/onboarding/presentation/onboarding_page.dart';
import 'package:teman_kereta/features/schedule/presentation/schedule_page.dart';
import 'package:teman_kereta/features/schedule/presentation/trip_detail_page.dart';
import 'package:teman_kereta/features/schedule/presentation/trip_search_controller.dart';
import 'package:teman_kereta/features/schedule/presentation/trip_search_page.dart';
import 'package:teman_kereta/features/stations/presentation/nearest_station_controller.dart';

/// Renders the trip-flow screens in every palette x brightness at a narrow
/// width and 1.3x text scale: no overflow or build exception, and the copy
/// the rider relies on is present.

final _now = DateTime(2026, 10, 15, 8);

TransitTrip _trip() {
  return TransitTrip(
    id: 'trip-1',
    originStationId: 'BOO',
    destinationStationId: 'UP',
    departureAt: _now.add(const Duration(minutes: 12)),
    arrivalAt: _now.add(const Duration(minutes: 70)),
    freshness: DataFreshness.estimated,
    sourceLabel: 'Jadwal statis',
    updatedAt: _now,
    transfers: 1,
    walkingMeters: 240,
    isDemo: true,
    legs: <TripLeg>[
      TripLeg(
        id: 'walk',
        mode: TransportMode.walk,
        originName: 'Lokasi kamu',
        destinationName: 'Bogor',
        departureAt: _now,
        arrivalAt: _now.add(const Duration(minutes: 12)),
        walkingMeters: 240,
      ),
      TripLeg(
        id: 'rail-1',
        mode: TransportMode.commuterRail,
        originName: 'Bogor',
        destinationName: 'Cilebut',
        departureAt: _now.add(const Duration(minutes: 12)),
        arrivalAt: _now.add(const Duration(minutes: 30)),
        lineName: 'Commuter Line Bogor',
        headsign: 'Jakarta Kota',
        stationIds: const <String>['BOO', 'CLT', 'BJD', 'CTA'],
        transferInstruction: 'Transit di Citayam, pindah ke peron 2.',
      ),
      TripLeg(
        id: 'rail-2',
        mode: TransportMode.commuterRail,
        originName: 'Citayam',
        destinationName: 'Universitas Pancasila',
        departureAt: _now.add(const Duration(minutes: 36)),
        arrivalAt: _now.add(const Duration(minutes: 70)),
        lineName: 'Commuter Line Cikarang',
        headsign: 'Cikarang',
        stationIds: const <String>['CTA', 'DP', 'DPB', 'POC', 'UI', 'UP'],
      ),
    ],
  );
}

class _FixedSearch extends TripSearchController {
  _FixedSearch(this._state);

  final TripSearchState _state;

  @override
  TripSearchState build() => _state;
}

class _FixedTrip extends ActiveTripController {
  _FixedTrip(this._session);

  final ActiveTripSession? _session;

  @override
  ActiveTripSession? build() => _session;
}

ActiveTripSession _session(ActiveTripState state, int index) {
  return ActiveTripSession(
    id: 'session',
    trip: _trip(),
    state: state,
    currentStationIndex: index,
    startedAt: _now,
    updatedAt: _now,
    distanceMeters: 8400,
    currentSpeedKmh: 42,
  );
}

Departure _departure(int minutes, {String? platform}) {
  final at = DateTime.now().add(Duration(minutes: minutes));
  return Departure(
    id: 'd$minutes',
    stationId: 'BOO',
    destination: 'Jakarta Kota',
    lineName: 'Commuter Line Bogor',
    scheduledAt: at,
    expectedAt: at,
    freshness: DataFreshness.estimated,
    sourceLabel: 'Jadwal statis',
    platform: platform,
  );
}

List<Override> _overrides({
  ActiveTripSession? session,
  TripSearchState? search,
  List<Departure>? departures,
  bool stationsFail = false,
}) {
  return <Override>[
    preferencesStoreProvider.overrideWithValue(MemoryPreferencesStore()),
    stationListProvider.overrideWith(
      (ref) async => stationsFail ? throw Exception('offline') : demoStations,
    ),
    departuresProvider.overrideWith(
      (ref, id) async =>
          departures ?? <Departure>[_departure(3, platform: 'Peron 2')],
    ),
    fixReaderProvider.overrideWithValue(
      () async => const FixReading.unavailable(),
    ),
    tripSearchControllerProvider.overrideWith(
      () => _FixedSearch(
        search ?? TripSearchState(
          originStationId: 'BOO',
          destinationStationId: 'UP',
          departureAt: _now,
        ),
      ),
    ),
    activeTripControllerProvider.overrideWith(() => _FixedTrip(session)),
  ];
}

Future<void> _pump(
  WidgetTester tester,
  Widget screen, {
  required TkPaletteId palette,
  required Brightness brightness,
  List<Override> overrides = const <Override>[],
}) async {
  tester.view.physicalSize = const Size(360 * 3, 4000 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      retry: (_, _) => null,
      child: MaterialApp(
        theme: brightness == Brightness.light
            ? AppTheme.light(palette)
            : AppTheme.dark(palette),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: const TextScaler.linear(1.3),
          ),
          child: child!,
        ),
        home: screen,
      ),
    ),
  );
  // Providers resolve asynchronously; a few frames are enough and avoid
  // waiting on the infinite pulse/ticker animations.
  for (var i = 0; i < 6; i += 1) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void _forEachTheme(
  String name,
  Future<void> Function(
    WidgetTester tester,
    TkPaletteId palette,
    Brightness brightness,
  )
  body,
) {
  for (final palette in TkPaletteId.values) {
    for (final brightness in Brightness.values) {
      testWidgets('$name [${palette.name} ${brightness.name}]', (tester) async {
        final errors = <FlutterErrorDetails>[];
        final previous = FlutterError.onError;
        FlutterError.onError = errors.add;
        try {
          await body(tester, palette, brightness);
        } finally {
          FlutterError.onError = previous;
          if (errors.isNotEmpty) {
            debugPrint(errors.first.toString());
          }
        }
        expect(errors.map((e) => e.toString()).join('\n---\n'), isEmpty);
      });
    }
  }
}

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  _forEachTheme('active trip on board shows status and actions', (
    tester,
    palette,
    brightness,
  ) async {
    await _pump(
      tester,
      const ActiveTripPage(),
      palette: palette,
      brightness: brightness,
      overrides: _overrides(session: _session(ActiveTripState.onBoard, 1)),
    );
    expect(find.text('Stasiun berikutnya'), findsOneWidget);
    expect(find.text('stasiun lagi'), findsOneWidget);
    expect(find.text('Batalkan'), findsOneWidget);
    expect(find.text('Aku sudah turun'), findsOneWidget);
    expect(find.text('Urutan stasiun'), findsOneWidget);
  });

  _forEachTheme('active trip transferring keeps the transfer copy', (
    tester,
    palette,
    brightness,
  ) async {
    await _pump(
      tester,
      const ActiveTripPage(),
      palette: palette,
      brightness: brightness,
      overrides: _overrides(session: _session(ActiveTripState.transferring, 3)),
    );
    expect(find.text('Turun dan transit di'), findsOneWidget);
    expect(find.text('Transit di Citayam, pindah ke peron 2.'), findsWidgets);
  });

  _forEachTheme('active trip arrived offers to finish', (
    tester,
    palette,
    brightness,
  ) async {
    await _pump(
      tester,
      const ActiveTripPage(),
      palette: palette,
      brightness: brightness,
      overrides: _overrides(session: _session(ActiveTripState.arrived, 5)),
    );
    expect(find.text('Kamu tiba di'), findsOneWidget);
    expect(find.text('Selesaikan perjalanan'), findsOneWidget);
  });

  _forEachTheme('active trip missed destination keeps its actions', (
    tester,
    palette,
    brightness,
  ) async {
    await _pump(
      tester,
      const ActiveTripPage(),
      palette: palette,
      brightness: brightness,
      overrides: _overrides(
        session: _session(ActiveTripState.missedDestination, 5),
      ),
    );
    expect(find.textContaining('Sepertinya kamu melewati'), findsOneWidget);
    expect(find.text('Akhiri perjalanan'), findsOneWidget);
  });

  testWidgets('cancel asks for confirmation before stopping the trip', (
    tester,
  ) async {
    await _pump(
      tester,
      const ActiveTripPage(),
      palette: TkPaletteId.navyKrl,
      brightness: Brightness.light,
      overrides: _overrides(session: _session(ActiveTripState.onBoard, 1)),
    );
    await tester.tap(find.text('Batalkan'));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Batalkan perjalanan?'), findsOneWidget);
    expect(find.text('Lanjutkan perjalanan'), findsOneWidget);
    await tester.tap(find.text('Lanjutkan perjalanan'));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Batalkan perjalanan?'), findsNothing);
  });

  testWidgets('finish asks for confirmation too', (tester) async {
    await _pump(
      tester,
      const ActiveTripPage(),
      palette: TkPaletteId.navyKrl,
      brightness: Brightness.dark,
      overrides: _overrides(session: _session(ActiveTripState.onBoard, 1)),
    );
    await tester.tap(find.text('Aku sudah turun'));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Sudah turun di tujuan?'), findsOneWidget);
    await tester.tap(find.text('Belum, lanjutkan'));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Sudah turun di tujuan?'), findsNothing);
  });

  _forEachTheme('schedule shows the search entry and a countdown', (
    tester,
    palette,
    brightness,
  ) async {
    await _pump(
      tester,
      const SchedulePage(),
      palette: palette,
      brightness: brightness,
      overrides: _overrides(),
    );
    expect(find.text('Cari kereta'), findsOneWidget);
    expect(find.text('Keberangkatan berikutnya'), findsOneWidget);
    expect(find.text('Berikutnya'), findsOneWidget);
    expect(find.textContaining('Nomor'), findsNothing);
  });

  _forEachTheme('schedule empty state renders', (
    tester,
    palette,
    brightness,
  ) async {
    await _pump(
      tester,
      const SchedulePage(),
      palette: palette,
      brightness: brightness,
      overrides: _overrides(departures: const <Departure>[]),
    );
    expect(find.text('Tidak ada keberangkatan'), findsOneWidget);
  });

  _forEachTheme('schedule error state offers a retry', (
    tester,
    palette,
    brightness,
  ) async {
    await _pump(
      tester,
      const SchedulePage(),
      palette: palette,
      brightness: brightness,
      overrides: _overrides(stationsFail: true),
    );
    expect(find.text('Coba lagi'), findsOneWidget);
  });

  _forEachTheme('trip search shows results with real times', (
    tester,
    palette,
    brightness,
  ) async {
    await _pump(
      tester,
      const TripSearchPage(),
      palette: palette,
      brightness: brightness,
      overrides: _overrides(
        search: TripSearchState(
          originStationId: 'BOO',
          destinationStationId: 'UP',
          departureAt: _now,
          hasSearched: true,
          results: <TransitTrip>[_trip()],
        ),
      ),
    );
    expect(find.text('Dari'), findsOneWidget);
    expect(find.text('Ke'), findsOneWidget);
    expect(find.text('1 alternatif'), findsOneWidget);
    expect(find.text('Pilihan tercepat'), findsOneWidget);
    expect(find.text('Berangkat'), findsOneWidget);
  });

  _forEachTheme('trip detail has one primary action and the stop list', (
    tester,
    palette,
    brightness,
  ) async {
    await _pump(
      tester,
      const TripDetailPage(tripId: 'trip-1'),
      palette: palette,
      brightness: brightness,
      overrides: _overrides(
        search: TripSearchState(
          originStationId: 'BOO',
          destinationStationId: 'UP',
          departureAt: _now,
          results: <TransitTrip>[_trip()],
        ),
      ),
    );
    expect(find.text('Mulai perjalanan'), findsOneWidget);
    expect(find.text('Langkah perjalanan'), findsOneWidget);
    expect(find.text('Stasiun yang dilewati'), findsOneWidget);
    expect(find.textContaining('Nomor'), findsNothing);
  });

  _forEachTheme('multimodal page lists legs and ride-hailing apps', (
    tester,
    palette,
    brightness,
  ) async {
    await _pump(
      tester,
      const MultimodalRoutePage(tripId: 'trip-1'),
      palette: palette,
      brightness: brightness,
      overrides: _overrides(
        search: TripSearchState(
          originStationId: 'BOO',
          destinationStationId: 'UP',
          departureAt: _now,
          results: <TransitTrip>[_trip()],
        ),
      ),
    );
    expect(find.text('Gojek'), findsOneWidget);
    expect(find.text('Grab'), findsOneWidget);
  });

  _forEachTheme('onboarding walks through four steps', (
    tester,
    palette,
    brightness,
  ) async {
    await _pump(
      tester,
      const OnboardingPage(),
      palette: palette,
      brightness: brightness,
      overrides: _overrides(),
    );
    expect(find.text('Mulai'), findsOneWidget);
    await tester.tap(find.text('Mulai'));
    await tester.pumpAndSettle();
    expect(find.text('Lokasi, secara bertahap'), findsOneWidget);
    expect(find.text('Lewati sekarang'), findsOneWidget);
    await tester.tap(find.text('Lewati sekarang'));
    await tester.pumpAndSettle();
    expect(find.text('Peringatan yang bisa diatur'), findsOneWidget);
    expect(find.text('Aktifkan notifikasi'), findsOneWidget);
    expect(find.text('Izinkan di latar belakang'), findsOneWidget);
    await tester.tap(find.text('Lewati sekarang'));
    await tester.pumpAndSettle();
    expect(find.text('Simpan rute harian'), findsOneWidget);
    expect(find.text('Buka Teman Kereta'), findsOneWidget);
  });
}
