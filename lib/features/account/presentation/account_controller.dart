import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/config/app_environment.dart';
import '../../../core/preferences/preferences_store.dart';

/// An account is optional. Guest mode preferences and display names are stored
/// on device, while authenticated accounts sync to Supabase when enabled.
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
      return 'Layanan akun belum tersedia. Silakan hubungi admin.';
    }
    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      return null;
    } on Object {
      return 'Email atau kata sandi salah. Silakan coba lagi.';
    }
  }

  /// `needsEmailConfirmation` is true when Auth requires confirming the email
  /// before a session is issued — caller tells the user to check inbox.
  Future<({String? error, bool needsEmailConfirmation})> signUp({
    required String email,
    required String password,
    String? displayName,
  }) async {
    if (!AppEnvironment.supabaseEnabled) {
      return (
        error: 'Layanan akun belum tersedia. Silakan hubungi admin.',
        needsEmailConfirmation: false,
      );
    }
    try {
      await Supabase.instance.client.auth.signUp(
        email: email,
        password: password,
        data: displayName != null ? {'display_name': displayName} : null,
      );
      if (displayName != null && displayName.trim().isNotEmpty) {
        await updateDisplayName(displayName.trim());
      }
      final needsEmailConfirmation = Supabase.instance.client.auth.currentSession == null;
      return (error: null, needsEmailConfirmation: needsEmailConfirmation);
    } on Object {
      return (
        error: 'Pendaftaran gagal. Pastikan email belum terdaftar dan coba lagi.',
        needsEmailConfirmation: false,
      );
    }
  }

  /// Reads this account's `display_name` — checks:
  /// 1. `user_metadata['display_name']` set during signUp (always available offline)
  /// 2. `public.users.display_name` from DB
  /// 3. Local guest preferences fallback
  Future<String?> fetchDisplayName() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      return ref.read(preferencesStoreProvider).snapshot.guestDisplayName;
    }
    // First check metadata stored at registration time — always present,
    // no network round-trip needed.
    final metaName = user.userMetadata?['display_name'] as String?;
    if (metaName != null && metaName.trim().isNotEmpty) {
      return metaName.trim();
    }
    try {
      final row = await Supabase.instance.client
          .from('users')
          .select('display_name')
          .eq('id', user.id)
          .maybeSingle();
      return (row?['display_name'] as String?) ??
          ref.read(preferencesStoreProvider).snapshot.guestDisplayName;
    } on Object {
      return ref.read(preferencesStoreProvider).snapshot.guestDisplayName;
    }
  }

  Future<String?> updateDisplayName(String displayName) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      await ref.read(preferencesStoreProvider).setGuestDisplayName(displayName);
      return null;
    }
    try {
      await Supabase.instance.client
          .from('users')
          .update({'display_name': displayName})
          .eq('id', user.id);
      await ref.read(preferencesStoreProvider).setGuestDisplayName(displayName);
      return null;
    } on Object {
      await ref.read(preferencesStoreProvider).setGuestDisplayName(displayName);
      return null;
    }
  }

  /// Reads this account's `username` from `public.users`. Unlike display
  /// name there is no local/guest fallback — username is a Supabase-only
  /// concept — so a signed-out user or one who hasn't set one yet gets null.
  Future<String?> fetchUsername() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return null;
    try {
      final row = await Supabase.instance.client
          .from('users')
          .select('username')
          .eq('id', user.id)
          .maybeSingle();
      return row?['username'] as String?;
    } on Object {
      return null;
    }
  }

  /// Returns an error message on failure, or null on success. Surfaces the
  /// unique-violation case (username already taken) with a friendly message
  /// so the caller can show it inline instead of a generic failure.
  Future<String?> updateUsername(String username) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      return 'Masuk untuk mengatur username.';
    }
    try {
      await Supabase.instance.client
          .from('users')
          .update({'username': username})
          .eq('id', user.id);
      return null;
    } on PostgrestException catch (error) {
      if (error.code == '23505') {
        return 'Username sudah dipakai, coba yang lain.';
      }
      return 'Gagal menyimpan username. Coba lagi.';
    } on Object {
      return 'Gagal menyimpan username. Coba lagi.';
    }
  }

  /// Reads this account's `avatar_url` from `public.users`.
  Future<String?> fetchAvatarUrl() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return null;
    try {
      final row = await Supabase.instance.client
          .from('users')
          .select('avatar_url')
          .eq('id', user.id)
          .maybeSingle();
      return row?['avatar_url'] as String?;
    } on Object {
      return null;
    }
  }

  Future<String?> updateAvatarUrl(String avatarUrl) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      return 'Masuk untuk mengubah foto profil.';
    }
    try {
      await Supabase.instance.client
          .from('users')
          .update({'avatar_url': avatarUrl})
          .eq('id', user.id);
      return null;
    } on Object {
      return 'Gagal menyimpan foto profil. Coba lagi.';
    }
  }

  /// Follower/following counts for this account, read directly off
  /// `public.users` (maintained server-side by a DB trigger — never
  /// computed or cached client-side).
  Future<({int followers, int following})> fetchFollowCounts() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return (followers: 0, following: 0);
    try {
      final row = await Supabase.instance.client
          .from('users')
          .select('follower_count, following_count')
          .eq('id', user.id)
          .maybeSingle();
      return (
        followers: (row?['follower_count'] as int?) ?? 0,
        following: (row?['following_count'] as int?) ?? 0,
      );
    } on Object {
      return (followers: 0, following: 0);
    }
  }

  Future<void> signOut() async {
    if (!AppEnvironment.supabaseEnabled) return;
    await Supabase.instance.client.auth.signOut();
  }

  /// Sends a password reset email. Returns an error string or null on success.
  Future<String?> resetPassword({required String email}) async {
    if (!AppEnvironment.supabaseEnabled) {
      return 'Layanan akun belum tersedia.';
    }
    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(
        email,
        redirectTo: 'temankereta://app/account/reset-password',
      );
      return null;
    } on Object {
      return 'Gagal mengirim email reset. Silakan coba lagi.';
    }
  }
}

final accountControllerProvider =
    NotifierProvider<AccountController, AsyncValue<User?>>(
      AccountController.new,
    );

/// Re-fetches whenever the signed-in account changes or local preferences update.
final userDisplayNameProvider = FutureProvider<String?>((ref) async {
  final user = ref.watch(accountControllerProvider).asData?.value;
  if (user == null) {
    return ref.watch(preferencesStoreProvider).snapshot.guestDisplayName;
  }
  return ref.read(accountControllerProvider.notifier).fetchDisplayName();
});

/// Null when signed out or the account hasn't set a username yet.
final userUsernameProvider = FutureProvider<String?>((ref) async {
  final user = ref.watch(accountControllerProvider).asData?.value;
  if (user == null) return null;
  return ref.read(accountControllerProvider.notifier).fetchUsername();
});

/// Null when signed out or no avatar has been uploaded yet.
final userAvatarUrlProvider = FutureProvider<String?>((ref) async {
  final user = ref.watch(accountControllerProvider).asData?.value;
  if (user == null) return null;
  return ref.read(accountControllerProvider.notifier).fetchAvatarUrl();
});

final userFollowCountsProvider =
    FutureProvider<({int followers, int following})>((ref) async {
      final user = ref.watch(accountControllerProvider).asData?.value;
      if (user == null) return (followers: 0, following: 0);
      return ref.read(accountControllerProvider.notifier).fetchFollowCounts();
    });
