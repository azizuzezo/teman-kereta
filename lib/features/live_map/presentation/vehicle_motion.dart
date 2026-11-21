import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/utils/geo.dart';
import '../../../domain/entities/transit_models.dart';
import 'track_motion.dart';

/// Satu kereta pengguna lain pada satu bingkai animasi.
///
/// Hanya berisi posisi, arah, dan tujuan kereta; tidak ada identitas
/// penumpang di data ini sama sekali.
class AnimatedVehicle {
  const AnimatedVehicle({
    required this.vehicle,
    required this.path,
    required this.arc,
    required this.dir,
    required this.point,
    required this.bearing,
    required this.directionKnown,
  });

  final VehiclePosition vehicle;

  /// Rel tempat kereta berjalan, jarak kepala dari awal rel, dan arah gerak
  /// (+1 ke jarak membesar, -1 sebaliknya).
  final TrackPath path;
  final double arc;
  final int dir;
  final LatLng point;

  /// Derajat dari utara, searah gerak kereta.
  final double bearing;

  /// False bila arah belum diketahui; kereta digambar sebagai titik bundar.
  final bool directionKnown;

  String get id => vehicle.id;
}

class _VehicleState {
  _VehicleState(this.vehicle, this.path, this.motion);

  VehiclePosition vehicle;
  TrackPath path;
  TrackMotion motion;
  int dir = 0; // 0 = belum diketahui
  double lastArc = 0;
  DateTime? lastRecordedAt;
  bool onRail = false;
  double displayBearing = 0;
}

/// Menggerakkan semua kereta pengguna lain: tiap kereta dipasang ke rel
/// terdekat dan meluncur di atasnya per frame, jadi laporan yang datang tiap
/// beberapa detik tidak terlihat sebagai loncatan.
class VehicleMotionHub {
  VehicleMotionHub({
    required this.riderPoint,
    required this.stationPoint,
  });

  /// Posisi kereta penumpang sendiri; kereta lain di dekatnya disembunyikan
  /// karena itu laporan dari kereta yang sama.
  final LatLng? Function() riderPoint;

  /// Koordinat stasiun menurut kode, untuk menebak arah dari "stasiun asal ke
  /// stasiun tujuan" bila kereta tidak membawa arah sendiri.
  final LatLng? Function(String code) stationPoint;

  final ValueNotifier<List<AnimatedVehicle>> frame =
      ValueNotifier<List<AnimatedVehicle>>(const <AnimatedVehicle>[]);

  /// Rel yang tersedia, sudah dalam bentuk [TrackPath].
  List<TrackPath> _rails = const <TrackPath>[];
  final Map<String, _VehicleState> _states = <String, _VehicleState>{};

  /// Jarak maksimum titik dari rel agar dianggap berada di rel itu.
  static const double _snapMeters = 80;

  /// Kereta yang laporan terakhirnya lebih tua dari ini dihapus.
  static const Duration _maxAge = Duration(minutes: 5);

  void setRails(List<List<LatLng>> tracks) {
    _rails = <TrackPath>[
      for (final t in tracks)
        if (t.length >= 2) TrackPath(t),
    ];
    for (final s in _states.values) {
      s.onRail = false; // dipasang ulang pada laporan berikutnya
    }
  }

  bool get hasVehicles => _states.isNotEmpty;

  AnimatedVehicle? find(String id) {
    for (final v in frame.value) {
      if (v.id == id) return v;
    }
    return null;
  }

  /// Dipanggil tiap daftar kereta dari server berubah.
  void update(List<VehiclePosition> vehicles, DateTime now) {
    final seen = <String>{};
    for (final v in vehicles) {
      if (now.difference(v.recordedAt) > _maxAge) continue;
      seen.add(v.id);
      final existing = _states[v.id];
      if (existing == null) {
        _create(v, now);
      } else {
        _refresh(existing, v, now);
      }
    }
    _states.removeWhere((id, _) => !seen.contains(id));
    tick(now);
  }

  void _create(VehiclePosition v, DateTime now) {
    final point = LatLng(v.latitude, v.longitude);
    final bearing = _bearingOf(v);
    final choice = _snap(point, bearing);
    final state = _VehicleState(v, choice.path, TrackMotion())
      ..onRail = choice.onRail
      ..dir = choice.dir
      ..lastArc = choice.arc;
    _states[v.id] = state;
    _observe(state, v, choice.arc, now);
  }

  void _refresh(_VehicleState state, VehiclePosition v, DateTime now) {
    state.vehicle = v;
    final last = state.lastRecordedAt;
    if (last != null && !v.recordedAt.isAfter(last)) return;
    final point = LatLng(v.latitude, v.longitude);
    final bearing = _bearingOf(v);

    var projection = state.path.project(
      point,
      near: state.lastArc,
      window: 2000,
    );
    if (!state.onRail || projection.offset > _snapMeters) {
      final choice = _snap(point, bearing);
      if (!identical(choice.path, state.path)) {
        state
          ..path = choice.path
          ..motion.reset()
          ..dir = choice.dir;
      }
      state.onRail = choice.onRail;
      projection = TrackProjection(choice.arc, 0);
      if (choice.dir != 0 && choice.dir != state.dir) {
        state
          ..dir = choice.dir
          ..motion.reset();
      }
    } else if (bearing != null) {
      final facing = _directionOn(state.path, projection.arc, bearing);
      if (facing != 0 && facing != state.dir) {
        state
          ..dir = facing
          ..motion.reset();
      }
    } else if (state.dir == 0) {
      final moved = projection.arc - state.lastArc;
      if (moved.abs() > 10) {
        state
          ..dir = moved > 0 ? 1 : -1
          ..motion.reset();
      }
    }
    _observe(state, v, projection.arc, now);
  }

