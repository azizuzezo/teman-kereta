import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/map_launcher.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/facility_icon_chip.dart';
import '../../../domain/usecases/nearest_station_finder.dart';
import 'nearest_station_controller.dart';

/// PRD §12 "Stasiun Terdekat" — list mode. There is no real geographic map
/// in this app yet (the live map page is an intentionally-labelled rail
/// schematic, not GPS-backed), so this page only offers the list mode
/// rather than a map toggle that couldn't actually show anything.
class NearbyStationsPage extends ConsumerWidget {
  const NearbyStationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nearest = ref.watch(nearestStationControllerProvider);
    final controller = ref.read(nearestStationControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Stasiun terdekat'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Muat ulang lokasi',
            onPressed: () => controller.refresh(),
            icon: const Icon(Icons.my_location_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: nearest.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => AppEmptyState(
            icon: Icons.location_off_outlined,
            title: 'Lokasi tidak tersedia',
            message: 'Terjadi kendala saat membaca lokasi perangkat.',
            action: OutlinedButton(
              onPressed: () => controller.refresh(),
              child: const Text('Coba lagi'),
            ),
          ),
          data: (items) {
            if (items.isEmpty) {
              return AppEmptyState(
                icon: Icons.location_searching_rounded,
                title: 'Lokasi belum aktif',
                message:
                    'Aktifkan lokasi agar TK dapat menghitung jarak sungguhan '
                    'ke stasiun sekitar. Fitur jadwal tetap berfungsi tanpa ini.',
                action: FilledButton.icon(
                  onPressed: () async {
                    final granted =
                        await controller.requestPermissionAndRefresh();
                    if (context.mounted && !granted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Lokasi belum diizinkan atau layanan lokasi mati.',
                          ),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.location_on_outlined),
                  label: const Text('Aktifkan lokasi'),
                ),
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
              itemCount: items.length,
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemBuilder: (context, index) =>
                  _NearbyStationCard(entry: items[index]),
            );
          },
        ),
      ),
    );
  }
}

class _NearbyStationCard extends StatelessWidget {
  const _NearbyStationCard({required this.entry});

  final StationDistance entry;

  @override
  Widget build(BuildContext context) {
    final station = entry.station;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    station.name,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                if (station.wheelchairAccessible)
                  const Padding(
                    padding: EdgeInsets.only(left: 8),
                    child: Icon(Icons.accessible_rounded, size: 20),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${_formatDistance(entry.distanceMeters)} • '
              '${entry.walkingMinutes} menit jalan kaki',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (station.facilities.isNotEmpty) ...<Widget>[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: <Widget>[
                  for (final facility in station.facilities)
                    FacilityIconChip(label: facility),
                ],
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: <Widget>[
                FilledButton(
                  onPressed: () => context.push('/station/${station.id}'),
                  child: const Text('Lihat kereta'),
                ),
                OutlinedButton(
                  onPressed: () => launchMapDirections(
                    station.latitude,
                    station.longitude,
                    label: station.name,
                  ),
                  child: const Text('Arah ke stasiun'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDistance(double meters) {
    if (meters >= 1000) {
      return '${(meters / 1000).toStringAsFixed(1)} km';
    }
    return '${meters.round()} m';
  }
}
