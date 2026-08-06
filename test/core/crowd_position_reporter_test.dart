import 'package:flutter_test/flutter_test.dart';
import 'package:teman_kereta/core/location/crowd_position_reporter.dart';
import 'package:teman_kereta/core/preferences/preferences_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'reportOnce is a safe no-op when SUPABASE_ENABLED is off '
    '(the default in every test run — no --dart-define is passed here)',
    () async {
      final reporter = CrowdPositionReporter(MemoryPreferencesStore());

      // Must not throw, must not touch Supabase.instance (which isn't even
      // initialized in this test binding) — the AppEnvironment.
      // supabaseEnabled guard has to short-circuit before any of that.
      await reporter.reportOnce(
        externalTripId: 'SOME_TRIP_1',
        serviceDate: DateTime.utc(2026, 1, 1),
      );
    },
  );

  test(
    'reportOnce never touches deviceSessionId when Supabase is disabled '
    '(confirms the guard runs before any state is generated, not just '
    'before the network call)',
    () async {
      final store = MemoryPreferencesStore();
      final reporter = CrowdPositionReporter(store);

      await reporter.reportOnce(
        externalTripId: 'T1',
        serviceDate: DateTime.utc(2026, 1, 1),
      );

      expect(store.snapshot.deviceSessionId, isNull);
    },
  );
}
