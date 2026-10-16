import 'package:flutter_test/flutter_test.dart';
import 'package:teman_kereta/domain/entities/transit_models.dart';
import 'package:teman_kereta/domain/usecases/nearest_station_finder.dart';
import 'package:teman_kereta/features/home/domain/next_train_logic.dart';

Station _station(String id, double lat, double lng) =>
    Station(id: id, code: id, name: id, latitude: lat, longitude: lng);

StationDistance _dist(String id, double meters) => StationDistance(
  station: _station(id, -6.2, 106.8),
  distanceMeters: meters,
  walkingMinutes: 1,
);

Departure _departure(String id, DateTime at, {String stationId = 'BOO'}) =>
    Departure(
      id: id,
      stationId: stationId,
      destination: 'Jakarta Kota',
      lineName: 'Commuter Line',
      scheduledAt: at,
      expectedAt: at,
      freshness: DataFreshness.estimated,
      sourceLabel: 'Jadwal',
    );

VehiclePosition _vehicle(
  String tripId,
  DateTime at, {
  double lat = -6.4,
  double lng = 106.8,
  String? prev,
  String? next,
}) => VehiclePosition(
  id: 'v-$tripId',
  tripId: tripId,
  latitude: lat,
  longitude: lng,
  recordedAt: at,
  freshness: DataFreshness.nearRealtime,
  sourceLabel: 'Crowd',
  previousStationId: prev,
  nextStationId: next,
);

