import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;

import '../../../app/theme/tk_colors.dart';
import 'krl_train_painter.dart';
import 'map_points_layer.dart';
import 'vehicle_motion.dart';

/// Kereta pengguna lain, digambar per frame di atas rel. Hanya arah dan tujuan
/// (`ke Bogor`) yang tampil, tidak pernah nama atau identitas siapa pun.
class MapVehiclesLayer extends StatelessWidget {
  const MapVehiclesLayer({
    required this.hub,
    required this.selection,
    required this.colors,
    super.key,
  });

  final VehicleMotionHub hub;
  final ValueNotifier<MapSelection?> selection;
  final TkColors colors;

  @override
  Widget build(BuildContext context) {
    final camera = MapCamera.of(context);
    return IgnorePointer(
      child: RepaintBoundary(
        child: ListenableBuilder(
          listenable: Listenable.merge(<Listenable>[hub.frame, selection]),
          builder: (context, _) {
            final vehicles = hub.frame.value;
            if (vehicles.isEmpty) return const SizedBox.shrink();
            return CustomPaint(
              size: Size(camera.nonRotatedSize.x, camera.nonRotatedSize.y),
              painter: _VehiclesPainter(
                camera: camera,
                vehicles: vehicles,
                selectedId: switch (selection.value) {
                  VehicleSelection(:final vehicle) => vehicle.id,
                  _ => null,
                },
                colors: colors,
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Di bawah zoom ini kereta hanya titik; di atasnya rangkaian KRL.
const double _trainShapeZoom = 11.5;

/// Dari zoom ini tujuan kereta ditulis di dekatnya.
const double _destinationZoom = 13;

class _VehiclesPainter extends CustomPainter {
  _VehiclesPainter({
    required this.camera,
    required this.vehicles,
    required this.selectedId,
    required this.colors,
  });

  final MapCamera camera;
  final List<AnimatedVehicle> vehicles;
  final String? selectedId;
  final TkColors colors;

  @override
  void paint(Canvas canvas, Size size) {
    final origin = camera.project(camera.center);
    final halfW = camera.nonRotatedSize.x / 2;
    final halfH = camera.nonRotatedSize.y / 2;
    Offset toScreen(LatLng p) {
      final pt = camera.project(p);
      return Offset(pt.x - origin.x + halfW, pt.y - origin.y + halfH);
    }

    final viewport = (Offset.zero & size).inflate(60);
    final zoom = camera.zoom;
    final fill = Paint()..style = PaintingStyle.fill;

    for (final v in vehicles) {
      final o = toScreen(v.point);
      if (!viewport.contains(o)) continue;
      final selected = v.id == selectedId;
      if (selected) {
        fill.color = colors.accent.withValues(alpha: 0.25);
        canvas.drawCircle(o, 24, fill);
      }

      if (zoom < _trainShapeZoom || !v.directionKnown) {
        fill.color = colors.surface;
        canvas.drawCircle(o, zoom < _trainShapeZoom ? 4.2 : 9, fill);
        fill.color = colors.primary;
        canvas.drawCircle(o, zoom < _trainShapeZoom ? 3 : 7, fill);
        continue;
      }

      final mpp = metersPerPixel(zoom, v.point.latitude);
      final carPx = (20 / mpp).clamp(11.0, 24.0).toDouble();
      final poses = layoutCars(
        path: v.path,
        arc: v.arc,
        dir: v.dir,
        count: 3,
        carPx: carPx,
        gapPx: math.max(1.2, carPx * 0.08),
        metersPerPx: mpp,
        toScreen: toScreen,
      );
      paintKrlSet(canvas, poses, carPx: carPx, outline: colors.surface);

      final headsign = v.vehicle.headsign;
      if (zoom >= _destinationZoom && headsign != null && headsign.isNotEmpty) {
        paintDestinationChip(
          canvas,
          o + Offset(0, carPx * 1.9),
          headsign,
          background: colors.surface,
          foreground: colors.text,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_VehiclesPainter oldDelegate) => true;
}
