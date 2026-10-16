import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/network/device_status.dart';
import '../../../core/network/gps_status_controller.dart';
import '../../../core/utils/map_launcher.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/facility_icon_chip.dart';
import '../../../core/widgets/tk_components.dart';
import '../../../domain/usecases/nearest_station_finder.dart';
import '../../../domain/usecases/travel_estimate.dart';
import 'nearest_station_controller.dart';

/// PRD section 12 "Stasiun Terdekat", list mode. There is no real geographic
/// map in this app yet (the live map page is an intentionally-labelled rail
/// schematic, not GPS-backed), so this page only offers the list mode rather
/// than a map toggle that couldn't actually show anything.
class NearbyStationsPage extends ConsumerWidget {
  const NearbyStationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nearest = ref.watch(nearestStationControllerProvider);
    final controller = ref.read(nearestStationControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Stasiun terdekat'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Muat ulang lokasi',
            onPressed: () => controller.refresh(),
            icon: const Icon(Icons.my_location_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: nearest.when(
          loading: () => const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 28),
            child: TkListSkeleton(count: 5),
          ),
          error: (error, stack) => TkErrorState(
            title: 'Lokasi belum terbaca',
            message: 'Terjadi kendala saat membaca lokasi perangkat.',
            onRetry: () => controller.refresh(),
          ),
          data: (items) {
            if (items.isEmpty) {
              return _NoLocation(controller: controller);
            }
            return RefreshIndicator(
              onRefresh: () => controller.refreshQuietly(),
              child: ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
                itemCount: items.length + 1,
                separatorBuilder: (context, index) =>
                    SizedBox(height: index == 0 ? 8 : 10),
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
                      child: Text(
                        'Diurutkan dari lokasimu. Waktu tempuh adalah '
                        'perkiraan dari jarak lurus.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    );
                  }
                  return _NearbyStationCard(
                    entry: items[index - 1],
                    isNearest: index == 1,
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}

class _NoLocation extends ConsumerWidget {
  const _NoLocation({required this.controller});

  final NearestStationController controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final level = ref.watch(gpsStatusProvider).level;
    // First read of the page: find out why there is no location.
    if (level == null) {
      unawaited(
        Future<void>.microtask(
          () => ref.read(gpsStatusProvider.notifier).refresh(),
        ),
      );
    }

    final (title, message, label, icon) = switch (level) {
      GpsLevel.servicesOff => (
        'Lokasi perangkat mati',
        'Nyalakan lokasi di pengaturan agar TK bisa menghitung jarak ke '
            'stasiun sekitar. Jadwal tetap berfungsi tanpa ini.',
        'Buka pengaturan lokasi',
        Icons.settings_outlined,
      ),
      GpsLevel.permissionBlocked => (
        'Izin lokasi ditolak',
        'Izinkan lokasi lewat pengaturan aplikasi agar TK bisa menghitung '
            'jarak ke stasiun sekitar.',
        'Buka pengaturan aplikasi',
        Icons.settings_outlined,
      ),
      _ => (
        'Lokasi belum aktif',
        'Aktifkan lokasi agar TK dapat menghitung jarak sungguhan ke stasiun '
            'sekitar. Fitur jadwal tetap berfungsi tanpa ini.',
        'Aktifkan lokasi',
        Icons.location_on_outlined,
      ),
    };

    return AppEmptyState(
      icon: Icons.location_searching_rounded,
      title: title,
      message: message,
      action: FilledButton.icon(
        onPressed: () async {
          final messenger = ScaffoldMessenger.of(context);
          switch (level) {
            case GpsLevel.servicesOff:
              await Geolocator.openLocationSettings();
            case GpsLevel.permissionBlocked:
              await Geolocator.openAppSettings();
            case _:
              final granted = await controller.requestPermissionAndRefresh();
              if (!granted) {
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Lokasi belum diizinkan atau layanan lokasi mati.',
                    ),
                  ),
                );
              }
          }
          await ref.read(gpsStatusProvider.notifier).refresh();
        },
        icon: Icon(icon),
        label: Text(label),
      ),
    );
  }
}

class _NearbyStationCard extends StatelessWidget {
  const _NearbyStationCard({required this.entry, required this.isNearest});

  final StationDistance entry;
  final bool isNearest;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final textTheme = Theme.of(context).textTheme;
    final station = entry.station;
    final estimate = formatEstimateLine(entry.estimate);
    final distance = formatDistance(entry.distanceMeters);
    final summary = estimate == null
        ? '$distance, terlalu jauh untuk diperkirakan'
        : '$distance · $estimate';

    return TkCard(
      tone: isNearest ? TkCardTone.soft : TkCardTone.surface,
      onTap: () => context.push('/station/${station.id}'),
      semanticLabel:
          'Stasiun ${station.name}, $summary. Ketuk untuk melihat jadwal.',
      padding: const EdgeInsets.fromLTRB(16, 14, 6, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (isNearest)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 6),
                    child: TkPill(
                      label: 'Paling dekat',
                      icon: Icons.near_me_rounded,
                      tone: TkPillTone.primary,
                      dense: true,
                    ),
                  ),
                Row(
                  children: <Widget>[
                    Flexible(
                      child: Text(
                        station.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.titleMedium,
                      ),
                    ),
                    if (station.wheelchairAccessible)
                      Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: Icon(
                          Icons.accessible_rounded,
                          size: 18,
                          color: tk.textMuted,
                          semanticLabel: 'Akses kursi roda',
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  summary,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodyMedium?.copyWith(
                    fontFeatures: AppTheme.timeFeatures,
                  ),
                ),
                if (station.facilities.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: <Widget>[
                      for (final facility in station.facilities.take(6))
                        FacilityIconChip(label: facility),
                    ],
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            tooltip: 'Arah ke Stasiun ${station.name}',
            onPressed: () => unawaited(
              launchMapDirections(
                station.latitude,
                station.longitude,
                label: station.name,
              ),
            ),
            icon: Icon(Icons.directions_rounded, color: tk.primary),
          ),
        ],
      ),
    );
  }
}
