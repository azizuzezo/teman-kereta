import '../../../core/utils/geo.dart';

/// A station on the intercity network. Separate from the KRL station list on
/// purpose: the two modes never share a picker, and an intercity-only station
/// (Cirebon, Purwokerto, ...) must not show up in KRL screens.
class IntercityStation {
  const IntercityStation({
    required this.code,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.region,
    required this.coordinateStatus,
    this.city = '',
    this.province = '',
  });

  factory IntercityStation.fromJson(String code, Map<String, dynamic> json) =>
      IntercityStation(
        code: code,
        name: json['n'] as String,
        latitude: (json['la'] as num).toDouble(),
        longitude: (json['lo'] as num).toDouble(),
        region: json['r'] as String,
        coordinateStatus: json['s'] as String,
        city: (json['c'] as String?) ?? '',
        province: (json['p'] as String?) ?? '',
      );

  final String code;
  final String name;
  final double latitude;
  final double longitude;

  /// `jawa` or `sumatra`.
  final String region;

  /// The city or regency the station is in, and its province ("Purwakarta",
  /// "Jawa Barat"). Empty when it could not be looked up.
  final String city;
  final String province;

  /// "Bandung, Jawa Barat" for a list subtitle; the island when the place is
  /// unknown.
  String get placeLabel {
    if (city.isEmpty) return region == 'sumatra' ? 'Sumatra' : 'Jawa';
    if (province.isEmpty || city == province) return city;
    return '$city, $province';
  }

  /// How the coordinate was checked: `verified` (two independent sources
  /// agree), `single_source_on_track` or `needs_review`.
  final String coordinateStatus;

  double distanceMetersTo(double lat, double lon) =>
      haversineMeters(latitude, longitude, lat, lon);
}

/// One stop of a named train, in origin -> destination order.
class IntercityStop {
  const IntercityStop({
    required this.code,
    required this.km,
    required this.estimatedMinutes,
    required this.dwellMinutes,
    this.qualifier,
  });

  factory IntercityStop.fromJson(Map<String, dynamic> json) => IntercityStop(
    code: json['c'] as String,
    km: (json['km'] as num).toDouble(),
    estimatedMinutes: (json['m'] as num).toDouble(),
    dwellMinutes: (json['d'] as num).toDouble(),
    qualifier: json['q'] as String?,
  );

  final String code;

  /// Distance along the track from the service's origin.
  final double km;

  /// Estimated minutes since departing the origin (no official timetable).
  final double estimatedMinutes;

  /// Estimated standing time at this stop.
  final double dwellMinutes;

  /// Wikipedia's note for the stop, for example "arah Jakarta" or "jadwal
  /// pagi": the train only stops here in some directions or runs.
  final String? qualifier;
}

enum IntercityTier { a, b, c }

/// `IntercityService.id` of a train the rider typed in themselves.
const customServiceId = 'custom';

class GeoPoint {
  const GeoPoint(this.latitude, this.longitude);

  final double latitude;
  final double longitude;
}

/// A named intercity train (Parahyangan, Anggrek, ...): the same route, stops
/// and track whichever coach classes it carries. Two trains with different
/// names are always different services.
class IntercityService {
  const IntercityService({
    required this.id,
    required this.name,
    required this.classes,
    required this.tier,
    required this.fromCode,
    required this.toCode,
    required this.totalKm,
    required this.region,
    required this.stops,
    required this.path,
    this.verified = true,
  });

  factory IntercityService.fromJson(Map<String, dynamic> json) {
    final path = (json['path'] as List<dynamic>)
        .map(
          (p) => GeoPoint(
            ((p as List<dynamic>)[0] as num).toDouble(),
            (p[1] as num).toDouble(),
          ),
        )
        .toList(growable: false);
    return IntercityService(
      id: json['id'] as String,
      name: json['name'] as String,
      classes: (json['classes'] as List<dynamic>).cast<String>(),
      tier: switch (json['tier'] as String) {
        'A' => IntercityTier.a,
        'B' => IntercityTier.b,
        _ => IntercityTier.c,
      },
      fromCode: json['from'] as String,
      toCode: json['to'] as String,
      totalKm: (json['km'] as num).toDouble(),
      region: json['region'] as String,
      stops: (json['stops'] as List<dynamic>)
          .map((s) => IntercityStop.fromJson(s as Map<String, dynamic>))
          .toList(growable: false),
      path: path,
      verified: (json['status'] as String?) == 'ok',
    );
  }

  final String id;
  final String name;
  final List<String> classes;
  final IntercityTier tier;
  final String fromCode;
  final String toCode;
  final double totalKm;
  final String region;
  final List<IntercityStop> stops;

  /// The track, origin -> destination, simplified to about 40 m.
  final List<GeoPoint> path;

  /// False when the route check left a note (a stretch whose track in the map
  /// data looks odd). The train is still usable; the app says so.
  final bool verified;

  int indexOfStop(String code) => stops.indexWhere((s) => s.code == code);

  IntercityStop? stopAt(String code) {
    final i = indexOfStop(code);
    return i < 0 ? null : stops[i];
  }

