import 'dart:math' as math;
import 'dart:ui' show Color, Offset, Rect;

import 'package:flutter/painting.dart' show HSLColor;
import 'package:latlong2/latlong.dart';

import '../../../domain/entities/transit_models.dart';

/// Pure map math for the live map: track geometry, line identity, colour
/// contrast and label placement. No widgets, so it is all unit-tested.

/// Older/mock data uses long-form line codes; the bundled track geometry and
/// the production `lines.code` values use the short ones.
const Map<String, String> lineIdAliases = <String, String>{
  'RANGKASBITUNG': 'RANGKAS',
  'TANJUNG_PRIOK': 'PRIOK',
};

String canonicalLineId(String id) => lineIdAliases[id] ?? id;

const Map<String, String> _lineShortNames = <String, String>{
  'BOGOR': 'Bogor',
  'NAMBO': 'Nambo',
  'CIKARANG': 'Cikarang',
  'RANGKAS': 'Rangkasbitung',
  'TANGERANG': 'Tangerang',
  'PRIOK': 'Tanjung Priok',
  'BEKASI': 'Bekasi',
  'SERPONG': 'Serpong',
};

/// Short label for a line chip, e.g. `Bogor`. Unknown codes are humanised
/// (`SOME_LINE` becomes `Some Line`) instead of shown raw.
String lineShortName(String lineId) {
  final id = canonicalLineId(lineId);
  final known = _lineShortNames[id];
  if (known != null) {
    return known;
  }
  return id
      .split(RegExp(r'[_\-\s]+'))
      .where((w) => w.isNotEmpty)
      .map((w) => w[0].toUpperCase() + w.substring(1).toLowerCase())
      .join(' ');
}

/// Full label, e.g. `Lintas Bogor`.
String lineLongName(String lineId) => 'Lintas ${lineShortName(lineId)}';

/// Canonical, de-duplicated, sorted line ids present on [stations].
List<String> lineIdsOf(List<Station> stations) {
  final ids = <String>{
    for (final s in stations)
      for (final id in s.lineIds) canonicalLineId(id),
  }.toList()..sort();
  return ids;
}

bool stationIsOnLine(Station station, String canonicalId) {
  for (final id in station.lineIds) {
    if (canonicalLineId(id) == canonicalId) {
      return true;
    }
  }
  return false;
}

// ---------------------------------------------------------------------------
// Polyline simplification
// ---------------------------------------------------------------------------

/// Douglas-Peucker simplification with the tolerance in meters. Endpoints are
/// always kept. Works on a local equirectangular projection, which is accurate
/// to well under a meter at the scale of one rail line.
List<LatLng> simplifyPolyline(List<LatLng> points, double toleranceMeters) {
  final n = points.length;
  if (n < 3 || toleranceMeters <= 0) {
    return List<LatLng>.of(points);
  }
  var latSum = 0.0;
  for (final p in points) {
    latSum += p.latitude;
  }
  final meanLat = latSum / n;
  final kx = 111320.0 * math.cos(meanLat * math.pi / 180);
  const ky = 110574.0;
  final xs = List<double>.generate(n, (i) => points[i].longitude * kx);
  final ys = List<double>.generate(n, (i) => points[i].latitude * ky);

  final keep = List<bool>.filled(n, false);
  keep[0] = true;
  keep[n - 1] = true;
  final stack = <(int, int)>[(0, n - 1)];
  while (stack.isNotEmpty) {
    final (start, end) = stack.removeLast();
    if (end - start < 2) {
      continue;
    }
    var maxDistance = -1.0;
    var maxIndex = -1;
    for (var i = start + 1; i < end; i += 1) {
      final d = _segmentDistance(
        xs[i],
        ys[i],
        xs[start],
        ys[start],
        xs[end],
        ys[end],
      );
      if (d > maxDistance) {
        maxDistance = d;
        maxIndex = i;
      }
    }
    if (maxDistance > toleranceMeters && maxIndex > 0) {
      keep[maxIndex] = true;
      stack
        ..add((start, maxIndex))
        ..add((maxIndex, end));
    }
  }
  return <LatLng>[
    for (var i = 0; i < n; i += 1)
      if (keep[i]) points[i],
  ];
}

double _segmentDistance(
  double px,
  double py,
  double ax,
  double ay,
  double bx,
  double by,
) {
  final dx = bx - ax;
  final dy = by - ay;
  final lengthSquared = dx * dx + dy * dy;
  if (lengthSquared == 0) {
    return math.sqrt((px - ax) * (px - ax) + (py - ay) * (py - ay));
  }
  final t = (((px - ax) * dx + (py - ay) * dy) / lengthSquared).clamp(0.0, 1.0);
  final cx = ax + t * dx;
  final cy = ay + t * dy;
  return math.sqrt((px - cx) * (px - cx) + (py - cy) * (py - cy));
}

