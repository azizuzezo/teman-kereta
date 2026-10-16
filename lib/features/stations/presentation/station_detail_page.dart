import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/utils/map_launcher.dart';
import '../../../core/widgets/data_badges.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/facility_icon_chip.dart';
import '../../../core/widgets/tk_components.dart';
import '../../../data/providers/provider_registry.dart';
import '../../../domain/entities/transit_models.dart';
import '../../../domain/usecases/travel_estimate.dart';
import '../../home/domain/next_train_logic.dart';
import '../../schedule/presentation/trip_search_controller.dart';
import 'nearest_station_controller.dart';

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
          loading: () => const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 28),
            child: TkListSkeleton(count: 3),
          ),
          error: (error, stack) => TkErrorState(
            title: 'Stasiun belum dimuat',
            message: 'Data stasiun belum bisa dibaca. Coba lagi.',
            onRetry: () => ref.invalidate(stationListProvider),
          ),
          data: (items) {
            final station = items
                .where((item) => item.id == stationId)
                .firstOrNull;
            if (station == null) {
              return AppEmptyState(
                icon: Icons.wrong_location_outlined,
                title: 'Stasiun tidak ditemukan',
                message: 'Kode stasiun tidak ada di daftar.',
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
    final tk = context.tk;
    final textTheme = Theme.of(context).textTheme;
    final departures = ref.watch(departuresProvider(station.id));
    final now = ref.watch(clockProvider).now();
    final ranked =
        ref.watch(nearestStationControllerProvider).asData?.value ??
        const [];
    final fromUser = ranked
        .where((entry) => entry.station.id == station.id)
        .firstOrNull;
    final estimateLine = fromUser == null
        ? null
        : formatEstimateLine(fromUser.estimate);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
      children: <Widget>[
        TkCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Container(
                    constraints: const BoxConstraints(
                      minWidth: 52,
                      minHeight: 52,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: tk.primarySoft,
                      borderRadius: BorderRadius.circular(TkRadius.control),
                    ),
                    child: Text(
                      station.code,
                      style: textTheme.titleMedium?.copyWith(
                        color: tk.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      'Stasiun ${station.name}',
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.headlineMedium,
                    ),
                  ),
                ],
              ),
              if (station.lineIds.isNotEmpty) ...<Widget>[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: <Widget>[
                    for (final line in station.lineIds)
                      TkPill(
                        label: line,
                        icon: Icons.train_rounded,
                        tone: TkPillTone.primary,
                        dense: true,
                      ),
                  ],
                ),
              ],
              if (fromUser != null) ...<Widget>[
                const SizedBox(height: 12),
                Row(
                  children: <Widget>[
                    Icon(
                      Icons.near_me_rounded,
                      size: 18,
                      color: tk.textMuted,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        estimateLine == null
                            ? '${formatDistance(fromUser.distanceMeters)} dari kamu'
                            : '${formatDistance(fromUser.distanceMeters)} dari kamu · $estimateLine',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodyMedium?.copyWith(
                          fontFeatures: AppTheme.timeFeatures,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
                  if (station.wheelchairAccessible)
                    const FacilityIconChip(label: 'Akses kursi roda'),
                  for (final facility in station.facilities)
                    FacilityIconChip(label: facility),
                  if (station.facilities.isEmpty &&
                      !station.wheelchairAccessible)
                    Text(
                      'Fasilitas belum terverifikasi',
                      style: textTheme.bodySmall,
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: <Widget>[
            Expanded(
              child: FilledButton.icon(
                onPressed: () {
                  ref
                      .read(tripSearchControllerProvider.notifier)
                      .setOrigin(station.id);
                  unawaited(context.push('/schedule/search'));
                },
                icon: const Icon(Icons.route_outlined, size: 18),
                label: const Text('Cari rute'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => context.go('/explore?station=${station.id}'),
                icon: const Icon(Icons.explore_outlined, size: 18),
                label: const Text('Jelajahi sekitar'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => unawaited(
              launchMapDirections(
                station.latitude,
                station.longitude,
                label: station.name,
              ),
            ),
            icon: const Icon(Icons.directions_rounded, size: 18),
            label: const Text('Arah ke stasiun'),
          ),
        ),
        const SizedBox(height: 16),
        TkSectionLabel(
          'Keberangkatan berikutnya',
          trailing: departures.asData?.value == null ||
                  upcomingDepartures(departures.asData!.value, now).isEmpty
              ? null
              : DataFreshnessBadge(
                  freshness: upcomingDepartures(
                    departures.asData!.value,
                    now,
                  ).first.freshness,
                  compact: true,
                ),
        ),
        departures.when(
          loading: () => const TkListSkeleton(count: 3),
          error: (error, stack) => TkCard(
            child: TkErrorState(
              title: 'Jadwal belum dimuat',
              message: 'Periksa koneksi, lalu coba lagi.',
              onRetry: () => ref.invalidate(departuresProvider(station.id)),
            ),
          ),
          data: (items) {
            final upcoming = upcomingDepartures(items, now, limit: 8);
            if (upcoming.isEmpty) {
              return const TkCard(
                child: AppEmptyState(
                  icon: Icons.schedule_outlined,
                  title: 'Tidak ada keberangkatan',
                  message:
                      'Belum ada keberangkatan berikutnya dari stasiun ini.',
                ),
              );
            }
            return _DepartureList(departures: upcoming, now: now);
          },
        ),
      ],
    );
  }
}

class _DepartureList extends StatelessWidget {
  const _DepartureList({required this.departures, required this.now});

  final List<Departure> departures;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return Material(
      color: tk.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(TkRadius.card),
        side: BorderSide(color: tk.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: <Widget>[
          for (var i = 0; i < departures.length; i++) ...<Widget>[
            if (i > 0) Divider(height: 1, indent: 16, endIndent: 16, color: tk.border),
            _DepartureRow(departure: departures[i], now: now),
          ],
        ],
      ),
    );
  }
}

class _DepartureRow extends StatelessWidget {
  const _DepartureRow({required this.departure, required this.now});

  final Departure departure;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final time = DateFormat.Hm('id_ID').format(departure.expectedAt);
    final countdown = countdownLabel(departure.expectedAt.difference(now));
    final detail = <String>[
      departure.lineName,
      ?platformLabel(departure.platform),
    ].join(' · ');

    return Semantics(
      label: 'Ke ${departure.destination}, berangkat $time, $countdown. $detail',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Row(
          children: <Widget>[
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 64),
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(
                  time,
                  maxLines: 1,
                  softWrap: false,
                  style: textTheme.titleLarge?.copyWith(
                    fontFeatures: AppTheme.timeFeatures,
                  ),
                ),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    departure.destination,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.titleSmall,
                  ),
                  Text(
                    '$countdown · $detail',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
