import 'package:flutter_test/flutter_test.dart';
import 'package:teman_kereta/core/network/device_status.dart';

void main() {
  group('classifyLatency', () {
    test('under 300 ms is good', () {
      expect(
        classifyLatency(hasConnection: true, latencyMs: 0),
        LatencyLevel.good,
      );
      expect(
        classifyLatency(hasConnection: true, latencyMs: 299),
        LatencyLevel.good,
      );
    });

    test('300 to 800 ms is slow, both ends included', () {
      expect(
        classifyLatency(hasConnection: true, latencyMs: 300),
        LatencyLevel.slow,
      );
      expect(
        classifyLatency(hasConnection: true, latencyMs: 800),
        LatencyLevel.slow,
      );
    });

    test('over 800 ms is bad', () {
      expect(
        classifyLatency(hasConnection: true, latencyMs: 801),
        LatencyLevel.bad,
      );
      expect(
        classifyLatency(hasConnection: true, latencyMs: 12000),
        LatencyLevel.bad,
      );
    });

    test('a connection that never answered (timeout) is bad, not offline', () {
      expect(
        classifyLatency(hasConnection: true, latencyMs: null),
        LatencyLevel.bad,
      );
    });

    test('no connection is offline whatever the latency says', () {
      expect(
        classifyLatency(hasConnection: false, latencyMs: 50),
        LatencyLevel.offline,
      );
      expect(
        classifyLatency(hasConnection: false, latencyMs: null),
        LatencyLevel.offline,
      );
    });

    test('a negative measurement is rejected as a failed probe', () {
      expect(
        classifyLatency(hasConnection: true, latencyMs: -1),
        LatencyLevel.bad,
      );
    });
  });

  group('latency copy', () {
    test('every level has a short label and a different icon cue', () {
      final labels = LatencyLevel.values.map(latencyLabel).toSet();
      expect(labels.length, LatencyLevel.values.length);
      for (final label in labels) {
        expect(label.contains('—'), isFalse);
      }
    });

    test('formatLatency shows ms or a dash-free placeholder', () {
      expect(formatLatency(123), '123 ms');
      expect(formatLatency(null), 'Tidak merespons');
    });
  });

  group('classifyGps', () {
    test('services on and permission granted is ready', () {
      expect(
        classifyGps(serviceEnabled: true, permission: GpsPermission.granted),
        GpsLevel.ready,
      );
    });

    test('services off wins over everything else', () {
      expect(
        classifyGps(serviceEnabled: false, permission: GpsPermission.granted),
        GpsLevel.servicesOff,
      );
      expect(
        classifyGps(serviceEnabled: false, permission: GpsPermission.denied),
        GpsLevel.servicesOff,
      );
    });

    test('denied can still be asked again', () {
      expect(
        classifyGps(serviceEnabled: true, permission: GpsPermission.denied),
        GpsLevel.permissionDenied,
      );
    });

    test('denied forever must go to app settings', () {
      expect(
        classifyGps(
          serviceEnabled: true,
          permission: GpsPermission.deniedForever,
        ),
        GpsLevel.permissionBlocked,
      );
    });

    test('only denied states are actionable beyond services', () {
      expect(gpsNeedsAction(GpsLevel.ready), isFalse);
      expect(gpsNeedsAction(GpsLevel.servicesOff), isTrue);
      expect(gpsNeedsAction(GpsLevel.permissionDenied), isTrue);
      expect(gpsNeedsAction(GpsLevel.permissionBlocked), isTrue);
    });
  });
}
