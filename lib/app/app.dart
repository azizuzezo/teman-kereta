import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
          child: child ?? const SizedBox.shrink(),
        );
      },
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
