import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/platform/native_trip_service.dart';
import '../../../core/widgets/tk_components.dart';
import '../../ride_detection/presentation/ride_detection_controller.dart';
import 'permission_status.dart';
import 'settings_controller.dart';
import 'widgets/settings_rows.dart';

class LocationSettingsPage extends ConsumerWidget {
  const LocationSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(devicePermissionStatusProvider);
    final settings = ref.watch(settingsControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Pengaturan lokasi')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          children: <Widget>[
            const SettingsIntro(
              'TK hanya membaca lokasi saat kamu membuka stasiun terdekat, '
              'mengaktifkan deteksi otomatis naik KRL, atau memulai perjalanan '
              'aktif. Tidak ada pelacakan lokasi berkelanjutan di luar itu.',
            ),
            const TkSectionLabel('Izin'),
            status.when(
              loading: () => const _PermissionSkeleton(),
              error: (error, stack) => TkCard(
                tone: TkCardTone.warning,
                child: Text(
                  'Status izin tidak dapat dibaca. Buka pengaturan aplikasi '
                  'untuk memeriksa langsung.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              data: (value) => TkRowGroup(
                children: <Widget>[
                  TkRow(
                    icon: Icons.my_location_rounded,
                    title: 'Lokasi saat digunakan',
                    trailing: PermissionPill(
                      granted: value['foregroundLocation'] == true,
                    ),
                  ),
                  TkRow(
                    icon: Icons.location_history_rounded,
                    title: 'Lokasi latar belakang',
                    trailing: PermissionPill(
                      granted: value['backgroundLocation'] == true,
                    ),
                  ),
                  TkRow(
                    icon: Icons.directions_walk_rounded,
                    title: 'Pengenalan aktivitas',
                    subtitle: 'Dipakai untuk mendeteksi naik KRL',
                    trailing: PermissionPill(
                      granted: value['activityRecognition'] == true,
                    ),
                  ),
                  TkRow(
                    icon: Icons.battery_charging_full_rounded,
                    title: 'Bebas optimisasi baterai',
                    trailing: PermissionPill(
                      granted: value['batteryOptimizationIgnored'] == true,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: Geolocator.openLocationSettings,
              icon: const Icon(Icons.settings_outlined),
              label: const Text('Buka pengaturan lokasi perangkat'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: Geolocator.openAppSettings,
              icon: const Icon(Icons.app_settings_alt_outlined),
              label: const Text('Buka pengaturan izin aplikasi'),
            ),
            const SizedBox(height: 4),
            TextButton.icon(
              onPressed: () => ref.invalidate(devicePermissionStatusProvider),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Segarkan status'),
            ),
            const SizedBox(height: 16),
            const TkSectionLabel('Deteksi otomatis'),
            TkRowGroup(
              children: <Widget>[
                SettingsSwitchRow(
                  icon: Icons.train_rounded,
                  title: 'Deteksi otomatis naik KRL',
                  subtitle:
                      'Meminta izin sensor gerak dan memakai GPS untuk '
                      'mendeteksi saat kamu meninggalkan stasiun rumah atau '
                      'kantor sambil bergerak. Tetap meminta konfirmasi '
                      'sebelum memulai panduan perjalanan.',
                  value: settings.rideDetectionEnabled,
                  onChanged: (value) =>
                      _toggleRideDetection(context, ref, value),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TkCard(
              tone: TkCardTone.soft,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Icon(
                    Icons.info_outline_rounded,
                    size: 20,
                    color: context.tk.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Saat perjalanan aktif berjalan, posisi GPS-mu juga '
                      'dikirim berkala ke server untuk membantu menampilkan '
                      'posisi kereta ke pengguna lain. Rinciannya ada di '
                      'Kebijakan privasi.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const TkSectionLabel('Keandalan di latar belakang'),
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
              child: Text(
                'Sebagian HP (Xiaomi, Oppo, Vivo, dan lainnya) punya '
                'pengaturan baterai sendiri di luar Android, yang bisa '
                'menghentikan pelacakan perjalanan aktif di tengah jalan '
                'meskipun izin lokasi sudah diberikan. Aktifkan dua hal di '
                'bawah ini supaya notifikasi stasiun tidak berhenti tiba-tiba.',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: context.tk.textMuted),
              ),
            ),
            status.maybeWhen(
              data: (value) => _BatteryOptimizationActions(
                ignored: (value['batteryOptimizationIgnored'] as bool?) ?? true,
                manufacturer: (value['manufacturer'] as String?) ?? '',
                onRefresh: () => ref.invalidate(devicePermissionStatusProvider),
              ),
              orElse: () => const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleRideDetection(
    BuildContext context,
    WidgetRef ref,
    bool value,
  ) async {
    final detection = ref.read(rideDetectionControllerProvider.notifier);
    if (value) {
      final started = await detection.enable();
      ref.invalidate(devicePermissionStatusProvider);
      if (context.mounted && !started) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Izin pengenalan aktivitas ditolak. Deteksi otomatis tetap '
              'nonaktif.',
            ),
          ),
        );
      }
    } else {
      await detection.disable();
    }
  }
}

class _PermissionSkeleton extends StatelessWidget {
  const _PermissionSkeleton();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Memuat status izin',
      child: const TkCard(
        child: Column(
          children: <Widget>[
            TkSkeleton(height: 36),
            SizedBox(height: 14),
            TkSkeleton(height: 36),
            SizedBox(height: 14),
            TkSkeleton(height: 36),
            SizedBox(height: 14),
            TkSkeleton(height: 36),
          ],
        ),
      ),
    );
  }
}

class _BatteryOptimizationActions extends ConsumerWidget {
  const _BatteryOptimizationActions({
    required this.ignored,
    required this.manufacturer,
    required this.onRefresh,
  });

  final bool ignored;
  final String manufacturer;
  final VoidCallback onRefresh;

  static const _knownAggressiveOems = <String>{
    'xiaomi',
    'oppo',
    'realme',
    'vivo',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasOemScreen = _knownAggressiveOems.contains(
      manufacturer.toLowerCase(),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        FilledButton.icon(
          onPressed: ignored
              ? null
              : () async {
                  await ref
                      .read(nativeTripServiceProvider)
                      .requestIgnoreBatteryOptimizations();
                  onRefresh();
                },
          icon: const Icon(Icons.battery_charging_full_rounded),
          label: Text(
            ignored
                ? 'Sudah bebas dari optimisasi baterai'
                : 'Izinkan berjalan bebas di latar belakang',
          ),
        ),
        if (hasOemScreen) ...<Widget>[
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () async {
              await ref
                  .read(nativeTripServiceProvider)
                  .openManufacturerBatterySettings();
              onRefresh();
            },
            icon: const Icon(Icons.phone_android_rounded),
            label: Text(
              'Buka pengaturan khusus ${_ownerCaseLabel(manufacturer)}',
            ),
          ),
        ],
      ],
    );
  }

  String _ownerCaseLabel(String manufacturer) {
    if (manufacturer.isEmpty) return manufacturer;
    return manufacturer[0].toUpperCase() +
        manufacturer.substring(1).toLowerCase();
  }
}
