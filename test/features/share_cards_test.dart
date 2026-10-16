import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teman_kereta/app/theme/app_theme.dart';
import 'package:teman_kereta/features/history/presentation/share/share_card_renderer.dart';
import 'package:teman_kereta/features/history/presentation/share/share_cards.dart';
import 'package:teman_kereta/features/history/presentation/share/share_data.dart';
import 'package:teman_kereta/features/history/presentation/share/share_preview_sheet.dart';

final _trip = TripShareData(
  originName: 'Depok',
  destinationName: 'Jakarta Kota',
  date: DateTime(2026, 10, 15, 7),
  duration: const Duration(minutes: 48),
  stationCount: 14,
  lineName: 'Commuter Line Bogor',
);

const _recap = RecapShareData(
  periodLabel: 'Minggu ini',
  periodPhrase: 'minggu ini',
  rangeLabel: '12 Okt - 18 Okt 2026',
  tripCount: 8,
  totalTime: Duration(hours: 5, minutes: 20),
  topRouteLabel: 'Depok → Jakarta Kota',
  topRouteCount: 5,
  tripsByWeekday: <int, int>{1: 2, 2: 1, 3: 3, 5: 2},
);

Widget _host(Widget child, {double textScale = 1}) {
  return MaterialApp(
    theme: AppTheme.light(),
    builder: (context, app) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(textScale),
      ),
      child: app!,
    ),
    home: Scaffold(body: SingleChildScrollView(child: child)),
  );
}

/// Pixel size from a PNG's IHDR chunk.
({int width, int height}) _pngSize(Uint8List bytes) {
  final data = ByteData.sublistView(bytes);
  return (width: data.getUint32(16), height: data.getUint32(20));
}

