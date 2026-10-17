import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:teman_kereta/core/utils/geo.dart';
import 'package:teman_kereta/features/intercity/domain/intercity_eta.dart';
import 'package:teman_kereta/features/intercity/domain/intercity_geometry.dart';
import 'package:teman_kereta/features/intercity/domain/intercity_models.dart';
import 'package:teman_kereta/features/intercity/domain/intercity_reminder_planner.dart';

IntercityCatalog _loadCatalog() {
  final raw = File('assets/intercity/intercity_v1.json').readAsStringSync();
  return IntercityCatalog.fromJson(jsonDecode(raw) as Map<String, dynamic>);
}

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

    test('only the two Medan trains are still flagged for review', () {
      final flagged = catalog.services
          .where((s) => !s.verified)
          .map((s) => s.id)
          .toSet();
      expect(flagged, <String>{'sribilah', 'putri-deli'});
    });

    test('every train is a different one: unique id and unique name', () {
      expect(catalog.services.map((s) => s.id).toSet().length,
          catalog.services.length);
      expect(catalog.services.map((s) => s.name).toSet().length,
          catalog.services.length);
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

  group('IntercityReminderPlanner', () {
    test('fires 30, 15 and 10 once each, in order, as the estimate falls', () {
      final p = IntercityReminderPlanner();
      final fired = <int>[];
      for (var minutes = 120; minutes >= 0; minutes -= 1) {
        final due = p.onEta(Duration(minutes: minutes));
        if (due != null) fired.add(due);
      }
      expect(fired, <int>[30, 15, 10]);
    });

    test('boarding with 20 minutes left skips the 30 but keeps 15 and 10', () {
      final p = IntercityReminderPlanner();
      final fired = <int>[];
      for (var minutes = 20; minutes >= 0; minutes -= 1) {
        final due = p.onEta(Duration(minutes: minutes));
        if (due != null) fired.add(due);
      }
      expect(fired, <int>[15, 10]);
    });

    test('boarding with 8 minutes left announces nothing', () {
      final p = IntercityReminderPlanner();
      expect(p.onEta(const Duration(minutes: 8)), isNull);
      expect(p.onEta(const Duration(minutes: 5)), isNull);
    });

    test('a wobbling estimate never repeats a reminder', () {
      final p = IntercityReminderPlanner()..onEta(const Duration(minutes: 90));
      expect(p.onEta(const Duration(minutes: 29)), 30);
      expect(p.onEta(const Duration(minutes: 31)), isNull);
      expect(p.onEta(const Duration(minutes: 29)), isNull);
      expect(p.onEta(const Duration(minutes: 30)), isNull);
    });

    test('a signal gap that jumps past reminders announces only the nearest', () {
      final p = IntercityReminderPlanner()..onEta(const Duration(minutes: 90));
      expect(p.onEta(const Duration(minutes: 12)), 15);
      expect(p.hasFired(30), isTrue);
      expect(p.onEta(const Duration(minutes: 9)), 10);
    });
  });
}
