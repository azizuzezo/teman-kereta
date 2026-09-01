import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/utils/geo.dart';
import '../../../core/utils/map_launcher.dart';
import '../../../core/widgets/data_badges.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../data/providers/demo_data.dart';
import '../../../data/providers/provider_registry.dart';
import '../../../domain/entities/active_trip.dart';
import '../../../domain/entities/transit_models.dart';
import '../../schedule/presentation/trip_search_controller.dart';
import 'active_trip_controller.dart';

class ActiveTripPage extends ConsumerWidget {
  const ActiveTripPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(activeTripControllerProvider);
    if (session == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Perjalanan aktif')),
        body: AppEmptyState(
          icon: Icons.navigation_outlined,
          title: 'Belum ada perjalanan aktif',
          message: 'Cari rute, buka detailnya, lalu pilih Mulai perjalanan.',
          action: FilledButton(
            onPressed: () => context.go('/schedule'),
            child: const Text('Cari perjalanan'),
          ),
        ),
      );
    }

    if (session.state == ActiveTripState.missedDestination) {
      return _MissedDestinationView(session: session);
    }

    final totalStops = session.trip.stationIds.length;
    final progress = totalStops <= 1
        ? 1.0
        : session.currentStationIndex / (totalStops - 1);
    final currentName = _stationName(session.currentStationId);
    final nextName = _stationName(session.nextStationId);
    final destinationName = _stationName(session.trip.destinationStationId);
    final isArrived = session.state == ActiveTripState.arrived;
    final isTransferring = session.state == ActiveTripState.transferring;
    final isApproachingTransfer =
        session.state == ActiveTripState.approachingTransfer;
    final transferBoundary = session.nextTransferBoundary;
    final transferStationName = transferBoundary == null
        ? null
        : _stationName(session.trip.stationIds[transferBoundary.index]);
    final headlineName = isArrived
        ? destinationName
        : (isTransferring || isApproachingTransfer) && transferStationName != null
        ? transferStationName
        : nextName;

    return Scaffold(
      backgroundColor: AppColors.navy,
      appBar: AppBar(
        foregroundColor: AppColors.surfaceLight,
        title: const Text('Perjalanan aktif'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Akhiri perjalanan',
            onPressed: () => _confirmCancel(context, ref),
            icon: const Icon(Icons.close_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      const Spacer(),
                      DataFreshnessBadge(
                        freshness: session.trip.freshness,
                        compact: true,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    isArrived
                        ? 'Kamu tiba di'
                        : isTransferring
                        ? 'Turun dan transit di'
                        : isApproachingTransfer
                        ? 'Bersiap transit di'
                        : session.remainingStops == 1
                        ? 'Stasiun berikutnya adalah tujuanmu'
                        : 'Stasiun berikutnya',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppColors.textSecondaryDark,
                    ),
                  ),
                  const SizedBox(height: 6),
                  AnimatedSwitcher(
                    duration: MediaQuery.disableAnimationsOf(context)
                        ? Duration.zero
                        : const Duration(milliseconds: 220),
                    child: Text(
                      headlineName,
                      key: ValueKey<String>(headlineName),
                      style: Theme.of(context).textTheme.displayLarge?.copyWith(
                        color: AppColors.surfaceLight,
                      ),
                    ),
                  ),
                  if ((isTransferring || isApproachingTransfer) &&
                      transferBoundary?.instruction != null) ...<Widget>[
                    const SizedBox(height: 8),
                    Text(
                      transferBoundary!.instruction!,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondaryDark,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 8,
                      backgroundColor: AppColors.borderDark,
                      color: AppColors.coral,
                      semanticsLabel: 'Progres perjalanan',
                      semanticsValue: '${(progress * 100).round()} persen',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          '$currentName • ${session.remainingStops} stasiun tersisa',
                          style: const TextStyle(color: AppColors.surfaceLight),
                        ),
                      ),
                      Text(
                        'ETA ${DateFormat.Hm('id_ID').format(session.trip.arrivalAt)}',
                        style: const TextStyle(
                          color: AppColors.surfaceLight,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _TripStatsRow(session: session),
                ],
              ),
            ),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(28),
                  ),
                ),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            'Urutan stasiun',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                        Text(
                          session.lowBatteryMode ? 'Hemat baterai' : 'GPS adaptif',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    for (var index = 0; index < session.trip.stationIds.length; index += 1)
                      _StationProgressRow(
                        name: _stationName(session.trip.stationIds[index]),
                        isPast: index < session.currentStationIndex,
                        isCurrent: index == session.currentStationIndex,
                        isDestination: index == session.trip.stationIds.length - 1,
                      ),
                    const SizedBox(height: 20),
                    if (session.trip.isDemo && !isArrived)
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: () => ref
                              .read(activeTripControllerProvider.notifier)
                              .advanceStop(),
                          icon: const Icon(Icons.skip_next_rounded),
                          label: const Text('Simulasikan stasiun berikutnya'),
                        ),
                      ),
                    if (isArrived)
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: () async {
                            await ref
                                .read(activeTripControllerProvider.notifier)
                                .complete();
                            if (context.mounted) {
                              context.go('/trip-complete');
                            }
                          },
                          icon: const Icon(Icons.flag_outlined),
                          label: const Text('Selesaikan perjalanan'),
                        ),
                      ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: () => ref
                          .read(activeTripControllerProvider.notifier)
                          .toggleLowBatteryMode(),
                      icon: Icon(
                        session.lowBatteryMode
                            ? Icons.battery_saver
                            : Icons.battery_5_bar_outlined,
                      ),
                      label: Text(
                        session.lowBatteryMode
                            ? 'Matikan hemat baterai'
                            : 'Aktifkan hemat baterai',
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

  Future<void> _confirmCancel(BuildContext context, WidgetRef ref) async {
    final shouldCancel = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Akhiri perjalanan?',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              const Text(
                'Notifikasi stasiun dan layanan latar belakang akan dihentikan.',
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Akhiri perjalanan'),
                ),
              ),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Lanjutkan perjalanan'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if ((shouldCancel ?? false) && context.mounted) {
      await ref.read(activeTripControllerProvider.notifier).cancel();
      if (context.mounted) {
        context.go('/');
      }
    }
  }

  String _stationName(String? id) {
    if (id == null) {
      return 'Tujuan';
    }
    return demoStations.where((station) => station.id == id).firstOrNull?.name ??
        id;
  }
}

