import 'dart:async';
import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart' show Color;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app/config/app_environment.dart';
import '../../core/database/app_database.dart';
import '../../core/database/database_provider.dart';
import '../../core/network/api_client.dart';
import '../../domain/entities/transit_models.dart';
import '../../domain/providers/transit_providers.dart';
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

final supabaseTransitProvider = Provider<SupabaseTransitProvider>((Ref ref) {
  if (!AppEnvironment.supabaseEnabled) {
    throw StateError(
      'TRANSIT_PROVIDER=local_supabase memerlukan SUPABASE_ENABLED=true '
      'dan Supabase.initialize() sudah dipanggil sebelum runApp().',
    );
  }
  return SupabaseTransitProvider(Supabase.instance.client);
});

// Fallback matrix, by TRANSIT_PROVIDER (see AppEnvironment.provider):
//   mock          -> demo data for everything.
//   officialApi   -> a self-hosted REST backend for every capability.
//   localSupabase -> a real Supabase-backed provider (see
//                    supabase_transit_provider.dart), but trip search only
//                    resolves direct + single-transfer trips — see that
//                    file's doc comment and ENGINEERING.md's "Known gaps".
final stationProvider = Provider<StationProvider>((Ref ref) {
  return switch (AppEnvironment.provider) {
    TransitProviderKind.officialApi => ref.watch(officialApiTransitProvider),
    TransitProviderKind.localSupabase => ref.watch(supabaseTransitProvider),
    _ => ref.watch(mockTransitProvider),
  };
});

final transitScheduleProvider = Provider<TransitScheduleProvider>((Ref ref) {
  return switch (AppEnvironment.provider) {
    TransitProviderKind.officialApi => ref.watch(officialApiTransitProvider),
    TransitProviderKind.localSupabase => ref.watch(supabaseTransitProvider),
    _ => ref.watch(mockTransitProvider),
  };
});

final transitRealtimeProvider = Provider<TransitRealtimeProvider>((Ref ref) {
  return switch (AppEnvironment.provider) {
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

/// Real per-line brand colors from `public.lines` ({code: color}), used by
/// the live map to draw each line's polyline/legend swatch in its actual
/// KAI Commuterline color instead of an arbitrary index-based palette.
/// Supabase-specific — matches `TRANSIT_PROVIDER=local_supabase`, the only
/// provider with a real `lines` table; any other provider (or a fetch
/// failure) yields an empty map, and callers fall back to a neutral grey.
final lineColorsProvider = FutureProvider<Map<String, Color>>((Ref ref) async {
  if (!AppEnvironment.supabaseEnabled) {
    return const <String, Color>{};
  }
  try {
    final rows = await Supabase.instance.client.from('lines').select('code, color');
    final colors = <String, Color>{};
    for (final row in (rows as List<dynamic>).cast<Map<String, dynamic>>()) {
      final code = row['code'] as String?;
      final hex = row['color'] as String?;
      if (code == null || hex == null || hex.isEmpty) {
        continue;
      }
      final parsed = int.tryParse(hex.replaceFirst('#', '0xFF'));
      if (parsed != null) {
        colors[code] = Color(parsed);
      }
    }
    return colors;
  } on Object {
    return const <String, Color>{};
  }
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
