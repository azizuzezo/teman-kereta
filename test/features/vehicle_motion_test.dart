import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:teman_kereta/domain/entities/transit_models.dart';
import 'package:teman_kereta/features/live_map/presentation/vehicle_motion.dart';

VehiclePosition _v(
  String id,
  double lat,
  double lon,
  DateTime at, {
  double? bearing,
  double? speed,
  String? headsign,
}) => VehiclePosition(
  id: id,
  tripId: 't',
  latitude: lat,
  longitude: lon,
  recordedAt: at,
  freshness: DataFreshness.nearRealtime,
  sourceLabel: 'Uji',
  bearing: bearing,
  speedMetersPerSecond: speed,
  headsign: headsign,
);

void main() {
  test('vehicle glides on the rail between 5 s reports, in the right direction', () {
    // Rel lurus ke timur 5 km.
    final rail = <LatLng>[for (var i = 0; i <= 50; i++) LatLng(-6.2, 106.80 + i * 0.001)];
    final hub = VehicleMotionHub(riderPoint: () => null, stationPoint: (_) => null);
    hub.setRails([rail]);
    final t0 = DateTime(2026, 11, 21, 10);
    // Kereta ke timur 20 m/s, laporan tiap 5 s (100 m).
    double lonAt(double s) => 106.80 + (500 + 20 * s) / 110700.0;
    var now = t0;
    hub.update([_v('a', -6.2, lonAt(0), t0, bearing: 90, speed: 20, headsign: 'Bogor')], now);
    expect(hub.frame.value.single.directionKnown, isTrue);
    expect(hub.frame.value.single.dir, 1);
    final xs = <double>[];
    var maxStep = 0.0;
    for (var s = 0; s < 20; s++) {
      for (var f = 0; f < 60; f++) {
        now = t0.add(Duration(milliseconds: (s * 1000 + f * 1000 / 60).round()));
        hub.tick(now);
        xs.add(hub.frame.value.single.point.longitude * 110700);
      }
      if ((s + 1) % 5 == 0 && s < 19) {
        // Laporan tiba 0.6 s setelah fix-nya terukur.
        final rec = now.subtract(const Duration(milliseconds: 600));
        final secs = rec.difference(t0).inMilliseconds / 1000.0;
        hub.update([_v('a', -6.2, lonAt(secs), rec, bearing: 90, speed: 20, headsign: 'Bogor')], now);
      }
    }
    for (var i = 1; i < xs.length; i++) {
      final d = xs[i] - xs[i - 1];
      expect(d, greaterThanOrEqualTo(-0.001), reason: 'never backwards at $i');
      if (d > maxStep) maxStep = d;
    }
    // 20 m/s at 60 fps = 0.33 m per frame; no frame may jump more than ~1 m.
    expect(maxStep, lessThan(1.0));
    final travelled = xs.last - xs.first;
    expect(travelled, greaterThan(300));
  });

  test('unknown direction stands still and is flagged', () {
    final hub = VehicleMotionHub(riderPoint: () => null, stationPoint: (_) => null);
    hub.setRails(const []);
    final t0 = DateTime(2026, 11, 21, 10);
    hub.update([_v('b', -6.2, 106.8, t0)], t0);
    expect(hub.frame.value.single.directionKnown, isFalse);
    expect(hub.frame.value.single.point.longitude, closeTo(106.8, 1e-6));
  });

  test('hides the train that is the rider own', () {
    final hub = VehicleMotionHub(riderPoint: () => const LatLng(-6.2, 106.8), stationPoint: (_) => null);
    final t0 = DateTime(2026, 11, 21, 10);
    hub.update([_v('c', -6.2, 106.8005, t0, bearing: 90)], t0);
    expect(hub.frame.value, isEmpty);
  });
}
