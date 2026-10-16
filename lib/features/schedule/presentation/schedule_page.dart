import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/widgets/data_badges.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/tk_components.dart';
import '../../../data/providers/provider_registry.dart';
import '../../../domain/entities/transit_models.dart';
import '../../stations/presentation/nearest_station_controller.dart';
import 'departure_countdown.dart';
import 'widgets/station_picker_sheet.dart';

/// The Jadwal tab: a departures board for the rider's current station (or
/// one they pick), with a clear "Cari kereta" entry to the Dari/Ke route
/// search (`TripSearchPage`).
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
    // departure that has since left drops off the board on its own: the
    // real RPC always queries "from now", and the estimate fallback always
    // regenerates from "now" too, so a re-fetch alone is what retires a
    // passed time. The `setState` also re-evaluates the countdowns, and
    // `items.where(isAfter(now))` in `_DeparturesBoard` below covers the gap
    // between ticks so nothing stale lingers up to 30s late.
    _refreshTimer = Timer.periodic(_refreshInterval, (_) {
      final id = _lastSelectedStationId;
      if (id != null) {
        ref.invalidate(departuresProvider(id));
      }
      if (mounted) {
        setState(() {});
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
    final nearest = ref
        .watch(nearestStationControllerProvider)
        .asData
        ?.value
        .firstOrNull;
    final selectedId = _manuallySelectedStationId ?? nearest?.station.id;
    _lastSelectedStationId = selectedId;

    return Scaffold(
      appBar: AppBar(title: const Text('Jadwal')),
      body: SafeArea(
        child: stations.when(
          loading: () => const _BoardSkeleton(),
          error: (error, stack) => TkErrorState(
            title: 'Daftar stasiun belum tersedia',
            message: 'Muat cache lokal lalu coba lagi.',
            onRetry: () => ref.invalidate(stationListProvider),
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

class _BoardSkeleton extends StatelessWidget {
  const _BoardSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      children: const <Widget>[
        TkSkeleton(height: 72, radius: 20),
        SizedBox(height: 12),
        TkSkeleton(height: 72, radius: 20),
        SizedBox(height: 28),
        TkListSkeleton(),
      ],
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
    final tk = context.tk;
    final textTheme = Theme.of(context).textTheme;
    final departures = ref.watch(departuresProvider(station.id));
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      children: <Widget>[
        TkCard(
          tone: TkCardTone.soft,
          onTap: () => context.push('/schedule/search'),
          semanticLabel: 'Cari kereta. Pilih stasiun asal dan tujuan.',
          child: Row(
            children: <Widget>[
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: tk.primary,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.search_rounded, color: tk.onPrimary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('Cari kereta', style: textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      'Pilih stasiun asal dan tujuan, lihat jam berangkat dan tiba.',
                      style: textTheme.bodySmall?.copyWith(color: tk.textMuted),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: tk.textMuted),
            ],
          ),
        ),
        const SizedBox(height: 12),
        TkCard(
          onTap: () => _pickStation(context),
          semanticLabel:
              '${isUsingNearest ? 'Stasiun terdekat' : 'Stasiun dipilih'} '
              '${station.name}. Ketuk untuk ganti stasiun.',
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
          child: ExcludeSemantics(
            child: Row(
              children: <Widget>[
                Icon(Icons.train_rounded, color: tk.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        isUsingNearest ? 'Stasiun terdekat' : 'Stasiun dipilih',
                        style: textTheme.bodySmall?.copyWith(
                          color: tk.textMuted,
                        ),
                      ),
                      Text(
                        station.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.titleLarge,
                      ),
                    ],
                  ),
                ),
                if (onUseNearest != null && !isUsingNearest)
                  IconButton(
                    tooltip: 'Pakai stasiun terdekat',
                    onPressed: onUseNearest,
                    icon: const Icon(Icons.my_location_rounded),
                  ),
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Icon(Icons.unfold_more_rounded, color: tk.textMuted),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        departures.when(
          loading: () => const _SectionHeading(freshness: null),
          error: (error, stack) => const _SectionHeading(freshness: null),
          data: (all) =>
              _SectionHeading(freshness: _upcoming(all).firstOrNull?.freshness),
        ),
        const SizedBox(height: 12),
        departures.when(
          loading: () => const TkListSkeleton(),
          error: (error, stack) => TkErrorState(
            title: 'Jadwal belum tersedia',
            message: 'Belum ada cache jadwal untuk stasiun ini.',
            onRetry: () => ref.invalidate(departuresProvider(station.id)),
          ),
          data: (allItems) {
            // Belt-and-suspenders alongside the periodic re-fetch: a
            // departure whose time has already passed since the last fetch
            // (up to the refresh interval stale) never lingers on screen.
            final items = _upcoming(allItems);
            if (items.isEmpty) {
              return const AppEmptyState(
                icon: Icons.schedule_outlined,
                title: 'Tidak ada keberangkatan',
                message: 'Belum ada jadwal untuk stasiun ini.',
              );
            }
            final headerFreshness = items.first.freshness;
            return Column(
              children: <Widget>[
                for (var i = 0; i < items.length; i += 1)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _DepartureCard(
                      departure: items[i],
                      originName: station.name,
                      isNext: i == 0,
                      showFreshness: items[i].freshness != headerFreshness,
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  List<Departure> _upcoming(List<Departure> all) {
    final now = DateTime.now();
    return all.where((d) => d.expectedAt.isAfter(now)).toList(growable: false);
  }

  Future<void> _pickStation(BuildContext context) async {
    final selected = await showStationPicker(
      context,
      stations: stations,
      title: 'Ganti stasiun',
      selectedId: station.id,
    );
    if (selected != null) {
      onPickStation(selected);
    }
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.freshness});

  final DataFreshness? freshness;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Semantics(
            header: true,
            child: Text(
              'Keberangkatan berikutnya',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
        ),
        if (freshness != null) ...<Widget>[
          const SizedBox(width: 8),
          DataFreshnessBadge(freshness: freshness!, compact: true),
        ],
      ],
    );
  }
}

class _DepartureCard extends StatelessWidget {
  const _DepartureCard({
    required this.departure,
    required this.originName,
    required this.isNext,
    required this.showFreshness,
  });

  final Departure departure;
  final String originName;
  final bool isNext;
  final bool showFreshness;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final textTheme = Theme.of(context).textTheme;
    final time = DateFormat.Hm('id_ID').format(departure.expectedAt);
    final countdown = formatCountdown(
      departure.expectedAt.difference(DateTime.now()),
    );
    final detail = <String>[
      if (departure.lineName.isNotEmpty) departure.lineName,
      if (departure.platform != null && departure.platform!.isNotEmpty)
        departure.platform!,
    ].join(' • ');
    return TkCard(
      tone: isNext ? TkCardTone.soft : TkCardTone.surface,
      semanticLabel:
          'Berangkat $time dari $originName ke ${departure.destination}, '
          '${countdown == 'Sekarang' ? 'sekarang' : '$countdown lagi'}',
      child: ExcludeSemantics(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 64),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    time,
                    style: textTheme.titleLarge?.copyWith(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      fontFeatures: AppTheme.timeFeatures,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    countdown,
                    style: textTheme.labelLarge?.copyWith(
                      color: isNext ? tk.primary : tk.textMuted,
                      fontFeatures: AppTheme.timeFeatures,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: TkRouteDots(count: 2, filled: isNext ? 1 : 0, height: 44),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    originName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodySmall?.copyWith(color: tk.textMuted),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tujuan ${departure.destination}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.titleSmall,
                  ),
                  if (detail.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 2),
                    Text(
                      detail,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodySmall?.copyWith(color: tk.textMuted),
                    ),
                  ],
                  if (isNext || showFreshness) ...<Widget>[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: <Widget>[
                        if (isNext)
                          const TkPill(
                            label: 'Berikutnya',
                            tone: TkPillTone.primary,
                            dense: true,
                          ),
                        if (showFreshness)
                          DataFreshnessBadge(
                            freshness: departure.freshness,
                            compact: true,
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
