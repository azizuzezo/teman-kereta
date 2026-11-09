import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../data/providers/rail_line_shapes.dart';
import '../../active_trip/presentation/active_trip_controller.dart';
import '../../active_trip/presentation/active_trip_stations.dart';
import 'trip_route_geometry.dart';

/// The active trip drawn on the real track: one slice of track per hop
/// (station i to station i+1), in the trip's own stop order.
class ActiveTripRoute {
  const ActiveTripRoute({
    required this.tripId,
    required this.stationIds,
    required this.stops,
    required this.hops,
  });

  final String tripId;
  final List<String> stationIds;
  final List<LatLng> stops;
  final List<List<LatLng>> hops;

  /// Every point of the route, start to end.
  List<LatLng> get points => <LatLng>[
    for (var i = 0; i < hops.length; i++)
      ...(i == 0 ? hops[i] : hops[i].skip(1)),
  ];

  /// The route up to [hopIndex] and [fraction] of the way through that hop,
  /// and the rest — for drawing what has been ridden apart from what is left.
  (List<LatLng>, List<LatLng>) splitAt(int hopIndex, double fraction) {
    if (hops.isEmpty) return (const <LatLng>[], const <LatLng>[]);
    final index = hopIndex.clamp(0, hops.length - 1);
    final hop = hops[index];
    final here = pointAlongPath(hop, fraction).point;
    final target = pathLength(hop) * fraction.clamp(0.0, 1.0);
    // First point of the hop that lies beyond the train.
    var cut = hop.length;
    var walked = 0.0;
    for (var i = 1; i < hop.length; i++) {
      walked += pathLength(<LatLng>[hop[i - 1], hop[i]]);
      if (walked > target) {
        cut = i;
        break;
      }
    }
    final ridden = <LatLng>[
      for (var i = 0; i < index; i++) ...(i == 0 ? hops[i] : hops[i].skip(1)),
      ...hop.sublist(index == 0 ? 0 : 1, cut),
      here,
    ];
    final left = <LatLng>[
      here,
      ...hop.sublist(cut),
      for (var i = index + 1; i < hops.length; i++) ...hops[i].skip(1),
    ];
    return (ridden, left);
  }
}

final _tripRouteBuilderProvider = Provider<TripRouteBuilder>(
  (ref) => TripRouteBuilder(railLineShapes),
);

/// The active trip's route on the real track, or null with no active trip
/// (or before its stations have loaded).
final activeTripRouteProvider = Provider<ActiveTripRoute?>((ref) {
  final trip = ref.watch(
    activeTripControllerProvider.select((session) => session?.trip),
  );
  if (trip == null) return null;
  final stations = ref.watch(activeTripStationsProvider).value;
  if (stations == null) return null;
  final byId = {for (final s in stations) s.id: s};
  final ids = trip.stationIds;
  final stops = <LatLng>[];
  for (final id in ids) {
    final station = byId[id];
    if (station == null) return null;
    stops.add(LatLng(station.latitude, station.longitude));
  }
  if (stops.length < 2) return null;
  return ActiveTripRoute(
    tripId: trip.id,
    stationIds: ids,
    stops: stops,
    hops: ref.read(_tripRouteBuilderProvider).hops(stops),
  );
});
