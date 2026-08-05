import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teman_kereta/app/app.dart';
import 'package:teman_kereta/core/preferences/preferences_store.dart';

void main() {
  testWidgets(
    'app boots to onboarding when no preferences are stored yet',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            preferencesStoreProvider.overrideWithValue(
              MemoryPreferencesStore(),
            ),
          ],
          child: const TemanKeretaApp(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Mulai'), findsOneWidget);
    },
  );
}
