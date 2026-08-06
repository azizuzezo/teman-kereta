// A genuine on-device end-to-end flow, not a widget test with mocked
// navigation — pumps the real `TemanKeretaApp` (real router, real page
// widgets) with only the storage layer swapped for in-memory fakes
// (`MemoryPreferencesStore`, an in-memory Drift `AppDatabase`), matching
// this project's default `TRANSIT_PROVIDER=mock` (no dart-define passed)
// so the whole flow is deterministic without needing any real backend.
//
// Run with: flutter test integration_test/app_test.dart -d <device-id>
// (a real device or a running emulator — this cannot run via plain
// `flutter test`, which is exactly why it lives here and not in test/).
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:teman_kereta/app/app.dart';
import 'package:teman_kereta/core/database/app_database.dart';
import 'package:teman_kereta/core/database/database_provider.dart';
import 'package:teman_kereta/core/preferences/preferences_store.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'search a trip, start it, ride it to arrival, then complete and return home',
    (WidgetTester tester) async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            preferencesStoreProvider.overrideWithValue(
              MemoryPreferencesStore(
                initial: const StoredPreferences(onboardingComplete: true),
              ),
            ),
            appDatabaseProvider.overrideWithValue(database),
          ],
          child: const TemanKeretaApp(),
        ),
      );
      await tester.pumpAndSettle();

      // Onboarding already marked complete -> lands straight on Home.
      expect(find.text('Cari perjalanan'), findsNothing);

      // Home -> Jadwal tab.
      await tester.tap(find.text('Jadwal'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(AppBar, 'Cari perjalanan'), findsOneWidget);

      // Default search (Bogor -> Sudirman, per TripSearchController.build())
      // is enough — just run it.
      await tester.tap(find.widgetWithText(FilledButton, 'Cari perjalanan'));
      await tester.pumpAndSettle();
      expect(find.text('Pilihan tercepat'), findsOneWidget);

      // Open the fastest result's detail page.
      await tester.tap(find.text('Pilihan tercepat'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(AppBar, 'Detail perjalanan'), findsOneWidget);

      // Start the trip.
      await tester.tap(find.text('Mulai perjalanan'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(AppBar, 'Perjalanan aktif'), findsOneWidget);

      // Manually advance through every stop (mock/demo data exposes this
      // button specifically so a real device/CI run can walk the whole
      // state machine without waiting on real geofence events) until
      // arrival — bounded so a real regression (the button never
      // disappearing) fails the test instead of looping forever.
      const advanceButton = 'Simulasikan stasiun berikutnya';
      const completeButton = 'Selesaikan perjalanan';
      var remainingTaps = 30;
      while (find.text(advanceButton).evaluate().isNotEmpty &&
          remainingTaps > 0) {
        await tester.tap(find.text(advanceButton));
        await tester.pumpAndSettle();
        remainingTaps -= 1;
      }
      expect(
        remainingTaps,
        greaterThan(0),
        reason: 'Trip never reached arrival within 30 manual advances.',
      );
      expect(find.text(completeButton), findsOneWidget);

      // Complete the trip.
      await tester.tap(find.text(completeButton));
      await tester.pumpAndSettle();
      expect(find.text('Perjalanan selesai'), findsOneWidget);

      // Back to Home.
      await tester.tap(find.text('Kembali ke beranda'));
      await tester.pumpAndSettle();
      expect(find.text('Perjalanan selesai'), findsNothing);
    },
  );
}
