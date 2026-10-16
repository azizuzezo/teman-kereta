import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/config/app_environment.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/notifications/local_notification_service.dart';
import '../../../core/updates/update_checker.dart';
import '../../../core/widgets/tk_components.dart';
import '../../account/presentation/account_controller.dart';
import '../../account/presentation/delete_account_dialog.dart';
import 'edit_display_name_dialog.dart';
import 'edit_username_dialog.dart';
import 'permission_status.dart';
import 'settings_controller.dart';
import 'widgets/theme_switcher_card.dart';

/// Profile tab, top to bottom: profile card, Sosial, Pengaturan, Tampilan,
/// Perjalanan, Bantuan, and last (visually apart) the account actions.
class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    // Permission rows show live OS state, which can change in the system
    // settings screen while this tab stays alive in the background.
    _lifecycle = AppLifecycleListener(
      onResume: () => ref.invalidate(devicePermissionStatusProvider),
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  void _refreshIdentity() {
    ref
      ..invalidate(userDisplayNameProvider)
      ..invalidate(userUsernameProvider)
      ..invalidate(userAvatarUrlProvider)
      ..invalidate(userFollowCountsProvider)
      ..invalidate(devicePermissionStatusProvider);
  }

  /// Pushes a settings page and re-reads permission state when it closes.
  void _openSettings(String location) {
    unawaited(
      context.push<void>(location).then((_) {
        if (mounted) ref.invalidate(devicePermissionStatusProvider);
      }),
    );
  }

  Future<void> _requestNotificationPermission() async {
    final granted = await ref
        .read(localNotificationServiceProvider)
        .requestPermission();
    ref.invalidate(devicePermissionStatusProvider);
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          granted
              ? 'Notifikasi perangkat diizinkan.'
              : 'Notifikasi belum diizinkan. Aktifkan lewat pengaturan '
                    'Android.',
        ),
        action: granted
            ? null
            : SnackBarAction(
                label: 'Buka',
                onPressed: () => unawaited(Geolocator.openAppSettings()),
              ),
      ),
    );
  }

  Future<void> _confirmSignOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Keluar dari akun?'),
        content: const Text(
          'Kamu perlu masuk lagi untuk memakai Teman Kereta. Data di '
          'perangkat ini tidak dihapus.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await ref.read(accountControllerProvider.notifier).signOut();
  }

  @override
  Widget build(BuildContext context) {
    final settingsController = ref.read(settingsControllerProvider.notifier);
    final account = ref.watch(accountControllerProvider).asData?.value;
    final nameAsync = ref.watch(userDisplayNameProvider);
    final usernameAsync = ref.watch(userUsernameProvider);
    final avatarAsync = ref.watch(userAvatarUrlProvider);
    final followAsync = ref.watch(userFollowCountsProvider);
    final permissions = ref.watch(devicePermissionStatusProvider);
    final version = ref
        .watch(packageInfoProvider)
        .whenOrNull(data: (info) => 'Versi ${info.version}');

    final identity = <AsyncValue<Object?>>[
      nameAsync,
      usernameAsync,
      avatarAsync,
      followAsync,
    ];
    final loading = identity.any((v) => v.isLoading && !v.hasValue);
    final failed = !loading && identity.any((v) => v.hasError && !v.hasValue);

    final user = AppEnvironment.supabaseEnabled ? account : null;
    final signedIn = user != null;
    final followers = followAsync.asData?.value.followers ?? 0;
    final following = followAsync.asData?.value.following ?? 0;
    final permissionData =
        permissions.asData?.value ?? const <String, Object?>{};

    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            _refreshIdentity();
            await ref.read(userDisplayNameProvider.future);
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: <Widget>[
              if (loading)
                const _ProfileCardSkeleton()
              else if (failed)
                _ProfileLoadError(onRetry: _refreshIdentity)
              else
                _ProfileCard(
                  displayName: nameAsync.asData?.value,
                  username: usernameAsync.asData?.value,
                  avatarUrl: avatarAsync.asData?.value,
                  signedIn: signedIn,
                  guestCanSignIn:
                      AppEnvironment.supabaseEnabled && user == null,
                  followers: followers,
                  following: following,
                  onAvatarTap: signedIn
                      ? () => _pickAndUploadAvatar(context, ref)
                      : null,
                  onEditName: () => showEditDisplayNameDialog(
                    context,
                    ref,
                    currentName: nameAsync.asData?.value,
                  ),
                  onSetUsername: () => showEditUsernameDialog(
                    context,
                    ref,
                    currentUsername: usernameAsync.asData?.value,
                  ),
                  onFollowers: () =>
                      context.push('/social/followers/${user?.id}'),
                  onFollowing: () =>
                      context.push('/social/following/${user?.id}'),
                  onSignIn: () => context.push('/account/login'),
                ),
              if (user != null) ...<Widget>[
                const SizedBox(height: 20),
                const TkSectionLabel('Sosial'),
                TkRowGroup(
                  children: <Widget>[
                    TkRow(
                      icon: Icons.person_search_outlined,
                      title: 'Cari pengguna',
                      onTap: () => context.push('/social/search'),
                    ),
                    TkRow(
                      icon: Icons.group_outlined,
                      title: 'Pengikut',
                      trailing: _CountTrailing(followers),
                      onTap: () => context.push('/social/followers/${user.id}'),
                    ),
                    TkRow(
                      icon: Icons.person_add_alt_1_outlined,
                      title: 'Mengikuti',
                      trailing: _CountTrailing(following),
                      onTap: () => context.push('/social/following/${user.id}'),
                    ),
                    TkRow(
                      icon: Icons.block_rounded,
                      title: 'Pengguna diblokir',
                      onTap: () => context.push('/blocked-users'),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 20),
              const TkSectionLabel('Pengaturan'),
              TkRowGroup(
                children: <Widget>[
                  TkRow(
                    icon: Icons.location_on_outlined,
                    title: 'Lokasi',
                    subtitle: permissions.isLoading && !permissions.hasValue
                        ? 'Memeriksa izin'
                        : locationPermissionSummary(permissionData),
                    onTap: () => _openSettings('/settings/location'),
                  ),
                  TkRow(
                    icon: Icons.notifications_active_outlined,
                    title: 'Aktifkan notifikasi',
                    subtitle: permissions.isLoading && !permissions.hasValue
                        ? 'Memeriksa izin'
                        : notificationPermissionSummary(permissionData),
                    onTap: _requestNotificationPermission,
                  ),
                  TkRow(
                    icon: Icons.notifications_none_rounded,
                    title: 'Pengaturan notifikasi',
                    onTap: () => _openSettings('/settings/notifications'),
                  ),
                  TkRow(
                    icon: Icons.accessibility_new_rounded,
                    title: 'Aksesibilitas',
                    onTap: () => _openSettings('/settings/accessibility'),
                  ),
                  TkRow(
                    icon: Icons.volume_up_rounded,
                    title: 'Tes suara',
                    onTap: () => _openSettings('/settings/sound-test'),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const TkSectionLabel('Tampilan'),
              const ThemeSwitcherCard(),
              const SizedBox(height: 20),
              const TkSectionLabel('Perjalanan'),
              TkRowGroup(
                children: <Widget>[
                  TkRow(
                    icon: Icons.history_rounded,
                    title: 'Riwayat perjalanan',
                    onTap: () => context.push('/history'),
                  ),
                  TkRow(
                    icon: Icons.insights_rounded,
                    title: 'Rekap perjalanan',
                    onTap: () => context.push('/history/recap'),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const TkSectionLabel('Bantuan'),
              TkRowGroup(
                children: <Widget>[
                  TkRow(
                    icon: Icons.help_outline_rounded,
                    title: 'Pusat bantuan',
                    onTap: () => context.push('/help'),
                  ),
                  TkRow(
                    icon: Icons.flag_outlined,
                    title: 'Laporkan masalah',
                    onTap: () => context.push('/report'),
                  ),
                  TkRow(
                    icon: Icons.privacy_tip_outlined,
                    title: 'Kebijakan privasi',
                    onTap: () => context.push('/privacy'),
                  ),
                  TkRow(
                    icon: Icons.info_outline_rounded,
                    title: 'Tentang & pembaruan',
                    subtitle: version,
                    onTap: () => context.push('/about'),
                  ),
                  TkRow(
                    icon: Icons.replay_rounded,
                    title: 'Ulangi pengenalan',
                    subtitle: 'Tidak menghapus favorit atau cache.',
                    onTap: () async {
                      await settingsController.resetOnboarding();
                      if (context.mounted) {
                        context.go('/onboarding');
                      }
                    },
                  ),
                ],
              ),
              if (signedIn) ...<Widget>[
                const SizedBox(height: 36),
                const TkSectionLabel('Akun'),
                TkRowGroup(
                  children: <Widget>[
                    TkRow(
                      icon: Icons.logout_rounded,
                      title: 'Keluar',
                      destructive: true,
                      onTap: _confirmSignOut,
                    ),
                    TkRow(
                      icon: Icons.delete_outline_rounded,
                      title: 'Hapus akun',
                      subtitle: 'Menghapus akun dan datanya secara permanen.',
                      destructive: true,
                      onTap: () => confirmAndDeleteAccount(context, ref),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickAndUploadAvatar(BuildContext context, WidgetRef ref) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 1600,
    );
    if (picked == null) return;
    try {
      final bytes = await picked.readAsBytes();
      final path = '$userId/avatar.jpg';
      await Supabase.instance.client.storage
          .from('avatars')
          .uploadBinary(
            path,
            bytes,
            fileOptions: const FileOptions(
              upsert: true,
              contentType: 'image/jpeg',
            ),
          );
      final publicUrl = Supabase.instance.client.storage
          .from('avatars')
          .getPublicUrl(path);
      // Cache-bust: re-uploading keeps the same path, so append a version
      // query param or the image cache (and other viewers) keep showing
      // the stale bytes they already cached for that URL.
      final versionedUrl =
          '$publicUrl?v=${DateTime.now().millisecondsSinceEpoch}';
      final error = await ref
          .read(accountControllerProvider.notifier)
          .updateAvatarUrl(versionedUrl);
      if (!context.mounted) return;
      if (error != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error)));
        return;
      }
      ref.invalidate(userAvatarUrlProvider);
    } on Object {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gagal mengunggah foto profil. Coba lagi.'),
        ),
      );
    }
  }
}

/// The one profile card: photo, name, @username, follower counts. Nothing
/// else lives in it when signed in; guests get one sign-in button instead.
class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.displayName,
    required this.username,
    required this.avatarUrl,
    required this.signedIn,
    required this.guestCanSignIn,
    required this.followers,
    required this.following,
    required this.onAvatarTap,
    required this.onEditName,
    required this.onSetUsername,
    required this.onFollowers,
    required this.onFollowing,
    required this.onSignIn,
  });

  final String? displayName;
  final String? username;
  final String? avatarUrl;
  final bool signedIn;
  final bool guestCanSignIn;
  final int followers;
  final int following;
  final VoidCallback? onAvatarTap;
  final VoidCallback onEditName;
  final VoidCallback onSetUsername;
  final VoidCallback onFollowers;
  final VoidCallback onFollowing;
  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final textTheme = Theme.of(context).textTheme;
    final name = (displayName?.isNotEmpty ?? false)
        ? displayName!
        : 'Pengguna Teman Kereta';
    final hasUsername = username?.isNotEmpty ?? false;

    return TkCard(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Column(
        children: <Widget>[
          _Avatar(name: name, imageUrl: avatarUrl, onTap: onAvatarTap),
          const SizedBox(height: 14),
          Semantics(
            button: true,
            label: 'Ubah nama, saat ini $name',
            child: InkWell(
              onTap: onEditName,
              borderRadius: BorderRadius.circular(TkRadius.control),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Flexible(
                        child: Text(
                          name,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.titleLarge,
                        ),
                      ),
                      const SizedBox(width: 8),
                      ExcludeSemantics(
                        child: Icon(
                          Icons.edit_outlined,
                          size: 18,
                          color: tk.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (signedIn && hasUsername)
            Text(
              '@$username',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textTheme.bodyMedium?.copyWith(color: tk.textMuted),
            )
          else if (signedIn)
            // Username is immutable once set (server-side trigger), so the
            // edit affordance only exists while it is still empty.
            TextButton.icon(
              onPressed: onSetUsername,
              icon: const Icon(Icons.edit_outlined, size: 16),
              label: const Text('Atur username'),
            ),
          if (signedIn) ...<Widget>[
            const SizedBox(height: 12),
            Divider(height: 1, color: tk.border),
            IntrinsicHeight(
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: _CountStat(
                      count: followers,
                      label: 'Pengikut',
                      onTap: onFollowers,
                    ),
                  ),
                  VerticalDivider(width: 1, color: tk.border),
                  Expanded(
                    child: _CountStat(
                      count: following,
                      label: 'Mengikuti',
                      onTap: onFollowing,
                    ),
                  ),
                ],
              ),
            ),
          ] else if (guestCanSignIn) ...<Widget>[
            const SizedBox(height: 8),
            FilledButton.tonal(
              onPressed: onSignIn,
              child: const Text('Masuk atau buat akun'),
            ),
            const SizedBox(height: 8),
          ] else
            const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.name, required this.imageUrl, this.onTap});

  final String name;
  final String? imageUrl;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final avatar = TkAvatar(name: name, imageUrl: imageUrl, size: 84);
    if (onTap == null) return avatar;
    return Semantics(
      button: true,
      label: 'Ubah foto profil',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            avatar,
            Positioned(
              right: -2,
              bottom: -2,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: tk.primary,
                  shape: BoxShape.circle,
                  border: Border.all(color: tk.surface, width: 2),
                ),
                child: Icon(
                  Icons.camera_alt_rounded,
                  size: 14,
                  color: tk.onPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CountStat extends StatelessWidget {
  const _CountStat({
    required this.count,
    required this.label,
    required this.onTap,
  });

  final int count;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      label: '$count $label',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 64),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Text(
                  '$count',
                  style: textTheme.titleLarge?.copyWith(
                    fontFeatures: AppTheme.timeFeatures,
                  ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CountTrailing extends StatelessWidget {
  const _CountTrailing(this.count);

  final int count;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          '$count',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: tk.textMuted,
            fontFeatures: AppTheme.timeFeatures,
          ),
        ),
        const SizedBox(width: 4),
        Icon(Icons.chevron_right_rounded, color: tk.textMuted),
      ],
    );
  }
}

class _ProfileCardSkeleton extends StatelessWidget {
  const _ProfileCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Memuat profil',
      child: const TkCard(
        padding: EdgeInsets.fromLTRB(16, 24, 16, 20),
        child: Column(
          children: <Widget>[
            TkSkeleton(height: 84, width: 84, radius: 42),
            SizedBox(height: 18),
            TkSkeleton(height: 20, width: 160),
            SizedBox(height: 10),
            TkSkeleton(height: 14, width: 100),
            SizedBox(height: 20),
            TkSkeleton(height: 40),
          ],
        ),
      ),
    );
  }
}

class _ProfileLoadError extends StatelessWidget {
  const _ProfileLoadError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return TkCard(
      tone: TkCardTone.warning,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(Icons.cloud_off_rounded, color: tk.warning),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Profil belum bisa dimuat',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Periksa koneksi, lalu coba lagi. Pengaturan di bawah '
                      'tetap bisa dipakai.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Coba lagi'),
            ),
          ),
        ],
      ),
    );
  }
}