class _StationProgressRow extends StatelessWidget {
  const _StationProgressRow({
    required this.name,
    required this.isPast,
    required this.isCurrent,
    required this.isDestination,
  });

  final String name;
  final bool isPast;
  final bool isCurrent;
  final bool isDestination;

  @override
  Widget build(BuildContext context) {
    final color = isCurrent
        ? AppColors.blue
        : isPast
        ? AppColors.success
        : Theme.of(context).colorScheme.outline;
    final icon = isDestination
        ? Icons.flag_rounded
        : isPast
        ? Icons.check_rounded
        : isCurrent
        ? Icons.train_rounded
        : Icons.circle_outlined;
    final label = isDestination
        ? '$name, tujuan'
        : isCurrent
        ? '$name, posisi saat ini'
        : name;
    return Semantics(
      label: label,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          children: <Widget>[
            Icon(icon, size: 22, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                name,
                style: TextStyle(
                  fontWeight: isCurrent || isDestination
                      ? FontWeight.w700
                      : FontWeight.w400,
                  color: isPast
                      ? Theme.of(context).colorScheme.onSurfaceVariant
                      : null,
                ),
              ),
            ),
            if (isCurrent) const Text('Sekarang'),
          ],
        ),
      ),
    );
  }
}

/// Live-ticking waktu perjalanan (elapsed since [ActiveTripSession.startedAt])
/// alongside the jarak tempuh / kecepatan carried on the session itself,
/// which only change when a new hop or GPS fix arrives.
class _TripStatsRow extends ConsumerStatefulWidget {
  const _TripStatsRow({required this.session});

  final ActiveTripSession session;

  @override
  ConsumerState<_TripStatsRow> createState() => _TripStatsRowState();
}

class _TripStatsRowState extends ConsumerState<_TripStatsRow> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    final elapsed = DateTime.now().difference(session.startedAt);
    return Row(
      children: <Widget>[
        Expanded(
          child: _TripStatChip(
            icon: Icons.timer_outlined,
            label: 'Waktu perjalanan',
            value: formatDuration(elapsed),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _TripStatChip(
            icon: Icons.route_outlined,
            label: 'Jarak tempuh',
            value: formatDistanceMeters(session.distanceMeters),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _TripStatChip(
            icon: Icons.speed_outlined,
            label: 'Kecepatan',
            value: formatSpeedKmh(session.currentSpeedKmh),
          ),
        ),
      ],
    );
  }
}

