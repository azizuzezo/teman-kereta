import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/utils/map_launcher.dart';
import '../../../core/widgets/data_badges.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/tk_components.dart';
import '../../../data/providers/demo_data.dart';
import '../../../data/providers/provider_registry.dart';
import '../../../domain/entities/transit_models.dart';
import '../../../domain/usecases/nearest_station_finder.dart';
import '../../favorites/presentation/favorite_route_controller.dart';
import '../../stations/presentation/nearest_station_controller.dart';
import 'departure_countdown.dart';
import 'trip_search_controller.dart';
import 'widgets/route_endpoints.dart';
import 'widgets/station_picker_sheet.dart';

/// "Cari kereta": the Dari/Ke route-search flow, reached from the Jadwal
/// tab and the Beranda quick-trip card.
class TripSearchPage extends ConsumerWidget {
  const TripSearchPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stations = ref.watch(stationListProvider);
    final search = ref.watch(tripSearchControllerProvider);
    final controller = ref.read(tripSearchControllerProvider.notifier);
    final nearest = ref
        .watch(nearestStationControllerProvider)
        .asData
        ?.value
        .firstOrNull;
    final favorite = ref.watch(favoriteRouteControllerProvider);
    final stationList = stations.asData?.value ?? const <Station>[];

    return Scaffold(
      appBar: AppBar(title: const Text('Cari kereta')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          children: <Widget>[
            stations.when(
              loading: () => const Column(
                children: <Widget>[
                  TkSkeleton(height: 132, radius: 20),
                  SizedBox(height: 12),
                  TkSkeleton(height: 56, radius: 14),
                ],
              ),
              error: (error, stack) => TkErrorState(
                title: 'Daftar stasiun belum tersedia',
                message: 'Muat cache lokal lalu coba lagi.',
                onRetry: () => ref.invalidate(stationListProvider),
              ),
              data: (items) => _RouteForm(stations: items, search: search),
            ),
            if (nearest != null) ...<Widget>[
              const SizedBox(height: 12),
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
            ],
            if (favorite != null &&
                favorite.split('|').length == 2) ...<Widget>[
              const SizedBox(height: 12),
              _FavoriteRouteShortcut(
                originName: _stationName(favorite.split('|')[0], stationList),
                destinationName: _stationName(
                  favorite.split('|')[1],
                  stationList,
                ),
                onTap: () {
                  final ids = favorite.split('|');
                  controller
                    ..setOrigin(ids[0])
                    ..setDestination(ids[1]);
                },
              ),
            ],
            if (search.isLoading) ...<Widget>[
              const SizedBox(height: 24),
              const TkListSkeleton(count: 3),
            ] else if (search.results.isNotEmpty) ...<Widget>[
              const SizedBox(height: 28),
              Row(
                children: <Widget>[
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(
                        '${search.results.length} alternatif',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  DataFreshnessBadge(
                    freshness: search.results.first.freshness,
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
                    originName: _stationName(
                      search.results[index].originStationId,
                      stationList,
                    ),
                    destinationName: _stationName(
                      search.results[index].destinationStationId,
                      stationList,
                    ),
                    label: switch (index) {
                      0 => 'Pilihan tercepat',
                      1 => 'Jalan kaki lebih sedikit',
                      _ => 'Berangkat berikutnya',
                    },
                    emphasized: index == 0,
                    onTap: () =>
                        context.push('/trip/${search.results[index].id}'),
                  ),
                ),
            ] else if (search.hasSearched &&
                search.errorMessage == null) ...<Widget>[
              const SizedBox(height: 24),
              const AppEmptyState(
                icon: Icons.route_outlined,
                title: 'Belum ada kereta untuk rute ini',
                message:
                    'Tidak ada jadwal yang cocok pada jam tersebut. Coba ganti jam berangkat atau stasiunnya.',
              ),
            ] else if (search.errorMessage == null) ...<Widget>[
              const SizedBox(height: 16),
              const _SearchHint(),
            ],
          ],
        ),
      ),
    );
  }
}

String _stationName(String id, List<Station> stations) {
  return stations.where((s) => s.id == id).firstOrNull?.name ??
      demoStations.where((s) => s.id == id).firstOrNull?.name ??
      id;
}

class _RouteForm extends ConsumerWidget {
  const _RouteForm({required this.stations, required this.search});