// ---------------------------------------------------------------------------
// Line tracks
// ---------------------------------------------------------------------------

class LineTrack {
  const LineTrack({
    required this.lineId,
    required this.points,
    required this.isRealTrack,
  });

  final String lineId;
  final List<LatLng> points;

  /// True when [points] is the real track geometry (OpenStreetMap rail
  /// relations bundled in the app); false when it is only the stations joined
  /// in stop order, which cuts corners between stations.
  final bool isRealTrack;
}

/// Stations of [lineId] in travel order. Uses `stopOrderByLine` when every
/// station has it; otherwise chains stations nearest-neighbour from one end of
/// the line (the station farthest from the line's centre), which follows a
/// roughly linear line far better than sorting by latitude.
List<Station> orderStationsOnLine(List<Station> stations, String lineId) {
  final id = canonicalLineId(lineId);
  final members = stations
      .where((s) => stationIsOnLine(s, id))
      .toList(growable: false);
  if (members.length < 2) {
    return members;
  }
  int? orderOf(Station s) {
    for (final entry in s.stopOrderByLine.entries) {
      if (canonicalLineId(entry.key) == id) {
        return entry.value;
      }
    }
    return null;
  }

  if (members.every((s) => orderOf(s) != null)) {
    final sorted = members.toList()
      ..sort((a, b) => orderOf(a)!.compareTo(orderOf(b)!));
    return sorted;
  }

  var cLat = 0.0;
  var cLon = 0.0;
  for (final s in members) {
    cLat += s.latitude;
    cLon += s.longitude;
  }
  cLat /= members.length;
  cLon /= members.length;
  double sq(Station a, double lat, double lon) {
    final dLat = a.latitude - lat;
    final dLon = a.longitude - lon;
    return dLat * dLat + dLon * dLon;
  }

  final remaining = members.toList();
  remaining.sort((a, b) => sq(b, cLat, cLon).compareTo(sq(a, cLat, cLon)));
  final ordered = <Station>[remaining.removeAt(0)];
  while (remaining.isNotEmpty) {
    final last = ordered.last;
    var bestIndex = 0;
    var best = double.infinity;
    for (var i = 0; i < remaining.length; i += 1) {
      final d = sq(remaining[i], last.latitude, last.longitude);
      if (d < best) {
        best = d;
        bestIndex = i;
      }
    }
    ordered.add(remaining.removeAt(bestIndex));
  }
  return ordered;
}

/// Builds the polyline for [lineId]: real track geometry from [shapes] when
/// available (simplified once at [simplifyMeters], which removes redundant
/// points without visibly changing the line), otherwise the stations joined in
/// stop order. Returns null when there is not enough data to draw anything.
LineTrack? buildLineTrack({
  required String lineId,
  required List<Station> stations,
  required Map<String, List<List<double>>> shapes,
  double simplifyMeters = 5,
}) {
  final id = canonicalLineId(lineId);
  final shape = shapes[id];
  if (shape != null && shape.length >= 2) {
    final raw = <LatLng>[for (final p in shape) LatLng(p[0], p[1])];
    return LineTrack(
      lineId: id,
      points: simplifyPolyline(raw, simplifyMeters),
      isRealTrack: true,
    );
  }
  final ordered = orderStationsOnLine(stations, id);
  if (ordered.length < 2) {
    return null;
  }
  return LineTrack(
    lineId: id,
    points: <LatLng>[for (final s in ordered) LatLng(s.latitude, s.longitude)],
    isRealTrack: false,
  );
}

/// Simplification tolerance (meters) worth one screen pixel at [zoom] for
/// latitudes near Jabodetabek. Anything finer than a pixel is invisible.
double simplifyToleranceForZoom(
  double zoom, {
  double pixels = 1.0,
  double latitude = -6.2,
}) {
  final metersPerPixel =
      156543.03392 * math.cos(latitude * math.pi / 180) / math.pow(2, zoom);
  return metersPerPixel * pixels;
}

// ---------------------------------------------------------------------------
// Colours
// ---------------------------------------------------------------------------

/// Used only for a line that has no colour in `public.lines` (offline, or a
/// provider without a lines table). Distinct hues so lines stay separable;
/// the legend names every line, so a colour is never the only identifier.
const List<Color> fallbackLineColors = <Color>[
  Color(0xFFD64545),
  Color(0xFF2B7BD6),
  Color(0xFF1F9E6B),
  Color(0xFFD98A1C),
  Color(0xFF8E5BD0),
  Color(0xFF179AAE),
  Color(0xFFC2457F),
  Color(0xFF6B7A8F),
];

