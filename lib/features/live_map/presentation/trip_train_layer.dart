import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart' show LatLng;

import '../../../app/theme/app_theme.dart';
import 'active_trip_route.dart';
import 'live_trip_position_controller.dart';

/// The active trip's route on the real track: what is still to ride in the
/// trip colour, what has been ridden faded behind the train.
class TripRouteLayer extends ConsumerWidget {
  const TripRouteLayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final route = ref.watch(activeTripRouteProvider);
    if (route == null) {
      return const SizedBox.shrink();
    }
    final marker = ref.watch(liveTripPositionControllerProvider);
    final tk = context.tk;
    final (ridden, left) = marker == null
        ? (const <LatLng>[], route.points)
        : route.splitAt(marker.hopIndex, marker.hopFraction);
    return PolylineLayer<Object>(
      polylines: <Polyline<Object>>[
        if (ridden.length >= 2)
          Polyline<Object>(
            points: ridden,
            color: tk.textMuted.withValues(alpha: 0.75),
            strokeWidth: 5,
            borderStrokeWidth: 2,
            borderColor: tk.surface,
            pattern: StrokePattern.dashed(segments: const <double>[8, 6]),
          ),
        if (left.length >= 2)
          Polyline<Object>(
            points: left,
            color: tk.accent,
            strokeWidth: 7,
            borderStrokeWidth: 3,
            borderColor: tk.surface,
          ),
      ],
    );
  }
}

/// The rider's train, drawn on the track and turned to face where it is
/// going. Glides from its last position to the new one instead of jumping
/// each time a GPS fix or schedule tick moves it.
class TripTrainLayer extends ConsumerStatefulWidget {
  const TripTrainLayer({super.key});

  @override
  ConsumerState<TripTrainLayer> createState() => _TripTrainLayerState();
}

class _TripTrainLayerState extends ConsumerState<TripTrainLayer>
    with TickerProviderStateMixin {
  late final AnimationController _glide = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );

  TripMapMarker? _from;
  TripMapMarker? _to;

  @override
  void dispose() {
    _glide.dispose();
    _pulse.dispose();
    super.dispose();
  }

  void _moveTo(TripMapMarker? next) {
    if (!mounted) return;
    if (next == null) {
      setState(() {
        _from = null;
        _to = null;
      });
      _pulse.stop();
      return;
    }
    final current = _current();
    setState(() {
      _from = current ?? next;
      _to = next;
    });
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (reduceMotion) {
      _glide.value = 1;
    } else {
      _glide.forward(from: 0);
      if (!_pulse.isAnimating) {
        _pulse.repeat();
      }
    }
  }

  TripMapMarker? _current() {
    final from = _from;
    final to = _to;
    if (from == null || to == null) return to;
    final t = Curves.easeInOut.transform(_glide.value);
    return TripMapMarker(
      point: LatLng(
        from.point.latitude + (to.point.latitude - from.point.latitude) * t,
        from.point.longitude + (to.point.longitude - from.point.longitude) * t,
      ),
      bearing: _lerpAngle(from.bearing, to.bearing, t),
      hopIndex: to.hopIndex,
      hopFraction: to.hopFraction,
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<TripMapMarker?>(
      liveTripPositionControllerProvider,
      (previous, next) => _moveTo(next),
    );
    if (_to == null) {
      final initial = ref.read(liveTripPositionControllerProvider);
      if (initial != null) {
        _from = initial;
        _to = initial;
        _glide.value = 1;
        if (!(MediaQuery.maybeDisableAnimationsOf(context) ?? false)) {
          _pulse.repeat();
        }
      }
    }
    final camera = MapCamera.of(context);
    final tk = context.tk;
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: Listenable.merge(<Listenable>[_glide, _pulse]),
        builder: (context, _) {
          final marker = _current();
          if (marker == null) {
            return const SizedBox.shrink();
          }
          return CustomPaint(
            size: Size(camera.nonRotatedSize.x, camera.nonRotatedSize.y),
            painter: _TrainPainter(
              camera: camera,
              marker: marker,
              pulse: _pulse.value,
              body: tk.accent,
              outline: tk.surface,
              window: tk.surface.withValues(alpha: 0.9),
            ),
          );
        },
      ),
    );
  }
}

/// Shortest-way interpolation between two compass bearings.
double _lerpAngle(double a, double b, double t) {
  var delta = (b - a) % 360;
  if (delta > 180) delta -= 360;
  if (delta < -180) delta += 360;
  return (a + delta * t + 360) % 360;
}

class _TrainPainter extends CustomPainter {
  _TrainPainter({
    required this.camera,
    required this.marker,
    required this.pulse,
    required this.body,
    required this.outline,
    required this.window,
  });

  final MapCamera camera;
  final TripMapMarker marker;
  final double pulse;
  final Color body;
  final Color outline;
  final Color window;

  @override
  void paint(Canvas canvas, Size size) {
    final origin = camera.project(camera.center);
    final pt = camera.project(marker.point);
    final center = Offset(
      pt.x - origin.x + size.width / 2,
      pt.y - origin.y + size.height / 2,
    );

    // A soft pulse so the train is easy to find on a busy map.
    final halo = Paint()
      ..color = body.withValues(alpha: 0.28 * (1 - pulse))
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 16 + 14 * pulse, halo);

    final scale = camera.zoom < 12 ? 1.0 : (camera.zoom < 14 ? 1.25 : 1.45);
    const length = 38.0;
    const width = 15.0;

    canvas
      ..save()
      ..translate(center.dx, center.dy)
      ..rotate(marker.bearing * math.pi / 180)
      ..scale(scale);

    // Train seen from above, nose pointing up (the direction of travel).
    final bodyPath = Path()
      ..moveTo(-width / 2, length / 2 - 3)
      ..lineTo(-width / 2, -length / 2 + 9)
      ..quadraticBezierTo(-width / 2, -length / 2, 0, -length / 2)
      ..quadraticBezierTo(width / 2, -length / 2, width / 2, -length / 2 + 9)
      ..lineTo(width / 2, length / 2 - 3)
      ..quadraticBezierTo(width / 2, length / 2, width / 2 - 3, length / 2)
      ..lineTo(-width / 2 + 3, length / 2)
      ..quadraticBezierTo(-width / 2, length / 2, -width / 2, length / 2 - 3)
      ..close();

    canvas
      ..drawShadow(bodyPath, Colors.black, 3, false)
      ..drawPath(
        bodyPath,
        Paint()
          ..color = outline
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..strokeJoin = StrokeJoin.round,
      )
      ..drawPath(bodyPath, Paint()..color = body);

    final glass = Paint()..color = window;
    // Windscreen.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-width / 2 + 3, -length / 2 + 4, width - 6, 5),
        const Radius.circular(2),
      ),
      glass,
    );
    // Side windows.
    for (var i = 0; i < 3; i++) {
      final y = -length / 2 + 13 + i * 7.0;
      canvas
        ..drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(-width / 2 + 2.5, y, 3, 4.5),
            const Radius.circular(1),
          ),
          glass,
        )
        ..drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(width / 2 - 5.5, y, 3, 4.5),
            const Radius.circular(1),
          ),
          glass,
        );
    }
    // Pantograph on the roof.
    canvas.drawLine(
      const Offset(-3.5, 4),
      const Offset(3.5, 4),
      Paint()
        ..color = outline
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_TrainPainter oldDelegate) => true;
}
