import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/providers/provider_registry.dart';
import '../../../domain/entities/transit_models.dart';
import '../../intercity/data/intercity_repository.dart';
import '../../intercity/domain/intercity_models.dart';
import '../../intercity/domain/intercity_trip.dart';
import 'active_trip_controller.dart';

/// [base] (the KRL stations) plus every intercity station. Where a code is in
/// both (Gambir), the intercity entry wins: its coordinate was cross-checked
/// against a second source.
///
/// Pure, so the trip controller can use it without reading
/// [activeTripStationsProvider], which depends on the controller itself.
List<Station> mergeIntercityStations(
  List<Station> base,
  IntercityCatalog catalog,
) {
  final intercity = <String, Station>{
    for (final station in catalog.stations.values)
      station.code: intercityStationAsStation(station),
  };
  return <Station>[
    for (final station in base)
      if (!intercity.containsKey(station.id)) station,
    ...intercity.values,
  ];
}

/// The stations the active trip's screens look up.
///
/// A KRL trip gets exactly the KRL station list, as before. An intercity ride
/// also needs the intercity stations (Cirebon, Purwokerto, ... are not KRL
/// stations and must stay out of every KRL list).
final activeTripStationsProvider = FutureProvider<List<Station>>((ref) async {
  final base = await ref.watch(stationListProvider.future);
  final tripId = ref.watch(
    activeTripControllerProvider.select((session) => session?.trip.id),
  );
  if (tripId == null || !tripId.startsWith(IntercityTripRef.prefix)) {
    return base;
  }
  final catalog = await ref.watch(intercityCatalogProvider.future);
  return mergeIntercityStations(base, catalog);
});
