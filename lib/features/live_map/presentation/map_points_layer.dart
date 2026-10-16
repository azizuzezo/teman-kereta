import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../app/theme/tk_colors.dart';
import '../../../domain/entities/transit_models.dart';
import 'live_map_geometry.dart';

/// A station prepared once for drawing: canonical line ids and a cached
/// coordinate, so the per-frame painter does no list work.
class MapStationPoint {
  MapStationPoint(this.station)
    : point = LatLng(station.latitude, station.longitude),
      lineIds = <String>[for (final id in station.lineIds) canonicalLineId(id)];

  final Station station;
  final LatLng point;
  final List<String> lineIds;

  bool get isInterchange => lineIds.toSet().length > 1;
}

sealed class MapSelection {
  const MapSelection();
}

class StationSelection extends MapSelection {
  const StationSelection(this.station);
  final Station station;
}

class VehicleSelection extends MapSelection {
  const VehicleSelection(this.vehicle);
  final VehiclePosition vehicle;
}

/// Screen position of [point] inside the map widget, for an unrotated camera
/// (rotation is disabled on this map).
Offset projectToScreen(MapCamera camera, LatLng point) {
  final origin = camera.project(camera.center);
  final p = camera.project(point);
  return Offset(
    p.x - origin.x + camera.nonRotatedSize.x / 2,
    p.y - origin.y + camera.nonRotatedSize.y / 2,
  );
}

const double _vehicleDotZoom = 11.5;

/// Resolves a tap at [tap] (map-local pixels) to a selection: a train within
/// reach wins over a station, since trains sit on top of stations.
MapSelection? hitTestMapPoints({
  required MapCamera camera,
  required Offset tap,
  required List<MapStationPoint> stations,
  required List<VehiclePosition> vehicles,
  required String? lineFilter,
}) {
  final vehicleReach = camera.zoom < _vehicleDotZoom ? 14.0 : 22.0;
  final vehicleIndex = nearestPointWithin(
    <Offset>[
      for (final v in vehicles)
        projectToScreen(camera, LatLng(v.latitude, v.longitude)),
    ],
    tap,
    vehicleReach,
  );
  if (vehicleIndex != null) {
    return VehicleSelection(vehicles[vehicleIndex]);
  }
  final candidates = <MapStationPoint>[
    for (final s in stations)
      if (lineFilter == null || s.lineIds.contains(lineFilter)) s,
  ];
  final stationIndex = nearestPointWithin(
    <Offset>[for (final s in candidates) projectToScreen(camera, s.point)],
    tap,
    26,
  );
  if (stationIndex != null) {
    return StationSelection(candidates[stationIndex].station);
  }
  return null;
}

/// Stations, trains and the rider's own position, drawn in one canvas pass.
///
/// This replaces ~100 `Marker` widgets (each a Row with a blurred-shadow Text)
/// that flutter_map re-laid-out and repainted on every pan frame. Here a pan
/// frame is one cheap paint: dots, and a few cached text labels that are
/// culled to the viewport and de-overlapped.
class MapPointsLayer extends StatelessWidget {
  const MapPointsLayer({
    required this.stations,
    required this.vehicles,
    required this.lineColors,
    required this.lineFilter,
    required this.selection,
    required this.myLocation,
    required this.tripPosition,
    required this.colors,
    super.key,
  });

  final List<MapStationPoint> stations;
  final List<VehiclePosition> vehicles;
  final Map<String, Color> lineColors;
  final String? lineFilter;
  final MapSelection? selection;
  final LatLng? myLocation;
  final LatLng? tripPosition;
  final TkColors colors;

  @override
  Widget build(BuildContext context) {
    final camera = MapCamera.of(context);
    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          size: Size(camera.nonRotatedSize.x, camera.nonRotatedSize.y),
          painter: _MapPointsPainter(
            camera: camera,
            stations: stations,
            vehicles: vehicles,
            lineColors: lineColors,
            lineFilter: lineFilter,
            selection: selection,
            myLocation: myLocation,
            tripPosition: tripPosition,
            colors: colors,
          ),
        ),
      ),
    );
  }
}

class _LabelPaint {
  const _LabelPaint(this.fill, this.halo);
  final TextPainter fill;
  final TextPainter halo;
}

final Map<String, _LabelPaint> _labelCache = <String, _LabelPaint>{};
final Map<int, TextPainter> _glyphCache = <int, TextPainter>{};

