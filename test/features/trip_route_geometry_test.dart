import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:teman_kereta/data/providers/rail_line_shapes.dart';
import 'package:teman_kereta/data/providers/station_coordinate_corrections.dart';
import 'package:teman_kereta/features/live_map/presentation/active_trip_route.dart';
import 'package:teman_kereta/features/live_map/presentation/trip_route_geometry.dart';

LatLng _at(String code) {
  final c = stationCoordinateCorrections[code]!;
  return LatLng(c.$1, c.$2);
}

void main() {
  final builder = TripRouteBuilder(railLineShapes);

  test('Matraman sits between Jatinegara and Manggarai on the track', () {
    final viaMatraman =
        pathLength(builder.hop(_at('JNG'), _at('MTR'))) +
        pathLength(builder.hop(_at('MTR'), _at('MRI')));
    final direct = pathLength(builder.hop(_at('JNG'), _at('MRI')));
    // Passing Matraman adds (almost) nothing to the real track length.
    expect(viaMatraman, closeTo(direct, 150));
  });

  test('a hop follows the real track, never a detour round the loop', () {
    // Bekasi–Kranji is on the branch the Cikarang shape runs twice.
    final hop = builder.hop(_at('BKS'), _at('KRI'));
    final straight = const Distance().as(
      LengthUnit.Meter,
      _at('BKS'),
      _at('KRI'),
    );
    expect(hop.length, greaterThan(2));
    expect(pathLength(hop), lessThan(straight * 1.4));
    expect(hop.first, _at('BKS'));
    expect(hop.last, _at('KRI'));
  });

  test('Jatinegara to Pondok Jati takes the Pasar Senen side', () {
    final hop = builder.hop(_at('JNG'), _at('POK'));
    expect(pathLength(hop), lessThan(2500));
  });

  test('points along a path and back', () {
    final hop = builder.hop(_at('JNG'), _at('POK'));
    final middle = pointAlongPath(hop, 0.5);
    expect(fractionNearest(hop, middle.point), closeTo(0.5, 0.02));
    expect(middle.bearing, inInclusiveRange(0, 360));
  });

  test('route splits into ridden and still to go at the train', () {
    final stops = <LatLng>[_at('BKS'), _at('KRI'), _at('CUK')];
    final route = ActiveTripRoute(
      tripId: 't',
      stationIds: const <String>['BKS', 'KRI', 'CUK'],
      stops: stops,
      hops: builder.hops(stops),
    );
    final (ridden, left) = route.splitAt(1, 0.5);
    expect(ridden.first, _at('BKS'));
    expect(left.last, _at('CUK'));
    expect(ridden.last, left.first);
    expect(
      pathLength(ridden) + pathLength(left),
      closeTo(pathLength(route.points), 1),
    );
  });
}
