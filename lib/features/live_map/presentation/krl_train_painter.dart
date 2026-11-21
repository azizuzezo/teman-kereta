import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart' hide Path;

import 'track_motion.dart';

/// KRL Commuter Line dilihat dari atas, gerbongnya mengikuti tikungan rel.
///
/// Warna di [KrlLivery] adalah pendekatan (putih dengan strip biru dan
/// merah). Semua ada di satu tempat supaya mudah disesuaikan dengan foto
/// acuan resmi.
class KrlLivery {
  const KrlLivery._();

  static const Color body = Color(0xFFF6F6F3);
  static const Color stripeBlue = Color(0xFF1F4E9C);
  static const Color stripeRed = Color(0xFFD62828);
  static const Color roofUnit = Color(0xFFC7CCD2);
  static const Color glass = Color(0xFF28323F);
  static const Color headlight = Color(0xFFFFE08A);
}

/// Meter per piksel pada [zoom] di [latitude] (proyeksi Web Mercator).
double metersPerPixel(double zoom, double latitude) {
  return 156543.03392 *
      math.cos(latitude * math.pi / 180) /
      math.pow(2, zoom).toDouble();
}

/// Satu gerbong di layar: titik tengah dan arah hadapnya (radian, searah jarum
/// jam dari atas layar).
class CarPose {
  const CarPose(this.center, this.angle);

  final Offset center;
  final double angle;
}

/// Menata [count] gerbong di sepanjang [path]. Kepala rangkaian ada di jarak
/// [arc]; [dir] +1 bila kereta bergerak ke arah jarak membesar, -1 sebaliknya.
/// Tiap gerbong diarahkan dari titik depan ke titik belakangnya di layar,
/// sehingga rangkaian melengkung mengikuti rel.
List<CarPose> layoutCars({
  required TrackPath path,
  required double arc,
  required int dir,
  required int count,
  required double carPx,
  required double gapPx,
  required double metersPerPx,
  required Offset Function(LatLng) toScreen,
}) {
  final carMeters = carPx * metersPerPx;
  final pitch = (carPx + gapPx) * metersPerPx;
  final poses = <CarPose>[];
  var lastAngle = 0.0;
  for (var i = 0; i < count; i++) {
    final frontArc = arc - dir * i * pitch;
    final rearArc = frontArc - dir * carMeters;
    final front = toScreen(path.pointAt(frontArc).point);
    final rear = toScreen(path.pointAt(rearArc).point);
    final d = front - rear;
    final angle = d.distance < 0.01 ? lastAngle : math.atan2(d.dx, -d.dy);
    lastAngle = angle;
    poses.add(CarPose(Offset.lerp(front, rear, 0.5)!, angle));
  }
  return poses;
}

/// Menggambar rangkaian: gerbong pertama berkabin depan, terakhir berkabin
/// belakang, pantograf di gerbong kedua dan keempat (gerbong bermotor).
void paintKrlSet(
  Canvas canvas,
  List<CarPose> poses, {
  required double carPx,
  required Color outline,
}) {
  final width = carPx * 0.46;
  for (var i = 0; i < poses.length; i++) {
    paintKrlCar(
      canvas,
      poses[i],
      length: carPx,
      width: width,
      frontCab: i == 0,
      rearCab: i == poses.length - 1,
      pantograph: i == 1 || i == 3,
      outline: outline,
    );
  }
}

