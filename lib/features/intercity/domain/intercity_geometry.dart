import 'dart:math' as math;

import '../../../core/utils/geo.dart';
import 'intercity_models.dart';

/// Where a GPS fix sits on a train's track.
class TrackPosition {
  const TrackPosition({required this.alongKm, required this.offsetMeters});

  /// Distance from the service's origin, in the same km as
  /// [IntercityStop.km] (the track length is rescaled to match).
  final double alongKm;

  /// How far the fix is from the track. A big value means the rider is not on
  /// this train's route (or GPS is poor): do not trust [alongKm].
  final double offsetMeters;
}

/// Projects GPS fixes onto a service's simplified track.
class TrackIndex {
  TrackIndex(this.service) {
    final points = service.path;
    var total = 0.0;
    _cumulative.add(0);
    for (var i = 1; i < points.length; i += 1) {
      total += haversineMeters(
        points[i - 1].latitude,
        points[i - 1].longitude,
        points[i].latitude,
        points[i].longitude,
      );
      _cumulative.add(total);
    }
    _lengthMeters = total;
    // The simplified line is a little shorter than the real track; km on the
    // stops come from the full-resolution path, so scale to agree with them.
    _scale = total <= 0 ? 1 : (service.totalKm * 1000) / total;
  }

  final IntercityService service;
  final List<double> _cumulative = <double>[];
  double _lengthMeters = 0;
  double _scale = 1;

  double get lengthMeters => _lengthMeters;

  /// Places a fix on the track.
  ///
  /// With [hintKm] (where the train was a moment ago) only the stretch within
  /// [windowKm] of it is searched, so a track that loops or runs back past the
  /// same point (around a terminus, say) cannot make the position jump to the
  /// wrong part. If nothing in that stretch is close, the whole track is
  /// searched instead: the rider may simply have boarded somewhere else.
  TrackPosition project(
    double lat,
    double lon, {
    double? hintKm,
    double windowKm = 25,
  }) {
    if (hintKm != null) {
      final near = _projectWithin(
        lat,
        lon,
        fromKm: hintKm - windowKm,
        toKm: hintKm + windowKm,
      );
      if (near.offsetMeters <= 600) return near;
    }
    return _projectWithin(lat, lon);
  }

  TrackPosition _projectWithin(
    double lat,
    double lon, {
    double? fromKm,
    double? toKm,
  }) {
    final points = service.path;
    if (points.length < 2) {
      return const TrackPosition(alongKm: 0, offsetMeters: double.infinity);
    }
    var bestOffset = double.infinity;
    var bestAlong = 0.0;
    const metersPerDegreeLat = 111320.0;
    final metersPerDegreeLon = metersPerDegreeLat * math.cos(lat * math.pi / 180);
    for (var i = 0; i < points.length - 1; i += 1) {
      if (fromKm != null && toKm != null) {
        final segmentStartKm = _cumulative[i] * _scale / 1000;
        final segmentEndKm = _cumulative[i + 1] * _scale / 1000;
        if (segmentEndKm < fromKm || segmentStartKm > toKm) continue;
      }
      final a = points[i];
      final b = points[i + 1];
      final ax = (a.longitude - lon) * metersPerDegreeLon;
      final ay = (a.latitude - lat) * metersPerDegreeLat;
      final bx = (b.longitude - lon) * metersPerDegreeLon;
      final by = (b.latitude - lat) * metersPerDegreeLat;
      final dx = bx - ax;
      final dy = by - ay;
      final lengthSquared = dx * dx + dy * dy;
      final t = lengthSquared == 0
          ? 0.0
          : ((-ax * dx) + (-ay * dy)) / lengthSquared;
      final clamped = t.clamp(0.0, 1.0);
      final px = ax + dx * clamped;
      final py = ay + dy * clamped;
      final offset = math.sqrt(px * px + py * py);
      if (offset < bestOffset) {
        bestOffset = offset;
        final segment = _cumulative[i + 1] - _cumulative[i];
        bestAlong = _cumulative[i] + segment * clamped;
      }
    }
    return TrackPosition(
      alongKm: bestAlong * _scale / 1000,
      offsetMeters: bestOffset,
    );
  }
}