_LabelPaint _labelFor(String name, TkColors tk, {required bool bold}) {
  final key = '$name|${tk.isDark}|$bold|${tk.text.toARGB32()}';
  final cached = _labelCache[key];
  if (cached != null) {
    return cached;
  }
  if (_labelCache.length > 400) {
    _labelCache.clear();
  }
  final weight = bold ? FontWeight.w800 : FontWeight.w600;
  TextPainter make(TextStyle style) => TextPainter(
    text: TextSpan(text: name, style: style),
    textDirection: TextDirection.ltr,
    maxLines: 1,
    ellipsis: '…',
  )..layout(maxWidth: 150);
  final halo = make(
    TextStyle(
      fontFamily: 'PlusJakartaSans',
      fontSize: 11,
      fontWeight: weight,
      foreground: Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeJoin = StrokeJoin.round
        ..color = tk.surface.withValues(alpha: 0.92),
    ),
  );
  final fill = make(
    TextStyle(
      fontFamily: 'PlusJakartaSans',
      fontSize: 11,
      fontWeight: weight,
      color: tk.text,
    ),
  );
  return _labelCache[key] = _LabelPaint(fill, halo);
}

TextPainter _glyph(IconData icon, Color color, double size) {
  final key = Object.hash(icon.codePoint, color.toARGB32(), size);
  return _glyphCache.putIfAbsent(
    key,
    () => TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          fontSize: size,
          color: color,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(),
  );
}

class _MapPointsPainter extends CustomPainter {
  _MapPointsPainter({
    required this.camera,
    required this.stations,
    required this.vehicles,
    required this.lineColors,
    required this.lineFilter,
    required this.selection,
    required this.myLocation,
    required this.tripPosition,
    required this.colors,
  });

  final MapCamera camera;
  final List<MapStationPoint> stations;
  final List<VehiclePosition> vehicles;
  final Map<String, Color> lineColors;
  final String? lineFilter;
  final MapSelection? selection;
  final LatLng? myLocation;
  final LatLng? tripPosition;
  final TkColors colors;

