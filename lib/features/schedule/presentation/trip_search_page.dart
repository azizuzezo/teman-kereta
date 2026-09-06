import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/utils/map_launcher.dart';
import '../../../core/widgets/data_badges.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../data/providers/provider_registry.dart';
import '../../../domain/entities/transit_models.dart';
import '../../../domain/usecases/nearest_station_finder.dart';
import '../../stations/presentation/nearest_station_controller.dart';
import 'trip_search_controller.dart';

/// The Dari/Ke route-search flow — reached via a "Cari rute" affordance
/// (the Jadwal tab itself now opens straight to a departures board, see
/// `SchedulePage`, since most riders just want to know what's leaving next
/// from a station rather than plan a multi-leg trip every time).
class TripSearchPage extends ConsumerWidget {
  const TripSearchPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stations = ref.watch(stationListProvider);
    final search = ref.watch(tripSearchControllerProvider);
    final controller = ref.read(tripSearchControllerProvider.notifier);
    final nearest =
        ref.watch(nearestStationControllerProvider).asData?.value.firstOrNull;

    return Scaffold(
      appBar: AppBar(title: const Text('Cari perjalanan')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          children: <Widget>[
            if (nearest != null) ...<Widget>[
              _NearestStationBlock(
                nearest: nearest,
                onUseAsOrigin: () => controller.setOrigin(nearest.station.id),
                onDirections: () => unawaited(
                  launchMapDirections(
                    nearest.station.latitude,
                    nearest.station.longitude,
                    label: nearest.station.name,
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
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
                    'Pilih stasiun awal dan tujuan. Hasil pencarian akan diberi label estimasi.',
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Nearest-station-with-distance block for the trip-search flow, mirroring
/// the home tab's equivalent card (`_NearestStationCard` in
/// `home_page.dart`) so picking an origin isn't only convenient from Home.
class _NearestStationBlock extends StatelessWidget {
  const _NearestStationBlock({
    required this.nearest,
    required this.onUseAsOrigin,
    required this.onDirections,
  });

  final StationDistance nearest;
  final VoidCallback onUseAsOrigin;
  final VoidCallback onDirections;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: <Widget>[
            const Icon(Icons.near_me_outlined),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Stasiun terdekat: ${nearest.station.name}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    '${_formatDistance(nearest.distanceMeters)} • '
                    '${nearest.walkingMinutes} menit jalan kaki',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Gunakan sebagai asal',
              onPressed: onUseAsOrigin,
              icon: const Icon(Icons.add_location_alt_outlined),
            ),
            IconButton(
              tooltip: 'Buka di Google Maps',
              onPressed: onDirections,
              icon: const Icon(Icons.map_outlined),
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