void main() {
  group('share cards', () {
    for (final aspect in ShareAspect.values) {
      testWidgets('trip card renders every real value (${aspect.label})', (
        tester,
      ) async {
        await tester.pumpWidget(
          _host(TripShareCard(data: _trip, aspect: aspect)),
        );
        expect(tester.takeException(), isNull);
        expect(find.text('Depok'), findsOneWidget);
        expect(find.text('Jakarta Kota'), findsOneWidget);
        expect(find.text('48 menit'), findsOneWidget);
        expect(find.text('15 Okt 2026'), findsOneWidget);
        expect(find.text('14'), findsOneWidget);
        expect(find.text('Commuter Line Bogor'), findsOneWidget);
        expect(
          tester.getSize(find.byType(TripShareCard)),
          aspect.size,
        );
      });

      testWidgets('recap card renders every real value (${aspect.label})', (
        tester,
      ) async {
        await tester.pumpWidget(
          _host(RecapShareCard(data: _recap, aspect: aspect)),
        );
        expect(tester.takeException(), isNull);
        expect(find.text('Minggu ini'), findsOneWidget);
        expect(find.text('8'), findsOneWidget);
        expect(find.text('5j 20m'), findsOneWidget);
        expect(find.text('Depok → Jakarta Kota'), findsOneWidget);
        expect(tester.getSize(find.byType(RecapShareCard)), aspect.size);
      });

      testWidgets('trip card survives long names and 1.3x text scale (${aspect.label})', (
        tester,
      ) async {
        final long = TripShareData(
          originName: 'Stasiun Cikini Tanah Abang Interchange Panjang Sekali',
          destinationName: 'Stasiun Pondok Ranji Rangkasbitung Lintas Panjang',
          date: DateTime(2026, 10, 15),
          duration: const Duration(hours: 1, minutes: 5),
          stationCount: 40,
          lineName: 'Commuter Line Cikarang Loop Line Lintas Raya',
        );
        await tester.pumpWidget(
          _host(TripShareCard(data: long, aspect: aspect), textScale: 1.3),
        );
        expect(tester.takeException(), isNull);
      });

      testWidgets('recap card survives a long route name (${aspect.label})', (
        tester,
      ) async {
        final long = RecapShareData(
          periodLabel: 'Semua',
          periodPhrase: 'sejauh ini',
          rangeLabel: 'Sejak 2 Mar 2026',
          tripCount: 1234,
          totalTime: const Duration(hours: 120, minutes: 5),
          topRouteLabel:
              'Stasiun Pondok Ranji Rangkasbitung → Stasiun Cikini Tanah Abang',
          topRouteCount: 99,
          tripsByWeekday: const <int, int>{1: 400, 2: 300, 3: 300, 4: 234},
        );
        await tester.pumpWidget(
          _host(RecapShareCard(data: long, aspect: aspect), textScale: 1.3),
        );
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('trip card omits blocks whose value is missing', (tester) async {
      final bare = TripShareData(
        originName: 'Depok',
        destinationName: 'Manggarai',
        date: DateTime(2026, 10, 15),
      );
      await tester.pumpWidget(
        _host(TripShareCard(data: bare, aspect: ShareAspect.portrait)),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('WAKTU TEMPUH'), findsNothing);
      expect(find.text('Waktu tempuh'), findsNothing);
      expect(find.text('STASIUN'), findsNothing);
      expect(find.text('JALUR'), findsNothing);
      // The date is always known.
      expect(find.text('TANGGAL'), findsOneWidget);
    });

    testWidgets('recap card omits time, route and chart when absent', (
      tester,
    ) async {
      const bare = RecapShareData(
        periodLabel: 'Bulan ini',
        periodPhrase: 'bulan ini',
        tripCount: 1,
        totalTime: Duration.zero,
        tripsByWeekday: <int, int>{},
      );
      await tester.pumpWidget(
        _host(RecapShareCard(data: bare, aspect: ShareAspect.portrait)),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('DI KERETA'), findsNothing);
      expect(find.text('RUTE TERSERING'), findsNothing);
      expect(find.byType(CustomPaint), findsWidgets);
    });
  });

  group('share preview sheet', () {
    testWidgets('opens, switches aspect and offers Bagikan', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: FilledButton(
                  onPressed: () =>
                      showSharePreviewSheet(context, TripShareSpec(_trip)),
                  child: const Text('Buka'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Buka'));
      await tester.pumpAndSettle();

      expect(find.text('Bagikan perjalanan'), findsOneWidget);
      expect(find.text('Bagikan'), findsOneWidget);
      expect(find.byType(TripShareCard), findsOneWidget);
      var card = tester.widget<TripShareCard>(find.byType(TripShareCard));
      expect(card.aspect, ShareAspect.portrait);

      await tester.tap(find.text('Story 9:16'));
      await tester.pumpAndSettle();
      card = tester.widget<TripShareCard>(find.byType(TripShareCard));
      expect(card.aspect, ShareAspect.story);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a failing share shows a snackbar and re-enables the button', (
      tester,
    ) async {
      final renderer = ShareCardRenderer(
        waitForFrame: () async {},
        writeFile: (bytes, stem) async => throw StateError('disk'),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: FilledButton(
                  onPressed: () => showSharePreviewSheet(
                    context,
                    RecapShareSpec(_recap),
                    renderer: renderer,
                  ),
                  child: const Text('Buka'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Buka'));
      await tester.pumpAndSettle();
      expect(find.text('Bagikan rekap'), findsOneWidget);

      // Rendering needs real async work (image encoding), so let it run for
      // real time while the sheet is on screen.
      await tester.runAsync(() async {
        await tester.tap(find.text('Bagikan'));
        await Future<void>.delayed(const Duration(milliseconds: 500));
      });
      await tester.pump();

      expect(find.text('Gagal membagikan gambar. Coba lagi.'), findsWidgets);
      expect(find.text('Bagikan'), findsOneWidget);
    });
  });

  group('ShareCardRenderer', () {
    testWidgets('renders 1080x1350 and 1080x1920 PNGs off-screen', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(body: SizedBox.expand()),
        ),
      );
      final context = tester.element(find.byType(Scaffold));
      final renderer = ShareCardRenderer(
        // Tests do not produce frames on their own; pump one for the overlay.
        waitForFrame: () => tester.pump(),
      );

      final sizes = <ShareAspect, ({int width, int height})>{};
      await tester.runAsync(() async {
        for (final aspect in ShareAspect.values) {
          final bytes = await renderer.renderPng(
            context,
            TripShareCard(data: _trip, aspect: aspect),
            aspect.size,
          );
          // PNG signature.
          expect(bytes.sublist(0, 8), <int>[137, 80, 78, 71, 13, 10, 26, 10]);
          sizes[aspect] = _pngSize(bytes);
        }
      });

      expect(sizes[ShareAspect.portrait], (width: 1080, height: 1350));
      expect(sizes[ShareAspect.story], (width: 1080, height: 1920));
      // The off-screen entry is gone once the next frame has been built.
      await tester.pump();
      expect(find.byType(TripShareCard), findsNothing);
    });
  });
}