class _TripStatChip extends StatelessWidget {
  const _TripStatChip({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Icon(icon, size: 14, color: AppColors.textSecondaryDark),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: const TextStyle(
                  color: AppColors.textSecondaryDark,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            color: AppColors.surfaceLight,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _MissedDestinationView extends ConsumerWidget {
  const _MissedDestinationView({required this.session});

  final ActiveTripSession session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final destinationName = _stationName(session.trip.destinationStationId);
    return Scaffold(
      appBar: AppBar(title: const Text('Perjalanan aktif')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Icon(
                Icons.warning_amber_rounded,
                color: AppColors.warning,
                size: 40,
              ),
              const SizedBox(height: 12),
              Text(
                'Sepertinya kamu melewati $destinationName',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              const Text(
                'Aplikasi tidak dapat memastikan posisimu setelah terlewat. '
                'Pilih stasiun tempatmu sekarang di halaman jadwal untuk '
                'mencari rute kembali.',
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () async {
                    ref
                        .read(tripSearchControllerProvider.notifier)
                        .setDestination(session.trip.destinationStationId);
                    await ref
                        .read(activeTripControllerProvider.notifier)
                        .cancel();
                    if (context.mounted) {
                      context.go('/schedule');
                    }
                  },
                  icon: const Icon(Icons.route_outlined),
                  label: Text('Cari rute kembali ke $destinationName'),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () async {
                    await ref
                        .read(activeTripControllerProvider.notifier)
                        .cancel();
                    if (context.mounted) {
                      context.go('/');
                    }
                  },
                  child: const Text('Akhiri perjalanan'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _stationName(String id) {
    return demoStations.where((station) => station.id == id).firstOrNull?.name ??
        id;
  }
}

class TripCompletePage extends ConsumerWidget {
  const TripCompletePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(activeTripControllerProvider);
    final finalDestinationQuery = session?.finalDestinationQuery;
    final destinationStation = session == null
        ? null
        : (ref.watch(stationListProvider).value ?? const <Station>[])
            .where((s) => s.id == session.trip.destinationStationId)
            .firstOrNull;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const CircleAvatar(
                  radius: 44,
                  backgroundColor: AppColors.softBlue,
                  child: Icon(
                    Icons.flag_rounded,
                    size: 44,
                    color: AppColors.navy,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Perjalanan selesai',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
                const SizedBox(height: 10),
                Text(
                  session == null
                      ? 'Sesi lokal telah ditutup.'
                      : 'Kamu tiba di ${_name(session.trip.destinationStationId)}. Riwayat cloud tidak dibuat pada mode lokal.',
                  textAlign: TextAlign.center,
                ),
                if (session != null) ...<Widget>[
                  const SizedBox(height: 20),
                  _TripSummaryStats(session: session),
                ],
                if (finalDestinationQuery != null && destinationStation != null) ...<Widget>[
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => unawaited(
                        launchMapDirectionsToQuery(
                          destinationStation.latitude,
                          destinationStation.longitude,
                          finalDestinationQuery,
                        ),
                      ),
                      icon: const Icon(Icons.map_outlined),
                      label: Text('Buka di Google Maps ke $finalDestinationQuery'),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      ref
                          .read(activeTripControllerProvider.notifier)
                          .dismissCompleted();
                      context.go('/');
                    },
                    child: const Text('Kembali ke beranda'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _name(String id) {
    return demoStations.where((station) => station.id == id).firstOrNull?.name ??
        id;
  }
}

/// Waktu tempuh / jarak / rata-rata kecepatan for the just-finished trip —
/// `session` is still populated with its final [ActiveTripSession.distanceMeters]
/// and `updatedAt` (stamped at arrival, by `ActiveTripController.complete()`)
/// at this point, since `dismissCompleted()` hasn't been called yet.
class _TripSummaryStats extends StatelessWidget {
  const _TripSummaryStats({required this.session});

  final ActiveTripSession session;

  @override
  Widget build(BuildContext context) {
    final duration = session.updatedAt.difference(session.startedAt);
    final distanceMeters = session.distanceMeters;
    final averageSpeedKmh = duration.inSeconds > 0
        ? (distanceMeters / 1000) / (duration.inSeconds / 3600)
        : null;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: _SummaryStatItem(
              icon: Icons.timer_outlined,
              label: 'Waktu tempuh',
              value: formatDuration(duration),
            ),
          ),
          Expanded(
            child: _SummaryStatItem(
              icon: Icons.route_outlined,
              label: 'Jarak',
              value: formatDistanceMeters(distanceMeters),
            ),
          ),
          Expanded(
            child: _SummaryStatItem(
              icon: Icons.speed_outlined,
              label: 'Rata-rata',
              value: formatSpeedKmh(averageSpeedKmh),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryStatItem extends StatelessWidget {
  const _SummaryStatItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 6),
        Text(
          value,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}
