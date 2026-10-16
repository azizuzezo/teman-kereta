import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teman_kereta/data/providers/provider_registry.dart';
import 'package:teman_kereta/domain/entities/transit_models.dart';
import 'package:teman_kereta/features/stations/presentation/nearest_station_controller.dart';

const _bogor = Station(
  id: 'BOO',
  code: 'BOO',
  name: 'Bogor',
  latitude: -6.5950,
  longitude: 106.7906,
);
const _cilebut = Station(
  id: 'CLT',
  code: 'CLT',
  name: 'Cilebut',
  latitude: -6.5309,
  longitude: 106.8005,
);

class _Reader {
  _Reader(this.readings);

  final List<FixReading> readings;
  int calls = 0;

  Future<FixReading> call() async {
    final reading = readings[calls < readings.length ? calls : readings.length - 1];
    calls++;
    return reading;
  }
}

ProviderContainer _container(_Reader reader) {
  final container = ProviderContainer(
    overrides: [
      stationListProvider.overrideWith((ref) async => const [_bogor, _cilebut]),
      fixReaderProvider.overrideWithValue(reader.call),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('build ranks stations from the first fix', () async {
    final reader = _Reader([const FixReading.ok(-6.5949, 106.7907)]);
    final container = _container(reader);

    final ranked = await container.read(nearestStationControllerProvider.future);

    expect(ranked.first.station.id, 'BOO');
    expect(ranked.first.distanceMeters, lessThan(50));
  });

  test('refreshQuietly updates the ranking without passing through loading', () async {
    final reader = _Reader([
      const FixReading.ok(-6.5949, 106.7907),
      const FixReading.ok(-6.5310, 106.8004),
    ]);
    final container = _container(reader);
    await container.read(nearestStationControllerProvider.future);

    final states = <AsyncValue<Object?>>[];
    container.listen(
      nearestStationControllerProvider,
      (_, next) => states.add(next),
    );
    await container.read(nearestStationControllerProvider.notifier).refreshQuietly();

    expect(states.any((s) => s.isLoading), isFalse);
    expect(
      container.read(nearestStationControllerProvider).value!.first.station.id,
      'CLT',
    );
  });

  test('a failed or timed out fix keeps the last known ranking', () async {
    final reader = _Reader([
      const FixReading.ok(-6.5949, 106.7907),
      const FixReading.failed(),
    ]);
    final container = _container(reader);
    await container.read(nearestStationControllerProvider.future);

    await container.read(nearestStationControllerProvider.notifier).refreshQuietly();

    expect(
      container.read(nearestStationControllerProvider).value!.first.station.id,
      'BOO',
    );
  });

  test('permission revoked while Home is open clears the ranking', () async {
    final reader = _Reader([
      const FixReading.ok(-6.5949, 106.7907),
      const FixReading.unavailable(),
    ]);
    final container = _container(reader);
    await container.read(nearestStationControllerProvider.future);

    await container.read(nearestStationControllerProvider.notifier).refreshQuietly();

    expect(container.read(nearestStationControllerProvider).value, isEmpty);
  });

  test('an unchanged position does not emit a new state', () async {
    final reader = _Reader([const FixReading.ok(-6.5949, 106.7907)]);
    final container = _container(reader);
    await container.read(nearestStationControllerProvider.future);

    var emissions = 0;
    container.listen(nearestStationControllerProvider, (_, _) => emissions++);
    await container.read(nearestStationControllerProvider.notifier).refreshQuietly();

    expect(emissions, 0);
  });

  test('overlapping quiet refreshes read the position once', () async {
    final reader = _Reader([const FixReading.ok(-6.5949, 106.7907)]);
    final container = _container(reader);
    await container.read(nearestStationControllerProvider.future);
    final before = reader.calls;

    final notifier = container.read(nearestStationControllerProvider.notifier);
    await Future.wait([notifier.refreshQuietly(), notifier.refreshQuietly()]);

    expect(reader.calls - before, 1);
  });
}
