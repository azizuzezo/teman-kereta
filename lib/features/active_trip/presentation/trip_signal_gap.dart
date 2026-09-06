import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A recovered signal gap on the current trip: GPS went quiet for a while
/// and the fix that eventually came back put the rider somewhere
/// meaningfully different. Recorded natively by `ActiveTripLocationService`
/// and drained by `ActiveTripController._refreshFromNative`.
///
/// This exists purely so the app can *ask* "masih di kereta?" the next time
/// the rider opens it. The trip itself never waits for that answer — native
/// `TripProgressEngine`'s catch-up gate has already resumed the trip from
/// wherever the rider actually is by the time this reaches the UI.
class TripSignalGap {
  const TripSignalGap({
    required this.lastSeenAt,
    required this.recoveredAt,
    required this.movedMeters,
    this.recoveredLatitude,
    this.recoveredLongitude,
  });

  /// Timestamp of the last fix before the outage.
  final DateTime lastSeenAt;

  /// Timestamp of the first fix after it.
  final DateTime recoveredAt;

  /// Straight-line distance between those two fixes.
  final double movedMeters;

  final double? recoveredLatitude;
  final double? recoveredLongitude;

  Duration get gap => recoveredAt.difference(lastSeenAt);

  /// Identity for "is this the same gap the user has already been asked
  /// about?" — the pair of timestamps is unique per outage, and native
  /// only ever keeps the most recent one pending.
  String get key =>
      '${lastSeenAt.millisecondsSinceEpoch}:${recoveredAt.millisecondsSinceEpoch}';

  static TripSignalGap? fromNative(Object? raw) {
    if (raw is! Map) {
      return null;
    }
    final fromAtMs = (raw['fromAtEpochMs'] as num?)?.toInt();
    final toAtMs = (raw['toAtEpochMs'] as num?)?.toInt();
    if (fromAtMs == null || toAtMs == null) {
      return null;
    }
    return TripSignalGap(
      lastSeenAt: DateTime.fromMillisecondsSinceEpoch(fromAtMs),
      recoveredAt: DateTime.fromMillisecondsSinceEpoch(toAtMs),
      movedMeters: (raw['distanceMeters'] as num?)?.toDouble() ?? 0,
      recoveredLatitude: (raw['toLatitude'] as num?)?.toDouble(),
      recoveredLongitude: (raw['toLongitude'] as num?)?.toDouble(),
    );
  }
}

/// Holds the gap awaiting the rider's acknowledgement, or null when there is
/// nothing to ask about.
///
/// Deliberately a standalone provider rather than a field on
/// `ActiveTripSession`: the session is persisted to SharedPreferences and
/// restored on launch, and a stale "are you still on the train?" question
/// surviving a restart is exactly what we don't want. Native owns the
/// pending flag; this is just its in-memory mirror for the current app run.
class TripSignalGapController extends Notifier<TripSignalGap?> {
  @override
  TripSignalGap? build() => null;

  void set(TripSignalGap? gap) {
    state = gap;
  }
}

final tripSignalGapProvider =
    NotifierProvider<TripSignalGapController, TripSignalGap?>(
      TripSignalGapController.new,
    );