  void _observe(
    _VehicleState state,
    VehiclePosition v,
    double arc,
    DateTime now,
  ) {
    state.lastArc = arc;
    state.lastRecordedAt = v.recordedAt;
    var at = v.recordedAt;
    if (at.isAfter(now)) at = now;
    final dir = state.dir == 0 ? 1 : state.dir;
    // Gerak selalu dihitung sebagai jarak yang membesar; untuk arah -1 jaraknya
    // dibalik tandanya.
    state.motion.observe(
      dir * arc,
      at,
      reportedSpeed: state.dir == 0 ? 0 : v.speedMetersPerSecond,
    );
  }

  double? _bearingOf(VehiclePosition v) {
    final given = v.bearing;
    if (given != null) return given;
    final from = v.previousStationId;
    final to = v.nextStationId;
    if (from == null || to == null) return null;
    final a = stationPoint(from);
    final b = stationPoint(to);
    if (a == null || b == null || a == b) return null;
    final dx = (b.longitude - a.longitude) * math.cos(a.latitude * math.pi / 180);
    final dy = b.latitude - a.latitude;
    return (math.atan2(dx, dy) * 180 / math.pi + 360) % 360;
  }

  /// +1 bila [bearing] searah rel di [arc], -1 bila berlawanan, 0 bila tegak
  /// lurus (tidak bisa dipastikan).
  int _directionOn(TrackPath path, double arc, double bearing) {
    final along = path.bearingAt(arc);
    final c = math.cos((bearing - along) * math.pi / 180);
    if (c > 0.35) return 1;
    if (c < -0.35) return -1;
    return 0;
  }

  _Snap _snap(LatLng point, double? bearing) {
    TrackPath? best;
    var bestOffset = double.infinity;
    var bestArc = 0.0;
    for (final rail in _rails) {
      final p = rail.project(point);
      if (p.offset < bestOffset) {
        bestOffset = p.offset;
        bestArc = p.arc;
        best = rail;
      }
    }
    if (best != null && bestOffset <= _snapMeters) {
      final dir = bearing == null ? 0 : _directionOn(best, bestArc, bearing);
      return _Snap(best, bestArc, dir, onRail: true);
    }
    // Di luar rel yang dikenal: jalur lurus dari titik ini searah hadap, hanya
    // bila arah diketahui. Tanpa arah, kereta diam di titik laporannya.
    final path = _straight(point, bearing);
    final projection = path.project(point);
    return _Snap(path, projection.arc, bearing == null ? 0 : 1, onRail: false);
  }

  TrackPath _straight(LatLng point, double? bearing) {
    final heading = bearing ?? 0;
    final ahead = destinationPoint(
      point.latitude,
      point.longitude,
      heading,
      30000,
    );
    final behind = destinationPoint(
      point.latitude,
      point.longitude,
      (heading + 180) % 360,
      2000,
    );
    // Titik laporan ada 2 km dari awal jalur, jadi kereta bisa maju 30 km.
    return TrackPath(<LatLng>[
      LatLng(behind.$1, behind.$2),
      point,
      LatLng(ahead.$1, ahead.$2),
    ]);
  }

  /// Satu frame. Mengembalikan true bila masih ada yang bergerak.
  bool tick(DateTime now) {
    final rider = riderPoint();
    final out = <AnimatedVehicle>[];
    var busy = false;
    for (final state in _states.values) {
      if (now.difference(state.vehicle.recordedAt) > _maxAge) continue;
      final dir = state.dir == 0 ? 1 : state.dir;
      final length = state.path.length;
      final u = state.motion.step(
        now,
        min: dir > 0 ? 0 : -length,
        max: dir > 0 ? length : 0,
      );
      if (!state.motion.isSettled) busy = true;
      final arc = (dir * u).clamp(0.0, length).toDouble();
      final head = state.path.pointAt(arc);
      if (rider != null &&
          const Distance().as(LengthUnit.Meter, rider, head.point) < 400) {
        continue; // laporan dari kereta penumpang sendiri
      }
      final along = state.path.bearingAt(arc);
      final raw = dir > 0 ? along : (along + 180) % 360;
      state.displayBearing = raw;
      out.add(
        AnimatedVehicle(
          vehicle: state.vehicle,
          path: state.path,
          arc: arc,
          dir: dir,
          point: head.point,
          bearing: state.displayBearing,
          directionKnown: state.dir != 0,
        ),
      );
    }
    frame.value = out;
    return busy;
  }

  void dispose() => frame.dispose();
}

class _Snap {
  const _Snap(this.path, this.arc, this.dir, {required this.onRail});

  final TrackPath path;
  final double arc;
  final int dir;
  final bool onRail;
}
