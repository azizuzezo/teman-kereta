import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/utils/geo.dart';
import '../../../core/utils/map_launcher.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../data/providers/demo_data.dart';
import '../../../data/providers/provider_registry.dart';
import '../../../domain/entities/active_trip.dart';
import '../../../domain/entities/transit_models.dart';
import '../../live_map/presentation/native_gps_fix.dart';
import '../../schedule/presentation/trip_search_controller.dart';
import 'active_trip_controller.dart';
import 'trip_battery_warning.dart';
import 'trip_progress_math.dart';
import 'trip_rail_timeline.dart';

/// Real station name for [id], preferring the live station list (Supabase —
/// real codes like 'KLDB'/'CUK' only resolve here) and falling back to the
/// bundled demo data, then the raw id itself as a last resort so the UI
/// never crashes on an unknown id — it just shows something less friendly.
String _resolveStationName(String? id, List<Station> stations) {
  if (id == null) {
    return 'Tujuan';
  }
  final fromLive = stations.where((s) => s.id == id).firstOrNull?.name;
  if (fromLive != null) {
    return fromLive;
  }
  return demoStations.where((s) => s.id == id).firstOrNull?.name ?? id;
}

class ActiveTripPage extends ConsumerWidget {
  const ActiveTripPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(activeTripControllerProvider);
    final stations = ref.watch(stationListProvider).value ?? const <Station>[];
    final gpsFix = ref.watch(latestNativeGpsFixProvider);
    // A plain `ref.listen` would miss this: `start()` already flips the flag
    // to true before this page ever mounts (it's set mid-`start()`, and
    // navigation here only happens once `start()` has returned), so there's
    // no false→true transition left for a listener registered on first
    // build to catch. Watching the current value and firing once per frame
    // where it's true — then clearing it in that same callback — catches
    // both "already true when this page first mounts" and any later flip.
    if (ref.watch(tripBatteryWarningProvider)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        ref.read(tripBatteryWarningProvider.notifier).set(false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 8),
            content: const Text(
              'HP kamu mungkin membatasi pelacakan latar belakang, '
              'jadi notifikasi stasiun bisa berhenti di tengah jalan.',
            ),
            action: SnackBarAction(
              label: 'Pengaturan',
              onPressed: () => context.push('/settings/location'),
            ),
          ),
        );
      });
    }
    if (session == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Perjalanan aktif')),
        body: AppEmptyState(
          icon: Icons.navigation_outlined,
          title: 'Belum ada perjalanan aktif',
          message: 'Cari rute, buka detailnya, lalu pilih Mulai perjalanan.',
          action: FilledButton(
            onPressed: () => context.go('/schedule/search'),
            child: const Text('Cari perjalanan'),
          ),
        ),
      );
    }

    if (session.state == ActiveTripState.missedDestination) {
      return _MissedDestinationView(session: session);
    }

    final totalStops = session.trip.stationIds.length;
    final stationsById = <String, Station>{
      for (final station in demoStations) station.id: station,
      for (final station in stations) station.id: station,
    };
    final hopFraction = hopFractionFromGps(
      from: stationsById[session.currentStationId],
      to: session.nextStationId == null
          ? null
          : stationsById[session.nextStationId],
      fix: gpsFix,
    );
    final progress = totalStops <= 1
        ? 1.0
        : (session.currentStationIndex + hopFraction) / (totalStops - 1);
    final remainingMeters = remainingDistanceMeters(
      trip: session.trip,
      currentStationIndex: session.currentStationIndex,
      hopFraction: hopFraction,
      stationsById: stationsById,
    );
    final liveEtaValue = liveEta(
      startedAt: session.startedAt,
      distanceMeters: session.distanceMeters,
      remainingMeters: remainingMeters,
      now: DateTime.now(),
    );
    final displayEta = liveEtaValue ?? session.trip.arrivalAt;
    final reduceMotion =
        MediaQuery.disableAnimationsOf(context) || session.lowBatteryMode;
    final currentName = _resolveStationName(session.currentStationId, stations);
    final nextName = _resolveStationName(session.nextStationId, stations);
    final destinationName = _resolveStationName(
      session.trip.destinationStationId,
      stations,
    );
    final isArrived = session.state == ActiveTripState.arrived;
    final isTransferring = session.state == ActiveTripState.transferring;
    final isApproachingTransfer =
        session.state == ActiveTripState.approachingTransfer;
    final transferBoundary = session.nextTransferBoundary;
    final transferStationName = transferBoundary == null
        ? null
        : _resolveStationName(
            session.trip.stationIds[transferBoundary.index],
            stations,
          );
    final headlineName = isArrived
        ? destinationName
        : (isTransferring || isApproachingTransfer) &&
              transferStationName != null
        ? transferStationName
        : nextName;

    return Scaffold(
      backgroundColor: AppColors.navy,
      appBar: AppBar(
        foregroundColor: AppColors.surfaceLight,
        // The app's global `AppBarTheme.titleTextStyle` (see app_theme.dart)
        // fixes a dark title color for the light-background app bars used
        // everywhere else — it wins over `foregroundColor` above, which only
        // covers icons once a `titleTextStyle` exists. On this page's dark
        // navy background that made the title unreadable (dark-on-dark, no
        // contrast) — confirmed live on-device. Overriding just the color
        // here keeps the same size/weight while fixing the contrast.
        titleTextStyle: Theme.of(
          context,
        ).appBarTheme.titleTextStyle?.copyWith(color: AppColors.surfaceLight),
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
        child: CustomScrollView(
          slivers: <Widget>[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
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
                      duration: reduceMotion
                          ? Duration.zero
                          : const Duration(milliseconds: 220),
                      child: Text(
                        headlineName,
                        key: ValueKey<String>(headlineName),
                        style: Theme.of(context).textTheme.displayLarge
                            ?.copyWith(color: AppColors.surfaceLight),
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
                    const SizedBox(height: 18),
                    if (!isArrived)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: <Widget>[
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  liveEtaValue != null
                                      ? 'Estimasi tiba • live'
                                      : 'Estimasi tiba • jadwal',
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: AppColors.textSecondaryDark,
                                      ),
                                ),
                                Text(
                                  DateFormat.Hm('id_ID').format(displayEta),
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineSmall
                                      ?.copyWith(
                                        color: AppColors.surfaceLight,
                                        fontWeight: FontWeight.w800,
                                      ),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: <Widget>[
                              Text(
                                'Stasiun saat ini',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: AppColors.textSecondaryDark,
                                    ),
                              ),
                              Text(
                                '$currentName • ${session.remainingStops} stasiun tersisa',
                                textAlign: TextAlign.end,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: AppColors.surfaceLight,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: TweenAnimationBuilder<double>(
                        tween: Tween<double>(begin: 0, end: progress),
                        duration: reduceMotion
                            ? Duration.zero
                            : const Duration(milliseconds: 500),
                        curve: Curves.easeOut,
                        builder: (context, value, _) => LinearProgressIndicator(
                          value: value,
                          minHeight: 8,
                          backgroundColor: AppColors.borderDark,
                          color: AppColors.coral,
                          semanticsLabel: 'Progres perjalanan',
                          semanticsValue: '${(value * 100).round()} persen',
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    _TripStatsRow(session: session),
                    const SizedBox(height: 14),
                    const _LocationHealthRow(),
                  ],
                ),
              ),
            ),
            SliverFillRemaining(
              hasScrollBody: false,
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(28),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
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
                            session.lowBatteryMode
                                ? 'Hemat baterai'
                                : 'GPS akurasi tinggi',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      TripRailTimeline(
                        stations: <RailStation>[
                          for (
                            var index = 0;
                            index < session.trip.stationIds.length;
                            index += 1
                          )
                            (
                              name: _resolveStationName(
                                session.trip.stationIds[index],
                                stations,
                              ),
                              transferInstruction: _transferInstructionAt(
                                session.trip,
                                index,
                              ),
                            ),
                        ],
                        currentIndex: session.currentStationIndex,
                        hopFraction: isArrived ? 0 : hopFraction,
                        reduceMotion: reduceMotion,
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
                            // Safety net only: arrival auto-completes, so
                            // this is reachable only if that never fired.
                            // Navigation is the app shell's job now (see
                            // `RideDetectionWatcher`), so completing is all
                            // this has to do — doing both would `go` twice.
                            onPressed: () => ref
                                .read(activeTripControllerProvider.notifier)
                                .complete(),
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

  /// Non-null exactly when [index] is one of this trip's real transfer
  /// stations — used to give every transit stop its own marker in "Urutan
  /// stasiun" instead of only the single upcoming one shown in the header.
  String? _transferInstructionAt(TransitTrip trip, int index) {
    for (final boundary in trip.transferBoundaries) {
      if (boundary.index == index) {
        return boundary.instruction ?? 'Transit';
      }
    }
    return null;
  }
}

/// GPS health readout plus the manual "Perbarui lokasi" button.
///
/// The button is deliberately secondary, and labelled as such: automatic
/// tracking is the source of truth (a fix every ~3s, a native watchdog that
/// rebuilds the subscription after 90s of silence, and a route catch-up that
/// re-syncs the trip from wherever the rider really is once fixes return).
/// This just lets a rider who can see the app is behind skip the wait
/// instead of sitting there wondering — it feeds the same pipeline and can
/// never move the trip somewhere automatic tracking wouldn't have.
class _LocationHealthRow extends ConsumerStatefulWidget {
  const _LocationHealthRow();

  @override
  ConsumerState<_LocationHealthRow> createState() => _LocationHealthRowState();
}

class _LocationHealthRowState extends ConsumerState<_LocationHealthRow> {
  bool _refreshing = false;

  Future<void> _refresh() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    try {
      await ref.read(activeTripControllerProvider.notifier).refreshLocation();
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(tripLocationStatusProvider);
    final fix = ref.watch(latestNativeGpsFixProvider);
    final degraded = status == 'signal_lost' || status == 'permission_missing';
    final label = switch (status) {
      'signal_lost' =>
        'Sinyal GPS hilang — perjalanan tetap jalan dan menyusul otomatis',
      'permission_missing' =>
        'Izin lokasi dicabut — aktifkan lagi di pengaturan',
      'waiting_for_location' => 'Mencari sinyal GPS…',
      'starting' => 'Menyiapkan pelacakan…',
      _ =>
        fix == null
            ? 'Melacak lokasi otomatis'
            : 'Lokasi terbaru ${DateFormat.Hms('id_ID').format(fix.at)}',
    };
    return Row(
      children: <Widget>[
        Icon(
          degraded ? Icons.gps_off_rounded : Icons.gps_fixed_rounded,
          size: 16,
          color: degraded ? AppColors.coral : AppColors.textSecondaryDark,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: degraded ? AppColors.coral : AppColors.textSecondaryDark,
            ),
          ),
        ),
        const SizedBox(width: 8),
        TextButton.icon(
          onPressed: _refreshing ? null : _refresh,
          style: TextButton.styleFrom(
            foregroundColor: AppColors.surfaceLight,
            visualDensity: VisualDensity.compact,
          ),
          icon: _refreshing
              ? const SizedBox.square(
                  dimension: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.my_location_rounded, size: 16),
          label: Text(
            _refreshing ? 'Memperbarui…' : 'Perbarui lokasi',
            style: const TextStyle(fontSize: 12),
          ),
        ),
      ],
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
    final stations = ref.watch(stationListProvider).value ?? const <Station>[];
    final destinationName = _resolveStationName(
      session.trip.destinationStationId,
      stations,
    );
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
                      context.go('/schedule/search');
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
}

class TripCompletePage extends ConsumerWidget {
  const TripCompletePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(activeTripControllerProvider);
    final finalDestinationQuery = session?.finalDestinationQuery;
    final stations = ref.watch(stationListProvider).value ?? const <Station>[];
    final destinationStation = session == null
        ? null
        : stations
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
                  session == null
                      ? 'Perjalanan selesai'
                      : 'Selamat, kamu tiba di '
                            '${_resolveStationName(session.trip.destinationStationId, stations)}!',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
                const SizedBox(height: 10),
                // The trip closes itself on arrival now, so this screen is
                // the confirmation of something that already happened —
                // not a place that still mentions which backend stored it.
                Text(
                  session == null
                      ? 'Perjalanan sudah ditutup.'
                      : 'Perjalanan otomatis diselesaikan setibanya kamu di tujuan.',
                  textAlign: TextAlign.center,
                ),
                if (session != null) ...<Widget>[
                  const SizedBox(height: 20),
                  _TripSummaryStats(session: session),
                ],
                if (finalDestinationQuery != null &&
                    destinationStation != null) ...<Widget>[
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
                      label: Text(
                        'Buka di Google Maps ke $finalDestinationQuery',
                      ),
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
