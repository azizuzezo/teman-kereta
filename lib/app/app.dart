import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/app_config/presentation/app_config_controller.dart';
import '../features/settings/presentation/settings_controller.dart';
import 'config/app_environment.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';

class TemanKeretaApp extends ConsumerWidget {
  const TemanKeretaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    AppEnvironment.validateLocalOnly();
    final settings = ref.watch(settingsControllerProvider);
    final router = ref.watch(appRouterProvider);
    final maintenanceMode =
        ref.watch(appConfigControllerProvider).maintenanceMode;

    return MaterialApp.router(
      title: 'Teman Kereta',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: settings.themeMode,
      routerConfig: router,
      locale: const Locale('id', 'ID'),
      supportedLocales: const <Locale>[Locale('id', 'ID')],
      localizationsDelegates: const <LocalizationsDelegate<Object>>[
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) {
        final media = MediaQuery.of(context);
        return MediaQuery(
          data: media.copyWith(
            disableAnimations: settings.reduceMotion || media.disableAnimations,
            textScaler: _ComposedTextScaler(media.textScaler, settings.textScale),
          ),
          child: maintenanceMode
              ? const _MaintenanceScreen()
              : (child ?? const SizedBox.shrink()),
        );
      },
    );
  }
}

/// Shown instead of the whole app when the admin panel's "Mode maintenance"
/// toggle (PRD §36, `public.app_config.maintenance_mode`) is on — a real,
/// admin-controlled kill switch, not just a Settings page field with no
/// effect on mobile.
class _MaintenanceScreen extends StatelessWidget {
  const _MaintenanceScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Icon(Icons.build_circle_outlined, size: 56),
                const SizedBox(height: 16),
                Text(
                  'Sedang dalam pemeliharaan',
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Teman Kereta sedang diperbarui. Silakan coba lagi sebentar lagi.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Layers the user's in-app text-scale preference (PRD §33) on top of the
/// device's own accessibility text scale, rather than replacing it — a user
/// who already increased system text size shouldn't see it reset by TK.
class _ComposedTextScaler extends TextScaler {
  const _ComposedTextScaler(this._base, this._factor);

  final TextScaler _base;
  final double _factor;

  @override
  double scale(double fontSize) => _base.scale(fontSize) * _factor;

  @override
  double get textScaleFactor => _base.textScaleFactor * _factor;
}
