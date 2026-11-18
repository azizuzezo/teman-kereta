import 'dart:convert';
import 'dart:io';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teman_kereta/app/theme/app_theme.dart';
import 'package:teman_kereta/data/providers/provider_registry.dart';
import 'package:teman_kereta/domain/entities/active_trip.dart';
import 'package:teman_kereta/features/active_trip/presentation/active_trip_controller.dart';
import 'package:teman_kereta/features/intercity/data/intercity_repository.dart';
import 'package:teman_kereta/features/intercity/domain/intercity_models.dart';
import 'package:teman_kereta/features/intercity/presentation/intercity_map_page.dart';
import 'package:teman_kereta/features/intercity/presentation/widgets/intercity_trip_card.dart';
import 'package:teman_kereta/features/live_map/presentation/map_tiles.dart';

final _transparentPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
);

class _FakeTileProvider extends TileProvider {
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) =>
      MemoryImage(_transparentPng);
}

/// No ride in progress, without the storage the real controller needs.
class _NoTrip extends ActiveTripController {
  @override
  ActiveTripSession? build() => null;
}

IntercityCatalog _catalog() => IntercityCatalog.fromJson(
  jsonDecode(File('assets/intercity/intercity_v2.json').readAsStringSync())
      as Map<String, dynamic>,
);

/// 18 November 2026, 08:00 WIB: before the GAPEKA 2026 timetable starts.
final _beforeTimetable = timetableInstant(DateTime.utc(2026, 11, 18), 8 * 60);

/// 2 December 2026, 04:00 WIB: the timetable is in force.
final _onTimetable = timetableInstant(DateTime.utc(2026, 12, 2), 4 * 60);

Widget _app(Widget child, {DateTime? now}) => ProviderScope(
  overrides: [
    intercityCatalogProvider.overrideWith((ref) async => _catalog()),
    mapTileProviderProvider.overrideWithValue(_FakeTileProvider()),
    clockProvider.overrideWithValue(Clock.fixed(now ?? _beforeTimetable)),
  ],
  child: MaterialApp(
    theme: AppTheme.light(),
    home: Scaffold(body: SingleChildScrollView(child: child)),
  ),
);

