import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/config/app_environment.dart';
import '../../../core/preferences/preferences_store.dart';
import 'auth_errors.dart';

const _unavailable = 'Layanan akun belum tersedia. Silakan hubungi admin.';

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

  /// `needsVerification` is true when the account exists but its email was
  /// never confirmed: the caller sends the user to the code screen.
  Future<({String? error, bool needsVerification})> signIn({
    required String email,
    required String password,
  }) async {
    if (!AppEnvironment.supabaseEnabled) {
      return (error: _unavailable, needsVerification: false);
    }
    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      return (error: null, needsVerification: false);
    } on Object catch (error) {
      final failure = mapAuthError(error, AuthFlow.signIn);
      return (
        error: failure.message,
        needsVerification: failure.needsVerification,
      );
    }
  }

  /// Creates the account and makes Supabase email a 6 digit code.
  ///
  /// With "Confirm email" enabled on the project Auth returns no session
  /// until the code is verified, so `needsEmailConfirmation` is true and the
  /// router gate (`currentUser != null`) keeps the user out of the app.
  /// If the project has confirmation switched off Auth hands back a session
  /// at once and `needsEmailConfirmation` is false.
  Future<({String? error, bool needsEmailConfirmation, bool alreadyRegistered})>
  signUp({
    required String email,
    required String password,
    String? displayName,
  }) async {
    if (!AppEnvironment.supabaseEnabled) {
      return (
        error: _unavailable,
        needsEmailConfirmation: false,
        alreadyRegistered: false,
      );
    }
    try {
      final response = await Supabase.instance.client.auth.signUp(
        email: email,
        password: password,
        data: displayName != null && displayName.trim().isNotEmpty
            ? <String, dynamic>{'display_name': displayName.trim()}
            : null,
      );
      // An already confirmed address does not raise an error when
      // confirmation is on (that would leak which emails exist). Auth returns
      // an obfuscated user with no identities and sends no email.
      if (response.session == null &&
          (response.user?.identities?.isEmpty ?? false)) {
        return (
          error: mapAuthError(
            const AuthException('', code: 'user_already_exists'),
            AuthFlow.signUp,
          ).message,
          needsEmailConfirmation: false,
          alreadyRegistered: true,
        );
      }
      final needsEmailConfirmation = response.session == null;
      if (needsEmailConfirmation) OtpCooldown.markSent(email);
      return (
        error: null,
        needsEmailConfirmation: needsEmailConfirmation,
        alreadyRegistered: false,
      );
    } on Object catch (error) {
      final failure = mapAuthError(error, AuthFlow.signUp);
      return (
        error: failure.message,
        needsEmailConfirmation: false,
        alreadyRegistered: failure.alreadyRegistered,
      );
    }
  }

  /// Checks the 6 digit code from the sign-up email. Returns an error message
  /// or null on success, in which case Auth has issued a session.
  Future<String?> verifySignupOtp({
    required String email,
    required String code,
  }) async {
    if (!AppEnvironment.supabaseEnabled) return _unavailable;
    try {
      await Supabase.instance.client.auth.verifyOTP(
        type: OtpType.signup,
        email: email,
        token: code,
      );
      return null;
    } on Object catch (error) {
      return mapAuthError(error, AuthFlow.verifyOtp).message;
    }
  }

  /// Emails a fresh code. Returns an error message or null on success.
  Future<String?> resendSignupOtp({required String email}) async {
    if (!AppEnvironment.supabaseEnabled) return _unavailable;
    try {
      await Supabase.instance.client.auth.resend(
        type: OtpType.signup,
        email: email,
      );
      OtpCooldown.markSent(email);
      return null;
    } on Object catch (error) {
      final failure = mapAuthError(error, AuthFlow.resendOtp);
      if (failure.rateLimited) OtpCooldown.markSent(email);
      return failure.message;
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

  /// Permanently deletes the signed-in account and everything attached to it
  /// (profile, preferences, favorites, device tokens, follows, forum posts,
  /// comments, likes) via the `delete_my_account` RPC, whose cascades do the
  /// database side. Uploaded files are removed first, best-effort, since a
  /// storage hiccup shouldn't stop someone from deleting their account.
  /// Returns an error message on failure, or null on success.
  Future<String?> deleteAccount() async {
    if (!AppEnvironment.supabaseEnabled) {
      return 'Layanan akun belum tersedia.';
    }
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) return 'Masuk dulu untuk menghapus akun.';
    try {
      await _removeUserFiles('avatars', user.id);
      await _removeUserFiles('forum-post-images', user.id);
    } on Object {
      // Best-effort; see above.
    }
    try {
      await client.rpc<void>('delete_my_account');
    } on Object {
      return 'Gagal menghapus akun. Periksa koneksi lalu coba lagi.';
    }
    // The server-side session is gone with the account, so only clear the
    // local one; a server round-trip here would just fail.
    try {
      await client.auth.signOut(scope: SignOutScope.local);
    } on Object {
      // Nothing left to clean up on the server.
    }
    return null;
  }

  /// Removes every object under `<bucket>/<prefix>/`, descending into the
  /// per-post subfolders forum images are stored in.
  Future<void> _removeUserFiles(String bucket, String prefix) async {
    final storage = Supabase.instance.client.storage.from(bucket);
    // `list` returns at most one page (100 by default), so walk every page
    // before deleting; otherwise files past the first page would be orphaned
    // for good once the account (and the RLS that lets us reach them) is gone.
    const pageSize = 100;
    final entries = <FileObject>[];
    for (var offset = 0; ; offset += pageSize) {
      final page = await storage.list(
        path: prefix,
        searchOptions: SearchOptions(limit: pageSize, offset: offset),
      );
      entries.addAll(page);
      if (page.length < pageSize) {
        break;
      }
    }
    final files = <String>[];
    for (final entry in entries) {
      // Folders come back without an id; files have one.
      if (entry.id == null) {
        await _removeUserFiles(bucket, '$prefix/${entry.name}');
      } else {
        files.add('$prefix/${entry.name}');
      }
    }
    if (files.isNotEmpty) {
      await storage.remove(files);
    }
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
    } on Object catch (error) {
      return mapAuthError(error, AuthFlow.resetPassword).message;
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
