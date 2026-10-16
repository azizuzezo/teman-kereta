import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:teman_kereta/core/updates/update_checker.dart';
import 'package:teman_kereta/features/support/presentation/app_update_page.dart';

Map<String, dynamic> _row({
  int code = 20,
  String name = '1.0.19',
  int? min,
  String? changelog = 'Perbaikan suara.',
}) => <String, dynamic>{
  'version_code': code,
  'version_name': name,
  'apk_url': 'https://example.com/tk.apk',
  'changelog': changelog,
  'min_supported_version_code': min,
};

PackageInfo _info(String build) => PackageInfo(
  appName: 'Teman Kereta',
  packageName: 'id.temankereta.teman_kereta',
  version: '1.0.17',
  buildNumber: build,
);

ProviderContainer _container({
  required Future<Map<String, dynamic>?> Function() fetch,
  String build = '18',
}) {
  return ProviderContainer(
    overrides: [
      latestReleaseFetcherProvider.overrideWithValue(fetch),
      packageInfoProvider.overrideWith((ref) async => _info(build)),
    ],
  );
}

void main() {
  group('evaluateRelease', () {
    test('null row or same/older build means no update', () {
      expect(evaluateRelease(null, 18), isNull);
      expect(evaluateRelease(_row(code: 18), 18), isNull);
      expect(evaluateRelease(_row(code: 17), 18), isNull);
    });

    test('newer build returns the update with changelog', () {
      final update = evaluateRelease(_row(), 18)!;
      expect(update.versionName, '1.0.19');
      expect(update.changelog, 'Perbaikan suara.');
      expect(update.forceUpdate, isFalse);
    });

    test('forceUpdate only when the running build is below the minimum', () {
      expect(evaluateRelease(_row(min: 19), 18)!.forceUpdate, isTrue);
      expect(evaluateRelease(_row(min: 18), 18)!.forceUpdate, isFalse);
    });
  });

  group('ManualUpdateCheckController', () {
    test('up to date', () async {
      final container = _container(fetch: () async => _row(code: 18));
      addTearDown(container.dispose);
      container.listen(manualUpdateCheckProvider, (_, _) {});

      expect(container.read(manualUpdateCheckProvider).phase, UpdateCheckPhase.idle);
      await container.read(manualUpdateCheckProvider.notifier).check();

      final state = container.read(manualUpdateCheckProvider);
      expect(state.phase, UpdateCheckPhase.upToDate);
      expect(state.checkedAt, isNotNull);
    });

    test('update available carries the release notes', () async {
      final container = _container(fetch: () async => _row());
      addTearDown(container.dispose);
      container.listen(manualUpdateCheckProvider, (_, _) {});

      await container.read(manualUpdateCheckProvider.notifier).check();

      final state = container.read(manualUpdateCheckProvider);
      expect(state.phase, UpdateCheckPhase.available);
      expect(state.update!.changelog, 'Perbaikan suara.');
    });

    test('shows checking while the request is in flight', () async {
      final gate = Completer<Map<String, dynamic>?>();
      final container = _container(fetch: () => gate.future);
      addTearDown(container.dispose);
      container.listen(manualUpdateCheckProvider, (_, _) {});

      final future = container.read(manualUpdateCheckProvider.notifier).check();
      await Future<void>.delayed(Duration.zero);
      expect(container.read(manualUpdateCheckProvider).phase, UpdateCheckPhase.checking);

      gate.complete(_row(code: 18));
      await future;
      expect(container.read(manualUpdateCheckProvider).phase, UpdateCheckPhase.upToDate);
    });

    test('server failure becomes an error state with a message, then can retry', () async {
      var fail = true;
      final container = _container(
        fetch: () async {
          if (fail) {
            throw Exception('offline');
          }
          return _row(code: 18);
        },
      );
      addTearDown(container.dispose);
      container.listen(manualUpdateCheckProvider, (_, _) {});

      await container.read(manualUpdateCheckProvider.notifier).check();
      var state = container.read(manualUpdateCheckProvider);
      expect(state.phase, UpdateCheckPhase.error);
      expect(state.errorMessage, isNotEmpty);

      fail = false;
      await container.read(manualUpdateCheckProvider.notifier).check();
      state = container.read(manualUpdateCheckProvider);
      expect(state.phase, UpdateCheckPhase.upToDate);
    });
  });

  group('effectiveUpdateState', () {
    test('startup-found update shows as available until a manual check runs', () {
      final startup = evaluateRelease(_row(), 18);
      expect(
        effectiveUpdateState(const UpdateCheckState(), startup).phase,
        UpdateCheckPhase.available,
      );
      expect(
        effectiveUpdateState(
          const UpdateCheckState(phase: UpdateCheckPhase.upToDate),
          startup,
        ).phase,
        UpdateCheckPhase.upToDate,
      );
      expect(
        effectiveUpdateState(const UpdateCheckState(), null).phase,
        UpdateCheckPhase.idle,
      );
    });
  });
}
