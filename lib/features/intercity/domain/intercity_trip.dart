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
    this.ka,
    this.serviceDate,
    this.startedAt,
  });

  static const prefix = 'ic|';

  final String serviceId;
  final String boardingCode;
  final String destinationCode;

  /// The train name the rider typed, for a [customServiceId] ride.
  final String? customName;

  /// The KA number of the timetabled run ("131", "42/43"), with the day its
  /// times count from (WIB, UTC midnight). Null for an estimated ride.
  final String? ka;
  final DateTime? serviceDate;

  /// When the ride was started (the stamp in the id), when readable.
  final DateTime? startedAt;

  bool get isCustom => serviceId == customServiceId;

  bool get isScheduled => ka != null && serviceDate != null;

  /// `ic|<service>|<from>|<to>|<epoch ms>[|<typed name>]`; the stamp keeps two
  /// rides on the same train apart. A timetabled ride adds
  /// `|<typed name or empty>|ka=<KA>|d=<yyyymmdd>`, so an id written before
  /// timetables existed still reads the same.
  String toTripId(DateTime at) {
    final base =
        '$prefix$serviceId|$boardingCode|$destinationCode|${at.millisecondsSinceEpoch}';
    final name = customName;
    final number = ka;
    final date = serviceDate;
    if (number != null && date != null) {
      final day =
          '${date.year.toString().padLeft(4, '0')}'
          '${date.month.toString().padLeft(2, '0')}'
          '${date.day.toString().padLeft(2, '0')}';
      return '$base|${name == null ? '' : Uri.encodeComponent(name)}'
          '|ka=${Uri.encodeComponent(number)}|d=$day';
    }
    return name == null ? base : '$base|${Uri.encodeComponent(name)}';
  }

  static IntercityTripRef? tryParse(String tripId) {
    if (!tripId.startsWith(prefix)) return null;
    final parts = tripId.substring(prefix.length).split('|');
    if (parts.length < 3) return null;
    String? ka;
    DateTime? serviceDate;
    for (final part in parts.skip(5)) {
      if (part.startsWith('ka=')) {
        ka = Uri.decodeComponent(part.substring(3));
      } else if (part.startsWith('d=') && part.length == 10) {
        final y = int.tryParse(part.substring(2, 6));
        final m = int.tryParse(part.substring(6, 8));
        final d = int.tryParse(part.substring(8, 10));
        if (y != null && m != null && d != null) {
          serviceDate = DateTime.utc(y, m, d);
        }
      }
    }
    final epoch = parts.length > 3 ? int.tryParse(parts[3]) : null;
    return IntercityTripRef(
      serviceId: parts[0],
      boardingCode: parts[1],
      destinationCode: parts[2],
      customName: parts.length > 4 && parts[4].isNotEmpty
          ? Uri.decodeComponent(parts[4])
          : null,
      ka: ka,
      serviceDate: serviceDate,
      startedAt: epoch == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(epoch),
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
/// for the existing trip session.
///
/// With [departure] (a GAPEKA run the rider picked) the times are that run's
/// timetable on its service day and the trip is marked scheduled. Without it
/// the times are the dataset's estimate starting [now], and the live estimate
/// takes over once moving.
TransitTrip buildIntercityTrip({
  required IntercityService service,
  required IntercityCatalog catalog,
  required String boarding,
  required String destination,
  required DateTime now,
  String? customName,
  IntercityDeparture? departure,
}) {
  final from = catalog.stations[boarding]!;
  final to = catalog.stations[destination]!;
  if (departure != null) {
    assert(departure.service.id == service.id, 'the run must be this train\'s');
    assert(
      departure.boarding.code == boarding &&
          departure.alighting.code == destination,
      'the run must board and alight at the chosen stations',
    );
    final run = departure.run;
    final ref = IntercityTripRef(
      serviceId: service.id,
      boardingCode: boarding,
      destinationCode: destination,
      ka: run.ka,
      serviceDate: departure.serviceDate,
    );
    final id = ref.toTripId(now);
    return TransitTrip(
      id: id,
      originStationId: boarding,
      destinationStationId: destination,
      departureAt: departure.departureAt,
      arrivalAt: departure.arrivalAt,
      legs: <TripLeg>[
        TripLeg(
          id: '$id-rail',
          mode: TransportMode.commuterRail,
          originName: from.name,
          destinationName: to.name,
          departureAt: departure.departureAt,
          arrivalAt: departure.arrivalAt,
          lineName: '${service.name} (KA ${run.ka})',
          headsign: to.name,
          stationIds: departure.stationCodes,
          serviceDate: departure.serviceDate,
          departureEstimated: departure.departureEstimated,
          arrivalEstimated: departure.arrivalEstimated,
          serviceId: run.fakultatif ? fakultatifServiceId : null,
        ),
      ],
      freshness: DataFreshness.scheduled,
      sourceLabel: 'Jadwal GAPEKA 2026',
      updatedAt: now,
    );
  }

  final ride = service.stopsBetween(boarding, destination);
  assert(ride.length >= 2, 'the train must serve both stations');
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
