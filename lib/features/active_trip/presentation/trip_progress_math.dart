import '../../../core/utils/geo.dart';
import '../../../domain/entities/transit_models.dart';
import '../../live_map/presentation/native_gps_fix.dart';

/// How far into the hop from the current station to the next one the rider
/// physically is, estimated from the latest GPS fix against both stations'
/// coordinates. 0 whenever there's no fix yet or a coordinate is missing —
/// the UI then just shows the train sitting at the current node, same as
/// before this existed.
double hopFractionFromGps({
  required Station? from,
  required Station? to,
  required NativeGpsFix? fix,
}) {
  if (from == null || to == null || fix == null) {
    return 0;
  }
  final total = haversineMeters(
    from.latitude,
    from.longitude,
    to.latitude,
    to.longitude,
  );
  if (total <= 1) {
    return 0;
  }
  final travelled = haversineMeters(
    from.latitude,
    from.longitude,
    fix.latitude,
    fix.longitude,
  );
  return (travelled / total).clamp(0.0, 1.0);
}

/// Straight-line distance left to the destination, starting from wherever
/// [hopFraction] says the rider is inside the current hop and summing every
/// remaining station-to-station leg from there. Null if any remaining
/// station's coordinates aren't known yet (live station list still
/// loading) — callers fall back to the trip's scheduled arrival time in
/// that case rather than show a distance that's silently wrong.
double? remainingDistanceMeters({
  required TransitTrip trip,
  required int currentStationIndex,
  required double hopFraction,
  required Map<String, Station> stationsById,
}) {
  final ids = trip.stationIds;
  var total = 0.0;
  for (var i = currentStationIndex; i < ids.length - 1; i += 1) {
    final from = stationsById[ids[i]];
    final to = stationsById[ids[i + 1]];
    if (from == null || to == null) {
      return null;
    }
    final hop = haversineMeters(
      from.latitude,
      from.longitude,
      to.latitude,
      to.longitude,
    );
    total += i == currentStationIndex ? hop * (1 - hopFraction) : hop;
  }
  return total;
}

/// A live ETA projected from the trip's average pace so far (`distanceMeters`
/// over time elapsed) applied to [remainingMeters] — steadier than
/// instantaneous GPS speed, which jitters between stops. Null whenever
/// there isn't enough signal yet to trust the projection (trip just started,
/// barely moved, or average pace reads as effectively stationary), so
/// callers fall back to the trip's scheduled arrival time instead of
/// showing a shaky guess.
DateTime? liveEta({
  required DateTime startedAt,
  required double distanceMeters,
  required double? remainingMeters,
  required DateTime now,
}) {
  if (remainingMeters == null) {
    return null;
  }
  final elapsedSeconds = now.difference(startedAt).inSeconds;
  if (elapsedSeconds < 30 || distanceMeters < 50) {
    return null;
  }
  final avgSpeedMps = distanceMeters / elapsedSeconds;
  if (avgSpeedMps < 1.0) {
    return null;
  }
  final etaSeconds = remainingMeters / avgSpeedMps;
  return now.add(Duration(seconds: etaSeconds.round()));
}