  /// True when this train serves both stations, in either direction.
  bool connects(String codeA, String codeB) =>
      codeA != codeB && indexOfStop(codeA) >= 0 && indexOfStop(codeB) >= 0;

  /// The stops a rider passes going from [fromCode] to [toCode], both
  /// included, in travel order. Empty when the train does not serve both.
  List<IntercityStop> stopsBetween(String fromCode, String toCode) {
    final a = indexOfStop(fromCode);
    final b = indexOfStop(toCode);
    if (a < 0 || b < 0 || a == b) return const <IntercityStop>[];
    return a < b
        ? stops.sublist(a, b + 1)
        : stops.sublist(b, a + 1).reversed.toList(growable: false);
  }

  /// "Gambir – Bandung" style label from the stop codes.
  String routeLabel(Map<String, IntercityStation> stations) {
    final from = stations[fromCode]?.name ?? fromCode;
    final to = stations[toCode]?.name ?? toCode;
    return '$from – $to';
  }
}

/// Everything the intercity mode needs, loaded from the bundled data file.
class IntercityCatalog {
  const IntercityCatalog({
    required this.stations,
    required this.services,
    required this.cruiseKmh,
    required this.version,
  });

  factory IntercityCatalog.fromJson(Map<String, dynamic> json) {
    final stations = (json['stations'] as Map<String, dynamic>).map(
      (code, value) => MapEntry(
        code,
        IntercityStation.fromJson(code, value as Map<String, dynamic>),
      ),
    );
    final speeds = json['speeds'] as Map<String, dynamic>;
    final cruise = speeds['cruiseKmh'] as Map<String, dynamic>;
    return IntercityCatalog(
      stations: stations,
      services: (json['services'] as List<dynamic>)
          .map((s) => IntercityService.fromJson(s as Map<String, dynamic>))
          .toList(growable: false),
      cruiseKmh: <IntercityTier, double>{
        IntercityTier.a: (cruise['A'] as num).toDouble(),
        IntercityTier.b: (cruise['B'] as num).toDouble(),
        IntercityTier.c: (cruise['C'] as num).toDouble(),
      },
      version: json['version'] as int,
    );
  }

  final Map<String, IntercityStation> stations;
  final List<IntercityService> services;
  final Map<IntercityTier, double> cruiseKmh;
  final int version;

  IntercityService? serviceById(String id) =>
      services.where((s) => s.id == id).firstOrNull;

  /// The track and estimate for a train the rider names themselves (one that
  /// is missing from the list). When a listed train serves both stations its
  /// track and timing are reused, taking the fastest; otherwise the two
  /// stations are joined by a straight line stretched by 1.2 to stand in for
  /// the rails, estimated at a plain 72 km/h. The estimate then follows the
  /// train's real speed like any other.
  IntercityService serviceForCustomRide(String fromCode, String toCode) {
    final known = servicesBetween(fromCode, toCode);
    if (known.isNotEmpty) {
      double minutes(IntercityService s) =>
          (s.stopAt(toCode)!.estimatedMinutes -
                  s.stopAt(fromCode)!.estimatedMinutes)
              .abs();
      return known.reduce((a, b) => minutes(b) < minutes(a) ? b : a);
    }
    final from = stations[fromCode]!;
    final to = stations[toCode]!;
    final km = haversineMeters(
          from.latitude,
          from.longitude,
          to.latitude,
          to.longitude,
        ) *
        1.2 /
        1000;
    final minutes = km / 72 * 60;
    return IntercityService(
      id: customServiceId,
      name: 'Kereta antar kota',
      classes: const <String>[],
      tier: IntercityTier.b,
      fromCode: fromCode,
      toCode: toCode,
      totalKm: km,
      region: from.region,
      stops: <IntercityStop>[
        IntercityStop(code: fromCode, km: 0, estimatedMinutes: 0, dwellMinutes: 0),
        IntercityStop(
          code: toCode,
          km: km,
          estimatedMinutes: minutes,
          dwellMinutes: 0,
        ),
      ],
      path: <GeoPoint>[
        GeoPoint(from.latitude, from.longitude),
        GeoPoint(to.latitude, to.longitude),
      ],
      verified: false,
    );
  }

  /// Trains that serve both stations, by name.
  List<IntercityService> servicesBetween(String codeA, String codeB) =>
      (services.where((s) => s.connects(codeA, codeB)).toList()
        ..sort((a, b) => a.name.compareTo(b.name)));

  /// Stations a rider can alight at when boarding at [fromCode]: every stop
  /// of any train that also stops at [fromCode].
  List<IntercityStation> destinationsFrom(String fromCode) {
    final codes = <String>{};
    for (final service in services) {
      if (service.indexOfStop(fromCode) < 0) continue;
      for (final stop in service.stops) {
        if (stop.code != fromCode) codes.add(stop.code);
      }
    }
    return (codes.map((c) => stations[c]).whereType<IntercityStation>().toList()
      ..sort((a, b) => a.name.compareTo(b.name)));
  }

  List<IntercityStation> get allStations =>
      stations.values.toList()..sort((a, b) => a.name.compareTo(b.name));
}
