import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app.dart';
import 'app/config/app_environment.dart';
import 'core/database/app_database.dart';
import 'core/database/database_provider.dart';
import 'core/preferences/preferences_store.dart';
import 'data/providers/gtfs_static_importer.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AppEnvironment.validateLocalOnly();

  final preferences = SharedPreferencesStore();
  await preferences.load();

  final database = AppDatabase();
  if (AppEnvironment.gtfsStaticEnabled) {
    await _importBundledGtfsFeedIfNeeded(database);
  }

  if (AppEnvironment.supabaseEnabled) {
    await Supabase.initialize(
      url: AppEnvironment.supabaseUrl,
      anonKey: AppEnvironment.supabaseAnonKey,
    );
  }

  final app = ProviderScope(
    overrides: [
      preferencesStoreProvider.overrideWithValue(preferences),
      appDatabaseProvider.overrideWithValue(database),
    ],
    child: const TemanKeretaApp(),
  );

  if (AppEnvironment.crashReportingEnabled) {
    await SentryFlutter.init((options) {
      options.dsn = AppEnvironment.sentryDsn;
      // Free-tier friendly: full error capture, no session/performance
      // sampling that would burn through a free Sentry quota quickly.
      options.tracesSampleRate = 0;
      options.sendDefaultPii = false;
    }, appRunner: () => runApp(app));
  } else {
    runApp(app);
  }
}

/// One-time bootstrap: if no GTFS static feed has been imported yet, load
/// the bundled dev feed asset and import it via the same
/// [GtfsStaticImporter] the manual "Impor jadwal GTFS" settings page uses.
/// Never blocks app startup on failure — a missing/corrupt bundled asset
/// just leaves `TRANSIT_PROVIDER=gtfs` on its existing Data Demo fallback,
/// same as if nothing had ever been imported.
Future<void> _importBundledGtfsFeedIfNeeded(AppDatabase database) async {
  if (AppEnvironment.gtfsStaticZipPath.isEmpty) {
    return;
  }
  if (await database.gtfsStopCount() > 0) {
    return;
  }
  try {
    final bytes = await rootBundle.load(AppEnvironment.gtfsStaticZipPath);
    await GtfsStaticImporter(
      database: database,
    ).importZipBytes(bytes.buffer.asUint8List());
  } on Object {
    // Best-effort bootstrap only — see doc comment above.
  }
}
