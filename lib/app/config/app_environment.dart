import 'package:flutter/foundation.dart';

enum TransitProviderKind { mock, officialApi, localSupabase }

abstract final class AppEnvironment {
  static const String name = String.fromEnvironment(
    'APP_ENV',
    defaultValue: 'remote',
  );

  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://127.0.0.1:54321',
  );

  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://slcttxbxcdrsavgugzdy.supabase.co',
  );

  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNsY3R0eGJ4Y2Ryc2F2Z3VnemR5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODU4NDM5NjksImV4cCI6MjEwMTQxOTk2OX0.o-N_03nF0ZmlurmHM3_ogRDupnXLOPY2ztAU8zU0kbE',
  );

  static const bool supabaseEnabled = bool.fromEnvironment(
    'SUPABASE_ENABLED',
    defaultValue: true,
  );

  static const bool firebaseEnabled = bool.fromEnvironment(
    'FIREBASE_ENABLED',
  );

  static const String providerName = String.fromEnvironment(
    'TRANSIT_PROVIDER',
    defaultValue: 'local_supabase',
  );

  static const String mapStyleUrl = String.fromEnvironment('MAP_STYLE_URL');

  static const String sentryDsn = String.fromEnvironment('SENTRY_DSN');

  static bool get isLocal => name == 'local';

  /// Crash reports never leave the device in local dev, even if a DSN is
  /// set by accident — matches the same "nothing local talks to a remote
  /// service" guarantee as [validateLocalOnly] without needing this to be a
  /// hard StateError like the checks below (a stray SENTRY_DSN isn't a
  /// misconfiguration worth crashing the app over, just something to ignore).
  static bool get crashReportingEnabled => sentryDsn.isNotEmpty && !isLocal;

  static TransitProviderKind get provider => switch (providerName) {
    'official_api' => TransitProviderKind.officialApi,
    'local_supabase' => TransitProviderKind.localSupabase,
    _ => TransitProviderKind.mock,
  };

  static void validateLocalOnly() {
    if (!isLocal || kReleaseMode) {
      return;
    }

    for (final entry in <String, String>{
      'API_BASE_URL': apiBaseUrl,
      if (supabaseEnabled) 'SUPABASE_URL': supabaseUrl,
      if (mapStyleUrl.isNotEmpty) 'MAP_STYLE_URL': mapStyleUrl,
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
