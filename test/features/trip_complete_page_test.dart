import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teman_kereta/app/theme/app_theme.dart';
import 'package:teman_kereta/data/providers/provider_registry.dart';
import 'package:teman_kereta/domain/entities/active_trip.dart';
import 'package:teman_kereta/domain/entities/transit_models.dart';
import 'package:teman_kereta/features/active_trip/presentation/active_trip_controller.dart';
import 'package:teman_kereta/features/active_trip/presentation/trip_complete_page.dart';
import 'package:teman_kereta/features/history/presentation/share/share_cards.dart';

class _FixedSession extends ActiveTripController {
  _FixedSession(this._session);

  final ActiveTripSession? _session;

  @override
  ActiveTripSession? build() => _session;
}

ActiveTripSession _session() {
  final start = DateTime(2026, 10, 15, 7);
  final trip = TransitTrip(
    id: 't',
    originStationId: 'A',
    destinationStationId: 'C',
    departureAt: start,
    arrivalAt: start.add(const Duration(minutes: 30)),
    freshness: DataFreshness.estimated,
    sourceLabel: 'test',
    updatedAt: start,
    legs: <TripLeg>[
      TripLeg(
        id: 'l1',
        mode: TransportMode.commuterRail,
        originName: 'Alpha',
        destinationName: 'Charlie',
        lineName: 'Lintas Uji',
        departureAt: start,
        arrivalAt: start.add(const Duration(minutes: 30)),
        stationIds: const <String>['A', 'B', 'C'],
      ),
    ],
  );
  return ActiveTripSession(
    id: 's',
    trip: trip,
    state: ActiveTripState.completed,
    currentStationIndex: 2,
    startedAt: start,
    updatedAt: start.add(const Duration(minutes: 32)),
    distanceMeters: 18400,
  );
}

Future<void> _pump(WidgetTester tester, ActiveTripSession? session) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        activeTripControllerProvider.overrideWith(() => _FixedSession(session)),
        stationListProvider.overrideWith((ref) async => const <Station>[]),
      ],
      child: MaterialApp(theme: AppTheme.light(), home: const TripCompletePage()),
    ),
  );
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets('summarises the finished trip from real session values', (
    tester,
  ) async {
    await _pump(tester, _session());
    expect(find.text('Kamu sudah tiba di C'), findsOneWidget);
    expect(find.text('32 menit'), findsOneWidget);
    expect(find.text('18.4 km'), findsOneWidget);
    expect(find.text('Selesai'), findsOneWidget);
    expect(find.text('Lihat riwayat'), findsOneWidget);
    expect(find.text('3 stasiun, Lintas Uji'), findsOneWidget);
  });

  testWidgets('Bagikan perjalanan opens the share preview', (tester) async {
    await _pump(tester, _session());
    await tester.tap(find.text('Bagikan perjalanan'));
    await tester.pumpAndSettle();
    expect(find.byType(TripShareCard), findsOneWidget);
    expect(find.text('Menyiapkan gambar'), findsNothing);
  });

  testWidgets('without a session it still closes cleanly and offers no share', (
    tester,
  ) async {
    await _pump(tester, null);
    expect(find.text('Perjalanan selesai'), findsOneWidget);
    expect(find.text('Bagikan perjalanan'), findsNothing);
    expect(find.text('Selesai'), findsOneWidget);
  });
}
