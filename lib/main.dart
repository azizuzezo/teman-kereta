import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app.dart';
import 'app/config/app_environment.dart';
import 'core/database/app_database.dart';
import 'core/database/database_provider.dart';
import 'core/notifications/local_notification_service.dart';
import 'core/notifications/push_token_registrar.dart';
import 'core/preferences/preferences_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    AppEnvironment.validateLocalOnly();
  } on Object catch (e) {
    debugPrint('AppEnvironment validation warning: $e');
  }

  final preferences = SharedPreferencesStore();
  try {
    await preferences.load();
  } on Object catch (e) {
    debugPrint('Preferences load error: $e');
  }

  final database = AppDatabase();

  if (AppEnvironment.supabaseEnabled && AppEnvironment.supabaseUrl.isNotEmpty) {
    try {
      await Supabase.initialize(
        url: AppEnvironment.supabaseUrl,
        anonKey: AppEnvironment.supabaseAnonKey,
      );
    } on Object catch (e) {
      debugPrint('Supabase initialize error: $e');
    }
  }

  // Real push notifications (FCM). Guarded end-to-end by
  // `AppEnvironment.firebaseEnabled` and wrapped in try/catch so a build
  // without `android/app/google-services.json` yet (this checkout doesn't
  // have one — see the Firebase console setup steps) never fails to start.
  // `Firebase.initializeApp()` itself is not runtime-tested by this change;
  // it is only verified statically until that file exists.
  if (AppEnvironment.firebaseEnabled) {
    try {
      await Firebase.initializeApp();
    } on Object catch (e) {
      debugPrint('Firebase initialize error: $e');
    }
  }

  final pushNotificationService = LocalNotificationService(
    onShown: (type, title, body) {
      unawaited(
        database.logNotification(
          NotificationLogEntriesCompanion.insert(
            notificationType: type,
            title: title,
            body: body,
            sentAt: DateTime.now(),
          ),
        ),
      );
    },
  );

  if (AppEnvironment.firebaseEnabled) {
    try {
      PushTokenRegistrar(preferences).start();
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        final title = message.notification?.title;
        final body = message.notification?.body;
        if (title == null || body == null) {
          return;
        }
        unawaited(
          pushNotificationService.showRemotePush(title: title, body: body),
        );
      });
    } on Object catch (e) {
      debugPrint('Push notification setup error: $e');
    }
  }

  final app = ProviderScope(
    overrides: [
      preferencesStoreProvider.overrideWithValue(preferences),
      appDatabaseProvider.overrideWithValue(database),
    ],
    child: const TemanKeretaApp(),
  );

  if (AppEnvironment.crashReportingEnabled) {
    try {
      await SentryFlutter.init((options) {
        options.dsn = AppEnvironment.sentryDsn;
        options.tracesSampleRate = 0;
        options.sendDefaultPii = false;
      }, appRunner: () => runApp(app));
      return;
    } on Object catch (e) {
      debugPrint('Sentry init error: $e');
    }
  }

  runApp(app);
}
