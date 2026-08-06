import 'package:freezed_annotation/freezed_annotation.dart';

import 'transit_models.dart';

part 'active_trip.freezed.dart';
part 'active_trip.g.dart';

enum ActiveTripState {
  idle,
  nearStation,
  atStation,
  possibleBoarding,
  confirmingTrip,
  onBoard,
  approachingTransfer,
  transferring,
  approachingDestination,
  arrived,
  missedDestination,
  completed,
  cancelled,
}

@freezed
abstract class ActiveTripSession with _$ActiveTripSession {
  const factory ActiveTripSession({
    required String id,
    required TransitTrip trip,
    required ActiveTripState state,
    required int currentStationIndex,
    required DateTime startedAt,
    required DateTime updatedAt,
    @Default(100) int confidenceScore,
    @Default(false) bool lowBatteryMode,
    @Default(false) bool confirmedByUser,
  }) = _ActiveTripSession;
  const ActiveTripSession._();

  factory ActiveTripSession.fromJson(Map<String, Object?> json) =>
      _$ActiveTripSessionFromJson(json);

  int get remainingStops {
    final total = trip.stationIds.length;
    if (total == 0) {
      return 0;
    }
    return (total - currentStationIndex - 1).clamp(0, total).toInt();
  }

  String? get currentStationId {
    if (trip.stationIds.isEmpty) {
      return null;
    }
    return trip.stationIds.elementAtOrNull(
      currentStationIndex.clamp(0, trip.stationIds.length - 1).toInt(),
    );
  }

  String? get nextStationId =>
      trip.stationIds.elementAtOrNull(currentStationIndex + 1);

  /// The nearest transfer boundary at or after the current position, or
  /// null once the last transfer has been passed.
  TransferBoundary? get nextTransferBoundary {
    for (final boundary in trip.transferBoundaries) {
      if (boundary.index >= currentStationIndex) {
        return boundary;
      }
    }
    return null;
  }

  /// Which physical rail leg (i.e. which real train/`externalTripId`) the
  /// rider is currently on, derived from [currentStationIndex] against the
  /// global transfer-boundary indices — used to tag crowd-sourced position
  /// reports with the correct vehicle on a multi-leg trip. `transferring`
  /// (index exactly at a boundary) still counts as "on the leg that just
  /// arrived," not the next one, since the rider hasn't boarded it yet.
  TripLeg? get currentRailLeg {
    final railLegs = trip.legs
        .where((leg) => leg.mode == TransportMode.commuterRail)
        .toList(growable: false);
    if (railLegs.isEmpty) {
      return null;
    }
    if (railLegs.length == 1) {
      return railLegs.first;
    }
    final boundaries = trip.transferBoundaries;
    for (var i = 0; i < boundaries.length; i += 1) {
      if (currentStationIndex <= boundaries[i].index) {
        return railLegs[i];
      }
    }
    return railLegs.last;
  }
}
