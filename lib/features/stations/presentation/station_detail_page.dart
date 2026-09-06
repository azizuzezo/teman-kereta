import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/utils/map_launcher.dart';
import '../../../core/widgets/data_badges.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/facility_icon_chip.dart';
import '../../../data/providers/provider_registry.dart';
import '../../../domain/entities/transit_models.dart';

class StationDetailPage extends ConsumerWidget {
  const StationDetailPage({required this.stationId, super.key});

  final String stationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stations = ref.watch(stationListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Detail stasiun')),
      body: SafeArea(
        child: stations.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => const AppEmptyState(
            icon: Icons.train_outlined,
            title: 'Stasiun belum tersedia',
            message: 'Data lokal tidak dapat dimuat.',
          ),
          data: (items) {
            final station = items.where((item) => item.id == stationId).firstOrNull;
            if (station == null) {
              return AppEmptyState(
                icon: Icons.wrong_location_outlined,
                title: 'Stasiun tidak ditemukan',
                message: 'Kode stasiun tidak ditemukan.',
                action: FilledButton(
                  onPressed: () => context.go('/map'),
                  child: const Text('Buka peta'),
                ),
              );
            }
            return _StationContent(station: station);
          },
        ),
      ),
    );
  }
}

class _StationContent extends ConsumerWidget {
  const _StationContent({required this.station});

  final Station station;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final departures = ref.watch(departuresProvider(station.id));
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
      children: <Widget>[
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    CircleAvatar(radius: 26, child: Text(station.code)),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'Stasiun ${station.name}',
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                          Text(station.lineIds.join(' • ')),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    if (station.wheelchairAccessible)
                      const FacilityIconChip(label: 'Akses kursi roda'),
                    for (final facility in station.facilities)
                      FacilityIconChip(label: facility),
                    if (station.facilities.isEmpty &&
                        !station.wheelchairAccessible)
                      const Chip(label: Text('Fasilitas belum terverifikasi')),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: <Widget>[
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => context.go('/explore?station=${station.id}'),
                icon: const Icon(Icons.explore_outlined),
                label: const Text('Jelajahi sekitar'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.icon(
                onPressed: () => context.go('/schedule/search'),
                icon: const Icon(Icons.route_outlined),
                label: const Text('Cari rute'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => launchMapDirections(
              station.latitude,
              station.longitude,
              label: station.name,
            ),
            icon: const Icon(Icons.directions_rounded),
            label: const Text('Arahkan ke Sini'),
          ),
        ),
        const SizedBox(height: 26),
        Text('Keberangkatan berikutnya', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 10),
        departures.when(
          loading: () => const LinearProgressIndicator(),
          error: (error, stack) => const AppEmptyState(
            icon: Icons.schedule_outlined,
            title: 'Jadwal belum tersedia',
            message: 'Belum ada cache jadwal untuk stasiun ini.',
          ),
          data: (items) => items.isEmpty
              ? const AppEmptyState(
                  icon: Icons.schedule_outlined,
                  title: 'Tidak ada keberangkatan',
                  message: 'Belum ada jadwal untuk stasiun ini.',
                )
              : Column(
                  children: <Widget>[
                    for (final departure in items.take(8))
                      Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: Text(
                            DateFormat.Hm('id_ID').format(departure.expectedAt),
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          title: Text('Tujuan ${departure.destination}'),
                          subtitle: Text(
                            '${departure.platform ?? 'Peron belum tersedia'} • ${departure.sourceLabel}',
                          ),
                          trailing: DataFreshnessBadge(
                            freshness: departure.freshness,
                            compact: true,
                          ),
                        ),
                      ),
                  ],
                ),
        ),
        const SizedBox(height: 14),
        Text(
          'Lokasi stasiun: ${station.latitude.toStringAsFixed(4)}, ${station.longitude.toStringAsFixed(4)}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}
