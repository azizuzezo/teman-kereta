import 'dart:async';
import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app/config/app_environment.dart';
import '../../core/database/app_database.dart';
import '../../core/database/database_provider.dart';
import '../../core/network/api_client.dart';
import '../../domain/entities/transit_models.dart';
import '../../domain/providers/transit_providers.dart';
import 'gtfs_realtime_provider.dart';
import 'gtfs_static_schedule_provider.dart';
import 'hybrid_transit_realtime_provider.dart';
import 'mock_transit_provider.dart';
import 'official_api_transit_provider.dart';
import 'supabase_transit_provider.dart';

final clockProvider = Provider<Clock>((Ref ref) => const Clock());

final mockTransitProvider = Provider<MockTransitProvider>((Ref ref) {
  return MockTransitProvider(clock: ref.watch(clockProvider));
});

final apiClientProvider = Provider<ApiClient>((Ref ref) {
  return ApiClient.localOnly();
});

final officialApiTransitProvider = Provider<OfficialApiTransitProvider>((
  Ref ref,
) {
  final provider = OfficialApiTransitProvider(ref.watch(apiClientProvider));
  ref.onDispose(() => unawaited(provider.dispose()));
  return provider;
});

final gtfsRealtimeTransitProvider = Provider<GtfsRealtimeTransitProvider>((
  Ref ref,
) {
  final provider = GtfsRealtimeTransitProvider(
    dio: ref.watch(apiClientProvider).dio,
    vehiclePositionsUrl: AppEnvironment.gtfsRtVehiclePositionsUrl,
    tripUpdatesUrl: AppEnvironment.gtfsRtTripUpdatesUrl,
    alertsUrl: AppEnvironment.gtfsRtAlertsUrl,
    pollInterval: Duration(seconds: AppEnvironment.gtfsRtPollSeconds),
  );
  ref.onDispose(() => unawaited(provider.dispose()));
  return provider;
});

final supabaseTransitProvider = Provider<SupabaseTransitProvider>((Ref ref) {
  if (!AppEnvironment.supabaseEnabled) {
    throw StateError(
      'TRANSIT_PROVIDER=local_supabase memerlukan SUPABASE_ENABLED=true '
      'dan Supabase.initialize() sudah dipanggil sebelum runApp().',
    );
  }
  return SupabaseTransitProvider(Supabase.instance.client);
});

/// Merges `gtfs`'s real-feed vehicle positions (empty today — no GTFS-RT
/// URL configured) with Supabase's `vehicle_positions` (schedule-estimated
/// + genuine crowd-sourced rider reports), so `TRANSIT_PROVIDER=gtfs` shows
/// real crowd-sourced positions without needing schedule data to also come
/// from Supabase. Only constructed when `SUPABASE_ENABLED=true` — see
/// `transitRealtimeProvider` below, which falls back to plain
/// `gtfsRealtimeTransitProvider` otherwise.
final hybridGtfsRealtimeProvider = Provider<HybridTransitRealtimeProvider>((
  Ref ref,
) {
  final provider = HybridTransitRealtimeProvider(
    primary: ref.watch(gtfsRealtimeTransitProvider),
    supplementalPositions: ref.watch(supabaseTransitProvider),
  );
  ref.onDispose(() => unawaited(provider.dispose()));
  return provider;
});

/// Real schedule/station data once `GtfsStaticImporter` has populated the
/// GTFS Drift tables; falls back to [mockTransitProvider] (Data Demo) until
/// then, so `TRANSIT_PROVIDER=gtfs` never shows an empty app pre-import.
final gtfsStaticScheduleProvider = Provider<GtfsStaticScheduleProvider>((
  Ref ref,
) {
  return GtfsStaticScheduleProvider(
    database: ref.watch(appDatabaseProvider),
    fallback: ref.watch(mockTransitProvider),
  );
});

