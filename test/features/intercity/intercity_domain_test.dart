import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:teman_kereta/core/utils/geo.dart';
import 'package:teman_kereta/domain/entities/transit_models.dart';
import 'package:teman_kereta/features/intercity/domain/intercity_eta.dart';
import 'package:teman_kereta/features/intercity/domain/intercity_geometry.dart';
import 'package:teman_kereta/features/intercity/domain/intercity_models.dart';
import 'package:teman_kereta/features/intercity/domain/intercity_reminder_planner.dart';
import 'package:teman_kereta/features/intercity/domain/intercity_trip.dart';

IntercityCatalog _loadCatalog([String file = 'intercity_v2.json']) {
  final raw = File('assets/intercity/$file').readAsStringSync();
  return IntercityCatalog.fromJson(jsonDecode(raw) as Map<String, dynamic>);
}

/// A day before and a day on the GAPEKA 2026 timetable (WIB dates).
final _before = DateTime.utc(2026, 11, 30);
final _dec2 = DateTime.utc(2026, 12, 2);
final _dec3 = DateTime.utc(2026, 12, 3);

/// Minimum distance from [lat],[lon] to the service's track, in meters.
double _distanceToTrack(IntercityService service, double lat, double lon) =>
    TrackIndex(service).project(lat, lon).offsetMeters;

/// Fixes every [stepSeconds] while a train covers [from]..[to] km at a
/// steady [kmh], placed on the track by interpolating the service's path.
Iterable<({double lat, double lon, DateTime at, double kmh})> _ride(
  IntercityService service, {
  required double fromKm,
  required double toKm,
  required double kmh,
  int stepSeconds = 4,
  DateTime? start,
}) sync* {
  final index = TrackIndex(service);
  final scale = (service.totalKm * 1000) / index.lengthMeters;
  // Cumulative polyline meters.
  final cumulative = <double>[0];
  for (var i = 1; i < service.path.length; i += 1) {
    cumulative.add(
      cumulative.last +
          haversineMeters(
            service.path[i - 1].latitude,
            service.path[i - 1].longitude,
            service.path[i].latitude,
            service.path[i].longitude,
          ),
    );
  }
  GeoPoint at(double km) {
    final target = km * 1000 / scale;
    var i = 1;
    while (i < cumulative.length - 1 && cumulative[i] < target) {
      i += 1;
    }
    final span = cumulative[i] - cumulative[i - 1];
    final t = span == 0 ? 0.0 : (target - cumulative[i - 1]) / span;
    final a = service.path[i - 1];
    final b = service.path[i];
    return GeoPoint(
      a.latitude + (b.latitude - a.latitude) * t,
      a.longitude + (b.longitude - a.longitude) * t,
    );
  }

  var clock = start ?? DateTime(2026, 10, 18, 8);
  final direction = toKm >= fromKm ? 1 : -1;
  var km = fromKm;
  final stepKm = kmh * stepSeconds / 3600;
  while ((toKm - km) * direction > 0) {
    final p = at(km);
    yield (lat: p.latitude, lon: p.longitude, at: clock, kmh: kmh);
    km += stepKm * direction;
    clock = clock.add(Duration(seconds: stepSeconds));
  }
}

