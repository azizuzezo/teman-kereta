import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:teman_kereta/data/providers/rail_line_shapes.dart';
import 'package:teman_kereta/data/providers/station_coordinate_corrections.dart';

/// Distance in meters from a point to the closest rail segment, on a local
/// flat approximation (fine at Jabodetabek scale).
double _distanceToTrack(double lat, double lon) {
  const metersPerDegree = 111320.0;
  final cosLat = math.cos(lat * math.pi / 180);
  var best = double.infinity;
  for (final points in railLineShapes.values) {
    for (var i = 0; i < points.length - 1; i += 1) {
      final ax = points[i][1] * metersPerDegree * cosLat;
      final ay = points[i][0] * metersPerDegree;
      final bx = points[i + 1][1] * metersPerDegree * cosLat;
      final by = points[i + 1][0] * metersPerDegree;
      final px = lon * metersPerDegree * cosLat;
      final py = lat * metersPerDegree;
      final dx = bx - ax;
      final dy = by - ay;
      final lengthSquared = dx * dx + dy * dy;
      final t = lengthSquared == 0
          ? 0.0
          : (((px - ax) * dx + (py - ay) * dy) / lengthSquared).clamp(0.0, 1.0);
      final d = math.sqrt(
        math.pow(px - (ax + t * dx), 2) + math.pow(py - (ay + t * dy), 2),
      );
      if (d < best) {
        best = d;
      }
    }
  }
  return best;
}

void main() {
  test('every corrected station sits on the real track geometry', () {
    expect(stationCoordinateCorrections, isNotEmpty);
    for (final entry in stationCoordinateCorrections.entries) {
      final distance = _distanceToTrack(entry.value.$1, entry.value.$2);
      expect(
        distance,
        lessThan(150),
        reason: '${entry.key} is ${distance.round()} m from the track',
      );
    }
  });

  test('Nambo is no longer 2 km away from its own line', () {
    final nambo = stationCoordinateCorrections['NMO']!;
    expect(_distanceToTrack(nambo.$1, nambo.$2), lessThan(100));
  });

  test('unknown station codes keep their stored coordinates', () {
    final result = applyStationCoordinateCorrection('ZZZ', -6.2, 106.8);
    expect(result.latitude, -6.2);
    expect(result.longitude, 106.8);
  });

  test('a known code is replaced by the corrected coordinate', () {
    final result = applyStationCoordinateCorrection('NMO', -6.0, 106.0);
    expect(result.latitude, stationCoordinateCorrections['NMO']!.$1);
    expect(result.longitude, stationCoordinateCorrections['NMO']!.$2);
  });
}