// Fallback matrix, by TRANSIT_PROVIDER (see AppEnvironment.provider):
//   mock          -> demo data for everything.
//   gtfs          -> vehicle positions come from HybridTransitRealtimeProvider
//                    when SUPABASE_ENABLED (real GTFS-RT feed, empty today,
//                    merged with Supabase's crowd-sourced/estimated
//                    positions) — otherwise plain GtfsRealtimeTransitProvider
//                    (empty until a real feed URL exists). Trip
//                    updates/alerts always come from the plain GTFS-RT
//                    provider — no crowd-sourced equivalent for those.
//                    Schedule/station data comes from
//                    GtfsStaticScheduleProvider once a feed has been
//                    imported via GtfsStaticImporter (see
//                    docs/backend-local.md) — Data Demo before that.
//   officialApi   -> a self-hosted REST backend for every capability.
//   localSupabase -> a real Supabase-backed provider (see
//                    supabase_transit_provider.dart), but trip search only
//                    resolves direct + single-transfer trips — see that
//                    file's doc comment and ENGINEERING.md's "Known gaps".
final stationProvider = Provider<StationProvider>((Ref ref) {
  return switch (AppEnvironment.provider) {
    TransitProviderKind.gtfs => ref.watch(gtfsStaticScheduleProvider),
    TransitProviderKind.officialApi => ref.watch(officialApiTransitProvider),
    TransitProviderKind.localSupabase => ref.watch(supabaseTransitProvider),
    _ => ref.watch(mockTransitProvider),
  };
});

final transitScheduleProvider = Provider<TransitScheduleProvider>((Ref ref) {
  return switch (AppEnvironment.provider) {
    TransitProviderKind.gtfs => ref.watch(gtfsStaticScheduleProvider),
    TransitProviderKind.officialApi => ref.watch(officialApiTransitProvider),
    TransitProviderKind.localSupabase => ref.watch(supabaseTransitProvider),
    _ => ref.watch(mockTransitProvider),
  };
});

final transitRealtimeProvider = Provider<TransitRealtimeProvider>((Ref ref) {
  return switch (AppEnvironment.provider) {
    TransitProviderKind.gtfs => AppEnvironment.supabaseEnabled
        ? ref.watch(hybridGtfsRealtimeProvider)
        : ref.watch(gtfsRealtimeTransitProvider),
    TransitProviderKind.officialApi => ref.watch(officialApiTransitProvider),
    TransitProviderKind.localSupabase => ref.watch(supabaseTransitProvider),
    _ => ref.watch(mockTransitProvider),
  };
});

final placesProvider = Provider<PlacesProvider>((Ref ref) {
  return switch (AppEnvironment.provider) {
    TransitProviderKind.officialApi => ref.watch(officialApiTransitProvider),
    TransitProviderKind.localSupabase => ref.watch(supabaseTransitProvider),
    _ => ref.watch(mockTransitProvider),
  };
});

/// Live stations, cached locally so a later offline session can still show
/// the last-known list (PRD §19) with an honest "last updated" timestamp
/// instead of silently going blank when the network/provider fails.
final stationListProvider = FutureProvider<List<Station>>((Ref ref) async {
  final database = ref.watch(appDatabaseProvider);
  try {
    final stations = await ref.watch(stationProvider).getStations();
    unawaited(_cacheStations(database, stations));
    return stations;
  } on Object {
    final cached = await database.allCachedStations();
    if (cached.isEmpty) {
      rethrow;
    }
    return cached
        .map(
          (row) =>
              Station.fromJson(jsonDecode(row.payloadJson) as Map<String, Object?>),
        )
        .toList(growable: false);
  }
});

Future<void> _cacheStations(AppDatabase database, List<Station> stations) async {
  try {
    await database.replaceStationCache(
      stations
          .map(
            (station) => CachedStationsCompanion.insert(
              id: station.id,
              code: station.code,
              name: station.name,
              latitude: station.latitude,
              longitude: station.longitude,
              payloadJson: jsonEncode(station.toJson()),
              updatedAt: DateTime.now(),
            ),
          )
          .toList(growable: false),
    );
  } on Object {
    // Caching is a convenience for the offline fallback above — never let a
    // cache-write failure surface to the UI that's just trying to show the
    // station list it already fetched successfully.
  }
}

final departuresProvider = FutureProvider.family<List<Departure>, String>(
  (Ref ref, String stationId) {
    return ref
        .watch(transitScheduleProvider)
        .getStationDepartures(stationId, ref.watch(clockProvider).now());
  },
);

final serviceAlertsProvider = StreamProvider<List<ServiceAlert>>((Ref ref) {
  return ref.watch(transitRealtimeProvider).watchServiceAlerts();
});

final vehiclePositionsProvider = StreamProvider<List<VehiclePosition>>((
  Ref ref,
) {
  return ref.watch(transitRealtimeProvider).watchVehiclePositions();
});

final nearbyPlacesProvider = FutureProvider.family<List<NearbyPlace>, String>(
  (Ref ref, String stationId) async {
    final station = await ref.watch(stationProvider).getStation(stationId);
    if (station == null) {
      return <NearbyPlace>[];
    }
    return ref
        .watch(placesProvider)
        .getNearbyPlaces(
          station.latitude,
          station.longitude,
          PlaceFilter(stationId: stationId),
        );
  },
);
