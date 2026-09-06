import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/network/connectivity_provider.dart';
import '../../../core/notifications/local_notification_service.dart';
import '../../../core/platform/widget_sync.dart';
import '../../../core/utils/map_launcher.dart';
import '../../../core/widgets/data_badges.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/tk_logo.dart';
import '../../../data/providers/demo_data.dart';
import '../../../data/providers/provider_registry.dart';
import '../../../domain/entities/active_trip.dart';
import '../../../domain/entities/transit_models.dart';
import '../../../domain/usecases/nearest_station_finder.dart';
import '../../account/presentation/account_controller.dart';
import '../../active_trip/presentation/active_trip_controller.dart';
import '../../ride_detection/presentation/ride_detection_controller.dart';
import '../../schedule/presentation/trip_search_controller.dart';
import '../../settings/presentation/settings_controller.dart';
import '../../stations/presentation/nearest_station_controller.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsControllerProvider);
    final homeStationId = settings.homeStationId ?? 'BOO';
    final departures = ref.watch(departuresProvider(homeStationId));
    final alerts = ref.watch(serviceAlertsProvider);
    final stations =
        ref.watch(stationListProvider).asData?.value ?? const <Station>[];
    final homeStationName = stations
            .where((station) => station.id == homeStationId)
            .firstOrNull
            ?.name ??
        'stasiun favorit';
    final nearestStations =
        ref.watch(nearestStationControllerProvider).asData?.value ??
            const <StationDistance>[];
    final nearest = nearestStations.firstOrNull;
    final ridePhase = ref.watch(rideDetectionControllerProvider);
    final activeTrip = ref.watch(activeTripControllerProvider);

    // Keeps the Android home-screen widgets showing the same data the app
    // just loaded, without the widgets themselves ever touching the network.
    ref.listen(departuresProvider(homeStationId), (previous, next) {
      unawaited(syncNextDepartureAndDailyRouteWidgets(ref, homeStationId));
    });
    ref.listen(serviceAlertsProvider, (previous, next) {
      unawaited(syncServiceStatusWidget(ref));
      final alerts = next.value;
      if (alerts != null && alerts.isNotEmpty) {
        final newest = alerts.first;
        final prevAlerts = previous?.value;
        if (prevAlerts == null || !prevAlerts.any((a) => a.id == newest.id)) {
          unawaited(
            ref
                .read(localNotificationServiceProvider)
                .showServiceDisruptionAlert(
                  title: newest.title,
                  description: newest.description,
                ),
          );
        }
      }
    });
    // Self-hosted APK update check (this app is sideloaded, no Play Store).
    // Update-available dialog is shown from `RideDetectionWatcher` instead
    // (wraps every tab, not just Home, and re-checks on app resume too).
    final displayName = ref.watch(userDisplayNameProvider).asData?.value;
    final nameSuffix = (displayName != null && displayName.trim().isNotEmpty)
        ? ', ${displayName.trim()}'
        : '';
    final now = DateTime.now();
    final greeting = switch (now.hour) {
      < 11 => 'Selamat pagi$nameSuffix',
      < 15 => 'Selamat siang$nameSuffix',
      < 19 => 'Selamat sore$nameSuffix',
      _ => 'Selamat malam$nameSuffix',
    };

    return Scaffold(
      body: CustomScrollView(
        slivers: <Widget>[
          SliverAppBar(
            floating: true,
            title: const TkLogo(size: 36),
            actions: <Widget>[
              IconButton(
                tooltip: 'Pusat notifikasi',
                onPressed: () => context.push('/notifications'),
                icon: const Icon(Icons.notifications_none_rounded),
              ),
              const SizedBox(width: 8),
            ],
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
            sliver: SliverList.list(
              children: <Widget>[
                Text(greeting, style: Theme.of(context).textTheme.headlineLarge),
                const SizedBox(height: 4),
                const _ConnectivityIndicator(),
                const SizedBox(height: 16),
                if (activeTrip != null) ...<Widget>[
                  const SizedBox(height: 12),
                  _ActiveTripStatusCard(
                    session: activeTrip,
                    stations: stations,
                    onTap: () => context.push('/active-trip'),
                  ),
                ] else if (_ridePhaseLabel(ridePhase?.state) != null) ...<Widget>[
                  const SizedBox(height: 12),
                  _RideDetectionPhaseBanner(
                    label: _ridePhaseLabel(ridePhase?.state)!,
                    stationName: ridePhase?.stationId == null
                        ? null
                        : (stations
                                .where((s) => s.id == ridePhase!.stationId)
                                .firstOrNull
                                ?.name ??
                            ridePhase?.stationId),
                  ),
                ],
                const SizedBox(height: 24),
                _NearestStationCard(
                  fallbackStationName: homeStationName,
                  nearest: nearest,
                  onDepartures: () => context.push(
                    '/station/${nearest?.station.id ?? homeStationId}',
                  ),
                  onDirections: () {
                    final lat = nearest?.station.latitude ?? -6.5947;
                    final lng = nearest?.station.longitude ?? 106.7906;
                    final sName = nearest?.station.name ?? homeStationName;
                    unawaited(launchMapDirections(lat, lng, label: sName));
                  },
                  onSeeAll: () => context.push('/nearby-stations'),
                ),
                const SizedBox(height: 28),
                const SectionHeader(
                  title: 'Mau ke mana kamu hari ini?',
                  description: 'Pilih sendiri stasiun awal dan akhirnya.',
                ),
                const SizedBox(height: 12),
                _QuickTripCard(
                  nearestStationId: nearest?.station.id,
                  nearestStationName: nearest?.station.name,
                  stations: stations,
                ),
                const SizedBox(height: 28),
                SectionHeader(
                  title: 'Kereta berikutnya',
                  description: 'Stasiun $homeStationName • estimasi',
                  action: TextButton(
                    onPressed: () => context.push('/station/$homeStationId'),
                    child: const Text('Lihat semua'),
                  ),
                ),
                const SizedBox(height: 12),
                departures.when(
                  loading: () => const _DepartureSkeleton(),
                  error: (error, stack) => AppEmptyState(
                    icon: Icons.cloud_off_outlined,
                    title: 'Jadwal belum dimuat',
                    message: 'Cache lokal tidak tersedia. Coba muat ulang.',
                    action: OutlinedButton(
                      onPressed: () =>
                          ref.invalidate(departuresProvider(homeStationId)),
                      child: const Text('Coba lagi'),
                    ),
                  ),
                  data: (items) => Column(
                    children: <Widget>[
                      for (final item in items
                          .where((d) => d.expectedAt.isAfter(DateTime.now()))
                          .take(3))
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _DepartureRow(departure: item),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const SectionHeader(title: 'Status layanan'),
                const SizedBox(height: 12),
                alerts.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (error, stack) => const Text(
                    'Status layanan tidak tersedia. Jadwal tetap dapat digunakan.',
                  ),
                  data: (items) => Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              const Expanded(
                                child: Text(
                                  'Commuter Line Jabodetabek',
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                              ),
                              ServiceStatusBadge(
                                status: items.firstOrNull?.status ??
                                    ServiceStatus.unavailable,
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            items.firstOrNull?.sourceLabel ??
                                'Informasi belum tersedia',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Only the pre-boarding phases get a subtle Home banner. `confirmingTrip`
  /// is deliberately excluded — that one navigates to a full confirmation
  /// page instead (PRD §9 treats crossing the ask threshold as needing an
  /// explicit prompt, not a passive banner).
  String? _ridePhaseLabel(ActiveTripState? state) => switch (state) {
    ActiveTripState.nearStation => 'Mendekati stasiun',
    ActiveTripState.atStation => 'Terdeteksi di stasiun',
    ActiveTripState.possibleBoarding => 'Memeriksa kemungkinan naik KRL…',
    _ => null,
  };

}

/// Shows real device connectivity — "Terhubung" with a green checkmark, or
/// "Terputus" with a red X and a prompt to check the connection — driven by
/// [connectivityProvider], never a static/hardcoded claim about which
/// backend the app happens to be configured against.
class _ConnectivityIndicator extends ConsumerWidget {
  const _ConnectivityIndicator();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isConnected = ref.watch(connectivityProvider).asData?.value ?? true;
    final color = isConnected ? Colors.green : Theme.of(context).colorScheme.error;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(
          isConnected ? Icons.check_circle_rounded : Icons.cancel_rounded,
          size: 16,
          color: color,
        ),
        const SizedBox(width: 6),
        Text(
          isConnected ? 'Terhubung' : 'Terputus • Periksa koneksi Anda',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: color),
        ),
      ],
    );
  }
}

/// The "Mau ke mana hari ini?" card. Both ends of the trip are chosen by
/// the rider, every time — nothing is pre-filled.
///
/// It used to default to the saved home station → work station (with a swap
/// button for the return leg), which is wrong for anyone whose next trip
/// isn't their commute: the two most prominent buttons on the home screen
/// would silently plan a journey they never asked for, and the only way to
/// go anywhere else was a third button hidden underneath. Now the origin
/// and destination are two empty, equal fields; the swap button, "Langsung
/// mulai" and "Lihat detail rute" all work exactly as before, they just
/// operate on the rider's own choice.
///
/// The rider's nearest station is still offered — as a one-tap suggestion
/// chip on the origin field, never as a pre-selected value.
class _QuickTripCard extends ConsumerStatefulWidget {
  const _QuickTripCard({
    required this.nearestStationId,
    required this.nearestStationName,
    required this.stations,
  });

  final String? nearestStationId;
  final String? nearestStationName;
  final List<Station> stations;

  @override
  ConsumerState<_QuickTripCard> createState() => _QuickTripCardState();
}

class _QuickTripCardState extends ConsumerState<_QuickTripCard> {
  String? _originId;
  String? _destinationId;
  bool _planning = false;

  bool get _isReady =>
      _originId != null && _destinationId != null && _originId != _destinationId;

  String _stationName(String id) =>
      widget.stations.where((s) => s.id == id).firstOrNull?.name ?? id;

  /// Runs the search for the two stations the rider picked and returns the
  /// top-ranked trip (the same one "Pilihan tercepat" would show), or null
  /// with a snackbar if nothing was found. Shared by both the instant-start
  /// and view-detail-first actions below — only what happens with the
  /// result differs between them.
  Future<TransitTrip?> _search() async {
    final originId = _originId;
    final destinationId = _destinationId;
    if (originId == null || destinationId == null || originId == destinationId) {
      return null;
    }
    final searchController = ref.read(tripSearchControllerProvider.notifier);
    searchController
      ..setOrigin(originId)
      ..setDestination(destinationId);
    if (mounted) setState(() => _planning = true);
    await searchController.search();
    final results = ref.read(tripSearchControllerProvider).results;
    if (mounted) setState(() => _planning = false);
    if (results.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tidak ada jadwal ditemukan. Coba lagi nanti.'),
          ),
        );
      }
      return null;
    }
    return results.first;
  }

  /// Opens the top-ranked trip's detail page so the rider sees stations
  /// passed / transfer count / schedule before confirming "Mulai
  /// perjalanan" there themselves.
  ///
  /// Captures the [GoRouter] up front rather than navigating via `context`
  /// at the end: a rebuild between the search and the navigation (e.g. this
  /// card shifting position in `HomePage`'s unkeyed children list) can tear
  /// down and recreate this card's element/State entirely (confirmed live
  /// with the instant-start flow below), which would otherwise silently
  /// drop the navigation. The router object itself stays valid regardless.
  Future<void> _viewDetail() async {
    final router = GoRouter.of(context);
    final trip = await _search();
    if (trip == null) return;
    router.push('/trip/${trip.id}');
  }

  /// Starts the top-ranked trip immediately, skipping the detail/confirm
  /// step — for a rider who already knows the route and just wants to go.
  /// Same [GoRouter]-capture reasoning as [_viewDetail]: starting the trip
  /// changes `activeTripControllerProvider`, which `HomePage` watches and
  /// reacts to by inserting a status card above this one, tearing this
  /// card's element down mid-flight (confirmed live).
  Future<void> _startNow() async {
    final router = GoRouter.of(context);
    final trip = await _search();
    if (trip == null) return;
    await ref.read(activeTripControllerProvider.notifier).start(trip);
    router.push('/active-trip');
  }

  Future<void> _pickStation({required bool isOrigin}) async {
    final excludedId = isOrigin ? _destinationId : _originId;
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => _StationPickerSheet(
        title: isOrigin ? 'Pilih stasiun awal' : 'Pilih stasiun akhir',
        stations: widget.stations,
        selectedId: isOrigin ? _originId : _destinationId,
        excludedId: excludedId,
      ),
    );
    if (selected == null || !mounted) return;
    setState(() {
      if (isOrigin) {
        _originId = selected;
      } else {
        _destinationId = selected;
      }
    });
  }

  void _swap() {
    setState(() {
      final previousOrigin = _originId;
      _originId = _destinationId;
      _destinationId = previousOrigin;
    });
  }

  @override
  Widget build(BuildContext context) {
    final activeTrip = ref.watch(activeTripControllerProvider);
    if (activeTrip != null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => context.push('/active-trip'),
              icon: const Icon(Icons.train_rounded),
              label: const Text('Buka perjalanan aktif'),
            ),
          ),
        ),
      );
    }

    final nearestId = widget.nearestStationId;
    final nearestName = widget.nearestStationName;
    final canSuggestNearest =
        nearestId != null && nearestName != null && _originId != nearestId;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    children: <Widget>[
                      _StationField(
                        label: 'Stasiun awal',
                        icon: Icons.trip_origin_rounded,
                        stationName:
                            _originId == null ? null : _stationName(_originId!),
                        onTap: _planning
                            ? null
                            : () => _pickStation(isOrigin: true),
                      ),
                      const SizedBox(height: 8),
                      _StationField(
                        label: 'Stasiun akhir',
                        icon: Icons.place_rounded,
                        stationName: _destinationId == null
                            ? null
                            : _stationName(_destinationId!),
                        onTap: _planning
                            ? null
                            : () => _pickStation(isOrigin: false),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  tooltip: 'Tukar stasiun awal dan akhir',
                  onPressed: _planning ||
                          (_originId == null && _destinationId == null)
                      ? null
                      : _swap,
                  icon: const Icon(Icons.swap_vert_rounded),
                ),
              ],
            ),
            if (canSuggestNearest) ...<Widget>[
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: ActionChip(
                  avatar: const Icon(Icons.near_me_outlined, size: 16),
                  label: Text('Mulai dari $nearestName (lokasi saat ini)'),
                  onPressed: _planning
                      ? null
                      : () => setState(() {
                            _originId = nearestId;
                            if (_destinationId == nearestId) {
                              _destinationId = null;
                            }
                          }),
                ),
              ),
            ],
            if (_originId != null &&
                _destinationId != null &&
                _originId == _destinationId) ...<Widget>[
              const SizedBox(height: 10),
              Text(
                'Stasiun awal dan akhir tidak boleh sama.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ],
            const SizedBox(height: 14),
            if (_planning)
              const SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: null,
                  child: SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            else
              Row(
                children: <Widget>[
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _isReady ? _startNow : null,
                      icon: const Icon(Icons.navigation_rounded, size: 18),
                      label: const Text(
                        'Langsung mulai',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isReady ? _viewDetail : null,
                      icon: const Icon(Icons.route_outlined, size: 18),
                      label: const Text(
                        'Lihat detail rute',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                ],
              ),
            if (_originId != null) ...<Widget>[
              const Divider(height: 24),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    final station = widget.stations
                        .where((s) => s.id == _originId)
                        .firstOrNull;
                    if (station != null) {
                      unawaited(
                        launchMapDirections(
                          station.latitude,
                          station.longitude,
                          label: station.name,
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.navigation_outlined, size: 18),
                  label: Text(
                    'Arahkan ke ${_stationName(_originId!)}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// One end of the trip: a tappable field that reads "Pilih stasiun…" until
/// the rider chooses. Deliberately identical in weight for origin and
/// destination — neither is the one the app assumes.
class _StationField extends StatelessWidget {
  const _StationField({
    required this.label,
    required this.icon,
    required this.stationName,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final String? stationName;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEmpty = stationName == null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: <Widget>[
            Icon(icon, size: 18, color: theme.colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(label, style: theme.textTheme.bodySmall),
                  const SizedBox(height: 2),
                  Text(
                    stationName ?? 'Pilih stasiun…',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: isEmpty
                          ? theme.textTheme.bodySmall?.color
                          : theme.textTheme.titleMedium?.color,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(Icons.expand_more_rounded, size: 20),
          ],
        ),
      ),
    );
  }
}

/// Searchable station list. The unfiltered list runs to the full KRL
/// network, which is far too long to scroll to "Universitas Pancasila" —
/// the picker this replaced had no search at all.
class _StationPickerSheet extends StatefulWidget {
  const _StationPickerSheet({
    required this.title,
    required this.stations,
    required this.selectedId,
    required this.excludedId,
  });

  final String title;
  final List<Station> stations;
  final String? selectedId;

  /// The station already chosen for the *other* end of the trip — shown but
  /// not selectable, so a rider can't build an origin-equals-destination
  /// trip and then wonder why nothing was found.
  final String? excludedId;

  @override
  State<_StationPickerSheet> createState() => _StationPickerSheetState();
}

class _StationPickerSheetState extends State<_StationPickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final query = _query.trim().toLowerCase();
    final matches = widget.stations.where((station) {
      if (query.isEmpty) return true;
      return station.name.toLowerCase().contains(query) ||
          station.id.toLowerCase().contains(query);
    }).toList(growable: false);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      builder: (context, scrollController) => Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  widget.title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                TextField(
                  autofocus: true,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search_rounded),
                    hintText: 'Cari nama stasiun',
                  ),
                  onChanged: (value) => setState(() => _query = value),
                ),
              ],
            ),
          ),
          Expanded(
            child: matches.isEmpty
                ? Center(
                    child: Text(
                      'Stasiun "$_query" tidak ditemukan.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  )
                : ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 24),
                    itemCount: matches.length,
                    itemBuilder: (context, index) {
                      final station = matches[index];
                      final isExcluded = station.id == widget.excludedId;
                      return ListTile(
                        leading: const Icon(Icons.train_outlined),
                        title: Text(station.name),
                        subtitle: isExcluded
                            ? const Text('Sudah dipakai di ujung lainnya')
                            : null,
                        selected: station.id == widget.selectedId,
                        enabled: !isExcluded,
                        onTap: () => Navigator.pop(context, station.id),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}


class _ActiveTripStatusCard extends StatelessWidget {
  const _ActiveTripStatusCard({
    required this.session,
    required this.stations,
    required this.onTap,
  });

  final ActiveTripSession session;
  final List<Station> stations;
  final VoidCallback onTap;

  String _nameOf(String? id) {
    if (id == null) return '-';
    return stations.where((s) => s.id == id).firstOrNull?.name ??
        demoStations.where((s) => s.id == id).firstOrNull?.name ??
        id;
  }

  @override
  Widget build(BuildContext context) {
    final nextName = session.nextStationId == null
        ? 'Tiba di tujuan'
        : _nameOf(session.nextStationId);
    final currentName = _nameOf(session.currentStationId);
    final destinationName = _nameOf(session.trip.destinationStationId);
    final remainingTransfers = session.trip.transferBoundaries
        .where((b) => b.index >= session.currentStationIndex)
        .length;
    final nextTransferName = session.nextTransferBoundary == null
        ? null
        : _nameOf(
            session.trip.stationIds[session.nextTransferBoundary!.index],
          );

    return Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  const Icon(Icons.train_rounded),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Perjalanan sedang berlangsung',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Baru saja melewati $currentName',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 2),
              Text(
                'Stasiun berikutnya: $nextName',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 2),
              Text(
                '${session.remainingStops} stasiun lagi menuju $destinationName',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 6),
              Text(
                remainingTransfers == 0
                    ? 'Tanpa transit lagi'
                    : 'Transit $remainingTransfers kali lagi'
                          '${nextTransferName == null ? '' : ', berikutnya di $nextTransferName'}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RideDetectionPhaseBanner extends StatelessWidget {
  const _RideDetectionPhaseBanner({required this.label, this.stationName});

  final String label;
  final String? stationName;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: stationName == null ? label : '$label $stationName',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: <Widget>[
            const Icon(Icons.sensors_rounded, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                stationName == null ? label : '$label $stationName',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NearestStationCard extends StatelessWidget {
  const _NearestStationCard({
    required this.fallbackStationName,
    required this.nearest,
    required this.onDepartures,
    required this.onDirections,
    required this.onSeeAll,
  });

  final String fallbackStationName;
  final StationDistance? nearest;
  final VoidCallback onDepartures;
  final VoidCallback onDirections;
  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context) {
    final distance = nearest;
    final displayName = distance?.station.name ?? fallbackStationName;
    final subtitle = distance == null
        ? 'Jarak pengguna belum dihitung'
        : '${_formatDistance(distance.distanceMeters)} • '
              '${distance.walkingMinutes} menit jalan kaki';

    return Card(
      color: AppColors.navy,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Icon(Icons.near_me_outlined, color: AppColors.softBlue),
                const SizedBox(width: 8),
                Text(
                  distance == null ? 'Stasiun favorit' : 'Stasiun terdekat',
                  style: const TextStyle(color: AppColors.softBlue),
                ),
                const Spacer(),
                TextButton(
                  onPressed: onSeeAll,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.softBlue,
                  ),
                  child: const Text('Lihat semua'),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              'Stasiun $displayName',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: AppColors.surfaceLight,
              ),
            ),
            const SizedBox(height: 6),
            Text(subtitle, style: const TextStyle(color: AppColors.textSecondaryDark)),
            const SizedBox(height: 18),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: <Widget>[
                FilledButton(
                  onPressed: onDepartures,
                  child: const Text('Lihat kereta'),
                ),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.surfaceLight,
                    side: const BorderSide(color: AppColors.borderDark),
                  ),
                  onPressed: onDirections,
                  child: const Text('Arah ke stasiun'),
                ),
              ],
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

class _DepartureRow extends StatelessWidget {
  const _DepartureRow({required this.departure});

  final Departure departure;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: <Widget>[
            SizedBox(
              width: 58,
              child: Text(
                DateFormat.Hm('id_ID').format(departure.expectedAt),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    departure.destination,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    departure.tripNumber ?? 'Nomor belum tersedia',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            DataFreshnessBadge(freshness: departure.freshness, compact: true),
          ],
        ),
      ),
    );
  }
}

class _DepartureSkeleton extends StatelessWidget {
  const _DepartureSkeleton();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Memuat jadwal',
      child: Column(
        children: List<Widget>.generate(
          3,
          (index) => Container(
            height: 76,
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(18),
            ),
          ),
        ),
      ),
    );
  }
}
