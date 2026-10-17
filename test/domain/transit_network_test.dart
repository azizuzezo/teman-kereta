import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teman_kereta/data/providers/provider_registry.dart';
import 'package:teman_kereta/domain/entities/transit_models.dart';
import 'package:teman_kereta/domain/usecases/krl_fare.dart';
import 'package:teman_kereta/domain/usecases/line_transfer_router.dart';
import 'package:teman_kereta/domain/usecases/rail_distance.dart';
import 'package:teman_kereta/domain/usecases/transit_network.dart';
import 'package:teman_kereta/features/schedule/presentation/trip_search_controller.dart';
import 'package:teman_kereta/features/stations/presentation/nearest_station_controller.dart';

Station _station(
  String code,
  String name,
  List<String> lines,
  int order, {
  double lat = 0,
  double lon = 0,
}) => Station(
  id: code,
  code: code,
  name: name,
  latitude: lat,
  longitude: lon,
  lineIds: lines,
  stopOrderByLine: {for (final line in lines) line: order},
);

final _bogor = _station('BOO', 'Bogor', ['BOGOR'], 1, lat: -6.5950, lon: 106.7906);
final _depok = _station('DP', 'Depok', ['BOGOR'], 5);
final _manggarai = _station('MRI', 'Manggarai', ['BOGOR', 'CIKARANG'], 9);
final _sudirman = _station('SUD', 'Sudirman', ['BOGOR'], 11);
final _yogya = _station('YK', 'Yogyakarta', ['YKPL'], 1, lat: -7.78924, lon: 110.363465);
final _klaten = _station('KT', 'Klaten', ['YKPL'], 6);
final _palur = _station('PL', 'Palur', ['YKPL'], 13, lat: -7.568171, lon: 110.875289);

final _all = <Station>[
  _bogor,
  _depok,
  _manggarai,
  _sudirman,
  _yogya,
  _klaten,
  _palur,
];

