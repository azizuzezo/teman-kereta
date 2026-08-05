import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/config/app_environment.dart';
import '../../../core/notifications/local_notification_service.dart';
import '../../../core/widgets/data_badges.dart';
import '../../../core/widgets/tk_logo.dart';
import '../../../data/providers/provider_registry.dart';
import '../../../domain/entities/transit_models.dart';
import '../../ride_detection/presentation/ride_detection_controller.dart';
import 'settings_controller.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsControllerProvider);
    final controller = ref.read(settingsControllerProvider.notifier);
    final stations =
        ref.watch(stationListProvider).asData?.value ?? const <Station>[];

    return Scaffold(
      appBar: AppBar(title: const Text('Profil & pengaturan')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          children: <Widget>[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: <Widget>[
                    const CircleAvatar(
                      radius: 28,
                      child: TkLogo(size: 36, showLabel: false),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'Mode tanpa akun',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const Text('Preferensi disimpan di perangkat ini.'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            Card(
              color: Theme.of(context).colorScheme.primaryContainer,
              child: const Padding(
                padding: EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Icon(Icons.developer_mode_rounded),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'Local-only guard aktif',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Endpoint non-lokal, Firebase, dan build release ditolak saat APP_ENV=local.',
                          ),
                        ],
                      ),
                    ),
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
              'Rute harian & deteksi otomatis',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 10),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    DropdownButtonFormField<String>(
                      initialValue: settings.homeStationId,
                      decoration: const InputDecoration(
                        labelText: 'Stasiun rumah',
                        prefixIcon: Icon(Icons.home_outlined),
                      ),
                      items: <DropdownMenuItem<String>>[
                        for (final station in stations)
                          DropdownMenuItem(
                            value: station.id,
                            child: Text(station.name),
                          ),
                      ],
                      onChanged: (value) => controller.setHomeStation(value),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: settings.workStationId,
                      decoration: const InputDecoration(
                        labelText: 'Stasiun kantor atau kampus',
                        prefixIcon: Icon(Icons.work_outline_rounded),
                      ),
                      items: <DropdownMenuItem<String>>[
                        for (final station in stations)
                          DropdownMenuItem(
                            value: station.id,
                            child: Text(station.name),
                          ),
                      ],
                      onChanged: (value) => controller.setWorkStation(value),
                    ),
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
                        'Tetap meminta konfirmasi sebelum memulai panduan perjalanan.',
                      ),
                    ),
                  ],
                ),
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
                    subtitle: const Text('Gunakan data demo dan cache perangkat.'),
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
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.schedule_send_outlined),
                    title: const Text('Impor jadwal GTFS'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => context.push('/settings/gtfs-import'),
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
            const Center(child: DemoDataBanner(compact: true)),
            const SizedBox(height: 8),
            Center(
              child: Text(
                'TK 0.1.0 • ${AppEnvironment.name} • ${AppEnvironment.providerName}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
