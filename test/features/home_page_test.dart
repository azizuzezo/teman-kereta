import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:teman_kereta/app/theme/app_theme.dart';
import 'package:teman_kereta/core/network/device_status.dart';
import 'package:teman_kereta/core/network/gps_status_controller.dart';
import 'package:teman_kereta/core/network/internet_status_controller.dart';
import 'package:teman_kereta/core/notifications/local_notification_service.dart';
import 'package:teman_kereta/core/platform/native_trip_service.dart';
import 'package:teman_kereta/core/preferences/preferences_store.dart';
import 'package:teman_kereta/data/providers/provider_registry.dart';
import 'package:teman_kereta/domain/entities/transit_models.dart';
import 'package:teman_kereta/features/account/presentation/account_controller.dart';
import 'package:teman_kereta/features/home/presentation/home_page.dart';
import 'package:teman_kereta/features/stations/presentation/nearest_station_controller.dart';

import '../support/fakes.dart';

final _now = DateTime(2026, 10, 15, 8, 0, 0);

const _bogor = Station(
  id: 'BOO',
  code: 'BOO',
  name: 'Bogor',
  latitude: -6.5950,
  longitude: 106.7906,
);
const _cilebut = Station(
  id: 'CLT',
  code: 'CLT',
  name: 'Cilebut',
  latitude: -6.5309,
  longitude: 106.8005,
);

Departure _departure(String id, String stationId, int minutes, String dest) =>
    Departure(
      id: id,
      stationId: stationId,
      destination: dest,
      lineName: 'Commuter Line Bogor',
      scheduledAt: _now.add(Duration(minutes: minutes)),
      expectedAt: _now.add(Duration(minutes: minutes)),
      freshness: DataFreshness.estimated,
      sourceLabel: 'Jadwal statis',
      tripNumber: null,
    );

class _Harness {
  _Harness({
    this.reading = const FixReading.ok(-6.5949, 106.7907),
    this.alerts = const <ServiceAlert>[],
    this.gps = const GpsSnapshot(
      serviceEnabled: true,
      permission: GpsPermission.granted,
    ),
    this.latencyMs = 120,
  });

  FixReading reading;
  final List<ServiceAlert> alerts;
  GpsSnapshot gps;
  final int latencyMs;
  int fixCalls = 0;
  int probeCalls = 0;
  final requestedDepartures = <String>[];

  List<Override> overrides() {
    final store = MemoryPreferencesStore();
    return [
      preferencesStoreProvider.overrideWithValue(store),
      clockProvider.overrideWithValue(Clock.fixed(_now)),
      nativeTripServiceProvider.overrideWithValue(FakeNativeTripService()),
      localNotificationServiceProvider.overrideWithValue(
        FakeNotificationService(),
      ),
      stationListProvider.overrideWith(
        (ref) async => const <Station>[_bogor, _cilebut],
      ),
      departuresProvider.overrideWith((ref, stationId) async {
        requestedDepartures.add(stationId);
        return <Departure>[
          _departure('t1', stationId, 5, 'Jakarta Kota'),
          _departure('t2', stationId, 17, 'Manggarai'),
          _departure('t3', stationId, 29, 'Angke'),
        ];
      }),
      serviceAlertsProvider.overrideWith((ref) => Stream.value(alerts)),
      vehiclePositionsProvider.overrideWith(
        (ref) => Stream.value(const <VehiclePosition>[]),
      ),
      userDisplayNameProvider.overrideWith((ref) async => 'Aziz'),
      fixReaderProvider.overrideWithValue(() async {
        fixCalls++;
        return reading;
      }),
      latencyProbeProvider.overrideWithValue(() async {
        probeCalls++;
        return latencyMs;
      }),
      connectionCheckProvider.overrideWithValue(() async => true),
      gpsProbeProvider.overrideWithValue(() async => gps),
    ];
  }
}

