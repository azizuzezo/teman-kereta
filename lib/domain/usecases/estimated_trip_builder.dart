import '../entities/transit_models.dart';
import 'line_transfer_router.dart';
import 'transfer_platform_guidance.dart';

/// Average minutes a KRL takes from one station to the next, stop included.
/// Measured from the bundled KCI timetable (Bekasi → Kemayoran via Pasar
/// Senen: 11 stops in 38 minutes).
const double minutesPerStop = 3.5;

/// Minutes allowed for a change of train (walk to the other platform and wait
/// for the next one).
const int transferMinutes = 8;

/// Departure offsets (minutes after the requested time) for the estimated
/// trips of the route at [optionIndex]. Each way round gets its own times so
/// two routes never look like the same train.
List<int> estimatedDepartureOffsets(int optionIndex) =>
    optionIndex == 0 ? const <int>[6, 18, 33] : const <int>[10, 25, 40];

/// Estimated trips for one real route, used when the timetable has nothing
/// for the pair. Every station is real (from [option]); only the times are
/// estimated, from the number of stops and changes, and the trips say so
/// (`DataFreshness.estimated`).
List<TransitTrip> buildEstimatedTrips({
  required RouteOption option,
  required int optionIndex,
  required TripSearchQuery query,
  required String originName,
  required String destinationName,
  bool labelRouteVia = false,
  List<Station> allStations = const <Station>[],
  DateTime? now,
}) {
  final legStations = option.legs;
  final via = labelRouteVia ? option.viaName : null;
  return <TransitTrip>[
    for (final (index, offset) in estimatedDepartureOffsets(
      optionIndex,
    ).indexed)
      _trip(
        legStations: legStations,
        departure: query.departureAt.add(Duration(minutes: offset)),
        id:
            'krl-trip-${query.originStationId}-${query.destinationStationId}'
            '${optionIndex == 0 ? '' : '-r$optionIndex'}-$index',
        query: query,
        originName: originName,
        destinationName: destinationName,
        via: via,
        allStations: allStations,
        now: now ?? DateTime.now(),
      ),
  ];
}

/// The same trip as [trip] but going the other way round, via [viaName]
/// (Cikarang loop), leaving at the same time. Null when there is no such
/// route. Used when the rider says, or GPS shows, that their train goes the
/// other way.
TransitTrip? alternativeEstimatedTrip({
  required TransitTrip trip,
  required List<Station> allStations,
  required String viaName,
  DateTime? now,
}) {
  final option = routeOptionsBetweenStations(
    allStations,
    trip.originStationId,
    trip.destinationStationId,
  ).where((o) => o.viaName == viaName).firstOrNull;
  if (option == null) return null;
  String nameOf(String id) =>
      allStations.where((s) => s.id == id).firstOrNull?.name ?? id;
  final baseId = trip.id.split('~').first;
  return _trip(
    legStations: option.legs,
    departure: trip.departureAt,
    id: '$baseId~$viaName',
    query: TripSearchQuery(
      originStationId: trip.originStationId,
      destinationStationId: trip.destinationStationId,
      departureAt: trip.departureAt,
    ),
    originName: nameOf(trip.originStationId),
    destinationName: nameOf(trip.destinationStationId),
    via: viaName,
    allStations: allStations,
    now: now ?? DateTime.now(),
  );
}

/// The other way(s) round for [trip]'s station pair: via names other than
/// the trip's own.
List<String> otherRouteVias(TransitTrip trip, List<Station> allStations) {
  if (trip.routeVia == null) return const <String>[];
  return <String>[
    for (final o in routeOptionsBetweenStations(
      allStations,
      trip.originStationId,
      trip.destinationStationId,
    ))
      if (o.viaName != null && o.viaName != trip.routeVia) o.viaName!,
  ];
}

TransitTrip _trip({
  required List<List<Station>> legStations,
  required DateTime departure,
  required String id,
  required TripSearchQuery query,
  required String originName,
  required String destinationName,
  required String? via,
  required DateTime now,
  List<Station> allStations = const <Station>[],
}) {
  final legs = <TripLeg>[];
  var legStart = departure;
  for (var legIndex = 0; legIndex < legStations.length; legIndex++) {
    final stations = legStations[legIndex];
    final isLastLeg = legIndex == legStations.length - 1;
    final rideMinutes = ((stations.length - 1) * minutesPerStop).round().clamp(
      3,
      600,
    );
    final legEnd = legStart.add(Duration(minutes: rideMinutes));
    final legOriginName = legIndex == 0 ? originName : stations.first.name;
    final legDestinationName = isLastLeg ? destinationName : stations.last.name;
    final service = allStations.isEmpty
        ? null
        : legService(allStations, stations);
    String? transferInstruction;
    if (!isLastLeg) {
      final nextStations = legStations[legIndex + 1];
      final nextName = nextStations.length >= 2 ? nextStations[1].name : null;
      // The real station immediately before this transfer on the CURRENT leg
      // — not the trip's origin — since most riders board well before the
      // transfer station (see transferPlatformInstruction).
      final approachingFromName = stations[stations.length - 2].name;
      transferInstruction =
          transferPlatformInstruction(
            approachingFromName: approachingFromName,
            transferName: legDestinationName,
            nextName: nextName,
          ) ??
          'Transit di $legDestinationName.';
    }
    legs.add(
      TripLeg(
        id: '$id-leg$legIndex',
        mode: TransportMode.commuterRail,
        originName: legOriginName,
        destinationName: legDestinationName,
        departureAt: legStart,
        arrivalAt: legEnd,
        lineName: service == null
            ? 'Commuter Line'
            : commuterLineName(service.lineCode),
        headsign: service?.headsign ?? legDestinationName,
        relation: service?.relation,
        stationIds: stations.map((s) => s.id).toList(growable: false),
        transferInstruction: transferInstruction,
      ),
    );
    legStart = legEnd.add(const Duration(minutes: transferMinutes));
  }
  return TransitTrip(
    id: id,
    originStationId: query.originStationId,
    destinationStationId: query.destinationStationId,
    departureAt: departure,
    arrivalAt: legs.last.arrivalAt,
    legs: legs,
    transfers: legs.length - 1,
    // No walking distance or fare is invented here: fare is computed from
    // track geometry at display time (`krl_fare.dart`), walking stays 0 until
    // there is a real source for it.
    freshness: DataFreshness.estimated,
    sourceLabel: 'Jadwal Operasional KRL • Terjadwal',
    updatedAt: now,
    routeVia: via,
  );
}
