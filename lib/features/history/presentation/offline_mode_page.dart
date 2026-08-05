import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/database/database_provider.dart';
import '../../../data/providers/provider_registry.dart';
import '../../favorites/presentation/favorite_route_controller.dart';
import '../../settings/presentation/settings_controller.dart';

final _cachedStationCountProvider = FutureProvider.autoDispose<int>((ref) async {
  final database = ref.watch(appDatabaseProvider);
  final rows = await database.allCachedStations();
  return rows.length;
});

final _cacheUpdatedAtProvider = FutureProvider.autoDispose<DateTime?>((ref) async {
  return ref.watch(appDatabaseProvider).latestStationCacheUpdate();
});

class OfflineModePage extends ConsumerWidget {
  const OfflineModePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsControllerProvider);
    final favorite = ref.watch(favoriteRouteControllerProvider);
    final stationCount = ref.watch(_cachedStationCountProvider).asData?.value;
    final updatedAt = ref.watch(_cacheUpdatedAtProvider).asData?.value;

    return Scaffold(
      appBar: AppBar(title: const Text('Mode offline')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          children: <Widget>[
            Card(
              color: settings.offlineMode
                  ? Theme.of(context).colorScheme.primaryContainer
                  : null,
              child: SwitchListTile(
                value: settings.offlineMode,
                onChanged: (value) =>
                    ref.read(settingsControllerProvider.notifier).setOfflineMode(value),
                secondary: const Icon(Icons.offline_bolt_outlined),
                title: const Text('Paksa mode offline'),
                subtitle: const Text(
                  'Gunakan data tersimpan meskipun koneksi tersedia. Berguna untuk menguji tampilan offline.',
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text('Data tersedia offline', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 10),
            Card(
              child: Column(
                children: <Widget>[
                  ListTile(
                    leading: const Icon(Icons.train_outlined),
                    title: Text('${stationCount ?? 0} stasiun tersimpan'),
                    subtitle: Text(
                      updatedAt == null
                          ? 'Belum ada data tersimpan'
                          : 'Terakhir diperbarui ${DateFormat('d MMM y, HH:mm', 'id_ID').format(updatedAt)}',
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.star_outline_rounded),
                    title: Text(
                      favorite == null ? 'Belum ada rute favorit' : 'Rute favorit tersimpan',
                    ),
                    subtitle: Text(favorite?.replaceAll('|', ' → ') ?? '—'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Icon(Icons.info_outline_rounded),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Perubahan jadwal terbaru mungkin belum tersedia saat offline. '
                        'Detail perjalanan yang sudah disimpan tetap dapat dibuka.',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () {
                ref.invalidate(stationListProvider);
                ref.invalidate(serviceAlertsProvider);
                ref.invalidate(_cachedStationCountProvider);
                ref.invalidate(_cacheUpdatedAtProvider);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Mencoba menyambungkan kembali…')),
                );
              },
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Coba sambungkan kembali'),
            ),
          ],
        ),
      ),
    );
  }
}
