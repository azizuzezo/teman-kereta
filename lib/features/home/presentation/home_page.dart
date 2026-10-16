import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/network/gps_status_controller.dart';
import '../../../core/network/internet_status_controller.dart';
import '../../../core/notifications/local_notification_service.dart';
import '../../../core/platform/widget_sync.dart';
import '../../../core/utils/map_launcher.dart';
import '../../../core/widgets/tk_components.dart';
import '../../../data/providers/provider_registry.dart';
import '../../../domain/entities/active_trip.dart';
import '../../../domain/entities/transit_models.dart';
import '../../account/presentation/account_controller.dart';
import '../../active_trip/presentation/active_trip_controller.dart';
import '../../favorites/presentation/favorite_route_controller.dart';
import '../../ride_detection/presentation/ride_detection_controller.dart';
import '../../schedule/presentation/trip_search_controller.dart';
import '../../settings/presentation/settings_controller.dart';
import '../../stations/presentation/nearest_station_controller.dart';
import '../domain/next_train_logic.dart';
import 'widgets/active_trip_cards.dart';
import 'widgets/anti_bablas_hint.dart';
import 'widgets/device_status_tiles.dart';
import 'widgets/home_header.dart';
import 'widgets/next_train_hero.dart';
import 'widgets/quick_actions.dart';
import 'widgets/quick_trip_card.dart';
import 'widgets/service_alert_banner.dart';

/// How often the nearest station is re-measured while Home is on screen.
const Duration homeLocationInterval = Duration(seconds: 10);

/// How often the internet latency is re-measured while Home is on screen.
const Duration homeStatusInterval = Duration(seconds: 15);

