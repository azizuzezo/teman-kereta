import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teman_kereta/app/theme/app_theme.dart';
import 'package:teman_kereta/core/database/app_database.dart';
import 'package:teman_kereta/data/providers/provider_registry.dart';
import 'package:teman_kereta/domain/entities/transit_models.dart';
import 'package:teman_kereta/features/history/presentation/share/share_cards.dart';
import 'package:teman_kereta/features/history/presentation/trip_history_page.dart';
import 'package:teman_kereta/features/history/presentation/trip_recap_page.dart';

// Thursday 15 October 2026, 10:00.
final _now = DateTime(2026, 10, 15, 10);

CompletedTrip _trip(
  String id,
  DateTime departedAt, {
  String origin = 'Depok',
  String destination = 'Manggarai',
  int minutes = 40,
  String? line = 'Commuter Line Bogor',
}) {
  final arrived = departedAt.add(Duration(minutes: minutes));
  return CompletedTrip(
    id: id,
    originStationId: 'o-$origin',
    originName: origin,
    destinationStationId: 'd-$destination',
    destinationName: destination,
    lineName: line,
    departedAt: departedAt,
    arrivedAt: arrived,
    isDemo: false,
    completedAt: arrived,
  );
}

Future<void> _pump(
  WidgetTester tester,
  Widget page, {
  Stream<List<CompletedTrip>>? history,
  double textScale = 1,
}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        tripHistoryProvider.overrideWith(
          (ref) => history ?? Stream.value(const <CompletedTrip>[]),
        ),
        stationListProvider.overrideWith((ref) async => const <Station>[]),
        clockProvider.overrideWithValue(Clock.fixed(_now)),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        builder: (context, app) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale),
          ),
          child: app!,
        ),
        home: page,
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

void main() {
  group('TripHistoryPage', () {
    testWidgets('shows an honest empty state with a way forward', (
      tester,
    ) async {
      await _pump(tester, const TripHistoryPage());
      expect(find.text('Belum ada perjalanan selesai'), findsOneWidget);
      expect(find.text('Cari kereta'), findsOneWidget);
      // Nothing to delete, so the clear action is disabled.
      final clear = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.delete_outline_rounded),
      );
      expect(clear.onPressed, isNull);
    });

    testWidgets('shows a retryable error state', (tester) async {
      await _pump(
        tester,
        const TripHistoryPage(),
        history: Stream<List<CompletedTrip>>.error(StateError('db')),
      );
      expect(find.text('Riwayat belum bisa dimuat'), findsOneWidget);
      expect(find.text('Coba lagi'), findsOneWidget);
    });

    testWidgets('groups trips by day and opens a detail with Bagikan', (
      tester,
    ) async {
      await _pump(
        tester,
        const TripHistoryPage(),
        history: Stream.value(<CompletedTrip>[
          _trip('a', DateTime(2026, 10, 15, 7)),
          _trip('b', DateTime(2026, 10, 14, 18), origin: 'Manggarai', destination: 'Depok'),
        ]),
      );
      expect(find.text('Hari ini'), findsOneWidget);
      expect(find.text('Kemarin'), findsOneWidget);
      expect(find.text('07:00'), findsOneWidget);
      expect(find.text('40 menit'), findsNWidgets(2));

      await tester.tap(find.text('07:00'));
      await tester.pumpAndSettle();
      expect(find.text('Detail perjalanan'), findsOneWidget);
      expect(find.text('Jam mengikuti jadwal perjalanan yang kamu pilih.'),
          findsOneWidget);

      await tester.tap(find.text('Bagikan'));
      await tester.pumpAndSettle();
      expect(find.text('Bagikan perjalanan'), findsOneWidget);
      expect(find.byType(TripShareCard), findsOneWidget);
    });

    testWidgets('rows survive 1.3x text scale', (tester) async {
      await _pump(
        tester,
        const TripHistoryPage(),
        textScale: 1.3,
        history: Stream.value(<CompletedTrip>[
          _trip(
            'a',
            DateTime(2026, 10, 15, 7),
            origin: 'Stasiun Pondok Ranji Rangkasbitung',
            destination: 'Jakarta Kota Beos Panjang Sekali',
            line: 'Commuter Line Cikarang Loop Line Panjang',
          ),
        ]),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('TripRecapPage', () {
    testWidgets('empty history reads honestly and offers no share', (
      tester,
    ) async {
      await _pump(tester, const TripRecapPage());
      expect(find.text('Belum ada yang bisa direkap'), findsOneWidget);
      final share = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.ios_share_rounded),
      );
      expect(share.onPressed, isNull);
    });

    testWidgets('period switch narrows the numbers to real trips', (
      tester,
    ) async {
      await _pump(
        tester,
        const TripRecapPage(),
        history: Stream.value(<CompletedTrip>[
          // This month but before this week's Monday (12 Oct).
          _trip('early', DateTime(2026, 10, 2, 7)),
          _trip('early2', DateTime(2026, 10, 5, 7)),
          // Last month.
          _trip('old', DateTime(2026, 9, 10, 7)),
        ]),
      );

      // Default period is the month: two trips.
      expect(find.text('Perjalanan bulan ini, Oktober 2026'), findsOneWidget);
      expect(find.text('2'), findsWidgets);

      await tester.tap(find.text('Semua'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Perjalanan sejauh ini'), findsOneWidget);
      expect(find.text('3'), findsWidgets);

      await tester.tap(find.text('Minggu ini'));
      await tester.pumpAndSettle();
      expect(find.text('Belum ada perjalanan minggu ini'), findsOneWidget);
      // No fabricated numbers for an empty period.
      expect(find.text('Bagikan rekap'), findsNothing);
    });

    testWidgets('shows habits, the weekday chart and opens the share sheet', (
      tester,
    ) async {
      await _pump(
        tester,
        const TripRecapPage(),
        history: Stream.value(<CompletedTrip>[
          _trip('a', DateTime(2026, 10, 12, 7)),
          _trip('b', DateTime(2026, 10, 13, 7)),
          _trip('c', DateTime(2026, 10, 14, 7)),
          _trip('d', DateTime(2026, 10, 14, 18), origin: 'Manggarai', destination: 'Depok'),
        ]),
      );
      expect(find.text('Depok → Manggarai'), findsWidgets);
      expect(find.text('Rute tersering, 3x'), findsOneWidget);
      expect(find.text('Rabu paling sering: 2 dari 4 perjalanan (50%)'),
          findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('Bagikan rekap'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Bagikan rekap'));
      await tester.pumpAndSettle();
      expect(find.text('Bagikan rekap'), findsWidgets);
      expect(find.byType(RecapShareCard), findsOneWidget);
    });

    testWidgets('survives 1.3x text scale', (tester) async {
      await _pump(
        tester,
        const TripRecapPage(),
        textScale: 1.3,
        history: Stream.value(<CompletedTrip>[
          _trip(
            'a',
            DateTime(2026, 10, 12, 7),
            origin: 'Stasiun Pondok Ranji Rangkasbitung',
            destination: 'Jakarta Kota Beos Panjang Sekali',
          ),
        ]),
      );
      expect(tester.takeException(), isNull);
    });
  });
}
