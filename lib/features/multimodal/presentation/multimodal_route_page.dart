import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/ride_hailing_launcher.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/trip_leg_timeline_tile.dart';
import '../../schedule/presentation/trip_search_controller.dart';

/// PRD §15 "Perjalanan multimoda" / §21 page 24. Shows the trip's full
/// walk+rail+walk sequence and lets the user continue past the last walking
/// leg with a real ride-hailing deep link. There is no partner API access
/// to prefill a destination or fare here — see [RideHailingLauncher].
class MultimodalRoutePage extends ConsumerWidget {
  const MultimodalRoutePage({required this.tripId, super.key});

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
        appBar: AppBar(title: const Text('Rute multimoda')),
        body: AppEmptyState(
          icon: Icons.alt_route_rounded,
          title: 'Perjalanan tidak ditemukan',
          message: 'Hasil pencarian sudah tidak aktif. Cari perjalanan lagi.',
          action: FilledButton(
            onPressed: () => context.go('/schedule/search'),
            child: const Text('Cari lagi'),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Rute multimoda')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          children: <Widget>[
            Text(
              'Seluruh tahap perjalanan',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 14),
            for (var index = 0; index < trip.legs.length; index += 1)
              TripLegTimelineTile(
                leg: trip.legs[index],
                isLast: index == trip.legs.length - 1,
              ),
            const SizedBox(height: 20),
            Text(
              'Lanjutkan dari ${trip.destinationStationId}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 6),
            const Text(
              'Butuh transportasi lanjutan? Buka aplikasi transportasi online '
              'yang sudah terpasang. TK tidak mengisi tujuan atau memperkirakan '
              'tarif secara otomatis.',
            ),
            const SizedBox(height: 14),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () =>
                        const RideHailingLauncher().open(RideHailingApp.gojek),
                    icon: const Icon(Icons.two_wheeler_rounded),
                    label: const Text('Gojek'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () =>
                        const RideHailingLauncher().open(RideHailingApp.grab),
                    icon: const Icon(Icons.local_taxi_outlined),
                    label: const Text('Grab'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
