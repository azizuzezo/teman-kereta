import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart' show LatLng;

import '../../../app/theme/app_theme.dart';
import '../../../app/theme/tk_colors.dart';
import 'active_trip_route.dart';
import 'krl_train_painter.dart';
import 'rider_train_motion.dart';

/// Seluruh rute trip di atas rel, digambar redup. Bagian yang belum dilalui
/// ditimpa warna trip oleh [TripAheadLayer] yang bergerak per frame, jadi
/// layer ini tidak perlu dibangun ulang saat kereta jalan.
class TripRouteLayer extends ConsumerWidget {
  const TripRouteLayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final route = ref.watch(activeTripRouteProvider);
    if (route == null) {
      return const SizedBox.shrink();
    }
    final tk = context.tk;
    return PolylineLayer<Object>(
      polylines: <Polyline<Object>>[
        Polyline<Object>(
          points: route.points,
          color: tk.textMuted.withValues(alpha: 0.75),
          strokeWidth: 5,
          borderStrokeWidth: 2,
          borderColor: tk.surface,
          pattern: StrokePattern.dashed(segments: const <double>[8, 6]),
        ),
      ],
    );
  }
}

Offset Function(LatLng) _screenMapper(MapCamera camera) {
  final origin = camera.project(camera.center);
  final halfW = camera.nonRotatedSize.x / 2;
  final halfH = camera.nonRotatedSize.y / 2;
  return (LatLng p) {
    final pt = camera.project(p);
    return Offset(pt.x - origin.x + halfW, pt.y - origin.y + halfH);
  };
}

/// Sisa rute di depan kereta, dalam warna trip. Ujung belakangnya selalu tepat
/// di kepala kereta karena ikut digambar ulang tiap frame.
class TripAheadLayer extends StatelessWidget {
  const TripAheadLayer({required this.motion, super.key});

  final RiderTrainMotion motion;

  @override
  Widget build(BuildContext context) {
    final camera = MapCamera.of(context);
    final tk = context.tk;
    return IgnorePointer(
      child: RepaintBoundary(
        child: ValueListenableBuilder<RiderPose?>(
          valueListenable: motion.pose,
          builder: (context, pose, _) {
            if (pose == null) return const SizedBox.shrink();
            return CustomPaint(
              size: Size(camera.nonRotatedSize.x, camera.nonRotatedSize.y),
              painter: _AheadPainter(
                camera: camera,
                pose: pose,
                accent: tk.accent,
                casing: tk.surface,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _AheadPainter extends CustomPainter {
  _AheadPainter({
    required this.camera,
    required this.pose,
    required this.accent,
    required this.casing,
  });

  final MapCamera camera;
  final RiderPose pose;
  final Color accent;
  final Color casing;

  @override
  void paint(Canvas canvas, Size size) {
    final toScreen = _screenMapper(camera);
    final path = pose.path;
    final from = path.firstPointBeyond(pose.arc);
    if (from >= path.points.length) return;
    final line = Path()
      ..moveTo(
        toScreen(pose.point).dx,
        toScreen(pose.point).dy,
      );
    for (var i = from; i < path.points.length; i++) {
      final o = toScreen(path.points[i]);
      line.lineTo(o.dx, o.dy);
    }
    canvas
      ..drawPath(
        line,
        Paint()
          ..color = casing
          ..style = PaintingStyle.stroke
          ..strokeWidth = 13
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      )
      ..drawPath(
        line,
        Paint()
          ..color = accent
          ..style = PaintingStyle.stroke
          ..strokeWidth = 7
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
  }

  @override
  bool shouldRepaint(_AheadPainter oldDelegate) => true;
}

/// KRL penumpang: rangkaian empat kereta yang meluncur mulus di atas rel dan
/// mengikuti tikungan, dengan halo berdenyut di kepalanya.
class TripTrainLayer extends StatelessWidget {
  const TripTrainLayer({required this.motion, super.key});

  final RiderTrainMotion motion;

  @override
  Widget build(BuildContext context) {
    final camera = MapCamera.of(context);
    final tk = context.tk;
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return IgnorePointer(
      child: RepaintBoundary(
        child: ValueListenableBuilder<RiderPose?>(
          valueListenable: motion.pose,
          builder: (context, pose, _) {
            if (pose == null) return const SizedBox.shrink();
            return CustomPaint(
              size: Size(camera.nonRotatedSize.x, camera.nonRotatedSize.y),
              painter: _TrainPainter(
                camera: camera,
                pose: pose,
                tk: tk,
                pulse: reduceMotion
                    ? 0
                    : (pose.time.millisecondsSinceEpoch % 1800) / 1800,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _TrainPainter extends CustomPainter {
  _TrainPainter({
    required this.camera,
    required this.pose,
    required this.tk,
    required this.pulse,
  });

  final MapCamera camera;
  final RiderPose pose;
  final TkColors tk;
  final double pulse;

  @override
  void paint(Canvas canvas, Size size) {
    final toScreen = _screenMapper(camera);
    final mpp = metersPerPixel(camera.zoom, pose.point.latitude);
    // Ukuran asli (20 m per kereta) kalau cukup besar; kalau tidak, dibesarkan
    // sampai tetap terbaca, dan di zoom dekat dibatasi supaya tidak raksasa.
    final carPx = (20 / mpp).clamp(13.0, 30.0).toDouble();
    final poses = layoutCars(
      path: pose.path,
      arc: pose.arc,
      dir: 1,
      count: 4,
      carPx: carPx,
      gapPx: math.max(1.5, carPx * 0.08),
      metersPerPx: mpp,
      toScreen: toScreen,
    );

    final head = poses.first.center;
    canvas.drawCircle(
      head,
      18 + 16 * pulse,
      Paint()..color = tk.accent.withValues(alpha: 0.28 * (1 - pulse)),
    );
    paintKrlSet(canvas, poses, carPx: carPx, outline: tk.surface);
  }

  @override
  bool shouldRepaint(_TrainPainter oldDelegate) => true;
}
