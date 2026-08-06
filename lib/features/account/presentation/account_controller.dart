import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/config/app_environment.dart';
import '../../../core/platform/device_identity.dart';

/// An account is entirely optional — see PrivacyPage/onboarding copy. This
/// never replaces the local-only guest mode this app has always defaulted
/// to; it only adds a real, opt-in way to sign in for whoever wants one
/// (e.g. for cross-device sync, added on top of this later). When
/// `SUPABASE_ENABLED` is false there is nothing to authenticate against, so
/// every method here is a deliberate no-op rather than throwing — matching
/// this project's existing "no real Supabase = no real network features"
/// posture (see CrowdPositionReporter for the same pattern).
class AccountController extends Notifier<AsyncValue<User?>> {
  @override
  AsyncValue<User?> build() {
    if (!AppEnvironment.supabaseEnabled) {
      return const AsyncValue.data(null);
    }

    final auth = Supabase.instance.client.auth;
    final subscription = auth.onAuthStateChange.listen((event) {
      state = AsyncValue.data(event.session?.user);
    });
    ref.onDispose(subscription.cancel);
    return AsyncValue.data(auth.currentSession?.user);
  }

  Future<String?> signIn({required String email, required String password}) async {
    if (!AppEnvironment.supabaseEnabled) {
      return 'Akun tidak tersedia dalam mode ini.';
    }
    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      unawaited(_claimTrialIfSignedIn());
      return null;
    } on AuthException catch (error) {
      return error.message;
    } on Object {
      return 'Gagal masuk. Periksa koneksi internet lalu coba lagi.';
    }
  }

  /// `needsEmailConfirmation` is true when Supabase Auth requires confirming
  /// the email before a session is issued (no `currentSession` right after
  /// `signUp()` succeeds) — the caller should tell the user to check their
  /// inbox rather than silently treating this the same as an immediate
  /// sign-in.
  Future<({String? error, bool needsEmailConfirmation})> signUp({
    required String email,
    required String password,
  }) async {
    if (!AppEnvironment.supabaseEnabled) {
      return (error: 'Akun tidak tersedia dalam mode ini.', needsEmailConfirmation: false);
    }
    try {
      await Supabase.instance.client.auth.signUp(email: email, password: password);
      final needsEmailConfirmation = Supabase.instance.client.auth.currentSession == null;
      unawaited(_claimTrialIfSignedIn());
      return (error: null, needsEmailConfirmation: needsEmailConfirmation);
    } on AuthException catch (error) {
      return (error: error.message, needsEmailConfirmation: false);
    } on Object {
      return (
        error: 'Gagal mendaftar. Periksa koneksi internet lalu coba lagi.',
        needsEmailConfirmation: false,
      );
    }
  }

  /// Reads this account's `display_name` from `public.users` — the Auth
  /// `User` object itself doesn't carry it (it's a separate profile table).
  Future<String?> fetchDisplayName() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return null;
    try {
      final row = await Supabase.instance.client
          .from('users')
          .select('display_name')
          .eq('id', user.id)
          .maybeSingle();
      return row?['display_name'] as String?;
    } on Object {
      return null;
    }
  }

  Future<String?> updateDisplayName(String displayName) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return 'Anda belum masuk.';
    try {
      await Supabase.instance.client
          .from('users')
          .update({'display_name': displayName})
          .eq('id', user.id);
      return null;
    } on Object {
      return 'Gagal menyimpan nama. Coba lagi.';
    }
  }

  Future<void> signOut() async {
    if (!AppEnvironment.supabaseEnabled) return;
    await Supabase.instance.client.auth.signOut();
  }

  /// Grants (or resolves) this account's premium free-trial entitlement,
  /// tied to this physical device — see `claim_trial()` in
  /// `20260806140000_premium_subscriptions.sql`. Safe to call redundantly:
  /// the RPC is idempotent per-user, and email-confirmation Supabase
  /// projects don't return a session from `signUp()` until confirmed, so
  /// this is also called from `signIn()` to cover a user's first real
  /// post-confirmation login. Never blocks sign-in/sign-up on failure —
  /// this is a bonus, not a precondition for using the app.
  Future<void> _claimTrialIfSignedIn() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    try {
      final deviceId = await DeviceIdentity.androidId();
      await Supabase.instance.client.rpc(
        'claim_trial',
        params: {'p_device_id': deviceId},
      );
    } on Object {
      // Best-effort only — see doc comment above.
    }
  }
}

final accountControllerProvider =
    NotifierProvider<AccountController, AsyncValue<User?>>(
      AccountController.new,
    );

/// Re-fetches whenever the signed-in account changes (sign-in/out/switch).
final userDisplayNameProvider = FutureProvider<String?>((ref) async {
  final user = ref.watch(accountControllerProvider).asData?.value;
  if (user == null) return null;
  return ref.read(accountControllerProvider.notifier).fetchDisplayName();
});
