// Runs SupabaseTransitProvider against a REAL local Supabase stack
// (`npx supabase start` from the project root), not mocks — closes the
// "compile-verified only, never runtime-tested" gap noted in
// ENGINEERING.md's `local_supabase` section.
//
// Skipped by default (the normal `flutter test` run has no live Supabase
// instance to talk to). Opt in explicitly:
//
//   npx supabase start
//   flutter test --dart-define=LIVE_SUPABASE=true test/integration/supabase_transit_provider_live_test.dart
//
// Uses the local stack's well-known demo anon key (see `supabase status`),
// never a real project credential — safe to keep in source.
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:teman_kereta/data/providers/supabase_transit_provider.dart';
import 'package:teman_kereta/domain/entities/transit_models.dart';

const _runLive = bool.fromEnvironment('LIVE_SUPABASE');
const _localAnonKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0';

void main() {
  if (!_runLive) {
    test(
      'skipped — pass --dart-define=LIVE_SUPABASE=true with a running local Supabase stack',
      () {},
      skip: true,
    );
    return;
  }

  late SupabaseTransitProvider provider;

  setUpAll(() {
    final client = SupabaseClient('http://127.0.0.1:54321', _localAnonKey);
    provider = SupabaseTransitProvider(client);
  });

  test('getStations returns the real seeded demo stations', () async {
    final stations = await provider.getStations();
    expect(stations.map((s) => s.code), containsAll(<String>[
      'DEMO-BOO',
      'DEMO-MRI',
      'DEMO-SUD',
    ]));
  });

  test('getStation resolves a single seeded station by id', () async {
    final stations = await provider.getStations();
    final boo = stations.firstWhere((s) => s.code == 'DEMO-BOO');

    final resolved = await provider.getStation(boo.id);
    expect(resolved?.name, contains('Bogor'));
  });

  test('getStationDepartures returns the seeded trip once it is due', () async {
    final stations = await provider.getStations();
    final boo = stations.firstWhere((s) => s.code == 'DEMO-BOO');

    // The seed's scheduled_departure (06:02 Asia/Jakarta) resolves to an
    // earlier UTC instant than its own service_date's UTC midnight, so
    // querying from well before that instant is what actually exercises the
    // interval + service_date + timezone resolution in
    // get_station_departures.
    final departures = await provider.getStationDepartures(
      boo.id,
      DateTime.utc(2000),
    );

    expect(departures, isNotEmpty);
    expect(departures.first.tripNumber, 'DEMO-001');
    expect(departures.first.sourceLabel, contains('Supabase lokal'));
  });

  test('searchTrips finds the seeded direct Bogor -> Sudirman trip', () async {
    final stations = await provider.getStations();
    final boo = stations.firstWhere((s) => s.code == 'DEMO-BOO');
    final sud = stations.firstWhere((s) => s.code == 'DEMO-SUD');

    final trips = await provider.searchTrips(
      TripSearchQuery(
        originStationId: boo.id,
        destinationStationId: sud.id,
        departureAt: DateTime.utc(2000),
      ),
    );

    expect(trips, isNotEmpty);
    final trip = trips.first;
    expect(trip.legs.single.stationIds, hasLength(3));
    expect(trip.legs.single.mode, TransportMode.commuterRail);
  });

  test(
    'searchTrips finds the seeded one-transfer Bogor -> Manggarai -> '
    'Kampung Bandan journey',
    () async {
      final stations = await provider.getStations();
      final boo = stations.firstWhere((s) => s.code == 'DEMO-BOO');
      final kpb = stations.firstWhere((s) => s.code == 'DEMO-KPB');

      // Unlike the direct-trip test above, search_one_transfer_trips bounds
      // its search to a horizon after p_from (it can't scan "any time in
      // the future" the way search_direct_trips does), so p_from has to
      // land shortly before the seeded ~06:00 Asia/Jakarta departure rather
      // than an arbitrary point in the past.
      final now = DateTime.now().toUtc();
      final today = DateTime.utc(now.year, now.month, now.day);
      final searchFrom = today.subtract(const Duration(hours: 2));

      final trips = await provider.searchTrips(
        TripSearchQuery(
          originStationId: boo.id,
          destinationStationId: kpb.id,
          departureAt: searchFrom,
        ),
      );

      expect(trips, isNotEmpty);
      final trip = trips.first;
      expect(trip.transfers, 1);
      expect(trip.legs, hasLength(2));
      expect(trip.legs[0].destinationName, contains('Manggarai'));
      expect(trip.legs[1].originName, contains('Manggarai'));
      expect(trip.transferBoundaries, hasLength(1));
      expect(trip.sourceLabel, contains('satu kali transit'));
    },
  );

  test('watchVehiclePositions streams the seeded vehicle over Realtime', () async {
    final positions = await provider.watchVehiclePositions().first.timeout(
      const Duration(seconds: 10),
    );
    expect(positions, isNotEmpty);
    expect(positions.first.sourceLabel, contains('Supabase lokal'));
  });
}
