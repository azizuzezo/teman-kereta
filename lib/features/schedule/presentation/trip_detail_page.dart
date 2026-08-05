import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/widgets/data_badges.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/trip_leg_timeline_tile.dart';
import '../../../data/providers/demo_data.dart';
import '../../active_trip/presentation/active_trip_controller.dart';
import '../../favorites/presentation/favorite_route_controller.dart';
import 'trip_search_controller.dart';

class TripDetailPage extends ConsumerWidget {
  const TripDetailPage({required this.tripId, super.key});

  final String tripId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trip = ref
        .watch(tripSearchControllerProvider)
        .results
        .where((item) => item.id == tripId)
        .firstOrNull;
    if (trip == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Detail perjalanan')),
        body: AppEmptyState(
          icon: Icons.route_outlined,
          title: 'Perjalanan tidak ditemukan',
          message: 'Hasil pencarian sudah tidak aktif. Cari perjalanan lagi.',
          action: FilledButton(
            onPressed: () => context.go('/schedule'),
            child: const Text('Cari lagi'),
          ),
        ),
      );
    }

    final favorite = ref.watch(favoriteRouteControllerProvider);
    final isFavorite = favorite ==
        '${trip.originStationId}|${trip.destinationStationId}';
    final activeTrip = ref.watch(activeTripControllerProvider);
    final time = DateFormat.Hm('id_ID');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detail perjalanan'),
        actions: <Widget>[
          IconButton(
            tooltip: isFavorite ? 'Hapus dari favorit' : 'Simpan sebagai favorit',
            onPressed: () => ref
                .read(favoriteRouteControllerProvider.notifier)
                .toggle(trip.originStationId, trip.destinationStationId),
            icon: Icon(
              isFavorite ? Icons.star_rounded : Icons.star_outline_rounded,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 124),
          children: <Widget>[
            if (trip.isDemo) const DemoDataBanner(),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      '${_stationName(trip.originStationId)} → ${_stationName(trip.destinationStationId)}',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 14),
                    Text(
                      '${time.format(trip.departureAt)} – ${time.format(trip.arrivalAt)}',
                      style: Theme.of(context).textTheme.displayLarge?.copyWith(
                        fontFeatures: const <FontFeature>[
                          FontFeature.tabularFigures(),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 14,
                      runSpacing: 10,
                      children: <Widget>[
                        _DetailMetric(
                          icon: Icons.timer_outlined,
                          label: '${trip.durationMinutes} menit',
                        ),
                        _DetailMetric(
                          icon: Icons.sync_alt_rounded,
                          label: '${trip.transfers} transit',
                        ),
                        _DetailMetric(
                          icon: Icons.directions_walk_rounded,
                          label: '${trip.walkingMeters} meter',
                        ),
                        _DetailMetric(
                          icon: Icons.payments_outlined,
                          label: 'Estimasi Rp${trip.estimatedFare}',
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    DataFreshnessBadge(freshness: trip.freshness),
                    const SizedBox(height: 10),
                    Text(
                      '${trip.sourceLabel}\nDiperbarui ${DateFormat('dd MMM, HH:mm', 'id_ID').format(trip.updatedAt)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 26),
            Text('Langkah perjalanan', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 14),
            for (var index = 0; index < trip.legs.length; index += 1)
              TripLegTimelineTile(
                leg: trip.legs[index],
                isLast: index == trip.legs.length - 1,
              ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => context.push('/trip/$tripId/multimodal'),
              icon: const Icon(Icons.alt_route_rounded),
              label: const Text('Lanjutkan dengan moda lain'),
            ),
            const SizedBox(height: 18),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Icon(Icons.verified_user_outlined),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Peron, perubahan layanan, dan posisi kereta harus diverifikasi dari sumber resmi sebelum mode produksi.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(16),
        child: SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () async {
              if (activeTrip == null) {
                await ref.read(activeTripControllerProvider.notifier).start(trip);
              }
              if (context.mounted) {
                context.push('/active-trip');
              }
            },
            icon: const Icon(Icons.navigation_rounded),
            label: Text(
              activeTrip == null ? 'Mulai perjalanan' : 'Buka perjalanan aktif',
            ),
          ),
        ),
      ),
    );
  }

  String _stationName(String id) {
    return demoStations.where((station) => station.id == id).firstOrNull?.name ??
        id;
  }
}

class _DetailMetric extends StatelessWidget {
  const _DetailMetric({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, size: 18),
        const SizedBox(width: 6),
        Text(label),
      ],
    );
  }
}

