import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/widgets/data_badges.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../data/providers/provider_registry.dart';
import '../../../domain/entities/transit_models.dart';
import 'trip_search_controller.dart';

class SchedulePage extends ConsumerWidget {
  const SchedulePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stations = ref.watch(stationListProvider);
    final search = ref.watch(tripSearchControllerProvider);
    final controller = ref.read(tripSearchControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Cari perjalanan')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          children: <Widget>[
            const DemoDataBanner(),
            const SizedBox(height: 18),
            stations.when(
              loading: () => const LinearProgressIndicator(),
              error: (error, stack) => const AppEmptyState(
                icon: Icons.train_outlined,
                title: 'Daftar stasiun belum tersedia',
                message: 'Muat cache lokal lalu coba lagi.',
              ),
              data: (items) => Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: <Widget>[
                      _StationDropdown(
                        label: 'Dari',
                        value: search.originStationId,
                        stations: items,
                        onChanged: controller.setOrigin,
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: IconButton.filledTonal(
                          tooltip: 'Tukar stasiun',
                          onPressed: controller.swapStations,
                          icon: const Icon(Icons.swap_vert_rounded),
                        ),
                      ),
                      _StationDropdown(
                        label: 'Ke',
                        value: search.destinationStationId,
                        stations: items,
                        onChanged: controller.setDestination,
                      ),
                      const SizedBox(height: 14),
                      const ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.schedule_rounded),
                        title: Text('Berangkat sekarang'),
                        subtitle: Text('Waktu perangkat lokal'),
                      ),
                      if (search.errorMessage != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            children: <Widget>[
                              const Icon(Icons.error_outline, size: 18),
                              const SizedBox(width: 8),
                              Expanded(child: Text(search.errorMessage!)),
                            ],
                          ),
                        ),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: search.isLoading ? null : controller.search,
                          icon: search.isLoading
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.search_rounded),
                          label: Text(
                            search.isLoading ? 'Mencari…' : 'Cari perjalanan',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (search.results.isNotEmpty) ...<Widget>[
              const SizedBox(height: 28),
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      '${search.results.length} alternatif',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  const DataFreshnessBadge(
                    freshness: DataFreshness.estimated,
                    compact: true,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              for (var index = 0; index < search.results.length; index += 1)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _TripResultCard(
                    trip: search.results[index],
                    label: switch (index) {
                      0 => 'Pilihan tercepat',
                      1 => 'Jalan kaki lebih sedikit',
                      _ => 'Berangkat berikutnya',
                    },
                    onTap: () => context.push('/trip/${search.results[index].id}'),
                  ),
                ),
            ] else if (!search.isLoading) ...<Widget>[
              const SizedBox(height: 24),
              const AppEmptyState(
                icon: Icons.route_outlined,
                title: 'Tentukan perjalananmu',
                message:
                    'Pilih stasiun awal dan tujuan. Hasil demo akan diberi label estimasi.',
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StationDropdown extends StatelessWidget {
  const _StationDropdown({
    required this.label,
    required this.value,
    required this.stations,
    required this.onChanged,
  });

  final String label;
  final String value;
  final List<Station> stations;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.train_outlined),
      ),
      items: <DropdownMenuItem<String>>[
        for (final station in stations)
          DropdownMenuItem(value: station.id, child: Text(station.name)),
      ],
      onChanged: (next) {
        if (next != null) {
          onChanged(next);
        }
      },
    );
  }
}

class _TripResultCard extends StatelessWidget {
  const _TripResultCard({
    required this.trip,
    required this.label,
    required this.onTap,
  });

  final TransitTrip trip;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final formatter = DateFormat.Hm('id_ID');
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      label,
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                '${formatter.format(trip.departureAt)} → ${formatter.format(trip.arrivalAt)}',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: <Widget>[
                  _Metric(icon: Icons.timer_outlined, label: '${trip.durationMinutes} mnt'),
                  _Metric(
                    icon: Icons.sync_alt_rounded,
                    label: '${trip.transfers} transit',
                  ),
                  _Metric(
                    icon: Icons.directions_walk_rounded,
                    label: '${trip.walkingMeters} m',
                  ),
                  _Metric(
                    icon: Icons.payments_outlined,
                    label: 'Rp${trip.estimatedFare}',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              DataFreshnessBadge(freshness: trip.freshness, compact: true),
            ],
          ),
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, size: 17),
        const SizedBox(width: 5),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