void main() {
  group('networkOfStation', () {
    test('Yogyakarta line stations are Jogja, everything else Jabodetabek', () {
      expect(networkOfStation(_yogya), TransitNetwork.jogja);
      expect(networkOfStation(_palur), TransitNetwork.jogja);
      expect(networkOfStation(_bogor), TransitNetwork.jabodetabek);
      expect(networkOfStation(_manggarai), TransitNetwork.jabodetabek);
    });

    test('a station without line data falls back to its code', () {
      const klaten = Station(
        id: 'KT',
        code: 'KT',
        name: 'Klaten',
        latitude: 0,
        longitude: 0,
      );
      const bogor = Station(
        id: 'BOO',
        code: 'BOO',
        name: 'Bogor',
        latitude: 0,
        longitude: 0,
      );
      expect(networkOfStation(klaten), TransitNetwork.jogja);
      expect(networkOfStation(bogor), TransitNetwork.jabodetabek);
    });
  });

  group('destinations', () {
    test('only same-network stations are offered, never the origin', () {
      final fromJogja = destinationsFor(_yogya, _all).map((s) => s.id);
      expect(fromJogja, unorderedEquals(<String>['KT', 'PL']));
      final fromJakarta = destinationsFor(_bogor, _all).map((s) => s.id);
      expect(fromJakarta, unorderedEquals(<String>['DP', 'MRI', 'SUD']));
    });

    test('the fallback destination is the far end of the origin network', () {
      expect(defaultDestinationFor(_yogya, _all)?.id, 'PL');
      expect(defaultDestinationFor(_palur, _all)?.id, 'YK');
    });
  });

  group('routing never joins the two networks', () {
    test('Jabodetabek to Jogja has no route, in either direction', () {
      expect(routeBetweenStations(_all, 'BOO', 'PL'), isNull);
      expect(routeBetweenStations(_all, 'SUD', 'YK'), isNull);
      expect(routeBetweenStations(_all, 'YK', 'MRI'), isNull);
    });

    test('a Jogja trip is routed along its own line', () {
      final route = routeBetweenStations(_all, 'YK', 'PL')!;
      expect(route, hasLength(1));
      expect(route.single.map((s) => s.id), ['YK', 'KT', 'PL']);
    });

    test('Jabodetabek routing is unchanged', () {
      final route = routeBetweenStations(_all, 'BOO', 'SUD')!;
      expect(route.single.map((s) => s.id), ['BOO', 'DP', 'MRI', 'SUD']);
    });
  });

  group('Jogja fare uses the same distance scheme as Jabodetabek', () {
    Station real(String code, double lat, double lon) => Station(
      id: code,
      code: code,
      name: code,
      latitude: lat,
      longitude: lon,
      lineIds: const <String>['YKPL'],
    );
    final yk = real('YK', -7.78924, 110.363465);
    final lpn = real('LPN', -7.790212, 110.375583);
    final slo = real('SLO', -7.556648, 110.821479);
    final pl = real('PL', -7.568171, 110.875289);

    test('Yogyakarta to Palur is about 66 km of track: Rp8.000', () {
      final meters = railTrackDistanceMeters(yk, pl)!;
      expect(meters, inInclusiveRange(65000, 67500));
      expect(krlFareRupiah(meters.round()), 8000);
    });

    test('a short hop costs the base fare', () {
      final meters = railTrackDistanceMeters(yk, lpn)!;
      expect(meters, lessThan(3000));
      expect(krlFareRupiah(meters.round()), 3000);
    });

    test('Yogyakarta to Solo Balapan lands in the Rp7.000 band', () {
      final meters = railTrackDistanceMeters(yk, slo)!;
      expect(krlFareRupiah(meters.round()), inInclusiveRange(6000, 7000));
    });

    test('the Jabodetabek formula itself is unchanged', () {
      expect(krlFareRupiah(1200), 3000);
      expect(krlFareRupiah(35001), 5000);
    });
  });

  group('TripSearchController', () {
    ProviderContainer container({
      FixReading fix = const FixReading.ok(-6.5950, 106.7906),
    }) {
      final c = ProviderContainer(
        overrides: [
          stationListProvider.overrideWith((ref) async => _all),
          fixReaderProvider.overrideWithValue(() async => fix),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    test('every station stays pickable: a manual origin never moves the destination', () async {
      final c = container();
      await c.read(stationListProvider.future);
      final controller = c.read(tripSearchControllerProvider.notifier)
        ..setOrigin('YK');
      final state = c.read(tripSearchControllerProvider);
      expect(state.originStationId, 'YK');
      expect(state.destinationStationId, 'SUD'); // untouched
      controller.setDestination('PL');
      expect(c.read(tripSearchControllerProvider).destinationStationId, 'PL');
    });

    test('a rider standing in Jogja gets a Jogja destination by default', () async {
      final c = container(fix: const FixReading.ok(-7.7893, 110.3636));
      await c.read(stationListProvider.future);
      c.listen(tripSearchControllerProvider, (_, _) {});
      await c.read(nearestStationControllerProvider.future);
      final state = c.read(tripSearchControllerProvider);
      expect(state.originStationId, 'YK');
      expect(state.destinationStationId, 'PL');
    });

    test('auto-fill never overrides a destination the rider picked', () async {
      final c = container(fix: const FixReading.ok(-7.7893, 110.3636));
      await c.read(stationListProvider.future);
      c.listen(tripSearchControllerProvider, (_, _) {});
      c.read(tripSearchControllerProvider.notifier).setDestination('SUD');
      await c.read(nearestStationControllerProvider.future);
      expect(c.read(tripSearchControllerProvider).originStationId, 'YK');
      expect(c.read(tripSearchControllerProvider).destinationStationId, 'SUD');
    });

    test('Bekasi-style cross pair: searching says the networks are not connected', () async {
      final c = container();
      await c.read(stationListProvider.future);
      final controller = c.read(tripSearchControllerProvider.notifier)
        ..setOrigin('BOO')
        ..setDestination('PL');

      await controller.search();

      final state = c.read(tripSearchControllerProvider);
      expect(state.errorMessage, crossNetworkMessage);
      expect(state.isLoading, isFalse);
      expect(state.results, isEmpty);
    });
  });
}
