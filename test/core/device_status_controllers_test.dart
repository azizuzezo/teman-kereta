import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teman_kereta/core/network/device_status.dart';
import 'package:teman_kereta/core/network/gps_status_controller.dart';
import 'package:teman_kereta/core/network/internet_status_controller.dart';

ProviderContainer _internet({
  required bool connected,
  required List<Object> probeResults,
}) {
  var call = 0;
  final container = ProviderContainer(
    overrides: [
      connectionCheckProvider.overrideWithValue(() async => connected),
      latencyProbeProvider.overrideWithValue(() async {
        final next = probeResults[call < probeResults.length ? call : probeResults.length - 1];
        call++;
        if (next is int) {
          return next;
        }
        throw next;
      }),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  group('InternetStatusController', () {
    test('starts unknown, not green', () {
      final container = _internet(connected: true, probeResults: [100]);
      final status = container.read(internetStatusProvider);
      expect(status.level, isNull);
      expect(status.latencyMs, isNull);
    });

    test('offline never probes and reports offline', () async {
      var probed = false;
      final container = ProviderContainer(
        overrides: [
          connectionCheckProvider.overrideWithValue(() async => false),
          latencyProbeProvider.overrideWithValue(() async {
            probed = true;
            return 1;
          }),
        ],
      );
      addTearDown(container.dispose);

      await container.read(internetStatusProvider.notifier).refresh();

      expect(container.read(internetStatusProvider).level, LatencyLevel.offline);
      expect(probed, isFalse);
    });

    test('a fast first probe is accepted as is', () async {
      final container = _internet(connected: true, probeResults: [120]);
      await container.read(internetStatusProvider.notifier).refresh();
      final status = container.read(internetStatusProvider);
      expect(status.level, LatencyLevel.good);
      expect(status.latencyMs, 120);
      expect(status.checking, isFalse);
    });

    test('a slow first probe is re-measured once on the warm connection', () async {
      // First call pays for DNS + TLS, the second is the real round trip.
      final container = _internet(connected: true, probeResults: [650, 140]);
      await container.read(internetStatusProvider.notifier).refresh();
      final status = container.read(internetStatusProvider);
      expect(status.latencyMs, 140);
      expect(status.level, LatencyLevel.good);
    });

    test('later probes are measured once, no warm-up repeat', () async {
      final container = _internet(connected: true, probeResults: [100, 500, 900]);
      final notifier = container.read(internetStatusProvider.notifier);
      await notifier.refresh();
      await notifier.refresh();
      expect(container.read(internetStatusProvider).latencyMs, 500);
      expect(container.read(internetStatusProvider).level, LatencyLevel.slow);
    });

    test('a probe that throws is bad, with no latency', () async {
      final container = _internet(
        connected: true,
        probeResults: [Exception('timeout')],
      );
      await container.read(internetStatusProvider.notifier).refresh();
      final status = container.read(internetStatusProvider);
      expect(status.level, LatencyLevel.bad);
      expect(status.latencyMs, isNull);
    });

    test('overlapping refreshes run the probe once', () async {
      var probes = 0;
      final container = ProviderContainer(
        overrides: [
          connectionCheckProvider.overrideWithValue(() async => true),
          latencyProbeProvider.overrideWithValue(() async {
            probes++;
            await Future<void>.delayed(const Duration(milliseconds: 20));
            return 50;
          }),
        ],
      );
      addTearDown(container.dispose);
      final notifier = container.read(internetStatusProvider.notifier);
      await Future.wait([notifier.refresh(), notifier.refresh()]);
      expect(probes, 1);
    });
  });

  group('GpsStatusController', () {
    test('maps the platform snapshot through classifyGps', () async {
      final container = ProviderContainer(
        overrides: [
          gpsProbeProvider.overrideWithValue(
            () async => const GpsSnapshot(
              serviceEnabled: true,
              permission: GpsPermission.deniedForever,
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(gpsStatusProvider).level, isNull);
      await container.read(gpsStatusProvider.notifier).refresh();
      expect(
        container.read(gpsStatusProvider).level,
        GpsLevel.permissionBlocked,
      );
    });

    test('a failing probe reports services off instead of crashing', () async {
      final container = ProviderContainer(
        overrides: [
          gpsProbeProvider.overrideWithValue(() async => throw Exception('x')),
        ],
      );
      addTearDown(container.dispose);
      await container.read(gpsStatusProvider.notifier).refresh();
      expect(container.read(gpsStatusProvider).level, GpsLevel.servicesOff);
    });
  });
}