void main() {
  group('resolveBoardChoice', () {
    test('uses the GPS nearest station and says so', () {
      final choice = resolveBoardChoice(
        ranked: [_dist('BOO', 450), _dist('CLT', 3000)],
        homeStationId: 'DP',
      );
      expect(choice.stationId, 'BOO');
      expect(choice.source, BoardSource.nearest);
      expect(choice.nearest!.distanceMeters, 450);
    });

    test('falls back to the saved home station without a GPS ranking', () {
      final choice = resolveBoardChoice(
        ranked: const <StationDistance>[],
        homeStationId: 'DP',
      );
      expect(choice.stationId, 'DP');
      expect(choice.source, BoardSource.home);
      expect(choice.nearest, isNull);
    });

    test('falls back to the default when there is no home station either', () {
      final choice = resolveBoardChoice(
        ranked: const <StationDistance>[],
        homeStationId: null,
      );
      expect(choice.stationId, 'BOO');
      expect(choice.source, BoardSource.fallback);
    });

    test('a nearest station tens of thousands of km away is not trusted', () {
      final choice = resolveBoardChoice(
        ranked: [_dist('BOO', 13963200)],
        homeStationId: 'DP',
      );
      expect(choice.source, BoardSource.home);
    });

    test('keeps the previous station while GPS jitter makes another win', () {
      final choice = resolveBoardChoice(
        ranked: [_dist('CLT', 400), _dist('BOO', 480)],
        homeStationId: null,
        previousNearestId: 'BOO',
      );
      expect(choice.stationId, 'BOO');
      expect(choice.nearest!.distanceMeters, 480);
    });

    test('switches once another station is clearly closer', () {
      final choice = resolveBoardChoice(
        ranked: [_dist('CLT', 300), _dist('BOO', 900)],
        homeStationId: null,
        previousNearestId: 'BOO',
      );
      expect(choice.stationId, 'CLT');
    });

    test('ignores a previous station that is no longer ranked', () {
      final choice = resolveBoardChoice(
        ranked: [_dist('CLT', 300)],
        homeStationId: null,
        previousNearestId: 'XXX',
      );
      expect(choice.stationId, 'CLT');
    });
  });

  group('upcomingDepartures', () {
    final now = DateTime(2026, 10, 15, 8, 0, 0);

    test('drops departed trains, sorts by time and limits the count', () {
      final list = [
        _departure('c', now.add(const Duration(minutes: 20))),
        _departure('old', now.subtract(const Duration(minutes: 2))),
        _departure('a', now.add(const Duration(minutes: 3))),
        _departure('b', now.add(const Duration(minutes: 9))),
      ];
      final result = upcomingDepartures(list, now, limit: 2);
      expect(result.map((d) => d.id), ['a', 'b']);
    });

    test('a train leaving this very second is still upcoming', () {
      final result = upcomingDepartures([_departure('now', now)], now);
      expect(result, hasLength(1));
    });
  });

  group('countdown', () {
    test('under one minute', () {
      expect(countdownLabel(const Duration(seconds: 40)), 'Kurang dari 1 mnt');
    });

    test('whole minutes use floor so it never promises too much time', () {
      expect(countdownLabel(const Duration(minutes: 5, seconds: 59)), '5 mnt lagi');
    });

    test('hours', () {
      expect(countdownLabel(const Duration(minutes: 75)), '1 j 15 mnt lagi');
    });

    test('already gone reads as departed', () {
      expect(countdownLabel(const Duration(seconds: -5)), 'Berangkat');
    });
  });

  group('matchVehicle', () {
    final now = DateTime(2026, 10, 15, 8, 0, 0);

    test('matches the vehicle with the same trip id', () {
      final d = _departure('trip-1', now.add(const Duration(minutes: 5)));
      final vehicles = [
        _vehicle('trip-2', now),
        _vehicle('trip-1', now.subtract(const Duration(seconds: 30))),
      ];
      expect(matchVehicle(d, vehicles, now)!.tripId, 'trip-1');
    });

    test('ignores positions that are too old to describe where it is now', () {
      final d = _departure('trip-1', now);
      final vehicles = [
        _vehicle('trip-1', now.subtract(const Duration(minutes: 10))),
      ];
      expect(matchVehicle(d, vehicles, now), isNull);
    });

    test('an empty trip id never matches', () {
      final d = _departure('', now);
      expect(matchVehicle(d, [_vehicle('', now)], now), isNull);
    });

    test('picks the freshest of several reports', () {
      final d = _departure('trip-1', now);
      final vehicles = [
        _vehicle('trip-1', now.subtract(const Duration(minutes: 2))),
        _vehicle('trip-1', now.subtract(const Duration(seconds: 10)), lat: -6.5),
      ];
      expect(matchVehicle(d, vehicles, now)!.latitude, -6.5);
    });
  });

  group('describeTrain', () {
    final board = _station('BOO', -6.5950, 106.7906);
    final prev = _station('CLT', -6.5309, 106.8005);
    final next = _station('BOO', -6.5950, 106.7906);

    test('reports distance to the board station and progress between stops', () {
      final vehicle = _vehicle(
        't',
        DateTime(2026, 10, 15),
        lat: -6.563,
        lng: 106.7955,
        prev: 'CLT',
        next: 'BOO',
      );
      final progress = describeTrain(
        vehicle,
        board,
        {'CLT': prev, 'BOO': next},
      );
      expect(progress.previousName, 'CLT');
      expect(progress.nextName, 'BOO');
      expect(progress.fraction, closeTo(0.5, 0.1));
      expect(progress.distanceToBoardMeters, closeTo(3600, 300));
    });

    test('no fraction when a neighbouring station is unknown', () {
      final vehicle = _vehicle('t', DateTime(2026, 10, 15), prev: 'ZZZ', next: 'BOO');
      final progress = describeTrain(vehicle, board, {'BOO': next});
      expect(progress.fraction, isNull);
      expect(progress.previousName, isNull);
      expect(progress.nextName, 'BOO');
    });

    test('fraction is clamped to the segment', () {
      final vehicle = _vehicle(
        't',
        DateTime(2026, 10, 15),
        lat: -7.0,
        lng: 106.7906,
        prev: 'CLT',
        next: 'BOO',
      );
      final progress = describeTrain(
        vehicle,
        board,
        {'CLT': prev, 'BOO': next},
      );
      expect(progress.fraction, inInclusiveRange(0.0, 1.0));
    });
  });

  group('disruptionAlerts', () {
    ServiceAlert alert(String id, ServiceStatus status, int minutesAgo) =>
        ServiceAlert(
          id: id,
          title: id,
          description: '',
          status: status,
          updatedAt: DateTime(2026, 10, 15, 8).subtract(Duration(minutes: minutesAgo)),
          sourceLabel: 's',
        );

    test('normal and unavailable alerts show nothing', () {
      expect(
        disruptionAlerts([
          alert('a', ServiceStatus.normal, 1),
          alert('b', ServiceStatus.unavailable, 1),
        ]),
        isEmpty,
      );
    });

    test('most severe first, then newest', () {
      final result = disruptionAlerts([
        alert('late-old', ServiceStatus.delayed, 30),
        alert('late-new', ServiceStatus.delayed, 5),
        alert('down', ServiceStatus.disrupted, 60),
        alert('ok', ServiceStatus.normal, 0),
      ]);
      expect(result.map((a) => a.id), ['down', 'late-new', 'late-old']);
    });
  });

  group('platformLabel', () {
    test('bare numbers get a prefix, labelled ones are kept', () {
      expect(platformLabel('3'), 'Peron 3');
      expect(platformLabel('Peron 3'), 'Peron 3');
    });

    test('missing data and the placeholder are hidden', () {
      expect(platformLabel(null), isNull);
      expect(platformLabel('  '), isNull);
      expect(platformLabel('Peron belum tersedia'), isNull);
    });
  });
}
