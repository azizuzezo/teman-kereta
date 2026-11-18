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
    test('Yogyakarta line stations are Jogja, Jabodetabek lines Jabodetabek', () {
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

  group('network map (networks.json)', () {
    test('every line hosted today keeps its network', () {
      for (final code in <String>[
        'BOGOR',
        'CIKARANG',
        'RANGKAS',
        'TANGERANG',
        'PRIOK',
        'NAMBO',
        'RANGKASBITUNG',
        'TANJUNG_PRIOK',
      ]) {
        expect(networkOfLineCode(code), TransitNetwork.jabodetabek, reason: code);
      }
      expect(networkOfLineCode('YKPL'), TransitNetwork.jogja);
    });

    test('new GAPEKA 2026 lines map to their own networks', () {
      expect(networkOfLineCode('BST'), TransitNetwork.jabodetabek);
      expect(networkOfLineCode('WALAHAR'), TransitNetwork.jabodetabek);
      expect(networkOfLineCode('YIA'), TransitNetwork.jogja);
      expect(networkOfLineCode('PRAMEKS'), TransitNetwork.jogja);
      expect(networkOfLineCode('BDR'), TransitNetwork.bandung);
      expect(networkOfLineCode('GARUT'), TransitNetwork.bandung);
      expect(networkOfLineCode('DHOHO'), TransitNetwork.jatim);
      expect(networkOfLineCode('KEDUNGSEPUR'), TransitNetwork.semarang);
      expect(networkOfLineCode('SILIWANGI'), TransitNetwork.sukabumi);
      expect(networkOfLineCode('PANDANWANGI'), TransitNetwork.banyuwangi);
    });

    test('ids and labels follow networks.json', () {
      expect(TransitNetwork.jabodetabek.id, 'jabodetabek');
      expect(TransitNetwork.jogja.id, 'jogja');
      expect(networkLabel(TransitNetwork.jabodetabek), 'Jabodetabek');
      expect(networkLabel(TransitNetwork.jogja), 'Yogyakarta');
      expect(networkLabel(TransitNetwork.bandung), 'Bandung Raya');
    });
  });

  group('unknown line codes', () {
    final mystery = _station('XX', 'Misteri', ['NOT_A_LINE'], 1);
    final mystery2 = _station('YY', 'Misteri Dua', ['NOT_A_LINE'], 2);

    test('are never assumed to be Jabodetabek', () {
      expect(networkOfLineCode('NOT_A_LINE'), isNull);
      expect(networkOfStation(mystery), isNull);
      expect(networksOfStation(mystery), isEmpty);
    });

    test('a station on no known network matches nothing, not even itself', () {
      expect(sameNetwork(mystery, _bogor), isFalse);
      expect(sameNetwork(_bogor, mystery), isFalse);
      expect(sameNetwork(mystery, mystery2), isFalse);
      expect(destinationsFor(mystery, <Station>[..._all, mystery2]), isEmpty);
      expect(defaultDestinationFor(mystery, _all), isNull);
    });

    test('a known line next to an unknown one still decides the network', () {
      final mixed = _station('MX', 'Campur', ['NOT_A_LINE', 'BOGOR'], 3);
      expect(networkOfStation(mixed), TransitNetwork.jabodetabek);
      expect(sameNetwork(mixed, _bogor), isTrue);
    });

    test('the message says the network is not recognised', () {
      expect(crossNetworkMessageFor(mystery, _bogor), unknownNetworkMessage);
      expect(crossNetworkMessageFor(_bogor, _palur), crossNetworkMessage);
    });
  });

  group('a station on two networks (Purwakarta)', () {
    final purwakarta = _station('PWK', 'Purwakarta', [
      'WALAHAR',
      'BDR',
      'GARUT',
    ], 1);
    final cikarang = _station('CKR', 'Cikarang', ['CIKARANG', 'WALAHAR'], 2);
    final bandung = _station('BD', 'Bandung', ['BDR'], 5);

    test('belongs to both networks', () {
      expect(networksOfStation(purwakarta), <TransitNetwork>{
        TransitNetwork.jabodetabek,
        TransitNetwork.bandung,
      });
    });

    test('connects to either side, but the two sides stay separate', () {
      expect(sameNetwork(purwakarta, cikarang), isTrue);
      expect(sameNetwork(purwakarta, bandung), isTrue);
      expect(sameNetwork(cikarang, bandung), isFalse);
      expect(sharedNetworks(purwakarta, bandung), {TransitNetwork.bandung});
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

  group('TripSearchController with an unknown line', () {
    final mystery = _station('XX', 'Misteri', ['NOT_A_LINE'], 1);

    test('searching from it says the network is not recognised', () async {
      final c = ProviderContainer(
        overrides: [
          stationListProvider.overrideWith((ref) async => <Station>[
            ..._all,
            mystery,
          ]),
          fixReaderProvider.overrideWithValue(
            () async => const FixReading.ok(-6.5950, 106.7906),
          ),
        ],
      );
      addTearDown(c.dispose);
      await c.read(stationListProvider.future);
      final controller = c.read(tripSearchControllerProvider.notifier)
        ..setOrigin('XX')
        ..setDestination('BOO');

      await controller.search();

      final state = c.read(tripSearchControllerProvider);
      expect(state.errorMessage, unknownNetworkMessage);
      expect(state.results, isEmpty);
    });
  });
}
