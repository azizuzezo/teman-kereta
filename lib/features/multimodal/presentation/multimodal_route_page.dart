import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/utils/ride_hailing_launcher.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/tk_components.dart';
import '../../../core/widgets/trip_leg_timeline_tile.dart';
import '../../../data/providers/demo_data.dart';
import '../../../data/providers/provider_registry.dart';
import '../../../domain/entities/transit_models.dart';
import '../../schedule/presentation/trip_search_controller.dart';

/// PRD §15 "Perjalanan multimoda" / §21 page 24. Shows the trip's full
/// walk+rail+walk sequence and lets the user continue past the last walking
/// leg with a real ride-hailing deep link. There is no partner API access
/// to prefill a destination or fare here, see [RideHailingLauncher].
class MultimodalRoutePage extends ConsumerWidget {
  const MultimodalRoutePage({required this.tripId, super.key});

  final String tripId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tk = context.tk;
    final textTheme = Theme.of(context).textTheme;
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

    final stations = ref.watch(stationListProvider).value ?? const <Station>[];
    final destinationName =
        stations
            .where((s) => s.id == trip.destinationStationId)
            .firstOrNull
            ?.name ??
        demoStations
            .where((s) => s.id == trip.destinationStationId)
            .firstOrNull
            ?.name ??
        trip.destinationStationId;

    return Scaffold(
      appBar: AppBar(title: const Text('Rute multimoda')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          children: <Widget>[
            TkSectionLabel('Seluruh tahap perjalanan'),
            const SizedBox(height: 6),
            TkCard(
              child: Column(
                children: <Widget>[
                  for (var index = 0; index < trip.legs.length; index += 1)
                    TripLegTimelineTile(
                      leg: trip.legs[index],
                      isLast: index == trip.legs.length - 1,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            TkSectionLabel('Lanjutkan dari $destinationName'),
            const SizedBox(height: 6),
            TkRowGroup(
              children: <Widget>[
                TkRow(
                  icon: Icons.two_wheeler_rounded,
                  title: 'Gojek',
                  subtitle: 'Buka aplikasi Gojek',
                  onTap: () =>
                      const RideHailingLauncher().open(RideHailingApp.gojek),
                ),
                TkRow(
                  icon: Icons.local_taxi_outlined,
                  title: 'Grab',
                  subtitle: 'Buka aplikasi Grab',
                  onTap: () =>
                      const RideHailingLauncher().open(RideHailingApp.grab),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                'Teman Kereta hanya membuka aplikasinya. Tujuan dan tarif tidak '
                'diisi otomatis, kamu isi sendiri di aplikasi tersebut.',
                style: textTheme.bodySmall?.copyWith(color: tk.textMuted),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
