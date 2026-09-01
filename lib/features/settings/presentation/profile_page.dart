import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/config/app_environment.dart';
import '../../../core/notifications/local_notification_service.dart';
import '../../../core/utils/station_location_resolver.dart';
import '../../../core/widgets/tk_logo.dart';
import '../../../data/providers/provider_registry.dart';
import '../../../domain/entities/transit_models.dart';
import '../../account/presentation/account_controller.dart';
import '../../ride_detection/presentation/ride_detection_controller.dart';
import 'edit_display_name_dialog.dart';
import 'edit_username_dialog.dart';
import 'settings_controller.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsControllerProvider);
    final controller = ref.read(settingsControllerProvider.notifier);
    final stations =
        ref.watch(stationListProvider).asData?.value ?? const <Station>[];
    final account = ref.watch(accountControllerProvider).asData?.value;
    final displayName = ref.watch(userDisplayNameProvider).asData?.value;
    final username = ref.watch(userUsernameProvider).asData?.value;
    final avatarUrl = ref.watch(userAvatarUrlProvider).asData?.value;
    final followCounts = ref.watch(userFollowCountsProvider).asData?.value;

    return Scaffold(
      appBar: AppBar(title: const Text('Profil & pengaturan')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          children: <Widget>[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        GestureDetector(
                          onTap: account == null
                              ? null
                              : () => _pickAndUploadAvatar(context, ref),
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: <Widget>[
                              CircleAvatar(
                                radius: 28,
                                backgroundImage:
                                    (avatarUrl != null && avatarUrl.isNotEmpty)
                                    ? CachedNetworkImageProvider(avatarUrl)
                                    : null,
                                child: (avatarUrl == null || avatarUrl.isEmpty)
                                    ? const TkLogo(size: 36, showLabel: false)
                                    : null,
                              ),
                              if (account != null)
                                Positioned(
                                  right: -2,
                                  bottom: -2,
                                  child: Container(
                                    padding: const EdgeInsets.all(3),
                                    decoration: BoxDecoration(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.camera_alt_rounded,
                                      size: 12,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onPrimary,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                (displayName?.isNotEmpty ?? false)
                                    ? displayName!
                                    : (account != null
                                          ? (account.email ?? 'Akun masuk')
                                          : 'Pengguna Teman Kereta'),
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              if (account != null) ...<Widget>[
                                const SizedBox(height: 2),
                                Builder(
                                  builder: (context) {
                                    final hasUsername =
                                        username?.isNotEmpty ?? false;
                                    return InkWell(
                                      onTap: hasUsername
                                          ? () => ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  'Username tidak bisa diubah setelah ditetapkan.',
                                                ),
                                              ),
                                            )
                                          : () => showEditUsernameDialog(
                                              context,
                                              ref,
                                              currentUsername: username,
                                            ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: <Widget>[
                                          Flexible(
                                            child: Text(
                                              hasUsername
                                                  ? '@$username'
                                                  : 'Atur username',
                                              overflow: TextOverflow.ellipsis,
                                              maxLines: 1,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodyMedium
                                                  ?.copyWith(
                                                    color: hasUsername
                                                        ? Theme.of(
                                                            context,
                                                          ).colorScheme.onSurfaceVariant
                                                        : Theme.of(
                                                            context,
                                                          ).colorScheme.primary,
                                                  ),
                                            ),
                                          ),
                                          // No edit affordance once a
                                          // username is set — it's immutable
                                          // server-side (see the DB trigger
                                          // in 20260822110000_username_immutable.sql).
                                          if (!hasUsername) ...<Widget>[
                                            const SizedBox(width: 4),
                                            Icon(
                                              Icons.edit_outlined,
                                              size: 14,
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.onSurfaceVariant,
                                            ),
                                          ],
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ],
                              const SizedBox(height: 2),
                              Text(
                                account != null
                                    ? 'Masuk dengan akun. Preferensi tetap tersimpan di perangkat ini.'
                                    : 'Mode tanpa akun. Preferensi tersimpan di perangkat ini.',
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit_outlined),
                          tooltip: 'Ubah nama',
                          onPressed: () => showEditDisplayNameDialog(
                            context,
                            ref,
                            currentName: displayName,
                          ),
                        ),
                      ],
                    ),
                    if (AppEnvironment.supabaseEnabled && account != null) ...<Widget>[
                      const SizedBox(height: 14),
                      Row(
                        children: <Widget>[
                          _FollowStat(
                            label: 'Pengikut',
                            count: followCounts?.followers ?? 0,
                            onTap: () =>
                                context.push('/social/followers/${account.id}'),
                          ),
                          const SizedBox(width: 24),
                          _FollowStat(
                            label: 'Mengikuti',
                            count: followCounts?.following ?? 0,
                            onTap: () =>
                                context.push('/social/following/${account.id}'),
                          ),
                        ],
                      ),
                    ],
                    if (AppEnvironment.supabaseEnabled) ...<Widget>[
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: account != null
                            ? OutlinedButton(
                                onPressed: () => ref
                                    .read(accountControllerProvider.notifier)
                                    .signOut(),
                                child: const Text('Keluar'),
                              )
                            : FilledButton.tonal(
                                onPressed: () => context.push('/account/login'),
                                child: const Text('Masuk atau buat akun'),
                              ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 26),
            Text('Tampilan', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 10),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      'Tema aplikasi',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: SegmentedButton<ThemeMode>(
                        segments: const <ButtonSegment<ThemeMode>>[
                          ButtonSegment(
                            value: ThemeMode.system,
                            icon: Icon(Icons.settings_brightness_outlined),
                            label: Text('Sistem'),
                          ),
                          ButtonSegment(
                            value: ThemeMode.light,
                            icon: Icon(Icons.light_mode_outlined),
                            label: Text('Terang'),
                          ),
                          ButtonSegment(
                            value: ThemeMode.dark,
                            icon: Icon(Icons.dark_mode_outlined),
                            label: Text('Gelap'),
                          ),
                        ],
                        selected: <ThemeMode>{settings.themeMode},
                        onSelectionChanged: (value) =>
                            controller.setThemeMode(value.first),
                      ),
                    ),
                    const Divider(height: 28),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: settings.reduceMotion,
                      onChanged: controller.setReduceMotion,
                      title: const Text('Kurangi animasi'),
                      subtitle: const Text(
                        'Mengurangi transisi untuk kenyamanan dan aksesibilitas.',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 26),
            Text(
              'Alamat & Stasiun Komuter',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 10),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    TextFormField(
                      initialValue: settings.homeAddress ?? '',
                      decoration: const InputDecoration(
                        labelText: 'Alamat / Lokasi Rumah',
                        hintText: 'Contoh: Billabong, Tajurhalang, Bintaro...',
                        prefixIcon: Icon(Icons.home_work_outlined),
                      ),
                      onChanged: (value) {
                        unawaited(controller.setHomeAddress(value));
                        final res = resolveAddressToNearestStation(value, stations);
                        if (res != null) {
                          unawaited(controller.setHomeStation(res.station.id));
                        }
                      },
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: settings.homeStationId,
                      decoration: const InputDecoration(
                        labelText: 'Stasiun terdekat dari rumah',
                        prefixIcon: Icon(Icons.home_outlined),
                      ),
                      items: <DropdownMenuItem<String>>[
                        for (final station in stations)
                          DropdownMenuItem(
                            value: station.id,
                            child: Text('${station.name} (${station.id})'),
                          ),
                      ],
                      onChanged: (value) => unawaited(controller.setHomeStation(value)),
                    ),
                    if (settings.homeAddress != null && settings.homeAddress!.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 4),
                      Builder(
                        builder: (context) {
                          final resolved = resolveAddressToNearestStation(
                            settings.homeAddress!,
                            stations,
                          );
                          if (resolved == null) return const SizedBox.shrink();
                          return Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.4),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: <Widget>[
                                const Icon(Icons.auto_awesome, size: 16),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    resolved.reason,
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                    const SizedBox(height: 16),
                    TextFormField(
                      initialValue: settings.workAddress ?? '',
                      decoration: const InputDecoration(
                        labelText: 'Alamat / Lokasi Kantor atau Kampus',
                        hintText: 'Contoh: Wisma 46 Sudirman, BSD City, Margonda...',
                        prefixIcon: Icon(Icons.business_outlined),
                      ),
                      onChanged: (value) {
                        unawaited(controller.setWorkAddress(value));
                        final res = resolveAddressToNearestStation(value, stations);
                        if (res != null) {
                          unawaited(controller.setWorkStation(res.station.id));
                        }
                      },
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: settings.workStationId,
                      decoration: const InputDecoration(
                        labelText: 'Stasiun terdekat dari kantor/kampus',
                        prefixIcon: Icon(Icons.work_outline_rounded),
                      ),
                      items: <DropdownMenuItem<String>>[
                        for (final station in stations)
                          DropdownMenuItem(
                            value: station.id,
                            child: Text('${station.name} (${station.id})'),
                          ),
                      ],
                      onChanged: (value) => unawaited(controller.setWorkStation(value)),
                    ),
                    if (settings.workAddress != null && settings.workAddress!.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 4),
                      Builder(
                        builder: (context) {
                          final resolved = resolveAddressToNearestStation(
                            settings.workAddress!,
                            stations,
                          );
                          if (resolved == null) return const SizedBox.shrink();
                          return Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.4),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: <Widget>[
                                const Icon(Icons.auto_awesome, size: 16),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    resolved.reason,
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                    const Divider(height: 28),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: settings.rideDetectionEnabled,
                      onChanged: (value) async {
                        final detection = ref.read(
                          rideDetectionControllerProvider.notifier,
                        );
                        if (value) {
                          final started = await detection.enable();
                          if (context.mounted && !started) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Izin pengenalan aktivitas ditolak. Deteksi otomatis tetap nonaktif.',
                                ),
                              ),
                            );
                          }
                        } else {
                          await detection.disable();
                        }
                      },
                      title: const Text('Deteksi otomatis naik KRL'),
                      subtitle: const Text(
                        'Meminta izin sensor gerak dan mendaftarkan geofence stasiun rumah/kantor. '
                        'Tetap meminta konfirmasi sebelum memulai panduan perjalanan. '
                        'Saat perjalanan aktif berjalan, posisi GPS-mu juga dikirim secara berkala '
                        'ke server untuk membantu menampilkan posisi kereta ke pengguna lain — '
                        'lihat halaman Privasi untuk detail lengkap.',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 26),
            Text('Sosial', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 10),
            Card(
              child: Column(
                children: <Widget>[
                  ListTile(
                    leading: const Icon(Icons.forum_outlined),
                    title: const Text('Forum'),
                    subtitle: const Text('Ngobrol soal KRL bareng pengguna lain.'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => context.push('/forum'),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.person_search_outlined),
                    title: const Text('Cari pengguna'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => context.push('/social/search'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 26),
            Text('Data & notifikasi', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 10),
            Card(
              child: Column(
                children: <Widget>[
                  SwitchListTile(
                    value: settings.offlineMode,
                    onChanged: controller.setOfflineMode,
                    secondary: const Icon(Icons.offline_bolt_outlined),
                    title: const Text('Paksa mode offline'),
                    subtitle: const Text('Gunakan data yang tersimpan di cache perangkat.'),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.notifications_active_outlined),
                    title: const Text('Aktifkan notifikasi perangkat'),
                    subtitle: const Text('Izin hanya diminta setelah kamu mengetuk.'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () async {
                      final granted = await ref
                          .read(localNotificationServiceProvider)
                          .requestPermission();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              granted
                                  ? 'Notifikasi perangkat diizinkan.'
                                  : 'Notifikasi belum diizinkan.',
                            ),
                          ),
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 26),
            Text('Perjalanan & aplikasi', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 10),
            Card(
              child: Column(
                children: <Widget>[
                  ListTile(
                    leading: const Icon(Icons.history_rounded),
                    title: const Text('Riwayat perjalanan'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => context.push('/history'),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.offline_bolt_outlined),
                    title: const Text('Mode offline'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => context.push('/offline-mode'),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.location_on_outlined),
                    title: const Text('Pengaturan lokasi'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => context.push('/settings/location'),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.notifications_none_rounded),
                    title: const Text('Pengaturan notifikasi'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => context.push('/settings/notifications'),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.accessibility_new_rounded),
                    title: const Text('Pengaturan aksesibilitas'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => context.push('/settings/accessibility'),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.widgets_outlined),
                    title: const Text('Widget layar utama'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => context.push('/settings/widgets'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 26),
            Text('Tentang', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 10),
            Card(
              child: Column(
                children: <Widget>[
                  ListTile(
                    leading: const Icon(Icons.info_outline_rounded),
                    title: const Text('Tentang & pembaruan'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => context.push('/about'),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.help_outline_rounded),
                    title: const Text('Bantuan'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => context.push('/help'),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.privacy_tip_outlined),
                    title: const Text('Privasi lokal'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => context.push('/privacy'),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.bug_report_outlined),
                    title: const Text('Buat laporan lokal'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => context.push('/report'),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.replay_rounded),
                    title: const Text('Ulangi pengenalan'),
                    subtitle: const Text('Tidak menghapus favorit atau cache.'),
                    onTap: () async {
                      await controller.resetOnboarding();
                      if (context.mounted) {
                        context.go('/onboarding');
                      }
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Center(
              child: Text(
                'TK 0.1.0',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
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
      // query param or CachedNetworkImage (and other viewers) keep showing
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

class _FollowStat extends StatelessWidget {
  const _FollowStat({
    required this.label,
    required this.count,
    required this.onTap,
  });

  final String label;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              '$count',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(width: 6),
            Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}