double contrastRatio(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = math.max(la, lb);
  final lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

/// Moves [color] lighter (on a dark background) or darker (on a light one)
/// until it reaches [minRatio] against [background], keeping its hue, so a
/// line colour stays visible on both the light and the dark map.
Color ensureContrast(Color color, Color background, {double minRatio = 3.0}) {
  if (contrastRatio(color, background) >= minRatio) {
    return color;
  }
  final lighten = background.computeLuminance() < 0.5;
  var hsl = HSLColor.fromColor(color);
  for (var i = 0; i < 25; i += 1) {
    final next = (hsl.lightness + (lighten ? 0.04 : -0.04)).clamp(0.0, 1.0);
    hsl = hsl.withLightness(next);
    final candidate = hsl.toColor();
    if (contrastRatio(candidate, background) >= minRatio) {
      return candidate;
    }
    if (next <= 0.0 || next >= 1.0) {
      break;
    }
  }
  return hsl.toColor();
}

/// `{canonicalLineId: color}` for every id in [lineIds]: the colour from
/// `public.lines` when [dbColors] has it (under either the short or the long
/// code), else a stable fallback, then adjusted for contrast against
/// [mapBackground].
Map<String, Color> resolveLineColors({
  required List<String> lineIds,
  required Map<String, Color> dbColors,
  required Color mapBackground,
}) {
  final byCanonical = <String, Color>{
    for (final e in dbColors.entries) canonicalLineId(e.key): e.value,
  };
  final result = <String, Color>{};
  for (var i = 0; i < lineIds.length; i += 1) {
    final id = canonicalLineId(lineIds[i]);
    final base =
        byCanonical[id] ?? fallbackLineColors[i % fallbackLineColors.length];
    result[id] = ensureContrast(base, mapBackground);
  }
  return result;
}

// ---------------------------------------------------------------------------
// Hit testing and label placement
// ---------------------------------------------------------------------------

/// Index of the point in [points] nearest to [tap] within [radius] pixels, or
/// null. Ties resolve to the earlier index, so callers can order [points] by
/// priority.
int? nearestPointWithin(List<Offset> points, Offset tap, double radius) {
  int? best;
  var bestDistance = radius * radius;
  for (var i = 0; i < points.length; i += 1) {
    final dx = points[i].dx - tap.dx;
    final dy = points[i].dy - tap.dy;
    final d = dx * dx + dy * dy;
    if (d <= bestDistance) {
      if (best == null || d < bestDistance) {
        best = i;
        bestDistance = d;
      }
    }
  }
  return best;
}

/// Greedy label placement: [rects] are candidate label boxes in priority
/// order; a label is accepted only when it overlaps no accepted one.
List<bool> placeLabels(List<Rect> rects) {
  final accepted = <Rect>[];
  final result = List<bool>.filled(rects.length, false);
  for (var i = 0; i < rects.length; i += 1) {
    final r = rects[i];
    var clear = true;
    for (final other in accepted) {
      if (r.overlaps(other)) {
        clear = false;
        break;
      }
    }
    if (clear) {
      accepted.add(r);
      result[i] = true;
    }
  }
  return result;
}

/// Stations matching [query] (name or code, case-insensitive). Names that
/// start with the query come first, then names containing it; capped at
/// [limit]. An empty query returns the first [limit] stations by name.
List<Station> searchStations(
  List<Station> stations,
  String query, {
  int limit = 60,
}) {
  final q = query.trim().toLowerCase();
  final sorted = stations.toList()
    ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  if (q.isEmpty) {
    return sorted.take(limit).toList(growable: false);
  }
  final starts = <Station>[];
  final contains = <Station>[];
  for (final s in sorted) {
    final name = s.name.toLowerCase();
    if (name.startsWith(q)) {
      starts.add(s);
    } else if (name.contains(q) || s.code.toLowerCase() == q) {
      contains.add(s);
    }
  }
  return <Station>[...starts, ...contains].take(limit).toList(growable: false);
}

/// Trains whose last report is newer than [maxAge]. A stalled feed must never
/// leave a ghost train frozen on the map looking live.
List<VehiclePosition> freshVehicles(
  List<VehiclePosition> vehicles,
  DateTime now, {
  Duration maxAge = const Duration(minutes: 5),
}) {
  return <VehiclePosition>[
    for (final v in vehicles)
      if (now.difference(v.recordedAt) <= maxAge) v,
  ];
}

/// Clock time for departure rows, `07:05`.
String formatClock(DateTime time) {
  final h = time.hour.toString().padLeft(2, '0');
  final m = time.minute.toString().padLeft(2, '0');
  return '$h:$m';
}

/// Plain-language wait, `Sekarang`, `5 menit`, `1 jam 10 menit`.
String formatWait(Duration wait) {
  if (wait.inSeconds < 60) {
    return 'Sekarang';
  }
  final minutes = wait.inMinutes;
  if (minutes < 60) {
    return '$minutes menit';
  }
  final h = minutes ~/ 60;
  final m = minutes % 60;
  return m == 0 ? '$h jam' : '$h jam $m menit';
}
