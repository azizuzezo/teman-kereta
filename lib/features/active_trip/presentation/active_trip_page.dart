import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/utils/geo.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/tk_components.dart';
import '../../../data/providers/demo_data.dart';
import '../../../domain/entities/active_trip.dart';
import '../../../domain/entities/transit_models.dart';
import '../../intercity/domain/intercity_trip.dart';
import '../../intercity/presentation/intercity_ride_controller.dart';
import '../../intercity/presentation/widgets/intercity_ride_card.dart';
import '../../live_map/presentation/native_gps_fix.dart';
import '../../schedule/presentation/trip_search_controller.dart';
import 'active_trip_controller.dart';
import 'active_trip_stations.dart';
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

/// Colors for the glanceable status block at the top of the active-trip
/// screen. Light themes get a solid primary block; dark themes keep the
/// surface color so a bright slab never glares in a night train. Both pairs
/// are token-derived, so every palette stays inside its own contrast rules.
class _HeroPalette {
  const _HeroPalette({
    required this.background,
    required this.foreground,
    required this.muted,
    required this.track,
    required this.bar,
    required this.border,
  });

  factory _HeroPalette.of(TkColors tk) {
    if (tk.isDark) {
      return _HeroPalette(
        background: tk.surface,
        foreground: tk.text,
        muted: tk.textMuted,
        track: tk.border,
        bar: tk.primary,
        border: tk.border,
      );
    }
    return _HeroPalette(
      background: tk.primary,
      foreground: tk.onPrimary,
      muted: tk.onPrimary.withValues(alpha: 0.82),
      track: tk.onPrimary.withValues(alpha: 0.28),
      bar: tk.onPrimary,
      border: Colors.transparent,
    );
  }

  final Color background;
  final Color foreground;
  final Color muted;
  final Color track;
  final Color bar;
  final Color border;
}

class ActiveTripPage extends ConsumerWidget {
  const ActiveTripPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tk = context.tk;
    final textTheme = Theme.of(context).textTheme;
    final session = ref.watch(activeTripControllerProvider);
    final stations = ref.watch(activeTripStationsProvider).value ?? const <Station>[];
    final gpsFix = ref.watch(latestNativeGpsFixProvider);
    final intercityRide = ref.watch(intercityRideControllerProvider);
    // A plain `ref.listen` would miss this: `start()` already flips the flag
    // to true before this page ever mounts (it's set mid-`start()`, and
    // navigation here only happens once `start()` has returned), so there's
    // no false→true transition left for a listener registered on first
    // build to catch. Watching the current value and firing once per frame
    // where it's true, then clearing it in that same callback, catches
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
    // An intercity ride has no timetable and stations tens of minutes apart:
    // its estimate comes from the track and the train's real speed instead.
    final isIntercity = isIntercityTrip(session.trip);
    final intercityEta = isIntercity ? intercityRide.eta : null;
    final displayEta = intercityEta != null
        ? DateTime.now().add(intercityEta.eta)
        : (liveEtaValue ?? session.trip.arrivalAt);
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
    final isApproachingDestination =
        session.state == ActiveTripState.approachingDestination;
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
    final headlineLabel = isArrived
        ? 'Kamu tiba di'
        : isTransferring
        ? 'Turun dan transit di'
        : isApproachingTransfer
        ? 'Bersiap transit di'
        : session.remainingStops == 1
        ? 'Stasiun berikutnya adalah tujuanmu'
        : 'Stasiun berikutnya';
    final hero = _HeroPalette.of(tk);
    final remaining = session.remainingStops;
    final bigValue = isIntercity
        ? (intercityEta != null ? formatIntercityEta(intercityEta.eta) : '…')
        : '$remaining';
    final bigUnit = isIntercity ? 'lagi' : 'stasiun lagi';

