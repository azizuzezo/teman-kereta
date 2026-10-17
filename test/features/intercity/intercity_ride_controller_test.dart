import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teman_kereta/core/database/app_database.dart';
import 'package:teman_kereta/core/database/database_provider.dart';
import 'package:teman_kereta/core/notifications/alert_audio_plan.dart';
import 'package:teman_kereta/core/notifications/local_notification_service.dart';
import 'package:teman_kereta/core/preferences/preferences_store.dart';
import 'package:teman_kereta/core/utils/geo.dart';
import 'package:teman_kereta/data/providers/provider_registry.dart';
import 'package:teman_kereta/domain/entities/transit_models.dart';
import 'package:teman_kereta/features/active_trip/presentation/active_trip_controller.dart';
import 'package:teman_kereta/features/active_trip/presentation/active_trip_stations.dart';
import 'package:teman_kereta/features/intercity/data/intercity_repository.dart';
import 'package:teman_kereta/features/intercity/domain/intercity_models.dart';
import 'package:teman_kereta/features/intercity/domain/intercity_trip.dart';
import 'package:teman_kereta/features/intercity/presentation/intercity_ride_controller.dart';
import 'package:teman_kereta/features/live_map/presentation/native_gps_fix.dart';

import '../../support/fakes.dart';

const _nativeChannel = MethodChannel('id.temankereta.teman_kereta/native');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final catalog = IntercityCatalog.fromJson(
    jsonDecode(File('assets/intercity/intercity_v1.json').readAsStringSync())
        as Map<String, dynamic>,
  );

  late ProviderContainer container;
  late FakeNotificationService notifications;
  late AppDatabase database;
  final nativeCalls = <String>[];
  final nativeArgs = <Map<Object?, Object?>>[];

  setUp(() {
    notifications = FakeNotificationService();
    database = AppDatabase.forTesting(NativeDatabase.memory());
    nativeCalls.clear();
    nativeArgs.clear();
    container = ProviderContainer(
      overrides: [
        preferencesStoreProvider.overrideWithValue(MemoryPreferencesStore()),
        localNotificationServiceProvider.overrideWithValue(notifications),
        stationListProvider.overrideWith((ref) async => const <Station>[]),
        appDatabaseProvider.overrideWithValue(database),
        intercityCatalogProvider.overrideWith((ref) async => catalog),
      ],
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_nativeChannel, (call) async {
          nativeCalls.add(call.method);
          if (call.arguments is Map) {
            nativeArgs.add(call.arguments as Map<Object?, Object?>);
          }
          return null;
        });
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_nativeChannel, null);
    container.dispose();
    await database.close();
  });

  TransitTrip tripFor(String serviceId, String from, String to) =>
      buildIntercityTrip(
        service: catalog.serviceById(serviceId)!,
        catalog: catalog,
        boarding: from,
        destination: to,
        now: DateTime(2026, 10, 18, 8),
      );

  test('a built intercity trip is recognisable and keeps only its stops', () {
    final trip = tripFor('parahyangan', 'GMR', 'BD');
    expect(isIntercityTrip(trip), isTrue);
    final ref = IntercityTripRef.tryParse(trip.id)!;
    expect(ref.serviceId, 'parahyangan');
    expect(ref.boardingCode, 'GMR');
    expect(ref.destinationCode, 'BD');
    expect(trip.stationIds.first, 'GMR');
    expect(trip.stationIds.last, 'BD');
    expect(trip.durationMinutes, greaterThan(120));
    expect(trip.durationMinutes, lessThan(240));
    // A KRL trip id is never mistaken for an intercity one.
    expect(IntercityTripRef.tryParse('trip-transfer'), isNull);
  });

  group('a train the rider names themselves', () {
    test('reuses a listed train\'s track when one serves the pair', () {
      final service = catalog.serviceForCustomRide('GMR', 'KAC');
      expect(<String>['papandayan', 'pangandaran'], contains(service.id));
      final trip = buildIntercityTrip(
        service: service,
        catalog: catalog,
        boarding: 'GMR',
        destination: 'KAC',
        now: DateTime(2026, 10, 18, 8),
        customName: 'KA Tambahan Libur',
      );
      expect(trip.legs.single.lineName, 'KA Tambahan Libur');
      final ref = IntercityTripRef.tryParse(trip.id)!;
      expect(ref.isCustom, isTrue);
      expect(ref.customName, 'KA Tambahan Libur');
      expect(trip.stationIds.first, 'GMR');
      expect(trip.stationIds.last, 'KAC');
    });

    test('joins two stations no train links with a stretched straight line', () {
      final service = catalog.serviceForCustomRide('KPT', 'GMR');
      expect(service.id, customServiceId);
      expect(service.stops.map((s) => s.code), <String>['KPT', 'GMR']);
      expect(service.totalKm, greaterThan(500));
      expect(service.stops.last.estimatedMinutes, closeTo(service.totalKm / 72 * 60, 0.5));
      final trip = buildIntercityTrip(
        service: service,
        catalog: catalog,
        boarding: 'KPT',
        destination: 'GMR',
        now: DateTime(2026, 10, 18, 8),
        customName: 'Argo Sumatra',
      );
      expect(trip.stationIds, <String>['KPT', 'GMR']);
      expect(IntercityTripRef.tryParse(trip.id)!.customName, 'Argo Sumatra');
    });

    test('a name with odd characters survives the trip id', () {
      final trip = buildIntercityTrip(
        service: catalog.serviceForCustomRide('GMR', 'BD'),
        catalog: catalog,
        boarding: 'GMR',
        destination: 'BD',
        now: DateTime(2026, 10, 18, 8),
        customName: 'KA 123 | Jakarta/Bandung',
      );
      expect(IntercityTripRef.tryParse(trip.id)!.customName, 'KA 123 | Jakarta/Bandung');
    });

    test('a typed-name ride is announced like any other', () async {
      final trip = buildIntercityTrip(
        service: catalog.serviceForCustomRide('PWK', 'BD'),
        catalog: catalog,
        boarding: 'PWK',
        destination: 'BD',
        now: DateTime(2026, 10, 18, 8),
        customName: 'KA Tambahan Libur',
      );
      container.listen(intercityRideControllerProvider, (_, _) {});
      await container.read(activeTripControllerProvider.notifier).start(trip);
      for (var i = 0; i < 20; i += 1) {
        await Future<void>.delayed(Duration.zero);
      }
      final ride = container.read(intercityRideControllerProvider);
      expect(ride.isActive, isTrue);
      expect(ride.serviceName, 'KA Tambahan Libur');
      expect(ride.destinationName, 'Bandung');
    });
  });

  test('the active-trip stations add intercity stations only for intercity rides',
      () async {
    final krl = await container.read(activeTripStationsProvider.future);
    expect(krl, isEmpty);

    await container
        .read(activeTripControllerProvider.notifier)
        .start(tripFor('parahyangan', 'GMR', 'BD'));
    final merged = await container.read(activeTripStationsProvider.future);
    expect(merged.map((s) => s.id), containsAll(<String>['GMR', 'BD', 'PWK']));
  });

  test('starting an intercity ride switches the station-count alerts off', () async {
    await container
        .read(activeTripControllerProvider.notifier)
        .start(tripFor('parahyangan', 'GMR', 'BD'));
    final start = nativeArgs.firstWhere(
      (args) => args.containsKey('stopAlertThreshold'),
    );
    expect(start['stopAlertThreshold'], 0);
  });

  /// A ride down [service]'s own track at [kmh], one fix every 4 s, standing
  /// still at each intermediate stop for as long as the dataset says the train
  /// does. Returns the fixes and the moment the train reaches the end.
  ({List<NativeGpsFix> fixes, List<double> kms, DateTime arrival}) simulate(
    IntercityService service, {
    required double kmh,
    required DateTime start,
  }) {
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
    final scale = (service.totalKm * 1000) / cumulative.last;
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

    final fixes = <NativeGpsFix>[];
    final kms = <double>[];
    var clock = start;
    var km = 0.0;
    var nextStop = 1;
    while (km < service.totalKm) {
      final p = at(km);
      fixes.add(
        NativeGpsFix(
          latitude: p.latitude,
          longitude: p.longitude,
          at: clock,
          speedMetersPerSecond: kmh / 3.6,
        ),
      );
      kms.add(km);
      km += kmh * 4 / 3600;
      clock = clock.add(const Duration(seconds: 4));
      if (nextStop < service.stops.length - 1 && km >= service.stops[nextStop].km) {
        final stop = service.stops[nextStop];
        final here = at(stop.km);
        final until = clock.add(Duration(minutes: stop.dwellMinutes.round()));
        while (clock.isBefore(until)) {
          fixes.add(
            NativeGpsFix(
              latitude: here.latitude,
              longitude: here.longitude,
              at: clock,
              speedMetersPerSecond: 0,
            ),
          );
          kms.add(stop.km);
          clock = clock.add(const Duration(seconds: 4));
        }
        nextStop += 1;
      }
    }
    return (fixes: fixes, kms: kms, arrival: clock);
  }

  test('a full ride announces 30, 15 and 10 km of rail left, once each, in order', () async {
    final service = catalog.serviceById('parahyangan')!;
    final trip = tripFor('parahyangan', 'GMR', 'BD');
    container.listen(intercityRideControllerProvider, (_, _) {});
    await container.read(activeTripControllerProvider.notifier).start(trip);
    // Let the controller load the catalog and arm itself.
    for (var i = 0; i < 20; i += 1) {
      await Future<void>.delayed(Duration.zero);
    }
    expect(container.read(intercityRideControllerProvider).isActive, isTrue);

    final ride = simulate(service, kmh: 85, start: DateTime(2026, 10, 18, 8));
    final fixNotifier = container.read(latestNativeGpsFixProvider.notifier);
    final railKmLeft = <int, double>{};
    var seen = 0;
    for (var i = 0; i < ride.fixes.length; i += 1) {
      fixNotifier.set(ride.fixes[i]);
      if (notifications.intercityDistanceAlerts.length > seen) {
        final km = notifications.intercityDistanceAlerts.last;
        railKmLeft[km] = service.totalKm - ride.kms[i];
        seen = notifications.intercityDistanceAlerts.length;
      }
    }

    expect(notifications.intercityDistanceAlerts, intercityReminderKm);
    // Each one comes when that much track is left: not later than promised,
    // and at most a few hundred metres early.
    for (final km in intercityReminderKm) {
      final left = railKmLeft[km]!;
      expect(left, closeTo(km.toDouble(), 0.8),
          reason: '$km km reminder came with $left km of rail left');
      expect(left, lessThanOrEqualTo(km + 0.5), reason: '$km km must not come late');
    }
    // And no "3 stasiun lagi" style alert was raised for an intercity ride.
    expect(notifications.stopAlerts, 0);
  });
}
