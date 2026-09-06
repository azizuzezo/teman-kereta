import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../app/config/app_environment.dart';
import '../preferences/preferences_store.dart';

/// Wires real Firebase Cloud Messaging push tokens into
/// `public.device_tokens`, so the `send-push-notification` Edge Function has
/// somewhere to look up who to notify. Entirely gated by
/// [AppEnvironment.firebaseEnabled] — until a human adds a real
/// `google-services.json` (see the Firebase console setup steps), every
/// method here is a no-op so a build without Firebase configured never
/// crashes on startup.
///
/// Mirrors [Supabase.instance.client.auth.onAuthStateChange] the same way
/// `AccountController` does — a token is only meaningful once we know which
/// `public.users` row to attach it to, so registration happens on sign-in,
/// not on app launch.
///
/// `device_id`: `device_info_plus` (the version pinned in this project)
/// no longer exposes a real Android ID — it was removed upstream because the
/// method channel backing it always returned null (see its CHANGELOG).
/// Rather than adding a new dependency for it, this reuses the same
/// "random per-install UUID, generated once and persisted" convention this
/// codebase already established for `StoredPreferences.deviceSessionId`
/// (see `CrowdPositionReporter`) — good enough to distinguish devices for
/// upsert purposes, which is all `device_tokens.device_id` is for.
class PushTokenRegistrar {
  PushTokenRegistrar(this._store);

  final PreferencesStore _store;

  StreamSubscription<AuthState>? _authSubscription;
  StreamSubscription<String>? _tokenRefreshSubscription;

  /// Starts listening for sign-in and token rotation. Safe to call once at
  /// app startup (see `main.dart`) and never disposed — this registrar lives
  /// for the lifetime of the process, same posture as the top-level Firebase
  /// initialization it depends on.
  void start() {
    if (!AppEnvironment.firebaseEnabled) {
      return;
    }

    final auth = Supabase.instance.client.auth;

    final currentUser = auth.currentSession?.user;
    if (currentUser != null) {
      unawaited(_registerCurrentToken(userId: currentUser.id));
    }

    _authSubscription = auth.onAuthStateChange.listen((event) {
      final user = event.session?.user;
      if (user != null) {
        unawaited(_registerCurrentToken(userId: user.id));
      }
    });

    _tokenRefreshSubscription = FirebaseMessaging.instance.onTokenRefresh.listen((
      token,
    ) {
      final user = auth.currentUser;
      if (user != null) {
        unawaited(_upsertToken(userId: user.id, token: token));
      }
    });
  }

  Future<void> _registerCurrentToken({required String userId}) async {
    try {
      await FirebaseMessaging.instance.requestPermission();
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) {
        return;
      }
      await _upsertToken(userId: userId, token: token);
    } on Object catch (e) {
      debugPrint('Push token registration error: $e');
    }
  }

  Future<void> _upsertToken({
    required String userId,
    required String token,
  }) async {
    try {
      final deviceId = await _deviceId();
      await Supabase.instance.client.from('device_tokens').upsert(
        <String, Object?>{
          'user_id': userId,
          'device_id': deviceId,
          'fcm_token': token,
          'platform': 'android',
        },
        onConflict: 'user_id,device_id',
      );
    } on Object catch (e) {
      debugPrint('Push token upsert error: $e');
    }
  }

  Future<String> _deviceId() async {
    final existing = _store.snapshot.deviceSessionId;
    if (existing != null) {
      return existing;
    }
    final generated = const Uuid().v4();
    await _store.setDeviceSessionId(generated);
    return generated;
  }

  void dispose() {
    unawaited(_authSubscription?.cancel());
    unawaited(_tokenRefreshSubscription?.cancel());
  }
}
