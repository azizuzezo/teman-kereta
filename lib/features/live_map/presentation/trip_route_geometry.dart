import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

/// Pure geometry for drawing the active trip on the map: the real track
/// between each pair of consecutive stations, and points along it.

/// A station must be this close to a track to be cut from it.
const double _snapMeters = 300;

const double _ky = 110574.0;
const double _kx = 110700.0; // 111320 * cos(~6.2°), Jabodetabek latitude.

double _meters(LatLng a, LatLng b) {
  final dx = (a.longitude - b.longitude) * _kx;
  final dy = (a.latitude - b.latitude) * _ky;
  return math.sqrt(dx * dx + dy * dy);
}

/// One rail shape with its running length, so any slice is cheap to measure.
class _Shape {
  _Shape(this.points) : cumulative = List<double>.filled(points.length, 0) {
    for (var i = 1; i < points.length; i++) {
      cumulative[i] = cumulative[i - 1] + _meters(points[i - 1], points[i]);
    }
  }

  final List<LatLng> points;
  final List<double> cumulative;

  /// The closest point of each stretch of the shape that passes within
  /// [_snapMeters] of [p] — a branch ridden twice (the Cikarang loop shape
  /// goes out and back) yields two candidates.
  List<int> candidates(LatLng p) {
    final result = <int>[];
    var bestIndex = -1;
    var bestDistance = double.infinity;
    for (var i = 0; i < points.length; i++) {
      final d = _meters(points[i], p);
      if (d <= _snapMeters) {
        if (d < bestDistance) {
          bestDistance = d;
          bestIndex = i;
        }
      } else if (bestIndex >= 0) {
        result.add(bestIndex);
        bestIndex = -1;
        bestDistance = double.infinity;
      }
    }
    if (bestIndex >= 0) result.add(bestIndex);
    return result;
  }
}

/// Builds and caches track slices for consecutive stations.
class TripRouteBuilder {
  TripRouteBuilder(Map<String, List<List<double>>> shapes)
    : _shapes = <_Shape>[
        for (final shape in shapes.values)
          if (shape.length >= 2)
            _Shape(<LatLng>[for (final p in shape) LatLng(p[0], p[1])]),
      ];

  final List<_Shape> _shapes;

  /// The real track from [a] to [b] (both endpoints included, exact station
  /// points at the ends). Falls back to the straight line when no track runs
  /// past both, or the only slice found is a detour far longer than the hop.
  List<LatLng> hop(LatLng a, LatLng b) {
    final straight = _meters(a, b);
    List<LatLng>? best;
    var bestLength = double.infinity;
    for (final shape in _shapes) {
      final fromCandidates = shape.candidates(a);
      if (fromCandidates.isEmpty) continue;
      final toCandidates = shape.candidates(b);
      for (final i in fromCandidates) {
        for (final j in toCandidates) {
          if (i == j) continue;
          final length = (shape.cumulative[j] - shape.cumulative[i]).abs();
          if (length < bestLength) {
            bestLength = length;
            best = i < j
                ? shape.points.sublist(i, j + 1)
                : shape.points.sublist(j, i + 1).reversed.toList();
          }
        }
      }
    }
    if (best == null || bestLength > straight * 3 + 400) {
      return <LatLng>[a, b];
    }
    return <LatLng>[a, ...best.sublist(1, best.length - 1), b];
  }

  /// One track slice per consecutive pair of [stops].
  List<List<LatLng>> hops(List<LatLng> stops) => <List<LatLng>>[
    for (var i = 0; i + 1 < stops.length; i++) hop(stops[i], stops[i + 1]),
  ];
}

/// Length of [path] in meters.
double pathLength(List<LatLng> path) {
  var total = 0.0;
  for (var i = 1; i < path.length; i++) {
    total += _meters(path[i - 1], path[i]);
  }
  return total;
}

/// A point on the track and the direction of travel there (degrees clockwise
/// from north).
class PathPoint {
  const PathPoint(this.point, this.bearing);

  final LatLng point;
  final double bearing;
}

double _bearing(LatLng a, LatLng b) {
  final dx = (b.longitude - a.longitude) * _kx;
  final dy = (b.latitude - a.latitude) * _ky;
  final degrees = math.atan2(dx, dy) * 180 / math.pi;
  return (degrees + 360) % 360;
}

/// The point [fraction] (0–1) of the way along [path].
PathPoint pointAlongPath(List<LatLng> path, double fraction) {
  if (path.length < 2) {
    return PathPoint(path.first, 0);
  }
  final target = pathLength(path) * fraction.clamp(0.0, 1.0);
  var walked = 0.0;
  for (var i = 1; i < path.length; i++) {
    final a = path[i - 1];
    final b = path[i];
    final segment = _meters(a, b);
    if (walked + segment >= target || i == path.length - 1) {
      final t = segment == 0
          ? 0.0
          : ((target - walked) / segment).clamp(0.0, 1.0);
      return PathPoint(
        LatLng(
          a.latitude + (b.latitude - a.latitude) * t,
          a.longitude + (b.longitude - a.longitude) * t,
        ),
        _bearing(a, b),
      );
    }
    walked += segment;
  }
  return PathPoint(path.last, _bearing(path[path.length - 2], path.last));
}

/// How far along [path] (0–1) the point nearest to [p] is.
double fractionNearest(List<LatLng> path, LatLng p) {
  if (path.length < 2) return 0;
  final total = pathLength(path);
  if (total == 0) return 0;
  var walked = 0.0;
  var bestDistance = double.infinity;
  var bestAlong = 0.0;
  for (var i = 1; i < path.length; i++) {
    final a = path[i - 1];
    final b = path[i];
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
    final segment = math.sqrt(lengthSquared);
    if (d < bestDistance) {
      bestDistance = d;
      bestAlong = walked + t * segment;
    }
    walked += segment;
  }
  return bestAlong / total;
}
