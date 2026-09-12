import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/platform/native_trip_service.dart';

final _permissionStatusProvider =
    FutureProvider.autoDispose<Map<String, Object?>>((ref) {
      return ref.watch(nativeTripServiceProvider).getPermissionStatus();
    });

class LocationSettingsPage extends ConsumerWidget {
  const LocationSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(_permissionStatusProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Pengaturan lokasi')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          children: <Widget>[
            Text(
              'Lokasi digunakan secara bertahap',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            const Text(
              'TK hanya membaca lokasi saat kamu membuka stasiun terdekat, '
              'mengaktifkan deteksi otomatis naik KRL, atau memulai perjalanan aktif. '
              'Tidak ada pelacakan lokasi berkelanjutan di luar itu.',
            ),
            const SizedBox(height: 20),
            status.when(
              loading: () => const LinearProgressIndicator(),
              error: (error, stack) => const Text(
                'Status izin tidak dapat dibaca. Buka pengaturan aplikasi untuk memeriksa langsung.',
              ),
              data: (value) => Card(
                child: Column(
                  children: <Widget>[
                    _StatusTile(
                      icon: Icons.my_location_rounded,
                      label: 'Lokasi saat digunakan',
                      granted: (value['foregroundLocation'] as bool?) ?? false,
                    ),
                    const Divider(height: 1),
                    _StatusTile(
                      icon: Icons.location_history_rounded,
                      label: 'Lokasi latar belakang',
                      granted: (value['backgroundLocation'] as bool?) ?? false,
                    ),
                    const Divider(height: 1),
                    _StatusTile(
                      icon: Icons.directions_walk_rounded,
                      label: 'Pengenalan aktivitas (deteksi naik KRL)',
                      granted: (value['activityRecognition'] as bool?) ?? false,
                    ),
                    const Divider(height: 1),
                    _StatusTile(
                      icon: Icons.battery_charging_full_rounded,
                      label: 'Bebas dari optimisasi baterai',
                      granted:
                          (value['batteryOptimizationIgnored'] as bool?) ??
                          false,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () => Geolocator.openLocationSettings(),
              icon: const Icon(Icons.settings_outlined),
              label: const Text('Buka pengaturan lokasi perangkat'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () => Geolocator.openAppSettings(),
              icon: const Icon(Icons.app_settings_alt_outlined),
              label: const Text('Buka pengaturan izin aplikasi'),
            ),
            const SizedBox(height: 10),
            TextButton.icon(
              onPressed: () => ref.invalidate(_permissionStatusProvider),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Segarkan status'),
            ),
            const SizedBox(height: 28),
            Text(
              'Keandalan pelacakan latar belakang',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            const Text(
              'Sebagian HP (Xiaomi, Oppo, Vivo, dan lainnya) punya pengaturan '
              'baterai sendiri di luar Android, yang bisa menghentikan '
              'pelacakan perjalanan aktif di tengah jalan meskipun izin '
              'lokasi sudah diberikan. Aktifkan dua hal di bawah ini supaya '
              'notifikasi stasiun tidak berhenti tiba-tiba.',
            ),
            const SizedBox(height: 16),
            status.maybeWhen(
              data: (value) => _BatteryOptimizationActions(
                ignored: (value['batteryOptimizationIgnored'] as bool?) ?? true,
                manufacturer: (value['manufacturer'] as String?) ?? '',
                onRefresh: () => ref.invalidate(_permissionStatusProvider),
              ),
              orElse: () => const SizedBox.shrink(),
            ),
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
      crossAxisAlignment: CrossAxisAlignment.start,
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

class _StatusTile extends StatelessWidget {
  const _StatusTile({
    required this.icon,
    required this.label,
    required this.granted,
  });

  final IconData icon;
  final String label;
  final bool granted;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      trailing: Icon(
        granted ? Icons.check_circle_rounded : Icons.cancel_outlined,
        color: granted ? Colors.green : Theme.of(context).colorScheme.error,
        semanticLabel: granted ? 'Diizinkan' : 'Belum diizinkan',
      ),
    );
  }
}
