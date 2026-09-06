import 'dart:math' as math;

import '../../core/utils/geo.dart';
import '../../data/providers/rail_line_shapes.dart';
import '../entities/transit_models.dart';

/// How far a station's own coordinate may sit from a line's track geometry
/// before we stop believing that station really rides on that line. Station
/// points are building/entrance coordinates while [railLineShapes] traces the
/// track centreline, so a few hundred metres is normal at a large interchange
/// — but a kilometre means we matched the wrong line.
const _maxTrackOffsetMeters = 400.0;

/// Older/mock data uses long-form line codes; [railLineShapes] is keyed by the
/// production `lines.code` values. Same mapping the live map applies.
const _lineIdAliases = <String, String>{
  'RANGKASBITUNG': 'RANGKAS',
  'TANJUNG_PRIOK': 'PRIOK',
};

/// Distance actually travelled on rails across [path], in meters.
///
/// Measured segment by segment between consecutive stations, following the
/// real OpenStreetMap track geometry in [railLineShapes] wherever both ends
/// of a segment sit on a line we have geometry for. That matters for fare:
/// straight-line distance systematically *under*-reports a curving corridor,
/// and under-reporting near a tariff band edge quotes a fare that is too low.
///
/// Walking a station at a time (rather than origin-to-destination in one
/// shot) is what makes this work across a transfer — each pair resolves on
/// whichever line covers that pair, so a Bogor-line leg and a Cikarang-line
/// leg each get measured on their own geometry.
///
/// Falls back to straight-line distance for any segment whose geometry can't
/// be resolved, so a partially-covered route still yields a total rather
/// than nothing.
///
/// **Known limitation, and the one place this can quote a wrong fare.** The
/// tariff formula in `krl_fare.dart` is exact, but its input is measured from
/// OpenStreetMap geometry, and OSM's traced route can differ from the
/// official KAI distance a fare is really assessed on by a few hundred
/// metres. Everywhere in the middle of a tariff band that difference is
/// invisible. Within ~0.5 km of a band edge (25, 35, 45, 55 km...) it can tip
/// the fare by one Rp1.000 block: Bogor-Jakarta Kota measures 55.0 km here,
/// which sits directly on the Rp6.000/Rp7.000 boundary. Feeding real
/// operator-published station-pair distances into `railPathDistanceMeters`'s
/// place is what would close this for good.
double railPathDistanceMeters(List<Station> path) {
  var total = 0.0;
  for (var i = 0; i < path.length - 1; i += 1) {
    total += _segmentDistanceMeters(path[i], path[i + 1]);
  }
  return total;
}

double _segmentDistanceMeters(Station a, Station b) {
  final straight = haversineMeters(
    a.latitude,
    a.longitude,
    b.latitude,
    b.longitude,
  );
  final track = railTrackDistanceMeters(a, b);
  if (track == null) {
    return straight;
  }
  // Two *adjacent* stations are never joined by a path twice as long as the
  // straight line between them. A result that long means the projection
  // latched onto the wrong part of a line that doubles back on itself —
  // trust the straight line rather than return a nonsense number. This bound
  // only holds between neighbours, which is why it lives here and not in
  // `railTrackDistanceMeters`, where the two stations may be a whole
  // corridor apart and legitimately far from any straight line.
  if (track > (straight * 2) + 500) {
    return straight;
  }
  return track;
}

/// Distance along the rails between any two stations that share a line we
/// have geometry for — the two need not be neighbours. Returns null when no
/// line's track plausibly passes through both, so callers can tell "not
/// measurable" apart from "measured as short".
double? railTrackDistanceMeters(Station a, Station b) {
  double? best;
  var bestOffset = double.infinity;

  for (final key in _candidateShapeKeys(a, b)) {
    final shape = railLineShapes[key];
    if (shape == null || shape.length < 2) {
      continue;
    }
    final projectedA = _projectOntoShape(shape, a.latitude, a.longitude);
    final projectedB = _projectOntoShape(shape, b.latitude, b.longitude);
    if (projectedA.offset > _maxTrackOffsetMeters ||
        projectedB.offset > _maxTrackOffsetMeters) {
      continue;
    }
    final distance = (projectedA.along - projectedB.along).abs();
    // Rails can only ever be longer than the straight line between their
    // endpoints. Shorter means the projection landed somewhere impossible.
    if (distance <
        haversineMeters(a.latitude, a.longitude, b.latitude, b.longitude)) {
      continue;
    }
    // With several plausible lines (common at interchanges), keep the one
    // whose track passes closest to both stations.
    final offset = projectedA.offset + projectedB.offset;
    if (offset < bestOffset) {
      bestOffset = offset;
      best = distance;
    }
  }
  return best;
}

/// Lines to test for a station pair: the ones both stations are recorded on,
/// falling back to every known shape for providers that don't populate
/// `lineIds` at all (mock/GTFS) — the offset threshold is what rejects a
/// wrong guess there, not the candidate list.
Iterable<String> _candidateShapeKeys(Station a, Station b) {
  final shared = <String>{
    for (final id in a.lineIds)
      if (b.lineIds.contains(id)) _lineIdAliases[id] ?? id,
  };
  return shared.isEmpty ? railLineShapes.keys : shared;
}

/// Where a point falls on a polyline: [along] is the distance from the
/// polyline's start to the nearest point on it, [offset] how far the point
/// itself lies from that nearest point.
typedef _Projection = ({double along, double offset});

_Projection _projectOntoShape(List<List<double>> shape, double lat, double lon) {
  var cumulative = 0.0;
  var bestAlong = 0.0;
  var bestOffset = double.infinity;

  for (var i = 0; i < shape.length - 1; i += 1) {
    final start = shape[i];
    final end = shape[i + 1];
    final segmentMeters = haversineMeters(
      start[0],
      start[1],
      end[0],
      end[1],
    );
    final t = _projectionFactor(start, end, lat, lon);
    final pointLat = start[0] + ((end[0] - start[0]) * t);
    final pointLon = start[1] + ((end[1] - start[1]) * t);
    final offset = haversineMeters(lat, lon, pointLat, pointLon);
    if (offset < bestOffset) {
      bestOffset = offset;
      bestAlong = cumulative + (segmentMeters * t);
    }
    cumulative += segmentMeters;
  }
  return (along: bestAlong, offset: bestOffset);
}

/// How far along the segment start->end the nearest point to (lat, lon) sits,
/// clamped to [0, 1] so a point beyond either end projects onto that end.
///
/// Uses a flat local approximation (degrees scaled to meters at this
/// latitude) rather than spherical geometry: individual polyline segments
/// here are tens of meters long, where the difference is far below the
/// precision the coordinates themselves carry.
double _projectionFactor(
  List<double> start,
  List<double> end,
  double lat,
  double lon,
) {
  const metersPerDegreeLat = 111320.0;
  final metersPerDegreeLon =
      metersPerDegreeLat * math.cos(start[0] * math.pi / 180);

  final segmentX = (end[1] - start[1]) * metersPerDegreeLon;
  final segmentY = (end[0] - start[0]) * metersPerDegreeLat;
  final pointX = (lon - start[1]) * metersPerDegreeLon;
  final pointY = (lat - start[0]) * metersPerDegreeLat;

  final lengthSquared = (segmentX * segmentX) + (segmentY * segmentY);
  if (lengthSquared == 0) {
    return 0;
  }
  final dot = (pointX * segmentX) + (pointY * segmentY);
  return (dot / lengthSquared).clamp(0.0, 1.0);
}
