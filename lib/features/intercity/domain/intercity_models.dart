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

  /// Minutes since departing the origin. For a v1 train a speed-based
  /// estimate (no official timetable); for a GAPEKA train the departure time
  /// of one real run (see [IntercityService.runs]), so the prior is real.
  final double estimatedMinutes;

  /// Standing time at this stop (estimated, or from that same run).
  final double dwellMinutes;

  /// A note for the stop: Wikipedia's ("arah Jakarta", "jadwal pagi") for a
  /// v1 train, or "hanya sebagian perjalanan berhenti" for a GAPEKA train
  /// whose runs do not all call here.
  final String? qualifier;
}

/// The UTC offset of GAPEKA times: Jawa and Sumatera Bagian Selatan both
/// keep WIB.
const timetableUtcOffset = Duration(hours: 7);

/// The calendar day (WIB) [instant] falls on, as a UTC midnight so days
/// compare with `==`.
DateTime timetableDate(DateTime instant) {
  final wib = instant.toUtc().add(timetableUtcOffset);
  return DateTime.utc(wib.year, wib.month, wib.day);
}

/// The moment [minutes] after midnight (WIB) of [serviceDate], in local time.
/// [minutes] may pass 1440: a run that crosses midnight keeps counting, so
/// 25:10 is 01:10 on the next day.
DateTime timetableInstant(DateTime serviceDate, int minutes) => DateTime.utc(
  serviceDate.year,
  serviceDate.month,
  serviceDate.day,
).add(Duration(minutes: minutes) - timetableUtcOffset).toLocal();

/// `2026-12-01` as a UTC midnight; null when absent or unreadable.
DateTime? _parseDate(Object? value) {
  if (value is! String) return null;
  final parsed = DateTime.tryParse(value);
  return parsed == null
      ? null
      : DateTime.utc(parsed.year, parsed.month, parsed.day);
}

/// One stop of a timetabled run. Times are minutes after midnight (WIB) of
/// the run's service day, and pass 1440 after midnight.
class IntercityRunStop {
  const IntercityRunStop({
    required this.code,
    required this.arrival,
    required this.departure,
    this.estimated = false,
  });

  factory IntercityRunStop.fromJson(Map<String, dynamic> json) =>
      IntercityRunStop(
        code: json['c'] as String,
        arrival: (json['arr'] as num).toInt(),
        departure: (json['dep'] as num).toInt(),
        estimated: (json['est'] as bool?) ?? false,
      );

  final String code;
  final int arrival;
  final int departure;

  /// GAPEKA prints no time here (the train stops, "Berh"/"Sb"): the time was
  /// interpolated along the track. Shown with a "~".
  final bool estimated;
}

/// One run of a GAPEKA train: a KA number (or a through journey under
/// several numbers, "42/43") with its own stops and times. It runs daily from
/// [IntercityCatalog.validFrom]; GAPEKA prints no weekday pattern.
class IntercityRun {
  const IntercityRun({
    required this.ka,
    required this.stops,
    this.fakultatif = false,
  });

  factory IntercityRun.fromJson(Map<String, dynamic> json) => IntercityRun(
    ka: json['ka'] as String,
    fakultatif: (json['fakultatif'] as bool?) ?? false,
    stops: (json['stops'] as List<dynamic>)
        .map((s) => IntercityRunStop.fromJson(s as Map<String, dynamic>))
        .toList(growable: false),
  );

  /// The KA number, e.g. "131", or "42/43" for a through journey.
  final String ka;

  /// A KA fakultatif: only run when needed, so it may not run on a day.
  final bool fakultatif;

  /// In the order the train calls, which may be the reverse of its service's
  /// [IntercityService.stops].
  final List<IntercityRunStop> stops;

  int indexOfStop(String code) => stops.indexWhere((s) => s.code == code);

