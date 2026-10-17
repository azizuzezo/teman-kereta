import '../../../domain/entities/transit_models.dart';
import 'intercity_models.dart';

/// Which intercity ride an active trip is. Carried in the trip id so the
/// existing trip session (and its saved snapshot) needs no new field: an id
/// that starts with [prefix] is an intercity ride.
class IntercityTripRef {
  const IntercityTripRef({
    required this.serviceId,
    required this.boardingCode,
    required this.destinationCode,
    this.customName,
  });

  static const prefix = 'ic|';

  final String serviceId;
  final String boardingCode;
  final String destinationCode;

  /// The train name the rider typed, for a [customServiceId] ride.
  final String? customName;

  bool get isCustom => serviceId == customServiceId;

  /// `ic|<service>|<from>|<to>|<epoch ms>[|<typed name>]`; the stamp keeps two
  /// rides on the same train apart.
  String toTripId(DateTime at) {
    final base =
        '$prefix$serviceId|$boardingCode|$destinationCode|${at.millisecondsSinceEpoch}';
    final name = customName;
    return name == null ? base : '$base|${Uri.encodeComponent(name)}';
  }

  static IntercityTripRef? tryParse(String tripId) {
    if (!tripId.startsWith(prefix)) return null;
    final parts = tripId.substring(prefix.length).split('|');
    if (parts.length < 3) return null;
    return IntercityTripRef(
      serviceId: parts[0],
      boardingCode: parts[1],
      destinationCode: parts[2],
      customName: parts.length > 4 ? Uri.decodeComponent(parts[4]) : null,
    );
  }
}

bool isIntercityTrip(TransitTrip trip) =>
    trip.id.startsWith(IntercityTripRef.prefix);

/// The intercity station as the app's general [Station], with the code as id,
/// so the trip machinery (progress, notifications, the map marker) works on it
/// unchanged.
Station intercityStationAsStation(IntercityStation station) => Station(
  id: station.code,
  code: station.code,
  name: station.name,
  latitude: station.latitude,
  longitude: station.longitude,
);

/// A ride on [service] from [boarding] to [destination], as an ordinary trip
/// for the existing trip session. Times are the dataset's estimate: there is
/// no official timetable, and the live estimate takes over once moving.
TransitTrip buildIntercityTrip({
  required IntercityService service,
  required IntercityCatalog catalog,
  required String boarding,
  required String destination,
  required DateTime now,
  String? customName,
}) {
  final ride = service.stopsBetween(boarding, destination);
  assert(ride.length >= 2, 'the train must serve both stations');
  final from = catalog.stations[boarding]!;
  final to = catalog.stations[destination]!;
  final minutes =
      (service.stopAt(destination)!.estimatedMinutes -
              service.stopAt(boarding)!.estimatedMinutes)
          .abs();
  final arrival = now.add(Duration(minutes: minutes.round()));
  final ref = IntercityTripRef(
    serviceId: customName == null ? service.id : customServiceId,
    boardingCode: boarding,
    destinationCode: destination,
    customName: customName,
  );
  final id = ref.toTripId(now);
  return TransitTrip(
    id: id,
    originStationId: boarding,
    destinationStationId: destination,
    departureAt: now,
    arrivalAt: arrival,
    legs: <TripLeg>[
      TripLeg(
        id: '$id-rail',
        mode: TransportMode.commuterRail,
        originName: from.name,
        destinationName: to.name,
        departureAt: now,
        arrivalAt: arrival,
        lineName: customName ?? service.name,
        headsign: to.name,
        stationIds: ride.map((s) => s.code).toList(growable: false),
      ),
    ],
    freshness: DataFreshness.estimated,
    sourceLabel: 'Estimasi kereta antar kota • tanpa jadwal resmi',
    updatedAt: now,
  );
}
