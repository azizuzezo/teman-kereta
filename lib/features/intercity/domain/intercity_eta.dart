import 'dart:math' as math;

import '../../../core/utils/geo.dart';
import 'intercity_geometry.dart';
import 'intercity_models.dart';

/// What the estimator knows about the rest of the ride.
class IntercityEta {
  const IntercityEta({
    required this.eta,
    required this.remainingKm,
    required this.speedKmh,
    required this.onTrack,
  });

  final Duration eta;
  final double remainingKm;

  /// The speed the estimate used: the prior and the observed speed blended.
  final double speedKmh;

  /// False when the fix was too far from the track to place on it; the
  /// estimate then uses the straight-line distance to the destination.
  final bool onTrack;
}

/// Time left to the destination for a train with no timetable.
///
/// Before there is any data it is the estimate in the dataset: track distance
/// at a cruising speed for the train's class (slower on winding legs) plus the
/// time it stands at each stop still ahead. As the ride goes on the speed it
/// really keeps takes over, gradually, and near the destination almost
/// entirely: the last stretch decides when the rider must be ready, and the
/// train's own speed there beats any prior.
class IntercityEtaEstimator {
  IntercityEtaEstimator({
    required this.service,
    required this.boardingCode,
    required this.destinationCode,
    required this.destinationLatitude,
    required this.destinationLongitude,
  }) : _track = TrackIndex(service),
       _forward = service.indexOfStop(boardingCode) <
           service.indexOfStop(destinationCode),
       destinationKm = service.stopAt(destinationCode)!.km {
    assert(service.connects(boardingCode, destinationCode));
  }

  final IntercityService service;
  final String boardingCode;
  final String destinationCode;
  final double destinationLatitude;
  final double destinationLongitude;
  final double destinationKm;
  final TrackIndex _track;
  final bool _forward;

  /// A fix further than this from the track is not placed on it.
  static const double maxTrackOffsetMeters = 600;

  /// Below this the train counts as standing: not a speed worth averaging.
  static const double movingKmh = 20;

  /// The slowest speed the estimate ever assumes, so a train standing at a
  /// signal does not push the estimate to infinity.
  static const double floorKmh = 20;

  late double? _lastAlongKm = service.stopAt(boardingCode)?.km;
  double? _observedKmh;
  double _movingSeconds = 0;
  DateTime? _lastAt;
  double? _lastLat;
  double? _lastLon;

  /// Straight-line detour allowance when the fix is off the track.
  static const double _offTrackDetourFactor = 1.2;

  /// Feeds one GPS fix and returns the new estimate. [speedKmh] is the speed
  /// the device reports; when it is missing the speed is worked out from the
  /// last fix.
  IntercityEta update({
    required double latitude,
    required double longitude,
    required DateTime at,
    double? speedKmh,
  }) {
    final dt = _lastAt == null
        ? 0.0
        : at.difference(_lastAt!).inMilliseconds / 1000.0;
    var speed = speedKmh;
    if (speed == null && dt > 0.5 && _lastLat != null) {
      speed =
          haversineMeters(_lastLat!, _lastLon!, latitude, longitude) /
          dt *
          3.6;
    }
    if (speed != null && speed >= movingKmh && dt > 0) {
      final alpha = 1 - math.exp(-dt / 180);
      _observedKmh = _observedKmh == null
          ? speed
          : _observedKmh! + (speed - _observedKmh!) * alpha;
      _movingSeconds += dt;
    }
    _lastAt = at;
    _lastLat = latitude;
    _lastLon = longitude;

    final hoursSinceLast = dt / 3600.0;
    final position = _track.project(
      latitude,
      longitude,
      hintKm: _lastAlongKm,
      // The train cannot have gone further than a fast train in the time
      // since the last fix; the floor covers a slow or paused phone.
      windowKm: math.max(20.0, 5 + hoursSinceLast * 220),
    );
    if (position.offsetMeters <= maxTrackOffsetMeters) {
      _lastAlongKm = position.alongKm;
    }
    final onTrack = position.offsetMeters <= maxTrackOffsetMeters;
    final double remainingKm;
    var dwell = 0.0;
    var priorMinutes = 0.0;
    if (onTrack) {
      remainingKm = math.max(
        0,
        _forward
            ? destinationKm - position.alongKm
            : position.alongKm - destinationKm,
      );
      dwell = _dwellAhead(position.alongKm);
      priorMinutes =
          (_minutesAt(destinationKm) - _minutesAt(position.alongKm)).abs();
    } else {
      remainingKm =
          haversineMeters(
            latitude,
            longitude,
            destinationLatitude,
            destinationLongitude,
          ) /
          1000 *
          _offTrackDetourFactor;
    }

    final cruiseMinutes = math.max(0.0, priorMinutes - dwell);
    final priorKmh = (onTrack && cruiseMinutes > 0 && remainingKm > 0)
        ? remainingKm / (cruiseMinutes / 60)
        : _fallbackPriorKmh;
    final speedUsed = _blend(priorKmh, remainingKm);
    final minutes = dwell + remainingKm / speedUsed * 60;
    return IntercityEta(
      eta: Duration(milliseconds: (minutes * 60 * 1000).round()),
      remainingKm: remainingKm,
      speedKmh: speedUsed,
      onTrack: onTrack,
    );
  }

  double get _fallbackPriorKmh => 70;

  double _blend(double priorKmh, double remainingKm) {
    final observed = _observedKmh;
    if (observed == null) return math.max(priorKmh, floorKmh);
    var weight = math.min(0.8, _movingSeconds / 900 * 0.8);
    if (remainingKm < 25 && _movingSeconds > 120) {
      weight = math.max(weight, 0.9);
    }
    final blended = weight * observed + (1 - weight) * priorKmh;
    return blended.clamp(floorKmh, 160.0);
  }

  /// Standing time at the stops still ahead of [alongKm] and before the
  /// destination.
  double _dwellAhead(double alongKm) {
    var total = 0.0;
    for (final stop in service.stops) {
      if (stop.code == destinationCode || stop.code == boardingCode) continue;
      final ahead = _forward
          ? stop.km > alongKm + 0.5 && stop.km < destinationKm
          : stop.km < alongKm - 0.5 && stop.km > destinationKm;
      if (ahead) total += stop.dwellMinutes;
    }
    return total;
  }

  /// Dataset estimate of minutes since the origin at [km], interpolated
  /// between stops.
  double _minutesAt(double km) {
    final stops = service.stops;
    if (km <= stops.first.km) return stops.first.estimatedMinutes;
    for (var i = 1; i < stops.length; i += 1) {
      if (km <= stops[i].km) {
        final a = stops[i - 1];
        final b = stops[i];
        final span = b.km - a.km;
        if (span <= 0) return b.estimatedMinutes;
        final t = (km - a.km) / span;
        return a.estimatedMinutes + (b.estimatedMinutes - a.estimatedMinutes) * t;
      }
    }
    return stops.last.estimatedMinutes;
  }
}
