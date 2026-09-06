import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/widgets/data_badges.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../data/providers/provider_registry.dart';
import '../../../domain/entities/transit_models.dart';
import '../../stations/presentation/nearest_station_controller.dart';

/// The Jadwal tab: a departures board for the rider's current station (or
/// one they pick) — nothing else. Route planning (Dari/Ke, with a
/// details-then-confirm step before starting) lives on Beranda instead, see
/// `_QuickTripCard` in `home_page.dart`.
class SchedulePage extends ConsumerStatefulWidget {
  const SchedulePage({super.key});

  @override
  ConsumerState<SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends ConsumerState<SchedulePage> {
  static const _refreshInterval = Duration(seconds: 30);

  String? _manuallySelectedStationId;
  String? _lastSelectedStationId;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    // Re-fetches on a fixed cadence (rather than only on user action) so a
    // departure that has since left drops off the board on its own — the
    // real RPC always queries "from now", and the estimate fallback always
    // regenerates from "now" too, so a re-fetch alone is what retires a
    // passed time. `items.where(isAfter(now))` in `_DeparturesBoard` below
    // covers the gap between ticks so nothing stale lingers up to 30s late.
    _refreshTimer = Timer.periodic(_refreshInterval, (_) {
      final id = _lastSelectedStationId;
      if (id != null) {
        ref.invalidate(departuresProvider(id));
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stations = ref.watch(stationListProvider);
    final nearest =
        ref.watch(nearestStationControllerProvider).asData?.value.firstOrNull;
    final selectedId = _manuallySelectedStationId ?? nearest?.station.id;
    _lastSelectedStationId = selectedId;

    return Scaffold(
      appBar: AppBar(title: const Text('Jadwal')),
      body: SafeArea(
        child: stations.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => const AppEmptyState(
            icon: Icons.train_outlined,
            title: 'Daftar stasiun belum tersedia',
            message: 'Muat cache lokal lalu coba lagi.',
          ),
          data: (items) {
            final selectedStation =
                items.where((s) => s.id == selectedId).firstOrNull ??
                    items.firstOrNull;
            if (selectedStation == null) {
              return const AppEmptyState(
                icon: Icons.train_outlined,
                title: 'Belum ada stasiun',
                message: 'Data stasiun belum tersedia.',
              );
            }
            return _DeparturesBoard(
              station: selectedStation,
              stations: items,
              isUsingNearest: _manuallySelectedStationId == null,
              onPickStation: (id) =>
                  setState(() => _manuallySelectedStationId = id),
              onUseNearest: nearest == null
                  ? null
                  : () => setState(() => _manuallySelectedStationId = null),
            );
          },
        ),
      ),
    );
  }
}

class _DeparturesBoard extends ConsumerWidget {
  const _DeparturesBoard({
    required this.station,
    required this.stations,
    required this.isUsingNearest,
    required this.onPickStation,
    required this.onUseNearest,
  });

  final Station station;
  final List<Station> stations;
  final bool isUsingNearest;
  final ValueChanged<String> onPickStation;
  final VoidCallback? onUseNearest;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final departures = ref.watch(departuresProvider(station.id));
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      children: <Widget>[
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: <Widget>[
                const Icon(Icons.train_rounded),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        isUsingNearest ? 'Stasiun terdekat' : 'Stasiun dipilih',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      Text(
                        station.name,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ],
                  ),
                ),
                if (onUseNearest != null)
                  IconButton(
                    tooltip: 'Pakai stasiun terdekat',
                    onPressed: onUseNearest,
                    icon: const Icon(Icons.my_location_rounded),
                  ),
                IconButton(
                  tooltip: 'Ganti stasiun',
                  onPressed: () => _pickStation(context),
                  icon: const Icon(Icons.edit_location_alt_outlined),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                'Keberangkatan berikutnya',
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
        departures.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: LinearProgressIndicator(),
          ),
          error: (error, stack) => const AppEmptyState(
            icon: Icons.schedule_outlined,
            title: 'Jadwal belum tersedia',
            message: 'Belum ada cache jadwal untuk stasiun ini.',
          ),
          data: (allItems) {
            // Belt-and-suspenders alongside the periodic re-fetch above: a
            // departure whose time has already passed since the last fetch
            // (up to `_refreshInterval` stale) never lingers on screen even
            // for that gap.
            final items = allItems
                .where((d) => d.expectedAt.isAfter(DateTime.now()))
                .toList(growable: false);
            return items.isEmpty
              ? const AppEmptyState(
                  icon: Icons.schedule_outlined,
                  title: 'Tidak ada keberangkatan',
                  message: 'Belum ada jadwal untuk stasiun ini.',
                )
              : Column(
                  children: <Widget>[
                    for (final departure in items)
                      Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: Text(
                            DateFormat.Hm('id_ID').format(departure.expectedAt),
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          title: Text('Tujuan ${departure.destination}'),
                          subtitle: departure.platform == null
                              ? null
                              : Text(departure.platform!),
                          trailing: DataFreshnessBadge(
                            freshness: departure.freshness,
                            compact: true,
                          ),
                        ),
                      ),
                  ],
                );
          },
        ),
      ],
    );
  }

  Future<void> _pickStation(BuildContext context) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        builder: (context, scrollController) => ListView(
          controller: scrollController,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          children: <Widget>[
            for (final s in stations)
              ListTile(
                leading: const Icon(Icons.train_outlined),
                title: Text(s.name),
                onTap: () => Navigator.pop(context, s.id),
              ),
          ],
        ),
      ),
    );
    if (selected != null) {
      onPickStation(selected);
    }
  }
}