  final List<Station> stations;
  final TripSearchState search;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tk = context.tk;
    final controller = ref.read(tripSearchControllerProvider.notifier);
    final originName = _stationName(search.originStationId, stations);
    final destinationName = _stationName(search.destinationStationId, stations);
    return TkCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              const Padding(
                padding: EdgeInsets.only(left: 2, right: 12),
                child: SizedBox(width: 14, child: _FormRouteDots()),
              ),
              Expanded(
                child: Column(
                  children: <Widget>[
                    _PickerField(
                      label: 'Dari',
                      value: originName,
                      icon: Icons.unfold_more_rounded,
                      onTap: () async {
                        final id = await showStationPicker(
                          context,
                          stations: stations,
                          title: 'Pilih stasiun asal',
                          selectedId: search.originStationId,
                        );
                        if (id != null) {
                          controller.setOrigin(id);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    _PickerField(
                      label: 'Ke',
                      value: destinationName,
                      icon: Icons.unfold_more_rounded,
                      onTap: () async {
                        final id = await showStationPicker(
                          context,
                          stations: stations,
                          title: 'Pilih stasiun tujuan',
                          selectedId: search.destinationStationId,
                        );
                        if (id != null) {
                          controller.setDestination(id);
                        }
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              IconButton.filledTonal(
                tooltip: 'Tukar stasiun',
                onPressed: controller.swapStations,
                icon: const Icon(Icons.swap_vert_rounded),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _TimeField(
            search: search,
            onPick: () async {
              final initial = TimeOfDay.fromDateTime(search.departureAt);
              final picked = await showTimePicker(
                context: context,
                initialTime: initial,
                helpText: 'Jam berangkat',
                cancelText: 'Batal',
                confirmText: 'Pilih',
              );
              if (picked != null) {
                controller.setDepartureTime(picked.hour, picked.minute);
              }
            },
            onNow: controller.setDepartNow,
          ),
          if (search.errorMessage != null) ...<Widget>[
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(Icons.error_outline_rounded, size: 18, color: tk.danger),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    search.errorMessage!,
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: tk.danger),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton.icon(
              onPressed: search.isLoading ? null : controller.search,
              icon: search.isLoading
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.search_rounded),
              label: Text(search.isLoading ? 'Mencari…' : 'Cari kereta'),
            ),
          ),
        ],
      ),
    );
  }
}

/// The dots between the two fields. Their centers line up with the middle of
/// each 56dp field (fields are 56dp apart by 12dp of gap).
class _FormRouteDots extends StatelessWidget {
  const _FormRouteDots();

  @override
  Widget build(BuildContext context) {
    return const TkRouteDots(count: 2, filled: 0, height: 78);
  }
}

class _PickerField extends StatelessWidget {
  const _PickerField({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final textTheme = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      label: '$label: $value. Ketuk untuk mengganti.',
      excludeSemantics: true,
      child: Material(
        color: tk.surfaceAlt,
        borderRadius: BorderRadius.circular(TkRadius.control),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          label,
                          style: textTheme.labelMedium?.copyWith(
                            color: tk.textMuted,
                          ),
                        ),
                        Text(
                          value,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.titleMedium,
                        ),
                      ],
                    ),
                  ),
                  Icon(icon, size: 20, color: tk.textMuted),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TimeField extends StatelessWidget {
  const _TimeField({
    required this.search,
    required this.onPick,
    required this.onNow,
  });

  final TripSearchState search;
  final VoidCallback onPick;
  final VoidCallback onNow;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final textTheme = Theme.of(context).textTheme;
    final now = DateTime.now();
    final at = search.departureAt;
    final isTomorrow =
        !search.departNow &&
        DateTime(
          at.year,
          at.month,
          at.day,
        ).isAfter(DateTime(now.year, now.month, now.day));
    final value = search.departNow
        ? 'Sekarang'
        : '${DateFormat.Hm('id_ID').format(at)}${isTomorrow ? ' besok' : ''}';
    return Row(
      children: <Widget>[
        Expanded(
          child: Semantics(
            button: true,
            label: 'Jam berangkat: $value. Ketuk untuk mengganti.',
            excludeSemantics: true,
            child: Material(
              color: tk.surfaceAlt,
              borderRadius: BorderRadius.circular(TkRadius.control),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onPick,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 56),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    child: Row(
                      children: <Widget>[
                        Icon(Icons.schedule_rounded, color: tk.textMuted),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                'Berangkat',
                                style: textTheme.labelMedium?.copyWith(
                                  color: tk.textMuted,
                                ),
                              ),
                              Text(
                                value,
                                style: textTheme.titleMedium?.copyWith(
                                  fontFeatures: AppTheme.timeFeatures,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        if (!search.departNow) ...<Widget>[
          const SizedBox(width: 8),
          TextButton(
            onPressed: onNow,
            style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
            child: const Text('Sekarang'),
          ),
        ],
      ],
    );
  }
}

/// Nearest-station-with-distance block for the trip-search flow, mirroring
/// the home tab's equivalent card so picking an origin isn't only convenient
/// from Home.
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
    final tk = context.tk;
    final textTheme = Theme.of(context).textTheme;
    return TkCard(
      tone: TkCardTone.alt,
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      child: Row(
        children: <Widget>[
          Icon(Icons.near_me_outlined, color: tk.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Stasiun terdekat: ${nearest.station.name}',
                  style: textTheme.titleSmall,
                ),
                Text(
                  '${_formatDistance(nearest.distanceMeters)} • '
                  '${nearest.walkingMinutes} menit jalan kaki',
                  style: textTheme.bodySmall?.copyWith(color: tk.textMuted),
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
    );
  }

  String _formatDistance(double meters) {
    if (meters >= 1000) {
      return '${(meters / 1000).toStringAsFixed(1)} km';
    }
    return '${meters.round()} m';
  }
}

class _FavoriteRouteShortcut extends StatelessWidget {
  const _FavoriteRouteShortcut({
    required this.originName,
    required this.destinationName,
    required this.onTap,
  });

  final String originName;
  final String destinationName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final textTheme = Theme.of(context).textTheme;
    return TkCard(
      tone: TkCardTone.alt,
      onTap: onTap,
      semanticLabel:
          'Rute favorit: $originName ke $destinationName. '
          'Ketuk untuk memakai rute ini.',
      child: ExcludeSemantics(
        child: Row(
          children: <Widget>[
            Icon(Icons.star_rounded, color: tk.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Rute favorit',
                    style: textTheme.bodySmall?.copyWith(color: tk.textMuted),
                  ),
                  Text(
                    '$originName → $destinationName',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.titleSmall,
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

class _SearchHint extends StatelessWidget {
  const _SearchHint();

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.info_outline_rounded, size: 18, color: tk.textMuted),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Pilih stasiun awal dan tujuan. Hasil pencarian diberi label '
              'sesuai sumber datanya.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: tk.textMuted),
            ),
          ),
        ],
      ),
    );
  }
}

class _TripResultCard extends StatelessWidget {
  const _TripResultCard({
    required this.trip,
    required this.originName,
    required this.destinationName,
    required this.label,
    required this.emphasized,
    required this.onTap,
  });

  final TransitTrip trip;
  final String originName;
  final String destinationName;
  final String label;
  final bool emphasized;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final textTheme = Theme.of(context).textTheme;
    final formatter = DateFormat.Hm('id_ID');
    final departs = trip.departureAt.difference(DateTime.now());
    final timeStyle = textTheme.titleLarge?.copyWith(
      fontSize: 22,
      fontWeight: FontWeight.w800,
      fontFeatures: AppTheme.timeFeatures,
    );
    final transfersLabel = trip.transfers == 0
        ? 'Langsung'
        : '${trip.transfers} transit';
    return TkCard(
      tone: emphasized ? TkCardTone.soft : TkCardTone.surface,
      onTap: onTap,
      semanticLabel:
          '$label. Berangkat ${formatter.format(trip.departureAt)} dari '
          '$originName, tiba ${formatter.format(trip.arrivalAt)} di '
          '$destinationName. ${trip.durationMinutes} menit, $transfersLabel.',
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: emphasized
                      ? Align(
                          alignment: Alignment.centerLeft,
                          child: TkPill(
                            label: label,
                            tone: TkPillTone.primary,
                            dense: true,
                          ),
                        )
                      : Text(
                          label,
                          style: textTheme.labelLarge?.copyWith(
                            color: tk.textMuted,
                          ),
                        ),
                ),
                if (departs.inSeconds > -60)
                  Text(
                    departs.inSeconds < 60
                        ? 'Berangkat sekarang'
                        : 'Berangkat ${formatCountdown(departs)} lagi',
                    style: textTheme.labelMedium?.copyWith(
                      color: tk.textMuted,
                      fontFeatures: AppTheme.timeFeatures,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            RouteEndpoints(
              highlighted: emphasized,
              top: _EndpointRow(
                time: formatter.format(trip.departureAt),
                name: originName,
                timeStyle: timeStyle,
              ),
              bottom: _EndpointRow(
                time: formatter.format(trip.arrivalAt),
                name: destinationName,
                timeStyle: timeStyle,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 14,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                Text(
                  _durationLabel(trip.durationMinutes),
                  style: textTheme.titleSmall?.copyWith(
                    fontFeatures: AppTheme.timeFeatures,
                  ),
                ),
                Text(
                  transfersLabel,
                  style: textTheme.bodyMedium?.copyWith(color: tk.textMuted),
                ),
                if (trip.walkingMeters > 0)
                  _Metric(
                    icon: Icons.directions_walk_rounded,
                    label: 'Jalan ${trip.walkingMeters} m',
                  ),
                DataFreshnessBadge(freshness: trip.freshness, compact: true),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _durationLabel(int minutes) {
    if (minutes < 60) {
      return '$minutes mnt';
    }
    final rest = minutes % 60;
    return rest == 0 ? '${minutes ~/ 60} j' : '${minutes ~/ 60} j $rest mnt';
  }
}

class _EndpointRow extends StatelessWidget {
  const _EndpointRow({
    required this.time,
    required this.name,
    required this.timeStyle,
  });

  final String time;
  final String name;
  final TextStyle? timeStyle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Text(time, style: timeStyle),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, size: 17, color: tk.textMuted),
        const SizedBox(width: 5),
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: tk.textMuted),
        ),
      ],
    );
  }
}
