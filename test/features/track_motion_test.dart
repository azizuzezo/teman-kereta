import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:teman_kereta/features/live_map/presentation/track_motion.dart';

/// Lurus ke timur sepanjang ~1.1 km, lalu berbelok ke utara.
TrackPath _elbow() => TrackPath(const <LatLng>[
  LatLng(-6.2, 106.80),
  LatLng(-6.2, 106.81),
  LatLng(-6.19, 106.81),
]);

void main() {
  group('TrackPath', () {
    test('length adds up the segments', () {
      final path = _elbow();
      expect(path.length, closeTo(1107 + 1105.74, 5));
    });

    test('pointAt walks along the track and reports the heading', () {
      final path = _elbow();
      final start = path.pointAt(0);
      expect(start.point.longitude, closeTo(106.80, 1e-9));
      expect(start.bearing, closeTo(90, 0.5)); // timur

      final afterTurn = path.pointAt(1107 + 500);
      expect(afterTurn.point.longitude, closeTo(106.81, 1e-6));
      expect(afterTurn.bearing, closeTo(0, 0.5)); // utara
    });

    test('pointAt clamps outside the track', () {
      final path = _elbow();
      expect(path.pointAt(-50).point.longitude, closeTo(106.80, 1e-9));
      expect(path.pointAt(1e9).point.latitude, closeTo(-6.19, 1e-9));
    });

    test('project finds the arc and how far off the rail the point is', () {
      final path = _elbow();
      final onRail = path.project(const LatLng(-6.2, 106.805));
      expect(onRail.arc, closeTo(553.5, 5));
      expect(onRail.offset, lessThan(1));

      final off = path.project(const LatLng(-6.199, 106.805));
      expect(off.arc, closeTo(553.5, 5));
      expect(off.offset, closeTo(110, 5));
    });

    test('project with a hint picks the right pass of a looped route', () {
      // Pergi ke timur lalu kembali ke barat di rel yang sama.
      final loop = TrackPath(const <LatLng>[
        LatLng(-6.2, 106.80),
        LatLng(-6.2, 106.82),
        LatLng(-6.2, 106.80),
      ]);
      const p = LatLng(-6.2, 106.81);
      final outbound = loop.project(p, near: 100, window: 600);
      final inbound = loop.project(p, near: loop.length - 100, window: 600);
      expect(outbound.arc, lessThan(loop.length / 2));
      expect(inbound.arc, greaterThan(loop.length / 2));
    });
  });

  group('TrackMotion', () {
    final t0 = DateTime(2026, 11, 21, 10);

    test('keeps moving between fixes instead of waiting for the next one', () {
      final m = TrackMotion();
      m.observe(0, t0);
      m.observe(100, t0.add(const Duration(seconds: 5))); // 20 m/s
      var now = t0.add(const Duration(seconds: 5));
      m.step(now);
      final positions = <double>[];
      for (var i = 0; i < 60; i++) {
        now = now.add(const Duration(milliseconds: 50));
        positions.add(m.step(now));
      }
      // Tiap frame maju, tanpa berhenti.
      for (var i = 1; i < positions.length; i++) {
        expect(positions[i], greaterThan(positions[i - 1]));
      }
      // Setelah 3 detik tanpa fix baru, sudah jauh melewati fix terakhir.
      expect(positions.last, greaterThan(150));
    });

    test('a late fix pulls the train back gently, never backwards', () {
      final m = TrackMotion();
      m.observe(0, t0);
      m.observe(100, t0.add(const Duration(seconds: 5)));
      var now = t0.add(const Duration(seconds: 5));
      m.step(now);
      for (var i = 0; i < 100; i++) {
        now = now.add(const Duration(milliseconds: 50));
        m.step(now);
      }
      final before = m.position;
      // Fix berikutnya ternyata lebih pendek dari prediksi.
      m.observe(150, t0.add(const Duration(seconds: 10)), reportedSpeed: 10);
      double previous = before;
      for (var i = 0; i < 100; i++) {
        now = now.add(const Duration(milliseconds: 50));
        final p = m.step(now);
        expect(p, greaterThanOrEqualTo(previous));
        previous = p;
      }
    });

    test('settles when the train stands still so the ticker can stop', () {
      final m = TrackMotion();
      m.observe(50, t0, reportedSpeed: 0);
      var now = t0;
      for (var i = 0; i < 10; i++) {
        now = now.add(const Duration(milliseconds: 50));
        m.step(now);
      }
      expect(m.isSettled, isTrue);
      expect(m.position, closeTo(50, 0.01));
      m.observe(80, t0.add(const Duration(seconds: 5)));
      expect(m.isSettled, isFalse);
    });

    test('a big jump (route switch) moves at once instead of racing', () {
      final m = TrackMotion();
      m.observe(0, t0);
      m.observe(5000, t0.add(const Duration(seconds: 5)));
      expect(m.position, 5000);
    });

    test('stops extrapolating after the window so it cannot run away', () {
      final m = TrackMotion();
      m.observe(0, t0);
      m.observe(100, t0.add(const Duration(seconds: 5)), reportedSpeed: 20);
      var now = t0.add(const Duration(seconds: 5));
      m.step(now);
      for (var i = 0; i < 1200; i++) {
        now = now.add(const Duration(milliseconds: 50));
        m.step(now);
      }
      // 100 m + 20 m/s * 12 s = 340 m paling jauh.
      expect(m.position, lessThan(345));
      expect(m.isSettled, isTrue);
    });
  });

  test('lerpBearing takes the short way round north', () {
    expect(lerpBearing(350, 10, 0.5), closeTo(0, 0.001));
    expect(lerpBearing(10, 350, 0.5), closeTo(0, 0.001));
  });
}