void paintKrlCar(
  Canvas canvas,
  CarPose pose, {
  required double length,
  required double width,
  required bool frontCab,
  required bool rearCab,
  required bool pantograph,
  required Color outline,
}) {
  canvas
    ..save()
    ..translate(pose.center.dx, pose.center.dy)
    ..rotate(pose.angle);

  final halfL = length / 2;
  final halfW = width / 2;
  final noseRadius = Radius.circular(halfW * 0.9);
  const squareRadius = Radius.circular(1.2);
  final bodyRect = RRect.fromRectAndCorners(
    Rect.fromCenter(center: Offset.zero, width: width, height: length),
    topLeft: frontCab ? noseRadius : squareRadius,
    topRight: frontCab ? noseRadius : squareRadius,
    bottomLeft: rearCab ? noseRadius : squareRadius,
    bottomRight: rearCab ? noseRadius : squareRadius,
  );
  final bodyPath = Path()..addRRect(bodyRect);

  canvas
    ..drawShadow(bodyPath, Colors.black, 2, false)
    ..drawPath(
      bodyPath,
      Paint()
        ..color = outline
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeJoin = StrokeJoin.round,
    )
    ..drawPath(bodyPath, Paint()..color = KrlLivery.body);

  // Terlalu kecil untuk detail: badan putih dan strip saja.
  final detailed = length >= 12;

  canvas.save();
  canvas.clipRRect(bodyRect);
  // Strip biru di kedua sisi atap, merah di tengah.
  final edge = width * 0.17;
  canvas
    ..drawRect(
      Rect.fromLTWH(-halfW, -halfL, edge, length),
      Paint()..color = KrlLivery.stripeBlue,
    )
    ..drawRect(
      Rect.fromLTWH(halfW - edge, -halfL, edge, length),
      Paint()..color = KrlLivery.stripeBlue,
    );
  if (detailed) {
    canvas.drawRect(
      Rect.fromLTWH(-width * 0.05, -halfL, width * 0.1, length),
      Paint()..color = KrlLivery.stripeRed,
    );
  }
  canvas.restore();

  if (detailed) {
    // Dua unit AC di atap.
    final unit = Paint()..color = KrlLivery.roofUnit;
    for (final dy in <double>[-0.2, 0.2]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(0, dy * length),
            width: width * 0.4,
            height: length * 0.2,
          ),
          const Radius.circular(0.8),
        ),
        unit,
      );
    }
    if (pantograph) {
      final line = Paint()
        ..color = KrlLivery.glass
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(0.8, width * 0.07);
      canvas.drawRect(
        Rect.fromCenter(
          center: Offset.zero,
          width: width * 0.5,
          height: length * 0.14,
        ),
        line,
      );
    }
    // Kaca depan dan lampu di ujung berkabin.
    void cab(double sign) {
      final glass = Paint()..color = KrlLivery.glass;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(0, sign * (halfL - length * 0.13)),
            width: width * 0.62,
            height: length * 0.15,
          ),
          const Radius.circular(1),
        ),
        glass,
      );
      final lamp = Paint()..color = KrlLivery.headlight;
      final r = math.max(0.9, width * 0.07);
      canvas
        ..drawCircle(Offset(-width * 0.26, sign * (halfL - length * 0.04)), r, lamp)
        ..drawCircle(Offset(width * 0.26, sign * (halfL - length * 0.04)), r, lamp);
    }

    if (frontCab) cab(-1);
    if (rearCab) cab(1);
  }
  canvas.restore();
}

/// Cache label tujuan (`ke Bogor`): satu TextPainter per teks dan tema.
final Map<String, TextPainter> _destinationCache = <String, TextPainter>{};

/// Gambar label kecil `ke <tujuan>` di [anchor]. Hanya tujuan kereta, tidak
/// pernah identitas penumpang.
void paintDestinationChip(
  Canvas canvas,
  Offset anchor,
  String destination, {
  required Color background,
  required Color foreground,
}) {
  final key = '$destination|${foreground.toARGB32()}';
  if (_destinationCache.length > 200) _destinationCache.clear();
  final text = _destinationCache.putIfAbsent(
    key,
    () => TextPainter(
      text: TextSpan(
        text: 'ke $destination',
        style: TextStyle(
          fontFamily: 'PlusJakartaSans',
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: foreground,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: 110),
  );
  final rect = Rect.fromLTWH(
    anchor.dx - text.width / 2 - 6,
    anchor.dy,
    text.width + 12,
    text.height + 6,
  );
  canvas.drawRRect(
    RRect.fromRectAndRadius(rect, const Radius.circular(8)),
    Paint()..color = background.withValues(alpha: 0.94),
  );
  text.paint(canvas, Offset(rect.left + 6, rect.top + 3));
}