  @override
  void paint(Canvas canvas, Size size) {
    final zoom = camera.zoom;
    final origin = camera.project(camera.center);
    final halfW = camera.nonRotatedSize.x / 2;
    final halfH = camera.nonRotatedSize.y / 2;
    Offset toScreen(LatLng p) {
      final pt = camera.project(p);
      return Offset(pt.x - origin.x + halfW, pt.y - origin.y + halfH);
    }

    final viewport = (Offset.zero & size).inflate(40);
    final selectedId = switch (selection) {
      StationSelection(:final station) => station.id,
      _ => null,
    };

    final radius = zoom < 10.5
        ? 2.4
        : zoom < 12
        ? 3.6
        : zoom < 13.5
        ? 4.8
        : 6.0;

    final fillPaint = Paint()..style = PaintingStyle.fill;
    final ringPaint = Paint()..style = PaintingStyle.stroke;

    final visible = <(MapStationPoint, Offset, bool)>[];
    for (final s in stations) {
      final o = toScreen(s.point);
      if (!viewport.contains(o)) {
        continue;
      }
      final active = lineFilter == null || s.lineIds.contains(lineFilter);
      visible.add((s, o, active));
    }

    // Dots: inactive first (dimmed), then active, then the selected one.
    for (final pass in <int>[0, 1, 2]) {
      for (final (s, o, active) in visible) {
        final isSelected = s.station.id == selectedId;
        final pass0 = !active;
        if (pass == 0 && !pass0) continue;
        if (pass == 1 && (pass0 || isSelected)) continue;
        if (pass == 2 && !isSelected) continue;

        final lineColor = _stationColor(s);
        final r = radius + (s.isInterchange ? 1.2 : 0);
        if (isSelected) {
          fillPaint.color = colors.accent.withValues(alpha: 0.22);
          canvas.drawCircle(o, r + 9, fillPaint);
        }
        if (!active) {
          fillPaint.color = colors.surface.withValues(alpha: 0.7);
          canvas.drawCircle(o, r * 0.8, fillPaint);
          continue;
        }
        if (zoom < 11.5 && !isSelected) {
          fillPaint.color = colors.surface;
          canvas.drawCircle(o, r + 1, fillPaint);
          fillPaint.color = lineColor;
          canvas.drawCircle(o, r, fillPaint);
        } else {
          fillPaint.color = colors.surface;
          canvas.drawCircle(o, r, fillPaint);
          ringPaint
            ..strokeWidth = isSelected ? 3.2 : (s.isInterchange ? 3.0 : 2.4)
            ..color = isSelected
                ? colors.accent
                : (s.isInterchange ? colors.text : lineColor);
          canvas.drawCircle(o, r - ringPaint.strokeWidth / 2, ringPaint);
        }
      }
    }

    // Labels: selected first, then interchanges, then the rest by name.
    // Interchanges are named at every zoom level (the label placer drops the
    // ones that would collide, interchanges first); every other station is
    // named once the map is close enough for the names to fit.
    final showAll = zoom >= 12.4;
    const showInterchange = true;
    final candidates =
        <(MapStationPoint, Offset, bool)>[
          for (final v in visible)
            if (v.$3 &&
                (v.$1.station.id == selectedId ||
                    showAll ||
                    (showInterchange && v.$1.isInterchange)))
              v,
        ]..sort((a, b) {
          int rank((MapStationPoint, Offset, bool) v) =>
              v.$1.station.id == selectedId ? 0 : (v.$1.isInterchange ? 1 : 2);
          final byRank = rank(a).compareTo(rank(b));
          return byRank != 0
              ? byRank
              : a.$1.station.name.compareTo(b.$1.station.name);
        });
    final labels = <_LabelPaint>[
      for (final c in candidates)
        _labelFor(
          c.$1.station.name,
          colors,
          bold: c.$1.station.id == selectedId || c.$1.isInterchange,
        ),
    ];
    final rects = <Rect>[
      for (var i = 0; i < candidates.length; i += 1)
        Rect.fromLTWH(
          candidates[i].$2.dx + radius + 6,
          candidates[i].$2.dy - labels[i].fill.height / 2,
          labels[i].fill.width,
          labels[i].fill.height,
        ).inflate(2),
    ];
    final placed = placeLabels(rects);
    for (var i = 0; i < candidates.length; i += 1) {
      final forced = candidates[i].$1.station.id == selectedId;
      if (!placed[i] && !forced) {
        continue;
      }
      final at = Offset(rects[i].left + 2, rects[i].top + 2);
      labels[i].halo.paint(canvas, at);
      labels[i].fill.paint(canvas, at);
    }

    // Trains.
    final selectedVehicleId = switch (selection) {
      VehicleSelection(:final vehicle) => vehicle.id,
      _ => null,
    };
    final detailed = zoom >= _vehicleDotZoom;
    for (final v in vehicles) {
      final o = toScreen(LatLng(v.latitude, v.longitude));
      if (!viewport.contains(o)) {
        continue;
      }
      final isSelected = v.id == selectedVehicleId;
      if (isSelected) {
        fillPaint.color = colors.accent.withValues(alpha: 0.25);
        canvas.drawCircle(o, 22, fillPaint);
      }
      if (!detailed) {
        fillPaint.color = colors.surface;
        canvas.drawCircle(o, 4.2, fillPaint);
        fillPaint.color = colors.primary;
        canvas.drawCircle(o, 3, fillPaint);
        continue;
      }
      fillPaint.color = colors.surface;
      canvas.drawCircle(o, 13, fillPaint);
      fillPaint.color = colors.primary;
      canvas.drawCircle(o, 11, fillPaint);
      final glyph = _glyph(Icons.train_rounded, colors.onPrimary, 14);
      glyph.paint(canvas, o - Offset(glyph.width / 2, glyph.height / 2));
    }

    // The rider: where the phone is, and where the trip says the train is.
    final trip = tripPosition;
    if (trip != null) {
      final o = toScreen(trip);
      fillPaint.color = colors.accent.withValues(alpha: 0.25);
      canvas.drawCircle(o, 17, fillPaint);
      fillPaint.color = colors.surface;
      canvas.drawCircle(o, 10.5, fillPaint);
      fillPaint.color = colors.accent;
      canvas.drawCircle(o, 7.5, fillPaint);
    }
    final me = myLocation;
    if (me != null) {
      final o = toScreen(me);
      fillPaint.color = colors.primary.withValues(alpha: 0.2);
      canvas.drawCircle(o, 18, fillPaint);
      fillPaint.color = colors.surface;
      canvas.drawCircle(o, 9, fillPaint);
      fillPaint.color = colors.primary;
      canvas.drawCircle(o, 6.5, fillPaint);
    }
  }

  Color _stationColor(MapStationPoint s) {
    if (lineFilter != null && s.lineIds.contains(lineFilter)) {
      return lineColors[lineFilter] ?? colors.primary;
    }
    for (final id in s.lineIds) {
      final c = lineColors[id];
      if (c != null) {
        return c;
      }
    }
    return colors.primary;
  }

  @override
  bool shouldRepaint(_MapPointsPainter oldDelegate) => true;
}
