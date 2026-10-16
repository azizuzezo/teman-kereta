import '../../../core/utils/geo.dart';
import '../../../domain/entities/transit_models.dart';
import '../../../domain/usecases/nearest_station_finder.dart';
import '../../../domain/usecases/travel_estimate.dart';

/// Which station drives Home's "Kereta berikutnya", and why. The UI must say
/// which one it is using so the rider never reads home-station times as if
/// they were for the station next to them.
enum BoardSource { nearest, home, fallback }

class BoardChoice {
  const BoardChoice({
    required this.stationId,
    required this.source,
    this.nearest,
  });

  final String stationId;
  final BoardSource source;

  /// Distance and estimates, present only when [source] is
  /// [BoardSource.nearest].
  final StationDistance? nearest;
}

/// Station used when the rider has neither a GPS fix nor a saved home station.
const String defaultBoardStationId = 'BOO';

/// How much closer another station must be before the board switches to it.
/// Stops the list from flipping between two stations of similar distance as
/// the GPS fix wobbles by a few tens of meters.
const double boardSwitchHysteresisMeters = 150;

/// GPS nearest station first, then the saved home station, then a default.
BoardChoice resolveBoardChoice({
  required List<StationDistance> ranked,
  required String? homeStationId,
  String? previousNearestId,
  String fallbackStationId = defaultBoardStationId,
}) {
  final first = ranked.firstOrNull;
  if (first != null && first.estimate.isReliable) {
    var pick = first;
    if (previousNearestId != null && previousNearestId != first.station.id) {
      final previous = ranked
          .where((entry) => entry.station.id == previousNearestId)
          .firstOrNull;
      if (previous != null &&
          previous.distanceMeters <=
              first.distanceMeters + boardSwitchHysteresisMeters) {
        pick = previous;
      }
    }
    return BoardChoice(
      stationId: pick.station.id,
      source: BoardSource.nearest,
      nearest: pick,
    );
  }
  if (homeStationId != null && homeStationId.isNotEmpty) {
    return BoardChoice(stationId: homeStationId, source: BoardSource.home);
  }
  return BoardChoice(
    stationId: fallbackStationId,
    source: BoardSource.fallback,
  );
}

/// Departures that have not left yet, soonest first.
List<Departure> upcomingDepartures(
  List<Departure> all,
  DateTime now, {
  int limit = 4,
}) {
  final upcoming =
      all.where((d) => !d.expectedAt.isBefore(now)).toList(growable: false)
        ..sort((a, b) => a.expectedAt.compareTo(b.expectedAt));
  return upcoming.take(limit).toList(growable: false);
}

/// "5 mnt lagi", "Kurang dari 1 mnt", "Berangkat". Whole minutes are floored
/// so the label never promises more time than is left.
String countdownLabel(Duration until) {
  if (until.inSeconds < 0) {
    return 'Berangkat';
  }
  final minutes = until.inMinutes;
  if (minutes < 1) {
    return 'Kurang dari 1 mnt';
  }
  return '${formatMinutes(minutes)} lagi';
}

/// A position report older than this no longer says where the train is.
const Duration vehiclePositionMaxAge = Duration(minutes: 5);

/// The reported position of the train running [departure], matched by trip
/// id. Null when no provider has a recent position for it, which is the
/// normal case for schedule-only data.
VehiclePosition? matchVehicle(
  Departure departure,
  List<VehiclePosition> positions,
  DateTime now,
) {
  if (departure.id.isEmpty) {
    return null;
  }
  VehiclePosition? best;
  for (final position in positions) {
    if (position.tripId != departure.id) {
      continue;
    }
    if (now.difference(position.recordedAt) > vehiclePositionMaxAge) {
      continue;
    }
    if (best == null || position.recordedAt.isAfter(best.recordedAt)) {
      best = position;
    }
  }
  return best;
}

class TrainProgress {
  const TrainProgress({
    required this.distanceToBoardMeters,
    this.previousName,
    this.nextName,
    this.fraction,
  });

  /// Straight-line distance from the train to the station being shown.
  final double distanceToBoardMeters;
  final String? previousName;
  final String? nextName;

  /// 0..1 progress along the previous to next station segment; null when
  /// either neighbouring station is unknown.
  final double? fraction;
}

TrainProgress describeTrain(
  VehiclePosition vehicle,
  Station boardStation,
  Map<String, Station> stationsById,
) {
  final previous = vehicle.previousStationId == null
      ? null
      : stationsById[vehicle.previousStationId];
  final next = vehicle.nextStationId == null
      ? null
      : stationsById[vehicle.nextStationId];

  double? fraction;
  if (previous != null && next != null) {
    final dx = next.longitude - previous.longitude;
    final dy = next.latitude - previous.latitude;
    final lengthSquared = dx * dx + dy * dy;
    if (lengthSquared > 0) {
      final t =
          ((vehicle.longitude - previous.longitude) * dx +
              (vehicle.latitude - previous.latitude) * dy) /
          lengthSquared;
      fraction = t.clamp(0.0, 1.0);
    }
  }

  return TrainProgress(
    distanceToBoardMeters: haversineMeters(
      vehicle.latitude,
      vehicle.longitude,
      boardStation.latitude,
      boardStation.longitude,
    ),
    previousName: previous?.name,
    nextName: next?.name,
    fraction: fraction,
  );
}

/// Alerts worth interrupting Home for: anything that is not "normal" and not
/// "no information". Most severe first, then newest. Empty means show
/// nothing at all.
List<ServiceAlert> disruptionAlerts(List<ServiceAlert> alerts) {
  int severity(ServiceStatus status) => switch (status) {
    ServiceStatus.disrupted => 3,
    ServiceStatus.limited => 2,
    ServiceStatus.delayed => 1,
    ServiceStatus.normal || ServiceStatus.unavailable => 0,
  };
  final active =
      alerts.where((a) => severity(a.status) > 0).toList(growable: false)
        ..sort((a, b) {
          final bySeverity = severity(b.status).compareTo(severity(a.status));
          return bySeverity != 0
              ? bySeverity
              : b.updatedAt.compareTo(a.updatedAt);
        });
  return active;
}

/// "Peron 3" when a real platform is known, otherwise null. Providers may
/// hand over a bare number, a "Peron 3" string or the placeholder
/// "Peron belum tersedia", which must not be shown as if it were data.
String? platformLabel(String? platform) {
  final value = platform?.trim();
  if (value == null || value.isEmpty) {
    return null;
  }
  if (value.toLowerCase().contains('belum tersedia')) {
    return null;
  }
  return value.toLowerCase().startsWith('peron') ? value : 'Peron $value';
}
