import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers/provider_registry.dart';
import '../../domain/entities/transit_models.dart';
import '../../features/favorites/presentation/favorite_route_controller.dart';
import 'native_trip_service.dart';

String serviceStatusLabel(ServiceStatus status) => switch (status) {
  ServiceStatus.normal => 'Normal',
  ServiceStatus.delayed => 'Terlambat',
  ServiceStatus.limited => 'Terbatas',
  ServiceStatus.disrupted => 'Gangguan',
  ServiceStatus.unavailable => 'Belum tersedia',
};

/// Pushes whatever the app already has loaded for [homeStationId] into the
/// "next departure" (2×2) and, when a matching favorite route exists, the
/// "daily route" (4×2) home-screen widgets. Never fetches anything itself —
/// widgets only ever show data the app already fetched for its own UI.
Future<void> syncNextDepartureAndDailyRouteWidgets(
  WidgetRef ref,
  String homeStationId,
) async {
  final departures =
      ref.read(departuresProvider(homeStationId)).asData?.value ??
          const <Departure>[];
  final firstDeparture = departures.firstOrNull;
  if (firstDeparture == null) {
    return;
  }
  final native = ref.read(nativeTripServiceProvider);
  await native.updateNextDepartureWidget(firstDeparture);

  final favoriteParts = ref.read(favoriteRouteControllerProvider)?.split('|');
  if (favoriteParts != null &&
      favoriteParts.length == 2 &&
      favoriteParts[0] == homeStationId) {
    final alerts =
        ref.read(serviceAlertsProvider).asData?.value ?? const <ServiceAlert>[];
    await native.updateDailyRouteWidget(
      originStationId: favoriteParts[0],
      destinationStationId: favoriteParts[1],
      upcomingDepartures: departures,
      lineStatusLabel: alerts.firstOrNull == null
          ? 'Status belum tersedia'
          : serviceStatusLabel(alerts.first.status),
      isDemo: firstDeparture.isDemo,
    );
  }
}

Future<void> syncServiceStatusWidget(WidgetRef ref) async {
  final alerts =
      ref.read(serviceAlertsProvider).asData?.value ?? const <ServiceAlert>[];
  if (alerts.isEmpty) {
    return;
  }
  await ref.read(nativeTripServiceProvider).updateServiceStatusWidget(
    alerts: alerts,
    isDemo: alerts.any((alert) => alert.isDemo),
  );
}

Future<void> syncAllHomeScreenWidgets(WidgetRef ref, String homeStationId) async {
  await syncNextDepartureAndDailyRouteWidgets(ref, homeStationId);
  await syncServiceStatusWidget(ref);
}