  /// True when this run calls at [fromCode] and later at [toCode].
  bool servesInOrder(String fromCode, String toCode) {
    final a = indexOfStop(fromCode);
    final b = indexOfStop(toCode);
    return a >= 0 && b > a;
  }
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
/// names are always different services. A GAPEKA train (id `g26-...`) is one
/// name between one pair of end stations; the same name on other ends or
/// another line is a further service (`g26-kaligung-smc-tg`, ...). Its
/// [stops] are every stop any of its [runs] calls at.
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
    this.approximateTrack = false,
    this.runs = const <IntercityRun>[],
    this.listedUntil,
    this.timingRunKa,
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
      approximateTrack: (json['status'] as String?) == 'approx',
      runs: ((json['runs'] as List<dynamic>?) ?? const <dynamic>[])
          .map((r) => IntercityRun.fromJson(r as Map<String, dynamic>))
          .toList(growable: false),
      listedUntil: _parseDate(json['until']),
      timingRunKa: json['mFrom'] as String?,
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
  /// data looks odd), or the track is only approximate. The train is still
  /// usable; the app says so.
  final bool verified;

  /// No map track was found for this route: [path] joins the stations with
  /// straight lines and the km are that line stretched by 1.2.
  final bool approximateTrack;

  /// The GAPEKA 2026 runs of this train; empty for a v1 train (estimates
  /// only).
  final List<IntercityRun> runs;

  /// The last day (WIB, UTC midnight) this train is offered: a v1 train that
  /// GAPEKA 2026 replaces. Null when it has no end.
  final DateTime? listedUntil;

  /// The KA number of the run [IntercityStop.estimatedMinutes] were taken
  /// from (a GAPEKA train), or after [forRun] the run itself. Null for a v1
  /// train, whose minutes are estimates.
  final String? timingRunKa;

  bool get hasTimetable => runs.isNotEmpty;

  IntercityRun? runByKa(String ka) => runs.where((r) => r.ka == ka).firstOrNull;