/// How often countdowns are recomputed (they show whole minutes).
const Duration homeClockInterval = Duration(seconds: 15);

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage>
    with WidgetsBindingObserver {
  Timer? _locationTimer;
  Timer? _statusTimer;
  Timer? _clockTimer;

  bool _foreground = true;
  bool _tabVisible = true;
  bool _polling = false;

  late DateTime _now = ref.read(clockProvider).now();
  String? _lastNearestId;
  DateTime? _lastDeparturesReload;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _foreground = lifecycle == null || lifecycle == AppLifecycleState.resumed;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // The shell keeps every tab mounted but disables tickers on the hidden
    // ones, and the navigator does the same for a page pushed on top. That
    // makes TickerMode the signal for "Home is actually on screen".
    _tabVisible = TickerMode.valuesOf(context).enabled;
    _syncPolling();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _syncPolling();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopTimers();
    super.dispose();
  }

  void _stopTimers() {
    _locationTimer?.cancel();
    _statusTimer?.cancel();
    _clockTimer?.cancel();
    _locationTimer = null;
    _statusTimer = null;
    _clockTimer = null;
  }

  /// Starts the 10 s / 15 s timers only while Home is visible and the app is
  /// in the foreground, and cancels every one of them otherwise. No position
  /// stream: each location tick is one `getCurrentPosition` call.
  void _syncPolling() {
    final shouldPoll = _foreground && _tabVisible;
    if (shouldPoll == _polling) {
      return;
    }
    _polling = shouldPoll;
    if (!shouldPoll) {
      _stopTimers();
      return;
    }
    // Refresh right away (the user may have come back from Settings), after
    // the current build so providers are not modified mid-build.
    unawaited(
      Future<void>.microtask(() {
        if (!mounted || !_polling) {
          return;
        }
        _tickClock();
        unawaited(_pollLocation());
        unawaited(_pollStatus());
      }),
    );
    _locationTimer = Timer.periodic(
      homeLocationInterval,
      (_) => unawaited(_pollLocation()),
    );
    _statusTimer = Timer.periodic(
      homeStatusInterval,
      (_) => unawaited(_pollStatus()),
    );
    _clockTimer = Timer.periodic(homeClockInterval, (_) => _tickClock());
  }

  Future<void> _pollLocation() async {
    if (!mounted || !_polling) {
      return;
    }
    await ref.read(nearestStationControllerProvider.notifier).refreshQuietly();
  }

  Future<void> _pollStatus() async {
    if (!mounted || !_polling) {
      return;
    }
    await Future.wait<void>(<Future<void>>[
      ref.read(internetStatusProvider.notifier).refresh(),
      ref.read(gpsStatusProvider.notifier).refresh(),
    ]);
  }

  void _tickClock() {
    if (!mounted) {
      return;
    }
    setState(() => _now = ref.read(clockProvider).now());
  }

  Future<void> _refreshAll(String boardStationId) async {
    ref.invalidate(departuresProvider(boardStationId));
    await Future.wait<void>(<Future<void>>[
      ref.read(nearestStationControllerProvider.notifier).refreshQuietly(),
      ref.read(internetStatusProvider.notifier).refresh(),
      ref.read(gpsStatusProvider.notifier).refresh(),
    ]);
    if (mounted) {
      _tickClock();
    }
  }

  /// The list comes from one query for "the next ten from when it was
  /// loaded", so after a while it runs dry. Reload at most once a minute.
  void _reloadDeparturesIfStale(String stationId, List<Departure> upcoming) {
    if (upcoming.length >= 2) {
      return;
    }
    final last = _lastDeparturesReload;
    if (last != null && _now.difference(last) < const Duration(minutes: 1)) {
      return;
    }
    _lastDeparturesReload = _now;
    unawaited(
      Future<void>.microtask(() {
        if (mounted) {
          ref.invalidate(departuresProvider(stationId));
        }
      }),
    );
  }

  /// Only the pre-boarding phases get a subtle banner. `confirmingTrip` is
  /// deliberately excluded: that one navigates to a full confirmation page
  /// (PRD section 9 treats crossing the ask threshold as an explicit prompt).
  String? _ridePhaseLabel(ActiveTripState? state) => switch (state) {
    ActiveTripState.nearStation => 'Mendekati stasiun',
    ActiveTripState.atStation => 'Terdeteksi di stasiun',
    ActiveTripState.possibleBoarding => 'Memeriksa kemungkinan naik KRL',
    _ => null,
  };

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsControllerProvider);
    final homeStationId = settings.homeStationId ?? 'BOO';
    final stationsAsync = ref.watch(stationListProvider);
    final stations = stationsAsync.asData?.value ?? const <Station>[];
    final ranked =
        ref.watch(nearestStationControllerProvider).asData?.value ?? const [];
    final ridePhase = ref.watch(rideDetectionControllerProvider);
    final activeTrip = ref.watch(activeTripControllerProvider);
    final alerts = ref.watch(serviceAlertsProvider);
    final vehicles =
        ref.watch(vehiclePositionsProvider).asData?.value ??
        const <VehiclePosition>[];
    final favorite = ref.watch(favoriteRouteControllerProvider);

    // Keeps the Android home-screen widgets showing the same data the app
    // just loaded, without the widgets themselves ever touching the network.
    // These stay keyed on the saved home station: that is what the widgets
    // are about, whatever station Home happens to be showing.
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

    final choice = resolveBoardChoice(
      ranked: ranked,
      homeStationId: settings.homeStationId,
      previousNearestId: _lastNearestId,
    );
    _lastNearestId = choice.source == BoardSource.nearest
        ? choice.stationId
        : null;
    final departures = ref.watch(departuresProvider(choice.stationId));

    final boardStation =
        stations.where((s) => s.id == choice.stationId).firstOrNull ??
        choice.nearest?.station;
    final upcoming = departures.asData == null
        ? const <Departure>[]
        : upcomingDepartures(departures.asData!.value, _now);
    if (departures.hasValue) {
      _reloadDeparturesIfStale(choice.stationId, upcoming);
    }

    VehiclePosition? vehicle;
    TrainProgress? progress;
    if (upcoming.isNotEmpty && boardStation != null) {
      vehicle = matchVehicle(upcoming.first, vehicles, _now);
      if (vehicle != null) {
        progress = describeTrain(vehicle, boardStation, {
          for (final s in stations) s.id: s,
        });
      }
    }

    final displayName = ref.watch(userDisplayNameProvider).asData?.value;
    final nameSuffix = (displayName != null && displayName.trim().isNotEmpty)
        ? ', ${displayName.trim()}'
        : '';
    final greeting = switch (_now.hour) {
      < 11 => 'Selamat pagi$nameSuffix',
      < 15 => 'Selamat siang$nameSuffix',
      < 19 => 'Selamat sore$nameSuffix',
      _ => 'Selamat malam$nameSuffix',
    };

    final disruptions = disruptionAlerts(
      alerts.asData?.value ?? const <ServiceAlert>[],
    );
    final ridePhaseLabel = _ridePhaseLabel(ridePhase?.state);

    String nameOf(String id) =>
        stations.where((s) => s.id == id).firstOrNull?.name ?? id;
    final favoriteParts = favorite?.split('|');
    final hasFavorite = favoriteParts != null && favoriteParts.length == 2;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () => _refreshAll(choice.stationId),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: <Widget>[
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                sliver: SliverList.list(
                  children: <Widget>[
                    HomeHeader(
                      greeting: greeting,
                      dateLabel: DateFormat(
                        'EEEE, d MMMM',
                        'id_ID',
                      ).format(_now),
                    ),
                    const SizedBox(height: 16),
                    if (activeTrip != null) ...<Widget>[
                      ActiveTripStatusCard(
                        session: activeTrip,
                        stations: stations,
                        onTap: () => context.push('/active-trip'),
                      ),
                      const SizedBox(height: 12),
                    ] else if (ridePhaseLabel != null) ...<Widget>[
                      RideDetectionPhaseBanner(
                        label: ridePhaseLabel,
                        stationName: ridePhase?.stationId == null
                            ? null
                            : nameOf(ridePhase!.stationId!),
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (disruptions.isNotEmpty) ...<Widget>[
                      ServiceAlertBanner(alerts: disruptions),
                      const SizedBox(height: 12),
                    ],
                    _buildHero(
                      context,
                      choice: choice,
                      stationsAsync: stationsAsync,
                      boardStation: boardStation,
                      departures: departures,
                      vehicle: vehicle,
                      progress: progress,
                    ),
                    const SizedBox(height: 12),
                    QuickActions(
                      onSearchTrains: () => context.push('/schedule/search'),
                      onExplore: () => context.go('/explore'),
                    ),
                    if (hasFavorite) ...<Widget>[
                      const SizedBox(height: 10),
                      FavoriteRouteTile(
                        originName: nameOf(favoriteParts[0]),
                        destinationName: nameOf(favoriteParts[1]),
                        onTap: () {
                          ref.read(tripSearchControllerProvider.notifier)
                            ..setOrigin(favoriteParts[0])
                            ..setDestination(favoriteParts[1]);
                          unawaited(context.push('/schedule/search'));
                        },
                      ),
                    ],
                    if (activeTrip == null) ...<Widget>[
                      const SizedBox(height: 20),
                      const TkSectionLabel(
                        'Mulai perjalanan',
                        trailing: AntiBablasHint(),
                      ),
                      QuickTripCard(
                        nearestStationId: choice.nearest?.station.id,
                        nearestStationName: choice.nearest?.station.name,
                        stations: stations,
                      ),
                    ],
                    const SizedBox(height: 16),
                    const DeviceStatusTiles(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHero(
    BuildContext context, {
    required BoardChoice choice,
    required AsyncValue<List<Station>> stationsAsync,
    required Station? boardStation,
    required AsyncValue<List<Departure>> departures,
    required VehiclePosition? vehicle,
    required TrainProgress? progress,
  }) {
    if (stationsAsync.isLoading && !stationsAsync.hasValue) {
      return const NextTrainHeroSkeleton();
    }
    if (stationsAsync.hasError && !stationsAsync.hasValue) {
      return TkCard(
        child: TkErrorState(
          title: 'Stasiun belum dimuat',
          message: 'Daftar stasiun belum bisa dibaca. Coba lagi.',
          onRetry: () => ref.invalidate(stationListProvider),
        ),
      );
    }
    final station = boardStation;
    return NextTrainHero(
      choice: choice,
      stationName: station?.name ?? choice.stationId,
      departures: departures,
      now: _now,
      vehicle: vehicle,
      progress: progress,
      onOpenStation: () => context.push('/station/${choice.stationId}'),
      onSeeAllNearby: () => context.push('/nearby-stations'),
      onRetry: () => ref.invalidate(departuresProvider(choice.stationId)),
      onDirections: () {
        if (station == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Lokasi stasiun belum tersedia.')),
          );
          return;
        }
        unawaited(
          launchMapDirections(
            station.latitude,
            station.longitude,
            label: station.name,
          ),
        );
      },
    );
  }
}
