import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

import 'trip_route_geometry.dart' show PathPoint;

/// Gerak kereta di atas rel, tanpa Flutter: jalur dengan jarak kumulatif dan
/// penggerak yang menghaluskan fix GPS yang datang jarang (3-20 detik) menjadi
/// gerak kontinu per frame.
///
/// Ide dasarnya sama dengan navigasi mobil: posisi tidak "meloncat ke fix
/// berikutnya", tetapi terus maju dengan kecepatan terakhir (dead reckoning)
/// dan tiap fix baru hanya mengoreksi pelan-pelan.

const double _ky = 110574.0;
const double _kx = 110700.0; // 111320 * cos(~6.2°), lintang Jawa.

double _bearingBetween(LatLng a, LatLng b) {
  final dx = (b.longitude - a.longitude) * _kx;
  final dy = (b.latitude - a.latitude) * _ky;
  return (math.atan2(dx, dy) * 180 / math.pi + 360) % 360;
}

/// Hasil memproyeksikan sebuah titik ke jalur: jarak [arc] dari awal jalur
/// (meter) dan [offset], jarak titik itu dari rel (meter).
class TrackProjection {
  const TrackProjection(this.arc, this.offset);

  final double arc;
  final double offset;
}

/// Polyline rel dengan jarak kumulatif, sehingga titik di jarak berapa pun
/// bisa dicari dengan pencarian biner.
class TrackPath {
  TrackPath(List<LatLng> source)
    : assert(source.length >= 2, 'A track needs at least two points'),
      points = List<LatLng>.unmodifiable(source),
      cumulative = _cumulate(source);

  final List<LatLng> points;
  final List<double> cumulative;

  static List<double> _cumulate(List<LatLng> pts) {
    final result = List<double>.filled(pts.length, 0);
    for (var i = 1; i < pts.length; i++) {
      final dx = (pts[i].longitude - pts[i - 1].longitude) * _kx;
      final dy = (pts[i].latitude - pts[i - 1].latitude) * _ky;
      result[i] = result[i - 1] + math.sqrt(dx * dx + dy * dy);
    }
    return result;
  }

  double get length => cumulative.last;

  /// Indeks segmen (titik akhirnya) yang memuat jarak [meters].
  int _segmentEnd(double meters) {
    var lo = 1;
    var hi = points.length - 1;
    while (lo < hi) {
      final mid = (lo + hi) >> 1;
      if (cumulative[mid] >= meters) {
        hi = mid;
      } else {
        lo = mid + 1;
      }
    }
    return lo;
  }

  /// Indeks titik pertama yang berada di luar jarak [meters] (untuk memotong
  /// jalur di posisi kereta). Sama dengan jumlah titik bila jarak melewati
  /// ujung jalur.
  int firstPointBeyond(double meters) {
    if (meters >= length) return points.length;
    return _segmentEnd(math.max(meters, 0));
  }

  /// Titik di jarak [meters] dari awal (dijepit ke ujung jalur) beserta arah
  /// jalur di sana, derajat searah jarum jam dari utara.
  PathPoint pointAt(double meters) {
    final m = meters.clamp(0.0, length).toDouble();
    final end = _segmentEnd(m);
    final a = points[end - 1];
    final b = points[end];
    final segment = cumulative[end] - cumulative[end - 1];
    final t = segment <= 0
        ? 0.0
        : ((m - cumulative[end - 1]) / segment).clamp(0.0, 1.0);
    return PathPoint(
      LatLng(
        a.latitude + (b.latitude - a.latitude) * t,
        a.longitude + (b.longitude - a.longitude) * t,
      ),
      _bearingBetween(a, b),
    );
  }

  /// Arah jalur di [meters], dirata-ratakan sepanjang [span] meter supaya tidak
  /// bergoyang di titik tikungan yang rapat.
  double bearingAt(double meters, {double span = 40}) {
    final from = pointAt(meters - span / 2).point;
    final to = pointAt(meters + span / 2).point;
    if (from == to) return pointAt(meters).bearing;
    return _bearingBetween(from, to);
  }

  /// Titik jalur terdekat dengan [p]. Dengan [near], hanya segmen yang berjarak
  /// kurang dari [window] meter dari [near] yang dicari; ini memilih cabang yang
  /// benar pada rute yang melewati lintasan yang sama dua kali (rute loop).
  /// Bila tidak ada segmen di jendela itu, seluruh jalur dicari.
  TrackProjection project(LatLng p, {double? near, double window = 1500}) {
    TrackProjection? best;
    var bestDistance = double.infinity;
    for (var i = 1; i < points.length; i++) {
      if (near != null &&
          (cumulative[i] < near - window || cumulative[i - 1] > near + window)) {
        continue;
      }
      final a = points[i - 1];
      final b = points[i];
      final ax = a.longitude * _kx;
      final ay = a.latitude * _ky;
      final dx = b.longitude * _kx - ax;
      final dy = b.latitude * _ky - ay;
      final px = p.longitude * _kx - ax;
      final py = p.latitude * _ky - ay;
      final lengthSquared = dx * dx + dy * dy;
      final t = lengthSquared == 0
          ? 0.0
          : ((px * dx + py * dy) / lengthSquared).clamp(0.0, 1.0);
      final cx = px - t * dx;
      final cy = py - t * dy;
      final d = cx * cx + cy * cy;
      if (d < bestDistance) {
        bestDistance = d;
        best = TrackProjection(
          cumulative[i - 1] + t * math.sqrt(lengthSquared),
          math.sqrt(d),
        );
      }
    }
    if (best == null) {
      return near == null ? const TrackProjection(0, double.infinity) : project(p);
    }
    return best;
  }
}

