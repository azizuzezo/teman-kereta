import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/utils/geo.dart';
import '../../../core/widgets/auth_guard.dart';
import '../../../core/widgets/data_badges.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/tk_components.dart';
import '../../../core/widgets/trip_leg_timeline_tile.dart';
import '../../../data/providers/demo_data.dart';
import '../../../data/providers/provider_registry.dart';
import '../../../domain/entities/transit_models.dart';
import '../../../domain/usecases/krl_fare.dart';
import '../../../domain/usecases/rail_distance.dart';
import '../../active_trip/presentation/active_trip_controller.dart';
import '../../favorites/presentation/favorite_route_controller.dart';
import 'trip_search_controller.dart';
import 'widgets/route_endpoints.dart';

class TripDetailPage extends ConsumerWidget {
  const TripDetailPage({required this.tripId, super.key});

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
        appBar: AppBar(title: const Text('Detail perjalanan')),
        body: AppEmptyState(
          icon: Icons.route_outlined,
          title: 'Perjalanan tidak ditemukan',
          message: 'Hasil pencarian sudah tidak aktif. Cari perjalanan lagi.',
          action: FilledButton(
            onPressed: () => context.go('/schedule/search'),
            child: const Text('Cari lagi'),
          ),
        ),
      );
    }

    final favorite = ref.watch(favoriteRouteControllerProvider);
    final isFavorite =
        favorite == '${trip.originStationId}|${trip.destinationStationId}';
    final activeTrip = ref.watch(activeTripControllerProvider);
    final time = DateFormat.Hm('id_ID');
    final stations = ref.watch(stationListProvider).value ?? const <Station>[];
    final pathStations = _resolvePathStations(trip.stationIds, stations);
    // Only quote a fare when every station on the route resolved to real
    // coordinates. A partially-resolved path measures short, and a short
    // measurement quotes a fare that is wrong in the passenger's favour
    // right up until they reach the gate, so better to show nothing.
    final fareMeters = pathStations.length < 2
        ? null
        : railPathDistanceMeters(pathStations).round();
    final fare = fareMeters == null ? null : krlFareRupiah(fareMeters);
    final originName = _stationName(trip.originStationId, stations);
    final destinationName = _stationName(trip.destinationStationId, stations);
    final transferByIndex = <int, String>{
      for (final boundary in trip.transferBoundaries)
        boundary.index: boundary.instruction ?? 'Transit',
    };

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detail perjalanan'),
        actions: <Widget>[
          IconButton(
            tooltip: isFavorite
                ? 'Hapus dari favorit'
                : 'Simpan sebagai favorit',
            onPressed: () => ref
                .read(favoriteRouteControllerProvider.notifier)
                .toggle(trip.originStationId, trip.destinationStationId),
            icon: Icon(
              isFavorite ? Icons.star_rounded : Icons.star_outline_rounded,
              color: isFavorite ? tk.primary : null,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: <Widget>[
            TkCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    '${time.format(trip.departureAt)} – ${time.format(trip.arrivalAt)}',
                    style: textTheme.displayLarge?.copyWith(
                      fontFeatures: AppTheme.timeFeatures,
                    ),
                  ),
                  const SizedBox(height: 14),
                  RouteEndpoints(
                    highlighted: true,
                    top: Text(
                      originName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.titleMedium,
                    ),
                    bottom: Text(
                      destinationName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.titleMedium,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Divider(height: 1, color: tk.border),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 28,
                    runSpacing: 14,
                    children: <Widget>[
                      _Stat(
                        label: 'Durasi',
                        value: '${trip.durationMinutes} menit',
                      ),
                      _Stat(
                        label: 'Transit',
                        value: trip.transfers == 0
                            ? 'Langsung'
                            : '${trip.transfers}x',
                      ),
                      if (fareMeters != null)
                        _Stat(
                          label: 'Jarak',
                          value: formatDistanceMeters(fareMeters.toDouble()),
                        ),
                      if (trip.walkingMeters > 0)
                        _Stat(
                          label: 'Jalan kaki',
                          value: '${trip.walkingMeters} m',
                        ),
                      _Stat(
                        label: 'Tarif',
                        value: fare == null
                            ? 'Belum tersedia'
                            : formatRupiah(fare),
                      ),
                    ],
                  ),
                  if (fare != null) ...<Widget>[
                    const SizedBox(height: 14),
                    Text(
                      'Tarif resmi KRL: Rp3.000 untuk 25 km pertama, lalu '
                      '+Rp1.000 tiap 10 km berikutnya. Transit di dalam '
                      'sistem KRL tidak menambah tarif. Kamu tap in sekali '
                      'dan tap out sekali.',
                      style: textTheme.bodySmall?.copyWith(color: tk.textMuted),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 10,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: <Widget>[
                      DataFreshnessBadge(freshness: trip.freshness),
                      Text(
                        '${trip.sourceLabel} • diperbarui '
                        '${DateFormat('dd MMM, HH:mm', 'id_ID').format(trip.updatedAt)}',
                        style: textTheme.bodySmall?.copyWith(
                          color: tk.textMuted,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            const _Heading('Langkah perjalanan'),
            const SizedBox(height: 14),
            for (var index = 0; index < trip.legs.length; index += 1)
              TripLegTimelineTile(
                leg: trip.legs[index],
                isLast: index == trip.legs.length - 1,
              ),
            if (trip.stationIds.length >= 2) ...<Widget>[
              const SizedBox(height: 24),
              const _Heading('Stasiun yang dilewati'),
              const SizedBox(height: 12),
              TkCard(
                child: _StopsTimeline(
                  names: <String>[
                    for (final id in trip.stationIds)
                      _stationName(id, stations),
                  ],
                  transferByIndex: transferByIndex,
                ),
              ),
            ],
            const SizedBox(height: 20),
            TkRowGroup(
              children: <Widget>[
                TkRow(
                  icon: Icons.alt_route_rounded,
                  title: 'Lanjutkan dengan moda lain',
                  subtitle: 'Gojek atau Grab dari stasiun tujuan',
                  onTap: () => context.push('/trip/$tripId/multimodal'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TkCard(
              tone: TkCardTone.alt,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Icon(Icons.info_outline_rounded, color: tk.textMuted),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Waktu mengikuti jadwal, bukan posisi kereta langsung. '
                      'Perubahan peron dan layanan diumumkan di stasiun.',
                      style: textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            TextFormField(
              key: const ValueKey('finalDestinationQuery'),
              initialValue: ref
                  .read(tripSearchControllerProvider)
                  .finalDestinationQuery,
              decoration: const InputDecoration(
                labelText: 'Tujuan akhir (opsional)',
                hintText: 'Contoh: Kantor Pusat, Jl. Sudirman',
                prefixIcon: Icon(Icons.location_on_outlined),
              ),
              onChanged: (value) => ref
                  .read(tripSearchControllerProvider.notifier)
                  .setFinalDestinationQuery(value),
            ),
          ],
        ),
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          color: tk.bg,
          border: Border(top: BorderSide(color: tk.border)),
        ),
        child: SafeArea(
          minimum: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            height: 56,
            child: FilledButton.icon(
              onPressed: () {
                if (activeTrip != null) {
                  unawaited(context.push('/active-trip'));
                  return;
                }
                checkAuthOrPrompt(
                  context,
                  featureName: 'Mulai Perjalanan',
                  onAllowed: () async {
                    final finalDestinationQuery = ref
                        .read(tripSearchControllerProvider)
                        .finalDestinationQuery;
                    await ref
                        .read(activeTripControllerProvider.notifier)
                        .start(
                          trip,
                          finalDestinationQuery: finalDestinationQuery,
                        );
                    if (context.mounted) {
                      unawaited(context.push('/active-trip'));
                    }
                  },
                );
              },
              icon: const Icon(Icons.navigation_rounded),
              label: Text(
                activeTrip == null
                    ? 'Mulai perjalanan'
                    : 'Buka perjalanan aktif',
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Every station on the route, in order, resolved to a record carrying real
  /// coordinates, or an empty list if even one of them can't be resolved.
  ///
  /// All-or-nothing on purpose: this feeds the fare, and a route measured
  /// with stations missing from the middle comes out shorter than the journey
  /// really is, which quotes a fare that is too low. No number beats a wrong
  /// one the passenger only finds out about at the gate.
  List<Station> _resolvePathStations(List<String> ids, List<Station> stations) {
    final byId = <String, Station>{
      for (final station in demoStations) station.id: station,
      // Live data last so it overrides the bundled demo fallback.
      for (final station in stations) station.id: station,
    };
    final resolved = <Station>[];
    for (final id in ids) {
      final station = byId[id];
      if (station == null) {
        return const <Station>[];
      }
      resolved.add(station);
    }
    return resolved;
  }
}

String _stationName(String id, List<Station> stations) {
  return stations.where((s) => s.id == id).firstOrNull?.name ??
      demoStations.where((s) => s.id == id).firstOrNull?.name ??
      id;
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Text(text, style: Theme.of(context).textTheme.titleLarge),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          label,
          style: textTheme.bodySmall?.copyWith(color: context.tk.textMuted),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: textTheme.titleMedium?.copyWith(
            fontFeatures: AppTheme.timeFeatures,
          ),
        ),
      ],
    );
  }
}

/// Every station of the trip on a route line. The stops between the origin,
/// the transfer stations and the destination are folded behind one row so a
/// 20-stop line stays scannable; tap it to expand.
class _StopsTimeline extends StatefulWidget {
  const _StopsTimeline({required this.names, required this.transferByIndex});

  final List<String> names;
  final Map<int, String> transferByIndex;

  @override
  State<_StopsTimeline> createState() => _StopsTimelineState();
}

class _StopsTimelineState extends State<_StopsTimeline> {
  bool _expanded = false;

  bool _isKey(int index) =>
      index == 0 ||
      index == widget.names.length - 1 ||
      widget.transferByIndex.containsKey(index);

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    var i = 0;
    while (i < widget.names.length) {
      if (!_expanded && !_isKey(i)) {
        var j = i;
        while (j < widget.names.length && !_isKey(j)) {
          j += 1;
        }
        rows.add(
          _FoldedStops(
            count: j - i,
            onTap: () => setState(() => _expanded = true),
          ),
        );
        i = j;
        continue;
      }
      rows.add(
        _StopRow(
          name: widget.names[i],
          isFirst: i == 0,
          isLast: i == widget.names.length - 1,
          transfer: widget.transferByIndex[i],
        ),
      );
      i += 1;
    }
    return Column(children: rows);
  }
}

class _StopRow extends StatelessWidget {
  const _StopRow({
    required this.name,
    required this.isFirst,
    required this.isLast,
    required this.transfer,
  });

  final String name;
  final bool isFirst;
  final bool isLast;
  final String? transfer;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final textTheme = Theme.of(context).textTheme;
    final isKey = isFirst || isLast || transfer != null;
    final dotColor = isLast
        ? tk.accent
        : transfer != null
        ? tk.warning
        : isFirst
        ? tk.primary
        : tk.border;
    final label = isFirst
        ? '$name, stasiun naik'
        : isLast
        ? '$name, stasiun tujuan'
        : transfer != null
        ? '$name, stasiun transit: $transfer'
        : name;
    return Semantics(
      label: label,
      excludeSemantics: true,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SizedBox(
              width: 14,
              child: Column(
                children: <Widget>[
                  Container(
                    width: isKey ? 14 : 10,
                    height: isKey ? 14 : 10,
                    margin: EdgeInsets.only(top: isKey ? 3 : 5),
                    decoration: BoxDecoration(
                      color: isFirst && !isLast ? tk.surface : dotColor,
                      shape: BoxShape.circle,
                      border: isFirst && !isLast
                          ? Border.all(color: dotColor, width: 3)
                          : null,
                    ),
                  ),
                  if (!isLast)
                    Expanded(
                      child: Container(
                        width: 3,
                        margin: const EdgeInsets.symmetric(vertical: 2),
                        color: tk.border,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      name,
                      style: isKey
                          ? textTheme.titleSmall
                          : textTheme.bodyMedium,
                    ),
                    if (transfer != null)
                      Text(
                        transfer!,
                        style: textTheme.bodySmall?.copyWith(
                          color: tk.warning,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FoldedStops extends StatelessWidget {
  const _FoldedStops({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return Semantics(
      button: true,
      label: 'Tampilkan $count stasiun di antara',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Row(
            children: <Widget>[
              SizedBox(
                width: 14,
                child: Center(
                  child: Container(width: 3, height: 32, color: tk.border),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  '$count stasiun di antara',
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(color: tk.primary),
                ),
              ),
              Icon(Icons.expand_more_rounded, color: tk.primary),
            ],
          ),
        ),
      ),
    );
  }
}