void main() {
  final catalog = _loadCatalog();

  group('the bundled intercity data', () {
    test('has the trains and stations it promises', () {
      expect(catalog.services.length, greaterThanOrEqualTo(60));
      expect(catalog.stations.length, greaterThanOrEqualTo(150));
    });

    test('only the two Medan trains and the GAPEKA trains without a mapped '
        'track are flagged', () {
      final flagged = catalog.services
          .where((s) => !s.verified)
          .map((s) => s.id)
          .toSet();
      final straightLine = catalog.services
          .where((s) => s.approximateTrack)
          .map((s) => s.id)
          .toSet();
      expect(flagged, <String>{'sribilah', 'putri-deli', ...straightLine});
      // Only GAPEKA trains can lack a track; each one is said to be approximate.
      expect(straightLine.every((id) => id.startsWith('g26-')), isTrue);
    });

    test('every train is a different one: unique id, and a unique name on any '
        'day before the timetable', () {
      expect(catalog.services.map((s) => s.id).toSet().length,
          catalog.services.length);
      final before = catalog.onDate(_before).services;
      expect(before.map((s) => s.name).toSet().length, before.length);
      // From the timetable on, one name can cover several routes (Kaligung
      // Semarang - Tegal and Semarang - Cirebon Prujakan): unique by route.
      final after = catalog.onDate(_dec2).services;
      expect(
        after.map((s) => '${s.name}|${s.fromCode}|${s.toCode}').toSet().length,
        after.length,
      );
    });

    test('every stop is a known station, in increasing distance and time', () {
      for (final service in catalog.services) {
        expect(service.stops.length, greaterThanOrEqualTo(2),
            reason: service.name);
        expect(service.stops.first.km, 0, reason: service.name);
        expect(service.stops.last.km, closeTo(service.totalKm, 0.6),
            reason: service.name);
        for (var i = 0; i < service.stops.length; i += 1) {
          final stop = service.stops[i];
          expect(catalog.stations.containsKey(stop.code), isTrue,
              reason: '${service.name}: ${stop.code}');
          if (i > 0) {
            final previous = service.stops[i - 1];
            expect(stop.km, greaterThan(previous.km),
                reason: '${service.name} ${previous.code}->${stop.code}');
            expect(stop.estimatedMinutes,
                greaterThanOrEqualTo(previous.estimatedMinutes),
                reason: service.name);
          }
        }
      }
    });

    test('every stop lies on its train\'s track', () {
      for (final service in catalog.services) {
        for (final stop in service.stops) {
          final station = catalog.stations[stop.code]!;
          final off = _distanceToTrack(
            service,
            station.latitude,
            station.longitude,
          );
          expect(off, lessThan(450),
              reason: '${service.name}: ${station.name} is $off m off the track');
        }
      }
    });

    test('the track and the stop distances agree', () {
      for (final service in catalog.services.where((s) => s.verified)) {
        final index = TrackIndex(service);
        for (final stop in service.stops) {
          final station = catalog.stations[stop.code]!;
          final projected = index.project(
            station.latitude,
            station.longitude,
            hintKm: stop.km,
          );
          expect(projected.alongKm, closeTo(stop.km, 4),
              reason: '${service.name}: ${station.name}');
        }
      }
    });

    test('Parahyangan runs Gambir to Bandung through Cikampek-less Purwakarta '
        'and Padalarang, never through Bogor or Sukabumi', () {
      final parahyangan = catalog.serviceById('parahyangan')!;
      expect(parahyangan.fromCode, 'GMR');
      expect(parahyangan.toCode, 'BD');
      expect(parahyangan.totalKm, inInclusiveRange(160, 175));
      // The track passes the stations it skips, and only the right ones.
      for (final code in <String>['CKP', 'PDL']) {
        final s = catalog.stations[code]!;
        expect(_distanceToTrack(parahyangan, s.latitude, s.longitude),
            lessThan(300), reason: '${s.name} must be on the way');
      }
      for (final name in <String>['Bogor', 'Sukabumi', 'Cianjur']) {
        final s = catalog.stations.values
            .where((x) => x.name == name)
            .firstOrNull;
        if (s == null) continue;
        expect(_distanceToTrack(parahyangan, s.latitude, s.longitude),
            greaterThan(3000), reason: '$name is not on this route');
      }
    });

    test('the north-coast and the southern trains take different tracks', () {
      final north = catalog.serviceById('gumarang')!; // via Semarang
      final south = catalog.serviceById('taksaka')!; // via Purwokerto
      final semarang = catalog.stations['SMT']!;
      final purwokerto = catalog.stations['PWT']!;
      expect(_distanceToTrack(north, semarang.latitude, semarang.longitude),
          lessThan(300));
      expect(_distanceToTrack(north, purwokerto.latitude, purwokerto.longitude),
          greaterThan(20000));
      expect(_distanceToTrack(south, purwokerto.latitude, purwokerto.longitude),
          lessThan(300));
      expect(_distanceToTrack(south, semarang.latitude, semarang.longitude),
          greaterThan(20000));
    });

    test('finding trains between two stations works in both directions', () {
      final forward = catalog.servicesBetween('GMR', 'BD');
      final reverse = catalog.servicesBetween('BD', 'GMR');
      expect(forward.map((s) => s.id), contains('parahyangan'));
      expect(reverse.map((s) => s.id), contains('parahyangan'));
      final stops = catalog
          .serviceById('parahyangan')!
          .stopsBetween('BD', 'GMR')
          .map((s) => s.code)
          .toList();
      expect(stops.first, 'BD');
      expect(stops.last, 'GMR');
    });

    test('Gambir to Kiaracondong is served, in the right order', () {
      final trains = catalog.servicesBetween('GMR', 'KAC');
      expect(trains.map((s) => s.id), containsAll(<String>['papandayan', 'pangandaran']));
      final stops = catalog
          .serviceById('papandayan')!
          .stopsBetween('GMR', 'KAC')
          .map((s) => s.code)
          .toList();
      expect(stops, <String>['GMR', 'JNG', 'BKS', 'KW', 'PWK', 'PDL', 'CMI', 'BD', 'KAC']);
      expect(catalog.destinationsFrom('GMR').map((s) => s.code), contains('KAC'));
      expect(catalog.destinationsFrom('KAC').map((s) => s.code), contains('GMR'));
    });

    test('a Jakarta station cannot reach a Jogja-only KRL stop by accident', () {
      // The intercity catalog is its own list: KRL-only stations such as
      // Klender are not offered as destinations for any train from Gambir.
      final codes = catalog.destinationsFrom('GMR').map((s) => s.code).toSet();
      expect(codes, isNot(contains('KLD')));
      expect(codes, contains('BD'));
    });
  });

  group('IntercityEtaEstimator', () {
    final service = catalog.serviceById('parahyangan')!;
    IntercityEtaEstimator estimator() => IntercityEtaEstimator(
      service: service,
      boardingCode: 'GMR',
      destinationCode: 'BD',
      destinationLatitude: catalog.stations['BD']!.latitude,
      destinationLongitude: catalog.stations['BD']!.longitude,
    );

    test('before moving, the estimate is the dataset estimate', () {
      final e = estimator();
      final first = _ride(service, fromKm: 0, toKm: 5, kmh: 60).first;
      final eta = e.update(latitude: first.lat, longitude: first.lon, at: first.at);
      expect(eta.onTrack, isTrue);
      expect(eta.remainingKm, closeTo(service.totalKm, 1.5));
      expect(eta.eta.inMinutes, closeTo(service.stops.last.estimatedMinutes, 12));
    });

    test('the estimate counts down and converges on the real arrival', () {
      // Gambir -> Cimahi: no stop in the last 15 km, so a train that keeps
      // its speed (as simulated) arrives exactly when the estimate says.
      final e = IntercityEtaEstimator(
        service: service,
        boardingCode: 'GMR',
        destinationCode: 'CMI',
        destinationLatitude: catalog.stations['CMI']!.latitude,
        destinationLongitude: catalog.stations['CMI']!.longitude,
      );
      final destinationKm = service.stopAt('CMI')!.km;
      const kmh = 90.0; // faster than the prior: the estimate must learn it
      final fixes = _ride(service, fromKm: 0, toKm: destinationKm - 0.2, kmh: kmh)
          .toList();
      final first = fixes.first.at;
      final end = fixes.last.at.add(const Duration(seconds: 8));
      var previous = double.infinity;
      Duration? lastEta;
      for (final f in fixes) {
        final eta = e.update(
          latitude: f.lat,
          longitude: f.lon,
          at: f.at,
          speedKmh: f.kmh,
        );
        lastEta = eta.eta;
        // Never grows by more than a couple of minutes between fixes.
        expect(eta.eta.inSeconds, lessThan(previous + 120));
        previous = eta.eta.inSeconds.toDouble();
        // Ten minutes before the real arrival the estimate is within 3 min.
        final realLeft = end.difference(f.at);
        if (realLeft.inMinutes == 10 && f.at.difference(first).inMinutes > 40) {
          expect((eta.eta - realLeft).inSeconds.abs(), lessThan(180));
        }
      }
      expect(lastEta!.inSeconds, lessThan(90));
    });

    test('a train that stops at a station does not push the estimate away', () {
      final e = estimator();
      final fixes = _ride(service, fromKm: 20, toKm: 40, kmh: 80).toList();
      Duration? moving;
      for (final f in fixes) {
        moving = e
            .update(latitude: f.lat, longitude: f.lon, at: f.at, speedKmh: f.kmh)
            .eta;
      }
      final last = fixes.last;
      final stopped = e
          .update(
            latitude: last.lat,
            longitude: last.lon,
            at: last.at.add(const Duration(minutes: 3)),
            speedKmh: 0,
          )
          .eta;
      expect(stopped.inMinutes, lessThan(moving!.inMinutes + 4));
    });

    test('a fix far from the track falls back to the straight line', () {
      final e = estimator();
      final eta = e.update(
        latitude: -6.0,
        longitude: 107.0,
        at: DateTime(2026, 10, 18, 8),
      );
      expect(eta.onTrack, isFalse);
      expect(eta.eta, greaterThan(Duration.zero));
    });

    test('works for a train running the other way', () {
      final e = IntercityEtaEstimator(
        service: service,
        boardingCode: 'BD',
        destinationCode: 'GMR',
        destinationLatitude: catalog.stations['GMR']!.latitude,
        destinationLongitude: catalog.stations['GMR']!.longitude,
      );
      final fixes = _ride(
        service,
        fromKm: service.totalKm,
        toKm: 100,
        kmh: 80,
      ).toList();
      IntercityEta? eta;
      for (final f in fixes) {
        eta = e.update(latitude: f.lat, longitude: f.lon, at: f.at, speedKmh: f.kmh);
      }
      expect(eta!.remainingKm, closeTo(100, 4));
    });
  });

  group('GAPEKA 2026 timetable (v2)', () {
    test('the file says which version and from which day', () {
      expect(catalog.version, 2);
      expect(catalog.validFrom, DateTime.utc(2026, 12, 1));
    });

    test('a v1 file still reads, with no timetable', () {
      final v1 = _loadCatalog('intercity_v1.json');
      expect(v1.version, 1);
      expect(v1.validFrom, isNull);
      expect(v1.services.every((s) => s.runs.isEmpty), isTrue);
      expect(v1.onDate(_dec2).services.length, v1.services.length);
      expect(
        v1.departuresBetween(
          'BD',
          'GMR',
          now: timetableInstant(_dec2, 4 * 60),
        ),
        isEmpty,
      );
    });

    test('runs carry the KA number, the fakultatif flag and the printed times',
        () {
      final pandalungan = catalog.serviceById('g26-pandalungan')!;
      // KA 42 and 43 are one journey in Buku Penomoran: one run.
      final run = pandalungan.runByKa('42/43')!;
      expect(run.fakultatif, isFalse);
      expect(run.stops.first.code, 'GMR');
      expect(run.stops.first.departure, 21 * 60); // 21:00
      expect(run.stops.last.code, 'JR');
      expect(run.stops.last.arrival, 34 * 60 + 4); // 10:04 the next day
      final fakultatif = catalog.serviceById('g26-parahyangan-fakultatif')!;
      expect(fakultatif.runs.map((r) => r.ka), containsAll(<String>['141F', '142F']));
      expect(fakultatif.runs.every((r) => r.fakultatif), isTrue);
      // A stop with no printed time is marked, never silent.
      final pangrango = catalog.serviceById('g26-pangrango')!.runByKa('265')!;
      final karangtengah = pangrango.stops[pangrango.indexOfStop('KE')];
      expect(karangtengah.estimated, isTrue);
    });

    test('every run is a known station list, in time order, inside its train',
        () {
      for (final service in catalog.services.where((s) => s.hasTimetable)) {
        final codes = service.stops.map((s) => s.code).toList();
        for (final run in service.runs) {
          var last = -1;
          var previous = -1;
          for (final stop in run.stops) {
            expect(catalog.stations.containsKey(stop.code), isTrue);
            expect(stop.arrival, greaterThanOrEqualTo(last),
                reason: '${service.id} KA ${run.ka} ${stop.code}');
            expect(stop.departure, greaterThanOrEqualTo(stop.arrival));
            last = stop.departure;
            // The run's stops are the service's stops, one way or the other.
            final i = codes.indexOf(stop.code);
            expect(i, isNot(-1), reason: '${service.id} ${stop.code}');
            if (previous >= 0) {
              final forward = codes.indexOf(run.stops.first.code) <
                  codes.indexOf(run.stops.last.code);
              expect(forward ? i > previous : i < previous, isTrue,
                  reason: '${service.id} KA ${run.ka} ${stop.code}');
            }
            previous = i;
          }
        }
      }
    });

    test('before the timetable the estimates are offered, from its first day '
        'the GAPEKA trains', () {
      final before = catalog.onDate(_before).services.map((s) => s.id).toSet();
      final after = catalog
          .onDate(DateTime.utc(2026, 12, 1))
          .services
          .map((s) => s.id)
          .toSet();
      expect(before, contains('parahyangan'));
      expect(before, isNot(contains('g26-parahyangan')));
      expect(after, contains('g26-parahyangan'));
      expect(after, isNot(contains('parahyangan')));
      // Medan is not in these GAPEKA books: its estimates stay.
      expect(before, contains('sribilah'));
      expect(after, contains('sribilah'));
    });

    test('no departures are listed before the timetable starts', () {
      expect(
        catalog.departuresBetween(
          'BD',
          'GMR',
          now: timetableInstant(_before, 10 * 60),
        ),
        isEmpty,
      );
    });

    test('lists the day\'s departures between two stations, in order', () {
      final departures = catalog.departuresBetween(
        'BD',
        'GMR',
        now: timetableInstant(_dec2, 4 * 60),
      );
      expect(departures, isNotEmpty);
      for (var i = 1; i < departures.length; i += 1) {
        expect(
          departures[i].departureAt.isBefore(departures[i - 1].departureAt),
          isFalse,
        );
      }
      final ka131 = departures.firstWhere((d) => d.run.ka == '131');
      expect(ka131.service.id, 'g26-parahyangan');
      expect(ka131.serviceDate, _dec2);
      expect(ka131.departureAt, timetableInstant(_dec2, 5 * 60)); // 05:00
      expect(ka131.arrivalAt, timetableInstant(_dec2, 8 * 60 + 8)); // 08:08
      expect(ka131.stationCodes.first, 'BD');
      expect(ka131.stationCodes.last, 'GMR');
      // The other direction is not offered for this pair.
      expect(departures.any((d) => d.run.ka == '132'), isFalse);
      expect(
        departures.where((d) => d.run.fakultatif).map((d) => d.run.ka),
        contains('141F'),
      );
    });

    test('a time past 24:00 is the next morning', () {
      // KA 42/43 leaves Tegal at 24:36 on its service day: 00:36 next day.
      final departures = catalog.departuresBetween(
        'TG',
        'JR',
        now: timetableInstant(_dec3, 10), // 00:10 on 3 December
      );
      final night = departures.firstWhere(
        (d) => d.run.ka == '42/43' && d.serviceDate == _dec2,
      );
      expect(night.departureAt, timetableInstant(_dec3, 36));
      expect(timetableDate(night.departureAt), _dec3);
      expect(night.arrivalAt, timetableInstant(_dec3, 10 * 60 + 4));
    });

    test('a night train boarded yesterday is still offered until it arrives',
        () {
      final departures = catalog.departuresBetween(
        'GMR',
        'JR',
        now: timetableInstant(_dec3, 60), // 01:00, the 21:00 train is running
      );
      expect(
        departures.any((d) => d.run.ka == '42/43' && d.serviceDate == _dec2),
        isTrue,
      );
      // Tonight's run of the same train is listed too.
      expect(
        departures.any((d) => d.run.ka == '42/43' && d.serviceDate == _dec3),
        isTrue,
      );
    });

    test('a run\'s own minutes become the estimate prior, either direction', () {
      final service = catalog.serviceById('g26-parahyangan')!;
      for (final ka in <String>['131', '132']) {
        final view = service.forRun(service.runByKa(ka)!);
        final minutes =
            (view.stopAt('GMR')!.estimatedMinutes -
                    view.stopAt('BD')!.estimatedMinutes)
                .abs();
        expect(minutes, 188, reason: 'KA $ka'); // 05:00-08:08, 06:30-09:38
        expect(view.timingRunKa, ka);
        expect(view.totalKm, service.totalKm);
        for (var i = 1; i < view.stops.length; i += 1) {
          expect(view.stops[i].km, greaterThan(view.stops[i - 1].km));
          expect(view.stops[i].estimatedMinutes,
              greaterThanOrEqualTo(view.stops[i - 1].estimatedMinutes));
        }
      }
    });
  });

  group('timetabled trips', () {
    final service = catalog.serviceById('g26-parahyangan')!;
    final now = timetableInstant(_dec2, 4 * 60 + 30);

    IntercityDeparture pick(String from, String to, String ka) => catalog
        .departuresBetween(from, to, now: now)
        .firstWhere((d) => d.run.ka == ka);

    test('a picked departure gives the timetable times and says so', () {
      final departure = pick('BD', 'GMR', '131');
      final trip = buildIntercityTrip(
        service: service,
        catalog: catalog,
        boarding: 'BD',
        destination: 'GMR',
        now: now,
        departure: departure,
      );
      expect(trip.freshness, DataFreshness.scheduled);
      expect(trip.sourceLabel, 'Jadwal GAPEKA 2026');
      expect(trip.departureAt, departure.departureAt);
      expect(trip.arrivalAt, departure.arrivalAt);
      expect(trip.stationIds, departure.stationCodes);
      expect(trip.legs.single.lineName, 'Parahyangan (KA 131)');
      expect(trip.legs.single.serviceId, isNull);
      final ref = IntercityTripRef.tryParse(trip.id)!;
      expect(ref.serviceId, 'g26-parahyangan');
      expect(ref.ka, '131');
      expect(ref.serviceDate, _dec2);
      expect(ref.isScheduled, isTrue);
      expect(ref.customName, isNull);
      expect(ref.boardingCode, 'BD');
      expect(ref.destinationCode, 'GMR');
    });

    test('a fakultatif run is marked on the trip', () {
      final departure = pick('BD', 'GMR', '141F');
      final trip = buildIntercityTrip(
        service: departure.service,
        catalog: catalog,
        boarding: 'BD',
        destination: 'GMR',
        now: now,
        departure: departure,
      );
      expect(trip.legs.single.serviceId, fakultatifServiceId);
      expect(IntercityTripRef.tryParse(trip.id)!.ka, '141F');
    });

    test('an interpolated time is marked on the trip', () {
      final departure = catalog
          .departuresBetween('SI', 'KE', now: timetableInstant(_dec2, 5 * 60))
          .firstWhere((d) => d.run.ka == '265');
      expect(departure.arrivalEstimated, isTrue);
      final trip = buildIntercityTrip(
        service: departure.service,
        catalog: catalog,
        boarding: 'SI',
        destination: 'KE',
        now: now,
        departure: departure,
      );
      expect(trip.legs.single.arrivalEstimated, isTrue);
      expect(trip.legs.single.departureEstimated, isFalse);
    });

    test('trip ids written before timetables still read the same', () {
      final plain = IntercityTripRef.tryParse(
        'ic|parahyangan|GMR|BD|1760749200000',
      )!;
      expect(plain.serviceId, 'parahyangan');
      expect(plain.boardingCode, 'GMR');
      expect(plain.destinationCode, 'BD');
      expect(plain.customName, isNull);
      expect(plain.ka, isNull);
      expect(plain.isScheduled, isFalse);
      expect(
        plain.startedAt,
        DateTime.fromMillisecondsSinceEpoch(1760749200000),
      );
      final typed = IntercityTripRef.tryParse(
        'ic|custom|PWK|BD|1760749200000|KA%20Tambahan%20Libur',
      )!;
      expect(typed.isCustom, isTrue);
      expect(typed.customName, 'KA Tambahan Libur');
      expect(typed.isScheduled, isFalse);
      // And an old service id still resolves to its train.
      expect(catalog.serviceById(plain.serviceId), isNotNull);
    });
  });

  group('IntercityReminderPlanner', () {
    test('fires 30, 15 and 10 km once each, in order, as the distance falls', () {
      final p = IntercityReminderPlanner();
      final fired = <int>[];
      for (var km = 120; km >= 0; km -= 1) {
        final due = p.onRemainingKm(km.toDouble());
        if (due != null) fired.add(due);
      }
      expect(fired, <int>[30, 15, 10]);
    });

    test('boarding with 20 km left skips the 30 but keeps 15 and 10', () {
      final p = IntercityReminderPlanner();
      final fired = <int>[];
      for (var km = 20; km >= 0; km -= 1) {
        final due = p.onRemainingKm(km.toDouble());
        if (due != null) fired.add(due);
      }
      expect(fired, <int>[15, 10]);
    });

    test('a short ride announces no distance reminder at all', () {
      final p = IntercityReminderPlanner();
      expect(p.onRemainingKm(8), isNull);
      expect(p.onRemainingKm(5), isNull);
      expect(p.onRemainingKm(1), isNull);
    });

    test('a reminder comes a little early, never late', () {
      final p = IntercityReminderPlanner()..onRemainingKm(90);
      expect(p.onRemainingKm(30.6), isNull);
      expect(p.onRemainingKm(30.2), 30);
    });

    test('a wobbling reading never repeats a reminder', () {
      final p = IntercityReminderPlanner()..onRemainingKm(90);
      expect(p.onRemainingKm(29.8), 30);
      expect(p.onRemainingKm(31), isNull);
      expect(p.onRemainingKm(29), isNull);
      expect(p.onRemainingKm(30), isNull);
    });

    test('a signal gap that jumps past reminders announces only the nearest', () {
      final p = IntercityReminderPlanner()..onRemainingKm(90);
      expect(p.onRemainingKm(12), 15);
      expect(p.hasFired(30), isTrue);
      expect(p.onRemainingKm(9), 10);
    });
  });
}
