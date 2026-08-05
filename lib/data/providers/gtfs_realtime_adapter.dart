import 'package:gtfs_realtime_bindings/gtfs_realtime_bindings.dart' as gtfs;

import '../../domain/entities/transit_models.dart';
import '../../domain/providers/transit_providers.dart';

class GtfsRealtimeSnapshot {
  const GtfsRealtimeSnapshot({
    required this.vehicles,
    required this.tripUpdates,
    required this.alerts,
  });

  final List<VehiclePosition> vehicles;
  final List<TripUpdate> tripUpdates;
  final List<ServiceAlert> alerts;
}

class GtfsRealtimeAdapter {
  const GtfsRealtimeAdapter();

  GtfsRealtimeSnapshot decode(List<int> bytes, {required DateTime receivedAt}) {
    final message = gtfs.FeedMessage.fromBuffer(bytes);
    final vehicles = <VehiclePosition>[];
    final tripUpdates = <TripUpdate>[];
    final alerts = <ServiceAlert>[];

    for (final entity in message.entity) {
      if (entity.hasVehicle() && entity.vehicle.hasPosition()) {
        final value = entity.vehicle;
        final timestamp = value.hasTimestamp()
            ? DateTime.fromMillisecondsSinceEpoch(
                value.timestamp.toInt() * 1000,
                isUtc: true,
              )
            : receivedAt;
        vehicles.add(
          VehiclePosition(
            id: entity.id,
            tripId: value.hasTrip() ? value.trip.tripId : '',
            latitude: value.position.latitude,
            longitude: value.position.longitude,
            recordedAt: timestamp,
            freshness: _freshness(timestamp, receivedAt),
            sourceLabel: 'GTFS-Realtime resmi • ${timestamp.toLocal()}',
            nextStationId: value.hasStopId() ? value.stopId : null,
            bearing: value.position.hasBearing() ? value.position.bearing : null,
            speedMetersPerSecond: value.position.hasSpeed()
                ? value.position.speed
                : null,
          ),
        );
      }

      if (entity.hasTripUpdate()) {
        final update = entity.tripUpdate;
        for (final stop in update.stopTimeUpdate) {
          final arrivalDelay = stop.hasArrival() && stop.arrival.hasDelay()
              ? stop.arrival.delay
              : 0;
          final departureDelay = stop.hasDeparture() && stop.departure.hasDelay()
              ? stop.departure.delay
              : 0;
          tripUpdates.add(
            TripUpdate(
              tripId: update.trip.tripId,
              stationId: stop.stopId,
              arrivalDelaySeconds: arrivalDelay,
              departureDelaySeconds: departureDelay,
              updatedAt: receivedAt,
            ),
          );
        }
      }

      if (entity.hasAlert()) {
        final alert = entity.alert;
        alerts.add(
          ServiceAlert(
            id: entity.id,
            title: _translation(alert.headerText, 'Informasi layanan'),
            description: _translation(
              alert.descriptionText,
              'Rincian tidak disediakan oleh feed.',
            ),
            status: ServiceStatus.delayed,
            updatedAt: receivedAt,
            sourceLabel: 'GTFS-Realtime resmi',
            isOfficial: true,
          ),
        );
      }
    }

    return GtfsRealtimeSnapshot(
      vehicles: vehicles,
      tripUpdates: tripUpdates,
      alerts: alerts,
    );
  }

  static DataFreshness _freshness(DateTime timestamp, DateTime receivedAt) =>
      freshnessFor(timestamp, receivedAt);

  /// Classifies how stale a GTFS-RT timestamp is as of [asOf]. Exposed so
  /// callers holding onto a previously-decoded position (e.g. because the
  /// feed has since become unreachable) can recompute its freshness against
  /// the current time instead of freezing the label at the last successful
  /// fetch — a real-time badge must decay to "estimasi"/"tidak tersedia" as
  /// time passes, not stay stuck on "real-time" while the feed is down.
  static DataFreshness freshnessFor(DateTime timestamp, DateTime asOf) {
    final age = asOf.toUtc().difference(timestamp.toUtc());
    if (age <= const Duration(seconds: 90)) {
      return DataFreshness.realtime;
    }
    if (age <= const Duration(minutes: 5)) {
      return DataFreshness.nearRealtime;
    }
    return DataFreshness.unavailable;
  }

  static String _translation(gtfs.TranslatedString value, String fallback) {
    return value.translation.where((item) => item.text.isNotEmpty).firstOrNull?.text ??
        fallback;
  }
}