  /// This train as [run] drives it: only the stops the run calls at, with
  /// [IntercityStop.estimatedMinutes] / [IntercityStop.dwellMinutes] taken from
  /// the run's own times, so the live estimate starts from the timetable.
  /// Track, km and id stay the same.
  IntercityService forRun(IntercityRun run) {
    final times = <String, IntercityRunStop>{
      for (final s in run.stops) s.code: s,
    };
    final kept = stops.where((s) => times.containsKey(s.code)).toList();
    if (kept.length < 2 || run.stops.length < 2) return this;
    final forward = kept.first.code == run.stops.first.code;
    final runFirst = run.stops.first;
    final runLast = run.stops.last;
    final view = <IntercityStop>[];
    for (final stop in kept) {
      final t = times[stop.code]!;
      final isRunFirst = stop.code == runFirst.code;
      final isRunLast = stop.code == runLast.code;
      // Minutes in service order, rising along the track either way: since
      // the run's departure going forward, until its arrival at the end going
      // backward.
      final minutes = forward
          ? (isRunLast ? t.arrival : t.departure) - runFirst.departure
          : runLast.arrival - (isRunLast ? t.arrival : t.departure);
      view.add(
        IntercityStop(
          code: stop.code,
          km: stop.km,
          estimatedMinutes: minutes.toDouble(),
          dwellMinutes: isRunFirst || isRunLast
              ? 0
              : (t.departure - t.arrival).toDouble(),
          qualifier: stop.qualifier,
        ),
      );
    }
    return IntercityService(
      id: id,
      name: name,
      classes: classes,
      tier: tier,
      fromCode: fromCode,
      toCode: toCode,
      totalKm: totalKm,
      region: region,
      stops: view,
      path: path,
      verified: verified,
      approximateTrack: approximateTrack,
      runs: runs,
      listedUntil: listedUntil,
      timingRunKa: run.ka,
    );
  }

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
    this.validFrom,
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
      validFrom: _parseDate(json['validFrom']),
    );
  }

  final Map<String, IntercityStation> stations;
  final List<IntercityService> services;
  final Map<IntercityTier, double> cruiseKmh;
  final int version;

  /// First day (WIB, UTC midnight) of the GAPEKA timetable in the file (v2:
  /// 2026-12-01). Null for a v1 file, which has no timetable.
  final DateTime? validFrom;

  bool _listedOn(IntercityService service, DateTime day) {
    final until = service.listedUntil;
    if (until != null && day.isAfter(until)) return false;
    if (!service.hasTimetable) return true;
    final from = validFrom;
    return from == null || !day.isBefore(from);
  }

  /// The catalog as offered on [day] (a WIB date, see [timetableDate]): before
  /// [validFrom] the v1 trains (estimates); from then on the GAPEKA trains,
  /// plus any v1 train GAPEKA does not cover (Medan). Stations are unchanged.
  IntercityCatalog onDate(DateTime day) {
    final date = DateTime.utc(day.year, day.month, day.day);
    return IntercityCatalog(
      stations: stations,
      services: services
          .where((s) => _listedOn(s, date))
          .toList(growable: false),
      cruiseKmh: cruiseKmh,
      version: version,
      validFrom: validFrom,
    );
  }

  /// The timetabled departures from [fromCode] to [toCode] a rider can take
  /// at [now]: every run that leaves [fromCode] on today's date (WIB), plus a
  /// run that left on an earlier day and has not reached [toCode] yet (a
  /// night train boarded before midnight). Sorted by departure. Empty before
  /// [validFrom] or for a file without a timetable.
  List<IntercityDeparture> departuresBetween(
    String fromCode,
    String toCode, {
    required DateTime now,
  }) {
    final from = validFrom;
    if (from == null || fromCode == toCode) return const <IntercityDeparture>[];
    final today = timetableDate(now);
    final found = <IntercityDeparture>[];
    // A run's times pass 1440 after midnight, so yesterday's service day can
    // still depart today.
    for (final serviceDate in <DateTime>[
      today.subtract(const Duration(days: 1)),
      today,
    ]) {
      if (serviceDate.isBefore(from)) continue;
      for (final service in services) {
        if (!service.hasTimetable || !_listedOn(service, serviceDate)) continue;
        for (final run in service.runs) {
          final i = run.indexOfStop(fromCode);
          final j = run.indexOfStop(toCode);
          if (i < 0 || j <= i) continue;
          final departure = IntercityDeparture(
            service: service,
            run: run,
            serviceDate: serviceDate,
            boardingIndex: i,
            alightingIndex: j,
          );
          final departsToday = timetableDate(departure.departureAt) == today;
          final stillRiding =
              departure.departureAt.isBefore(now) &&
              departure.arrivalAt.isAfter(now);
          if (departsToday || stillRiding) found.add(departure);
        }
      }
    }
    found.sort((a, b) {
      final byTime = a.departureAt.compareTo(b.departureAt);
      return byTime != 0 ? byTime : a.service.name.compareTo(b.service.name);
    });
    return found;
  }

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

/// One timetabled departure: [run] of [service] on [serviceDate], boarding at
/// stop [boardingIndex] of the run and alighting at [alightingIndex].
class IntercityDeparture {
  const IntercityDeparture({
    required this.service,
    required this.run,
    required this.serviceDate,
    required this.boardingIndex,
    required this.alightingIndex,
  });

  final IntercityService service;
  final IntercityRun run;

  /// The day (WIB, UTC midnight) the run's minutes count from.
  final DateTime serviceDate;
  final int boardingIndex;
  final int alightingIndex;

  IntercityRunStop get boarding => run.stops[boardingIndex];
  IntercityRunStop get alighting => run.stops[alightingIndex];

  DateTime get departureAt =>
      timetableInstant(serviceDate, boarding.departure);
  DateTime get arrivalAt => timetableInstant(serviceDate, alighting.arrival);

  bool get departureEstimated => boarding.estimated;
  bool get arrivalEstimated => alighting.estimated;

  /// The run's stops from boarding to alighting, both included.
  List<String> get stationCodes => run.stops
      .sublist(boardingIndex, alightingIndex + 1)
      .map((s) => s.code)
      .toList(growable: false);

  /// Identifies the choice in a list: service, KA number and day.
  String get key =>
      '${service.id}|${run.ka}|${serviceDate.toIso8601String().substring(0, 10)}';
}