Future<void> _pickStation(
  WidgetTester tester, {
  required String field,
  required String search,
  required String result,
}) async {
  await tester.tap(find.text(field));
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextField).last, search);
  await tester.pumpAndSettle();
  await tester.tap(find.text(result).last);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  group('IntercityTripCard', () {
    testWidgets('lists the trains for Gambir to Kiaracondong and offers a name of '
        'your own', (tester) async {
      tester.view.physicalSize = const Size(800, 2200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_app(const IntercityTripCard()));
      await tester.pumpAndSettle();

      await _pickStation(tester, field: 'Naik dari', search: 'Gambir', result: 'Gambir');
      await _pickStation(tester, field: 'Turun di', search: 'Kiaracondong', result: 'Kiaracondong');

      expect(find.text('Papandayan'), findsOneWidget);
      expect(find.text('Pangandaran'), findsOneWidget);
      expect(find.text('Kereta lain (isi nama sendiri)'), findsOneWidget);
    });

    testWidgets('the station list names the city, not just the island', (tester) async {
      tester.view.physicalSize = const Size(800, 2200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_app(const IntercityTripCard()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Naik dari'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'Gambir');
      await tester.pumpAndSettle();
      expect(find.text('Jakarta Pusat, DKI Jakarta'), findsOneWidget);
      expect(find.text('Jawa'), findsNothing);
    });

    testWidgets('a pair no listed train serves asks for your own train name', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 2600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_app(const IntercityTripCard()));
      await tester.pumpAndSettle();

      await _pickStation(tester, field: 'Naik dari', search: 'Kertapati', result: 'Kertapati');
      // Gambir is on another island: no listed train links the two.
      await tester.tap(find.text('Turun di'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'Gambir');
      await tester.pumpAndSettle();
      expect(find.textContaining('belum ada kereta tercatat'), findsOneWidget);
      await tester.tap(find.text('Gambir').last);
      await tester.pumpAndSettle();

      expect(find.text('Isi nama kereta sendiri'), findsOneWidget);
      final start = find.widgetWithText(FilledButton, 'Mulai perjalanan');
      expect(tester.widget<FilledButton>(start).onPressed, isNull);

      await tester.enterText(find.byType(TextField).last, 'Argo Sumatra');
      await tester.pumpAndSettle();
      expect(tester.widget<FilledButton>(start).onPressed, isNotNull);
    });

    testWidgets('from the timetable start, lists the day\'s departures with the '
        'estimate kept as a choice', (tester) async {
      tester.view.physicalSize = const Size(800, 3200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        _app(const IntercityTripCard(), now: _onTimetable),
      );
      await tester.pumpAndSettle();

      await _pickStation(tester, field: 'Naik dari', search: 'Bandung', result: 'Bandung');
      await _pickStation(tester, field: 'Turun di', search: 'Gambir', result: 'Gambir');

      expect(find.text('Pilih keberangkatan hari ini'), findsOneWidget);
      expect(find.text('KA 131 Parahyangan'), findsOneWidget);
      expect(find.textContaining('05:00 → 08:08'), findsOneWidget);
      // The fakultatif run carries its chip.
      expect(find.text('KA 141F Parahyangan Fakultatif'), findsOneWidget);
      expect(find.text('Fakultatif'), findsWidgets);
      // The train list waits behind "Pakai perkiraan".
      expect(find.text('Pilih kereta'), findsNothing);
      final start = find.widgetWithText(FilledButton, 'Mulai perjalanan');
      expect(tester.widget<FilledButton>(start).onPressed, isNull);

      await tester.tap(find.text('KA 131 Parahyangan'));
      await tester.pumpAndSettle();
      expect(tester.widget<FilledButton>(start).onPressed, isNotNull);

      await tester.tap(find.text('Pakai perkiraan (tanpa jadwal)'));
      await tester.pumpAndSettle();
      expect(find.text('Pilih kereta'), findsOneWidget);
      expect(find.text('Parahyangan'), findsOneWidget);
    });

    testWidgets('before the timetable start, only the estimate is offered', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 2200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_app(const IntercityTripCard()));
      await tester.pumpAndSettle();

      await _pickStation(tester, field: 'Naik dari', search: 'Bandung', result: 'Bandung');
      await _pickStation(tester, field: 'Turun di', search: 'Gambir', result: 'Gambir');

      expect(find.text('Pilih keberangkatan hari ini'), findsNothing);
      expect(find.text('Pakai perkiraan (tanpa jadwal)'), findsNothing);
      expect(find.text('Pilih kereta'), findsOneWidget);
      expect(find.text('Parahyangan'), findsOneWidget);
    });
  });

  group('IntercityMapPage', () {
    testWidgets('shows a train\'s route and says how precise it is', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            intercityCatalogProvider.overrideWith((ref) async => _catalog()),
            mapTileProviderProvider.overrideWithValue(_FakeTileProvider()),
            activeTripControllerProvider.overrideWith(_NoTrip.new),
            clockProvider.overrideWithValue(Clock.fixed(_beforeTimetable)),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const IntercityMapPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Pilih kereta'), findsWidgets);
      expect(find.byType(FlutterMap), findsOneWidget);

      await tester.tap(find.text('Pilih kereta').first);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'Parahyangan');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Parahyangan').last);
      await tester.pumpAndSettle();

      expect(find.text('Gambir – Bandung'), findsWidgets);
      // One line of summary first; the detail opens on request.
      expect(find.textContaining('Rute mengikuti rel'), findsOneWidget);
      expect(find.text('Seberapa tepat rute ini?'), findsNothing);
      await tester.tap(find.textContaining('Lihat detail dan pemberhentian'));
      await tester.pumpAndSettle();
      expect(find.text('Seberapa tepat rute ini?'), findsOneWidget);
      expect(find.textContaining('Garis mengikuti rel dari OpenStreetMap'), findsOneWidget);
      expect(find.textContaining('Wikipedia'), findsOneWidget);
      expect(find.byType(PolylineLayer<Object>), findsOneWidget);
    });
  });
}
