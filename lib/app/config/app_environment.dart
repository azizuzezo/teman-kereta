import 'package:flutter/foundation.dart';

enum TransitProviderKind { mock, gtfs, officialApi, localSupabase }

abstract final class AppEnvironment {
  static const String name = String.fromEnvironment(
    'APP_ENV',
    defaultValue: 'local',
  );

  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://127.0.0.1:54321',
  );

  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'http://127.0.0.1:54321',
  );

  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
  );

  static const bool supabaseEnabled = bool.fromEnvironment(
    'SUPABASE_ENABLED',
  );

  static const bool firebaseEnabled = bool.fromEnvironment(
    'FIREBASE_ENABLED',
  );

  static const String providerName = String.fromEnvironment(
    'TRANSIT_PROVIDER',
    defaultValue: 'mock',
  );

  static const String mapStyleUrl = String.fromEnvironment('MAP_STYLE_URL');

  static const String gtfsRtVehiclePositionsUrl = String.fromEnvironment(
    'GTFS_RT_VEHICLE_POSITIONS_URL',
  );

  static const String gtfsRtTripUpdatesUrl = String.fromEnvironment(
    'GTFS_RT_TRIP_UPDATES_URL',
  );

  static const String gtfsRtAlertsUrl = String.fromEnvironment(
    'GTFS_RT_ALERTS_URL',
  );

  static const int gtfsRtPollSeconds = int.fromEnvironment(
    'GTFS_RT_POLL_SECONDS',
    defaultValue: 30,
  );

  static const String sentryDsn = String.fromEnvironment('SENTRY_DSN');

  /// Whether to auto-import the bundled GTFS Schedule (static) asset at
  /// [gtfsStaticZipPath] on first launch, once, if no GTFS static feed has
  /// been imported yet (see `main.dart`). A manual import via the "Impor
  /// jadwal GTFS" settings page always takes precedence over/after this —
  /// this flag only controls the automatic bootstrap.
  static const bool gtfsStaticEnabled = bool.fromEnvironment(
    'GTFS_STATIC_ENABLED',
  );

  static const String gtfsStaticZipPath = String.fromEnvironment(
    'GTFS_STATIC_ZIP_PATH',
  );

  static bool get isLocal => name == 'local';

  /// Crash reports never leave the device in local dev, even if a DSN is
  /// set by accident — matches the same "nothing local talks to a remote
  /// service" guarantee as [validateLocalOnly] without needing this to be a
  /// hard StateError like the checks below (a stray SENTRY_DSN isn't a
  /// misconfiguration worth crashing the app over, just something to ignore).
  static bool get crashReportingEnabled => sentryDsn.isNotEmpty && !isLocal;

  static TransitProviderKind get provider => switch (providerName) {
    'gtfs' => TransitProviderKind.gtfs,
    'official_api' => TransitProviderKind.officialApi,
    'local_supabase' => TransitProviderKind.localSupabase,
    _ => TransitProviderKind.mock,
  };

  static void validateLocalOnly() {
    if (!isLocal) {
      return;
    }

    for (final entry in <String, String>{
      'API_BASE_URL': apiBaseUrl,
      if (supabaseEnabled) 'SUPABASE_URL': supabaseUrl,
      if (mapStyleUrl.isNotEmpty) 'MAP_STYLE_URL': mapStyleUrl,
      if (gtfsRtVehiclePositionsUrl.isNotEmpty)
        'GTFS_RT_VEHICLE_POSITIONS_URL': gtfsRtVehiclePositionsUrl,
      if (gtfsRtTripUpdatesUrl.isNotEmpty)
        'GTFS_RT_TRIP_UPDATES_URL': gtfsRtTripUpdatesUrl,
      if (gtfsRtAlertsUrl.isNotEmpty) 'GTFS_RT_ALERTS_URL': gtfsRtAlertsUrl,
    }.entries) {
      final uri = Uri.tryParse(entry.value);
      if (uri == null || !_isLocalHost(uri.host)) {
        throw StateError(
          '${entry.key} ditolak dalam APP_ENV=local. '
          'Gunakan localhost, 127.0.0.1, ::1, atau 10.0.2.2.',
        );
      }
    }

    if (firebaseEnabled) {
      throw StateError('Firebase tidak boleh aktif dalam APP_ENV=local.');
    }

    if (kReleaseMode) {
      throw StateError(
        'Build release dinonaktifkan saat APP_ENV=local. Gunakan debug/profile.',
      );
    }
  }

  static bool _isLocalHost(String host) {
    return host == 'localhost' ||
        host == '127.0.0.1' ||
        host == '::1' ||
        host == '10.0.2.2';
  }
}