    return Scaffold(
      appBar: AppBar(title: const Text('Perjalanan aktif')),
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: <Widget>[
            Container(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
              decoration: BoxDecoration(
                color: hero.background,
                borderRadius: BorderRadius.circular(TkRadius.sheet),
                border: Border.all(color: hero.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Semantics(
                    liveRegion: true,
                    label: '$headlineLabel $headlineName',
                    excludeSemantics: true,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          headlineLabel,
                          style: textTheme.titleMedium?.copyWith(
                            color: hero.muted,
                            fontWeight: FontWeight.w600,
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
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.displayLarge?.copyWith(
                              color: hero.foreground,
                              fontSize: 38,
                              height: 1.1,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if ((isTransferring || isApproachingTransfer) &&
                      transferBoundary?.instruction != null) ...<Widget>[
                    const SizedBox(height: 8),
                    Text(
                      transferBoundary!.instruction!,
                      style: textTheme.bodyLarge?.copyWith(
                        color: hero.foreground,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  if (!isArrived) ...<Widget>[
                    const SizedBox(height: 20),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: <Widget>[
                        Expanded(
                          child: Semantics(
                            label: '$bigValue $bigUnit menuju $destinationName',
                            excludeSemantics: true,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: <Widget>[
                                Text(
                                  bigValue,
                                  style: textTheme.displayLarge?.copyWith(
                                    color: hero.foreground,
                                    fontSize: isIntercity ? 44 : 64,
                                    height: 1,
                                    fontFeatures: AppTheme.timeFeatures,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.only(bottom: 4),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: <Widget>[
                                        Text(
                                          bigUnit,
                                          style: textTheme.titleMedium
                                              ?.copyWith(
                                                color: hero.foreground,
                                                fontWeight: FontWeight.w700,
                                              ),
                                        ),
                                        Text(
                                          'ke $destinationName',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: textTheme.bodyMedium?.copyWith(
                                            color: hero.muted,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            isIntercity
                                ? 'Estimasi tiba • perkiraan'
                                : liveEtaValue != null
                                ? 'Estimasi tiba • live'
                                : 'Estimasi tiba • jadwal',
                            style: textTheme.bodyMedium?.copyWith(
                              color: hero.muted,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          DateFormat.Hm('id_ID').format(displayEta),
                          style: textTheme.headlineMedium?.copyWith(
                            color: hero.foreground,
                            fontWeight: FontWeight.w800,
                            fontFeatures: AppTheme.timeFeatures,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 14),
                  Semantics(
                    label: 'Progres perjalanan',
                    value: '${(progress.clamp(0.0, 1.0) * 100).round()} persen',
                    child: ExcludeSemantics(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: TweenAnimationBuilder<double>(
                          tween: Tween<double>(begin: 0, end: progress),
                          duration: reduceMotion
                              ? Duration.zero
                              : const Duration(milliseconds: 500),
                          curve: Curves.easeOut,
                          builder: (context, value, _) =>
                              LinearProgressIndicator(
                                value: value.clamp(0.0, 1.0),
                                minHeight: 10,
                                backgroundColor: hero.track,
                                color: hero.bar,
                              ),
                        ),
                      ),
                    ),
                  ),
                  if (!isArrived) ...<Widget>[
                    const SizedBox(height: 10),
                    Text(
                      'Stasiun saat ini: $currentName',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodyMedium?.copyWith(color: hero.muted),
                    ),
                  ],
                  const SizedBox(height: 16),
                  _TripStatsRow(session: session, palette: hero),
                  const SizedBox(height: 8),
                  _LocationHealthRow(palette: hero),
                ],
              ),
            ),
            if (isIntercity) ...<Widget>[
              const SizedBox(height: 16),
              const IntercityRideCard(),
            ],
            const SizedBox(height: 24),
            Row(
              children: <Widget>[
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text('Urutan stasiun', style: textTheme.titleLarge),
                  ),
                ),
                if (session.lowBatteryMode)
                  const TkPill(
                    label: 'Hemat baterai',
                    icon: Icons.battery_saver_rounded,
                    tone: TkPillTone.success,
                    dense: true,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TkCard(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
              child: TripRailTimeline(
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
            ),
            if (session.trip.isDemo && !isArrived) ...<Widget>[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.tonalIcon(
                  onPressed: () => ref
                      .read(activeTripControllerProvider.notifier)
                      .advanceStop(),
                  icon: const Icon(Icons.skip_next_rounded),
                  label: const Text('Simulasikan stasiun berikutnya'),
                ),
              ),
            ],
            const SizedBox(height: 12),
            TkRowGroup(
              children: <Widget>[
                TkRow(
                  icon: session.lowBatteryMode
                      ? Icons.battery_saver_rounded
                      : Icons.battery_5_bar_outlined,
                  title: 'Hemat baterai',
                  subtitle: session.lowBatteryMode
                      ? 'Aktif. Matikan untuk pelacakan lebih sering.'
                      : 'Kurangi animasi dan pembaruan saat baterai tipis.',
                  onTap: () => ref
                      .read(activeTripControllerProvider.notifier)
                      .toggleLowBatteryMode(),
                  trailing: ExcludeSemantics(
                    child: Switch(
                      value: session.lowBatteryMode,
                      onChanged: (_) => ref
                          .read(activeTripControllerProvider.notifier)
                          .toggleLowBatteryMode(),
                    ),
                  ),
                ),
              ],
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
          minimum: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            children: <Widget>[
              TextButton(
                onPressed: () => _confirmCancel(context, ref),
                style: TextButton.styleFrom(
                  foregroundColor: tk.danger,
                  minimumSize: const Size(96, 56),
                ),
                child: const Text('Batalkan'),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SizedBox(
                  height: 56,
                  child: isArrived || isApproachingDestination
                      ? FilledButton.icon(
                          onPressed: () => _confirmFinish(context, ref),
                          icon: const Icon(Icons.flag_outlined),
                          label: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              isArrived
                                  ? 'Selesaikan perjalanan'
                                  : 'Aku sudah turun',
                            ),
                          ),
                        )
                      : FilledButton.tonalIcon(
                          onPressed: () => _confirmFinish(context, ref),
                          icon: const Icon(Icons.flag_outlined),
                          label: const FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text('Aku sudah turun'),
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmCancel(BuildContext context, WidgetRef ref) async {
    final shouldCancel = await _showConfirmSheet(
      context,
      title: 'Batalkan perjalanan?',
      message:
          'Perjalanan ini tidak dicatat di riwayat. Notifikasi stasiun dan '
          'layanan latar belakang akan dihentikan.',
      confirmLabel: 'Ya, batalkan',
      keepLabel: 'Lanjutkan perjalanan',
      destructive: true,
    );
    if (shouldCancel && context.mounted) {
      await ref.read(activeTripControllerProvider.notifier).cancel();
      if (context.mounted) {
        context.go('/');
      }
    }
  }

  Future<void> _confirmFinish(BuildContext context, WidgetRef ref) async {
    final shouldFinish = await _showConfirmSheet(
      context,
      title: 'Sudah turun di tujuan?',
      message:
          'Perjalanan ditutup dan dicatat di riwayat. Notifikasi stasiun '
          'dihentikan.',
      confirmLabel: 'Ya, aku sudah turun',
      keepLabel: 'Belum, lanjutkan',
    );
    if (shouldFinish && context.mounted) {
      // Navigation to the recap is the app shell's job (see
      // `RideDetectionWatcher`), so completing is all this has to do.
      await ref.read(activeTripControllerProvider.notifier).complete();
    }
  }

  Future<bool> _showConfirmSheet(
    BuildContext context, {
    required String title,
    required String message,
    required String confirmLabel,
    required String keepLabel,
    bool destructive = false,
  }) async {
    final tk = context.tk;
    final result = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(title, style: Theme.of(sheetContext).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(
                message,
                style: Theme.of(
                  sheetContext,
                ).textTheme.bodyMedium?.copyWith(color: tk.textMuted),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  style: destructive
                      ? FilledButton.styleFrom(
                          backgroundColor: tk.danger,
                          foregroundColor: Theme.of(
                            sheetContext,
                          ).colorScheme.onError,
                        )
                      : null,
                  onPressed: () => Navigator.pop(sheetContext, true),
                  child: Text(confirmLabel),
                ),
              ),
              const SizedBox(height: 4),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: TextButton(
                  onPressed: () => Navigator.pop(sheetContext, false),
                  child: Text(keepLabel),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return result ?? false;
  }

  /// Non-null exactly when [index] is one of this trip's real transfer
  /// stations, used to give every transit stop its own marker in "Urutan
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
/// instead of sitting there wondering: it feeds the same pipeline and can
/// never move the trip somewhere automatic tracking wouldn't have.
class _LocationHealthRow extends ConsumerStatefulWidget {
  const _LocationHealthRow({required this.palette});

  final _HeroPalette palette;

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
    final palette = widget.palette;
    final status = ref.watch(tripLocationStatusProvider);
    final fix = ref.watch(latestNativeGpsFixProvider);
    final degraded = status == 'signal_lost' || status == 'permission_missing';
    final label = switch (status) {
      'signal_lost' =>
        'Sinyal GPS hilang. Perjalanan tetap jalan dan menyusul otomatis',
      'permission_missing' =>
        'Izin lokasi dicabut, aktifkan lagi di pengaturan',
      'waiting_for_location' => 'Mencari sinyal GPS…',
      'starting' => 'Menyiapkan pelacakan…',
      _ =>
        fix == null
            ? 'Melacak lokasi otomatis'
            : 'Lokasi terbaru ${DateFormat.Hms('id_ID').format(fix.at)}',
    };
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: degraded
          ? const EdgeInsets.fromLTRB(12, 4, 4, 4)
          : const EdgeInsets.fromLTRB(0, 0, 0, 0),
      decoration: degraded
          ? BoxDecoration(
              color: palette.foreground.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(TkRadius.control),
            )
          : null,
      child: Row(
        children: <Widget>[
          Icon(
            degraded ? Icons.gps_off_rounded : Icons.gps_fixed_rounded,
            size: 18,
            color: degraded ? palette.foreground : palette.muted,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: textTheme.bodySmall?.copyWith(
                color: degraded ? palette.foreground : palette.muted,
                fontWeight: degraded ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            tooltip: _refreshing ? 'Memperbarui lokasi' : 'Perbarui lokasi',
            onPressed: _refreshing ? null : _refresh,
            style: IconButton.styleFrom(
              foregroundColor: palette.foreground,
              disabledForegroundColor: palette.muted,
              minimumSize: const Size(48, 48),
            ),
            icon: _refreshing
                ? SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: palette.foreground,
                    ),
                  )
                : const Icon(Icons.my_location_rounded, size: 22),
          ),
        ],
      ),
    );
  }
}

/// Live-ticking waktu perjalanan (elapsed since [ActiveTripSession.startedAt])
/// alongside the jarak tempuh / kecepatan carried on the session itself,
/// which only change when a new hop or GPS fix arrives.
class _TripStatsRow extends ConsumerStatefulWidget {
  const _TripStatsRow({required this.session, required this.palette});

  final ActiveTripSession session;
  final _HeroPalette palette;

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
    final palette = widget.palette;
    final elapsed = DateTime.now().difference(session.startedAt);
    return Row(
      children: <Widget>[
        Expanded(
          child: _TripStatChip(
            icon: Icons.timer_outlined,
            label: 'Waktu perjalanan',
            value: formatDuration(elapsed),
            palette: palette,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _TripStatChip(
            icon: Icons.route_outlined,
            label: 'Jarak tempuh',
            value: formatDistanceMeters(session.distanceMeters),
            palette: palette,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _TripStatChip(
            icon: Icons.speed_outlined,
            label: 'Kecepatan',
            value: formatSpeedKmh(session.currentSpeedKmh),
            palette: palette,
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
    required this.palette,
  });

  final IconData icon;
  final String label;
  final String value;
  final _HeroPalette palette;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label: $value',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(icon, size: 14, color: palette.muted),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: TextStyle(color: palette.muted, fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: palette.foreground,
              fontWeight: FontWeight.w700,
              fontSize: 16,
              fontFeatures: AppTheme.timeFeatures,
            ),
          ),
        ],
      ),
    );
  }
}

class _MissedDestinationView extends ConsumerWidget {
  const _MissedDestinationView({required this.session});

  final ActiveTripSession session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tk = context.tk;
    final textTheme = Theme.of(context).textTheme;
    final stations = ref.watch(activeTripStationsProvider).value ?? const <Station>[];
    final destinationName = _resolveStationName(
      session.trip.destinationStationId,
      stations,
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Perjalanan aktif')),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                children: <Widget>[
                  Container(
                    width: 56,
                    height: 56,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: tk.warningSoft,
                      borderRadius: BorderRadius.circular(TkRadius.control),
                    ),
                    child: Icon(
                      Icons.warning_amber_rounded,
                      color: tk.warning,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Sepertinya kamu melewati $destinationName',
                    style: textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Aplikasi tidak dapat memastikan posisimu setelah terlewat. '
                    'Pilih stasiun tempatmu sekarang di halaman jadwal untuk '
                    'mencari rute kembali.',
                    style: textTheme.bodyLarge?.copyWith(color: tk.textMuted),
                  ),
                ],
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                color: tk.bg,
                border: Border(top: BorderSide(color: tk.border)),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: FilledButton.icon(
                        onPressed: () async {
                          ref
                              .read(tripSearchControllerProvider.notifier)
                              .setDestination(
                                session.trip.destinationStationId,
                              );
                          await ref
                              .read(activeTripControllerProvider.notifier)
                              .cancel();
                          if (context.mounted) {
                            context.go('/schedule/search');
                          }
                        },
                        icon: const Icon(Icons.route_outlined),
                        label: Text(
                          'Cari rute kembali ke $destinationName',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
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
          ],
        ),
      ),
    );
  }
}
