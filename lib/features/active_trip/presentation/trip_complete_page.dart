import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/utils/geo.dart';
import '../../../core/utils/map_launcher.dart';
import '../../../core/widgets/tk_components.dart';
import '../../../data/providers/demo_data.dart';
import '../../../data/providers/provider_registry.dart';
import '../../../domain/entities/active_trip.dart';
import '../../../domain/entities/transit_models.dart';
import '../../history/presentation/share/share_cards.dart';
import '../../history/presentation/share/share_data.dart';
import '../../history/presentation/share/share_preview_sheet.dart';
import 'active_trip_controller.dart';

/// Real station name for [id]: live station list first, then the bundled demo
/// data, then the raw id so the screen never fails on an unknown station.
String _stationName(String? id, List<Station> stations) {
  if (id == null) {
    return 'Tujuan';
  }
  final fromLive = stations.where((s) => s.id == id).firstOrNull?.name;
  if (fromLive != null) {
    return fromLive;
  }
  return demoStations.where((s) => s.id == id).firstOrNull?.name ?? id;
}

/// "Perjalanan selesai": a calm confirmation of a trip that already closed by
/// itself on arrival. A summary of real numbers, a share action, and the way
/// out. The session is still populated here; `dismissCompleted()` clears it.
class TripCompletePage extends ConsumerWidget {
  const TripCompletePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tk = context.tk;
    final theme = Theme.of(context);
    final session = ref.watch(activeTripControllerProvider);
    final stations = ref.watch(stationListProvider).value ?? const <Station>[];
    final destinationName = session == null
        ? null
        : _stationName(session.trip.destinationStationId, stations);
    final destinationStation = session == null
        ? null
        : stations
              .where((s) => s.id == session.trip.destinationStationId)
              .firstOrNull;
    final finalDestinationQuery = session?.finalDestinationQuery;

    void finish() {
      ref.read(activeTripControllerProvider.notifier).dismissCompleted();
      context.go('/');
    }

    void openHistory() {
      final router = GoRouter.of(context);
      ref.read(activeTripControllerProvider.notifier).dismissCompleted();
      router.go('/');
      unawaited(router.push<void>('/history'));
    }

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: tk.successSoft,
                        borderRadius: BorderRadius.circular(TkRadius.control),
                      ),
                      child: Icon(
                        Icons.check_rounded,
                        size: 30,
                        color: tk.success,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Semantics(
                    header: true,
                    child: Text(
                      destinationName == null
                          ? 'Perjalanan selesai'
                          : 'Kamu sudah tiba di $destinationName',
                      style: theme.textTheme.headlineLarge,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // The trip is already closed here, whether it ended on
                  // arrival or from "Aku sudah turun", so say only that.
                  Text(
                    session == null
                        ? 'Perjalanan ini sudah ditutup.'
                        : 'Perjalanan sudah ditutup dan tercatat di riwayat.',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: tk.textMuted,
                    ),
                  ),
                  if (session != null) ...<Widget>[
                    const SizedBox(height: 24),
                    _SummaryCard(session: session, stations: stations),
                  ],
                  if (finalDestinationQuery != null &&
                      destinationStation != null) ...<Widget>[
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () => unawaited(
                        launchMapDirectionsToQuery(
                          destinationStation.latitude,
                          destinationStation.longitude,
                          finalDestinationQuery,
                        ),
                      ),
                      icon: const Icon(Icons.map_outlined),
                      label: Text(
                        'Buka rute ke $finalDestinationQuery',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                  const SizedBox(height: 28),
                  FilledButton(
                    onPressed: finish,
                    child: const Text('Selesai'),
                  ),
                  if (session != null) ...<Widget>[
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: () => showSharePreviewSheet(
                        context,
                        TripShareSpec(_shareData(session, stations)),
                      ),
                      icon: const Icon(Icons.ios_share_rounded),
                      label: const Text('Bagikan perjalanan'),
                    ),
                  ],
                  const SizedBox(height: 6),
                  TextButton(
                    onPressed: openHistory,
                    child: const Text('Lihat riwayat'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Share card values for the just-finished trip, from the live session. The
/// duration is the real elapsed time, not the schedule.
TripShareData _shareData(ActiveTripSession session, List<Station> stations) {
  final elapsed = session.updatedAt.difference(session.startedAt);
  final line = session.trip.legs
      .where((leg) => leg.mode == TransportMode.commuterRail)
      .map((leg) => leg.lineName)
      .whereType<String>()
      .firstOrNull;
  return TripShareData(
    originName: _stationName(session.trip.originStationId, stations),
    destinationName: _stationName(session.trip.destinationStationId, stations),
    date: session.startedAt,
    duration: elapsed > Duration.zero ? elapsed : null,
    stationCount: session.trip.stationIds.length,
    lineName: line,
  );
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.session, required this.stations});

  final ActiveTripSession session;
  final List<Station> stations;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tk = context.tk;
    final data = _shareData(session, stations);
    final duration = data.duration;
    final distance = session.distanceMeters;
    final elapsed = session.updatedAt.difference(session.startedAt);
    final averageSpeedKmh = elapsed.inSeconds > 0 && distance > 0
        ? (distance / 1000) / (elapsed.inSeconds / 3600)
        : null;
    final footnote = <String>[
      if (data.visibleStationCount != null)
        '${data.visibleStationCount} stasiun',
      if (data.lineName != null && data.lineName!.trim().isNotEmpty)
        data.lineName!.trim(),
    ].join(', ');

    return TkCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              TkRouteDots(count: 2, filled: 2, height: 58),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 58,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        data.originName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall,
                      ),
                      Text(
                        data.destinationName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(color: tk.border),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: _Stat(
                  label: 'Waktu tempuh',
                  value: duration == null ? '-' : formatDuration(duration),
                ),
              ),
              Expanded(
                child: _Stat(
                  label: 'Jarak',
                  value: distance > 0 ? formatDistanceMeters(distance) : '-',
                ),
              ),
              Expanded(
                child: _Stat(
                  label: 'Rata-rata',
                  value: formatSpeedKmh(averageSpeedKmh),
                ),
              ),
            ],
          ),
          if (footnote.isNotEmpty) ...<Widget>[
            const SizedBox(height: 14),
            Text(footnote, style: theme.textTheme.bodySmall),
          ],
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label, style: theme.textTheme.bodySmall),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontFeatures: AppTheme.timeFeatures,
          ),
        ),
      ],
    );
  }
}
