import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import 'active_trip_route.dart';
import 'live_trip_position_controller.dart';
import 'track_motion.dart';
import 'trip_route_geometry.dart';

/// Rute trip aktif sebagai satu jalur panjang, plus awal tiap hop, supaya
/// posisi "hop ke-i, sekian persen" bisa dijadikan satu jarak tunggal.
class RouteTrack {
  RouteTrack({
    required this.tripId,
    required this.path,
    required this.hopStarts,
    required this.hopLengths,
  });

  final String tripId;
  final TrackPath path;
  final List<double> hopStarts;
  final List<double> hopLengths;

  /// Jarak dari awal rute untuk posisi di hop [hopIndex], [fraction] 0..1.
  double arcOf(int hopIndex, double fraction) {
    if (hopStarts.isEmpty) return 0;
    final i = hopIndex.clamp(0, hopStarts.length - 1);
    final f = fraction.clamp(0.0, 1.0);
    return math.min(hopStarts[i] + hopLengths[i] * f, path.length);
  }
}

final activeTripTrackProvider = Provider<RouteTrack?>((ref) {
  final route = ref.watch(activeTripRouteProvider);
  if (route == null || route.hops.isEmpty) return null;
  final points = route.points;
  if (points.length < 2) return null;
  final starts = <double>[];
  final lengths = <double>[];
  var walked = 0.0;
  for (final hop in route.hops) {
    final length = pathLength(hop);
    starts.add(walked);
    lengths.add(length);
    walked += length;
  }
  return RouteTrack(
    tripId: route.tripId,
    path: TrackPath(points),
    hopStarts: starts,
    hopLengths: lengths,
  );
});

/// Satu bingkai posisi kereta penumpang: di mana kepalanya, ke arah mana, dan
/// jalur yang dilaluinya (untuk menggambar gerbong yang mengikuti tikungan dan
/// memotong rute menjadi sudah dilalui/belum).
class RiderPose {
  const RiderPose({
    required this.path,
    required this.arc,
    required this.point,
    required this.bearing,
    required this.time,
  });

  final TrackPath path;

  /// Jarak kepala kereta dari awal rute (meter).
  final double arc;
  final LatLng point;

  /// Arah kepala kereta, derajat dari utara, sudah dihaluskan.
  final double bearing;
  final DateTime time;
}

/// Menggerakkan kereta penumpang tiap frame. Tidak tahu apa-apa soal widget:
/// pemilik (halaman peta) memanggil [observe] saat marker baru datang dan
/// [tick] tiap frame dari sebuah Ticker.
class RiderTrainMotion {
  final ValueNotifier<RiderPose?> pose = ValueNotifier<RiderPose?>(null);

  final TrackMotion _motion = TrackMotion();
  RouteTrack? _track;
  double _bearing = 0;
  bool _hasBearing = false;
  DateTime? _lastTick;

  /// Perlu frame terus selama kereta tampil (denyut halo ikut beranimasi).
  bool get wantsFrames => pose.value != null;

  void setTrack(RouteTrack? track) {
    if (track == null || track.tripId != _track?.tripId) {
      _motion.reset();
      _hasBearing = false;
      pose.value = null;
    }
    _track = track;
  }

  void observe(TripMapMarker? marker, {DateTime? now}) {
    final track = _track;
    if (marker == null) {
      _motion.reset();
      _hasBearing = false;
      pose.value = null;
      return;
    }
    if (track == null) return;
    final clock = now ?? DateTime.now();
    final hint = track.arcOf(marker.hopIndex, marker.hopFraction);
    var arc = hint;
    final fix = marker.fixPoint;
    if (fix != null) {
      // Proyeksikan fix ke seluruh rute di sekitar hop yang dipercaya. Jendela
      // itu memilih sisi yang benar pada rute loop, dan tidak menahan kereta
      // di ujung hop kalau indeks stasiun terlambat naik.
      final projection = track.path.project(fix, near: hint, window: 1800);
      if (projection.offset < 150) arc = projection.arc;
    }
    var at = marker.at ?? clock;
    if (at.isAfter(clock)) at = clock;
    _motion.observe(arc, at, reportedSpeed: marker.speedMetersPerSecond);
    _emit(clock);
  }

  /// Satu frame. Mengembalikan true selama masih perlu frame berikutnya.
  bool tick(DateTime now) {
    final track = _track;
    if (track == null || !_motion.started) return false;
    _motion.step(now, min: 0, max: track.path.length);
    _emit(now);
    return true;
  }

  void _emit(DateTime now) {
    final track = _track;
    if (track == null || !_motion.started) return;
    final arc = _motion.position.clamp(0.0, track.path.length).toDouble();
    final raw = track.path.bearingAt(arc);
    if (!_hasBearing) {
      _bearing = raw;
      _hasBearing = true;
    } else {
      final last = _lastTick;
      final dt = last == null
          ? 0.016
          : (now.difference(last).inMilliseconds / 1000.0).clamp(0.0, 0.25);
      _bearing = lerpBearing(_bearing, raw, 1 - math.exp(-6 * dt));
    }
    _lastTick = now;
    pose.value = RiderPose(
      path: track.path,
      arc: arc,
      point: track.path.pointAt(arc).point,
      bearing: _bearing,
      time: now,
    );
  }

  void dispose() => pose.dispose();
}
