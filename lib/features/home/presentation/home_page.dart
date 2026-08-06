import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/config/app_environment.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/platform/widget_sync.dart';
import '../../../core/widgets/data_badges.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/tk_logo.dart';
import '../../../data/providers/provider_registry.dart';
import '../../../domain/entities/active_trip.dart';
import '../../../domain/entities/transit_models.dart';
import '../../../domain/usecases/nearest_station_finder.dart';
import '../../ride_detection/presentation/ride_detection_controller.dart';
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

    // Keeps the Android home-screen widgets showing the same data the app
    // just loaded, without the widgets themselves ever touching the network.
    ref.listen(departuresProvider(homeStationId), (previous, next) {
      unawaited(syncNextDepartureAndDailyRouteWidgets(ref, homeStationId));
    });
    ref.listen(serviceAlertsProvider, (previous, next) {
      unawaited(syncServiceStatusWidget(ref));
    });
    final now = DateTime.now();
    final greeting = switch (now.hour) {
      < 11 => 'Selamat pagi',
      < 15 => 'Selamat siang',
      < 19 => 'Selamat sore',
      _ => 'Selamat malam',
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
                Text(
                  settings.offlineMode
                      ? 'Mode offline aktif • data terakhir tersimpan'
                      : _connectionLabel(),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                if (departures.value?.firstOrNull?.isDemo ?? true)
                  const DemoDataBanner(),
                if (_ridePhaseLabel(ridePhase?.state) != null) ...<Widget>[
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
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Navigasi eksternal belum dibuka pada mode demo lokal.',
                        ),
                      ),
                    );
                  },
                  onSeeAll: () => context.push('/nearby-stations'),
                ),
                const SizedBox(height: 28),
                const SectionHeader(
                  title: 'Perjalanan cepat',
                  description: 'Rencanakan dari stasiun ke stasiun.',
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text('$homeStationName → Sudirman'),
                              const SizedBox(height: 4),
                              const Text('Berangkat sekarang • Data Demo'),
                            ],
                          ),
                        ),
                        FilledButton.icon(
                          onPressed: () => context.go('/schedule'),
                          icon: const Icon(Icons.search_rounded),
                          label: const Text('Cari'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                SectionHeader(
                  title: 'Kereta berikutnya',
                  description: 'Stasiun $homeStationName • estimasi lokal',
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
                      for (final item in items.take(3))
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

  /// Was hardcoded to always claim "runs locally", regardless of which
  /// provider was actually active — accurate when this app only ever had
  /// `gtfs`/`mock`, wrong now that `local_supabase` genuinely reads a real,
  /// live database. Matches this project's own established pattern of
  /// re-checking hardcoded config claims whenever the config itself changes
  /// (see the Round 21 "Local-only guard aktif" fix in ENGINEERING.md).
  String _connectionLabel() => switch (AppEnvironment.provider) {
    TransitProviderKind.localSupabase ||
    TransitProviderKind.officialApi => 'Terhubung ke database secara real-time',
    TransitProviderKind.gtfs => 'Jadwal dari berkas GTFS bawaan di perangkat',
    TransitProviderKind.mock => 'Data demo • berjalan lokal di perangkat',
  };
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
        ? 'Jarak pengguna belum dihitung • Lokasi demo'
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
