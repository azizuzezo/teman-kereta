import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teman_kereta/core/preferences/preferences_store.dart';
import 'package:teman_kereta/domain/entities/active_trip.dart';
import 'package:teman_kereta/domain/entities/ride_detection.dart';
import 'package:teman_kereta/features/ride_detection/presentation/ride_detection_confirm_page.dart';
import 'package:teman_kereta/features/ride_detection/presentation/ride_detection_controller.dart';

class _FixedPhaseController extends RideDetectionController {
  _FixedPhaseController(this._phase);

  final RideDetectionPhase? _phase;

  @override
  RideDetectionPhase? build() => _phase;
}

Future<void> _pump(WidgetTester tester, RideDetectionPhase? phase) {
  return tester.pumpWidget(
    ProviderScope(
      overrides: [
        preferencesStoreProvider.overrideWithValue(MemoryPreferencesStore()),
        rideDetectionControllerProvider.overrideWith(
          () => _FixedPhaseController(phase),
        ),
      ],
      child: const MaterialApp(home: RideDetectionConfirmPage()),
    ),
  );
}

void main() {
  testWidgets('shows an empty state when no detection is pending', (tester) async {
    await _pump(tester, null);
    await tester.pumpAndSettle();

    expect(find.text('Tidak ada deteksi yang menunggu'), findsOneWidget);
    expect(find.text('Ya, mulai'), findsNothing);
  });

  testWidgets('shows the soft-ask prompt with reasons when below the strong threshold', (
    tester,
  ) async {
    await _pump(
      tester,
      RideDetectionPhase(
        state: ActiveTripState.confirmingTrip,
        stationId: 'BOO',
        assessment: RideDetectionAssessment(
          score: 60,
          level: RideDetectionLevel.soft,
          stationId: 'BOO',
          exitedAt: DateTime(2026, 1, 1, 6),
          reasons: const <String>['Terdeteksi bergerak di dalam kendaraan'],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Apakah kamu sedang naik kereta?'), findsOneWidget);
    expect(find.text('Terdeteksi bergerak di dalam kendaraan'), findsOneWidget);
    // No suggested destination at the soft tier, so there is no "Ya, mulai".
    expect(find.text('Ya, mulai'), findsNothing);
    expect(find.text('Pilih kereta lain'), findsOneWidget);
    expect(find.text('Bukan'), findsOneWidget);
    expect(find.text('Jangan tanya lagi hari ini'), findsOneWidget);
  });

  testWidgets('shows the specific-trip prompt with a start button at the strong threshold', (
    tester,
  ) async {
    await _pump(
      tester,
      RideDetectionPhase(
        state: ActiveTripState.confirmingTrip,
        stationId: 'BOO',
        assessment: RideDetectionAssessment(
          score: 90,
          level: RideDetectionLevel.strong,
          stationId: 'BOO',
          exitedAt: DateTime(2026, 1, 1, 6),
          reasons: const <String>['Cocok dengan rute rumah -> kantor tersimpan'],
          suggestedDestinationId: 'JAKK',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Mulai panduan perjalanan?'), findsOneWidget);
    expect(find.text('Ya, mulai'), findsOneWidget);
  });
}