/// Posisi satu kereta sebagai jarak skalar yang terus bertambah.
///
/// [observe] dipanggil tiap ada fix (jarak target dan waktu fix itu), [step]
/// tiap frame. Di antara fix, kereta maju dengan kecepatan terakhir; saat fix
/// baru tiba, selisihnya dihabiskan dengan pendekatan eksponensial, jadi tidak
/// ada loncatan dan tidak ada berhenti-lalu-lari.
class TrackMotion {
  TrackMotion({
    this.catchUpPerSecond = 2.5,
    this.maxSpeed = 45,
    this.maxExtrapolation = const Duration(seconds: 12),
    this.jumpMeters = 500,
  });

  /// Seberapa cepat selisih terhadap target dihabiskan (per detik).
  final double catchUpPerSecond;

  /// Kecepatan tertinggi yang dipercaya (m/s). KRL paling cepat sekitar 25.
  final double maxSpeed;

  /// Berapa lama posisi boleh diprediksi setelah fix terakhir. Lewat itu kereta
  /// berhenti di prediksi terakhir daripada melaju ke tempat yang tak diketahui.
  final Duration maxExtrapolation;

  /// Selisih sebesar ini dianggap lompatan nyata (ganti rute), bukan noise:
  /// posisi langsung dipindah, tidak dianimasikan.
  final double jumpMeters;

  double position = 0;
  double speed = 0;

  double _target = 0;
  DateTime? _targetAt;
  DateTime? _lastStep;
  bool _started = false;
  bool _idle = true;
  bool _speedKnown = false;

  bool get started => _started;

  /// True bila frame berikutnya tidak akan menggeser apa pun, sehingga ticker
  /// boleh berhenti sampai ada fix baru.
  bool get isSettled => !_started || _idle;

  void reset() {
    position = 0;
    speed = 0;
    _target = 0;
    _targetAt = null;
    _lastStep = null;
    _started = false;
    _idle = true;
    _speedKnown = false;
  }

  double _clampSpeed(double v) => v.clamp(0.0, maxSpeed).toDouble();

  void observe(double target, DateTime at, {double? reportedSpeed}) {
    _idle = false;
    if (!_started) {
      _started = true;
      position = target;
      _target = target;
      _targetAt = at;
      speed = _clampSpeed(reportedSpeed ?? 0);
      _speedKnown = reportedSpeed != null;
      return;
    }
    final dt = at.difference(_targetAt!).inMilliseconds / 1000.0;
    if (dt <= 0) return; // fix lama atau kembar
    if ((target - position).abs() > jumpMeters) {
      position = target;
    }
    final measured = dt >= 0.5 ? _clampSpeed((target - _target) / dt) : null;
    final given = reportedSpeed != null && reportedSpeed >= 0
        ? _clampSpeed(reportedSpeed)
        : null;
    if (given != null && measured != null) {
      speed = 0.6 * given + 0.4 * measured;
      _speedKnown = true;
    } else if (given != null) {
      speed = given;
      _speedKnown = true;
    } else if (measured != null) {
      // Pengukuran pertama dipercaya penuh; sesudahnya dirata-ratakan.
      speed = _speedKnown ? 0.5 * speed + 0.5 * measured : measured;
      _speedKnown = true;
    }
    _target = target;
    _targetAt = at;
  }

  /// Memajukan posisi sampai [now] dan mengembalikannya, dijepit ke
  /// [min]..[max].
  double step(
    DateTime now, {
    double min = double.negativeInfinity,
    double max = double.infinity,
  }) {
    final last = _lastStep;
    _lastStep = now;
    final targetAt = _targetAt;
    if (!_started || targetAt == null) return position;
    final dt = last == null
        ? 0.0
        : (now.difference(last).inMilliseconds / 1000.0).clamp(0.0, 0.25);
    if (dt == 0) return position;

    final window = maxExtrapolation.inMilliseconds / 1000.0;
    final rawAge = now.difference(targetAt).inMilliseconds / 1000.0;
    final age = rawAge.clamp(0.0, window).toDouble();
    // Lewat jendela prediksi, kereta berhenti di prediksi terakhir.
    final v = rawAge < window ? speed : 0.0;
    final predicted = _target + speed * age;
    final ahead = position + v * dt;
    final k = 1 - math.exp(-catchUpPerSecond * dt);
    var next = ahead + (predicted - ahead) * k;
    // Kereta tidak mundur: koreksi kecil ke belakang diabaikan sampai target
    // menyusul. Selisih besar tetap diikuti.
    if (next < position && position - next < 60) next = position;
    next = next.clamp(min, max).toDouble();
    _idle = (next - position).abs() < 0.02;
    position = next;
    return position;
  }
}

/// Interpolasi sudut terpendek antara dua arah kompas, [t] 0..1.
double lerpBearing(double a, double b, double t) {
  var delta = (b - a) % 360;
  if (delta > 180) delta -= 360;
  if (delta < -180) delta += 360;
  return (a + delta * t + 360) % 360;
}