Future<void> _scrollToStatus(WidgetTester tester) async {
  await tester.scrollUntilVisible(
    find.text('Status perangkat'),
    300,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pump(const Duration(milliseconds: 100));
}

Future<void> _pump(
  WidgetTester tester,
  _Harness harness, {
  double textScale = 1.0,
  Size size = const Size(390, 900),
  bool tickersEnabled = true,
}) async {
  tester.view.physicalSize = size * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: harness.overrides(),
      child: MaterialApp(
        theme: AppTheme.light(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: TickerMode(enabled: tickersEnabled, child: const HomePage()),
      ),
    ),
  );
  // Let the async providers resolve without waiting on the periodic timers.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('id_ID');
  });

  testWidgets('shows the nearest station, the estimate and the next train', (
    tester,
  ) async {
    final harness = _Harness();
    await _pump(tester, harness);

    expect(find.text('Stasiun terdekat'), findsOneWidget);
    expect(find.text('Stasiun Bogor'), findsOneWidget);
    expect(find.textContaining('dari kamu'), findsOneWidget);
    expect(find.textContaining('jalan kaki'), findsOneWidget);
    expect(find.text('Kereta berikutnya'), findsOneWidget);
    expect(find.text('Jakarta Kota'), findsOneWidget);
    expect(find.text('Manggarai'), findsOneWidget);
    expect(find.textContaining('5 mnt lagi'), findsOneWidget);
    expect(harness.requestedDepartures, contains('BOO'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('never shows a train number label', (tester) async {
    await _pump(tester, _Harness());
    expect(find.textContaining('Nomor'), findsNothing);
    expect(find.textContaining('No. KA'), findsNothing);
    expect(find.text('Peron belum tersedia'), findsNothing);
  });

  testWidgets('without a location it says it is using the home station', (
    tester,
  ) async {
    final harness = _Harness(reading: const FixReading.unavailable());
    await _pump(tester, harness);

    expect(find.text('Stasiun bawaan'), findsOneWidget);
    expect(find.textContaining('jalan kaki'), findsNothing);
    expect(find.textContaining('stasiun rumah'), findsOneWidget);
  });

  testWidgets('the list follows the nearest station when it changes', (
    tester,
  ) async {
    final harness = _Harness();
    await _pump(tester, harness);
    expect(find.text('Stasiun Bogor'), findsOneWidget);

    harness.reading = const FixReading.ok(-6.5310, 106.8004);
    await tester.pump(homeLocationInterval);
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Stasiun Cilebut'), findsOneWidget);
    expect(harness.requestedDepartures, contains('CLT'));
  });

  testWidgets('polls the position every 10 seconds while Home is visible', (
    tester,
  ) async {
    final harness = _Harness();
    await _pump(tester, harness);
    final before = harness.fixCalls;

    await tester.pump(homeLocationInterval);
    expect(harness.fixCalls, before + 1);
    await tester.pump(homeLocationInterval);
    expect(harness.fixCalls, before + 2);
  });

  testWidgets('stops polling in the background and resumes in the foreground', (
    tester,
  ) async {
    final harness = _Harness();
    await _pump(tester, harness);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    final paused = harness.fixCalls;
    final pausedProbes = harness.probeCalls;
    await tester.pump(const Duration(seconds: 60));
    expect(harness.fixCalls, paused);
    expect(harness.probeCalls, pausedProbes);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(harness.fixCalls, greaterThan(paused));
  });

  testWidgets('does not poll when the Home tab is not the visible one', (
    tester,
  ) async {
    final harness = _Harness();
    await _pump(tester, harness, tickersEnabled: false);
    final before = harness.fixCalls;

    await tester.pump(const Duration(seconds: 60));

    expect(harness.fixCalls, before);
    expect(harness.probeCalls, 0);
  });

  testWidgets('internet tile shows measured latency with a word, not only color', (
    tester,
  ) async {
    await _pump(tester, _Harness(latencyMs: 120));
    await _scrollToStatus(tester);

    expect(find.text('Status perangkat'), findsOneWidget);
    expect(find.text('120 ms'), findsOneWidget);
    expect(find.text('Baik'), findsOneWidget);
  });

  testWidgets('a slow connection is labelled slow', (tester) async {
    await _pump(tester, _Harness(latencyMs: 500));
    await _scrollToStatus(tester);
    // 500 ms on the first probe triggers one warm-up re-measure, still 500.
    expect(find.text('500 ms'), findsOneWidget);
    expect(find.text('Lambat'), findsOneWidget);
  });

  testWidgets('GPS off offers to open settings', (tester) async {
    final harness = _Harness(
      gps: const GpsSnapshot(
        serviceEnabled: false,
        permission: GpsPermission.granted,
      ),
    );
    await _pump(tester, harness);
    await _scrollToStatus(tester);

    expect(find.text('GPS mati'), findsOneWidget);
    expect(find.text('Buka pengaturan'), findsOneWidget);
  });

  testWidgets('GPS permission denied offers to ask again', (tester) async {
    final harness = _Harness(
      gps: const GpsSnapshot(
        serviceEnabled: true,
        permission: GpsPermission.denied,
      ),
    );
    await _pump(tester, harness);
    await _scrollToStatus(tester);

    expect(find.text('Izinkan lokasi'), findsOneWidget);
  });

  testWidgets('normal service shows no alert banner', (tester) async {
    await _pump(tester, _Harness());
    expect(find.textContaining('info lainnya'), findsNothing);
    expect(find.byIcon(Icons.warning_amber_rounded), findsNothing);
  });

  testWidgets('a real disruption shows a compact banner', (tester) async {
    final harness = _Harness(
      alerts: <ServiceAlert>[
        ServiceAlert(
          id: 'a1',
          title: 'Gangguan sinyal Manggarai',
          description: 'Perjalanan terlambat sekitar 20 menit.',
          status: ServiceStatus.disrupted,
          updatedAt: _now,
          sourceLabel: 'Operator',
        ),
      ],
    );
    await _pump(tester, harness);
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Gangguan sinyal Manggarai'), findsOneWidget);
  });

  testWidgets('survives 1.3x text scale on a 360 dp screen', (tester) async {
    await _pump(
      tester,
      _Harness(),
      textScale: 1.3,
      size: const Size(360, 800),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(tester.takeException(), isNull);
    expect(find.text('Stasiun Bogor'), findsOneWidget);

    await _scrollToStatus(tester);
    expect(tester.takeException(), isNull);
    expect(find.text('120 ms'), findsOneWidget);
  });
}
