import 'package:freezed_annotation/freezed_annotation.dart';

part 'transit_models.freezed.dart';
part 'transit_models.g.dart';

enum DataFreshness { realtime, nearRealtime, estimated, unavailable }

enum TransportMode { walk, commuterRail, mrt, lrt, bus, bicycle, rideHailing }

enum ServiceStatus { normal, delayed, limited, disrupted, unavailable }

@freezed
abstract class Station with _$Station {
  const factory Station({
    required String id,
    required String code,
    required String name,
    required double latitude,
    required double longitude,
    @Default(<String>[]) List<String> lineIds,
    @Default(<String>[]) List<String> facilities,
    @Default(false) bool wheelchairAccessible,
  }) = _Station;

  factory Station.fromJson(Map<String, Object?> json) =>
      _$StationFromJson(json);
}

@freezed
abstract class Departure with _$Departure {
  const factory Departure({
    required String id,
    required String stationId,
    required String destination,
    required String lineName,
    required DateTime scheduledAt,
    required DateTime expectedAt,
    required DataFreshness freshness,
    required String sourceLabel,
    String? platform,
    String? tripNumber,
    @Default(false) bool isDemo,
  }) = _Departure;

  factory Departure.fromJson(Map<String, Object?> json) =>
      _$DepartureFromJson(json);
}

@freezed
abstract class TripLeg with _$TripLeg {
  const factory TripLeg({
    required String id,
    required TransportMode mode,
    required String originName,
    required String destinationName,
    required DateTime departureAt,
    required DateTime arrivalAt,
    String? lineName,
    String? headsign,
    @Default(<String>[]) List<String> stationIds,
    @Default(0) int walkingMeters,
    String? transferInstruction,
    // The raw GTFS trip_id + service date backing this leg's physical
    // vehicle, when the originating provider actually has one (real feed
    // data, not Data Demo/mock) — the shared identifier crowd-sourced
    // position reports key off, since it's the one thing every provider
    // (`gtfs`/`local_supabase`) agrees on regardless of which one is
    // active. Null for mock/demo legs, which never report a position.
    String? externalTripId,
    DateTime? serviceDate,
  }) = _TripLeg;

  factory TripLeg.fromJson(Map<String, Object?> json) =>
      _$TripLegFromJson(json);
}

@freezed
abstract class TransitTrip with _$TransitTrip {
  const factory TransitTrip({
    required String id,
    required String originStationId,
    required String destinationStationId,
    required DateTime departureAt,
    required DateTime arrivalAt,
    required List<TripLeg> legs,
    required DataFreshness freshness,
    required String sourceLabel,
    required DateTime updatedAt,
    @Default(0) int transfers,
    @Default(0) int walkingMeters,
    @Default(0) int estimatedFare,
    @Default(false) bool isDemo,
    @Default(ServiceStatus.normal) ServiceStatus serviceStatus,
  }) = _TransitTrip;
  const TransitTrip._();

  factory TransitTrip.fromJson(Map<String, Object?> json) =>
      _$TransitTripFromJson(json);

  int get durationMinutes => arrivalAt.difference(departureAt).inMinutes;

  /// Flattened station sequence across all rail legs. Consecutive duplicate
  /// ids at a transfer junction (the alighting stop of one rail leg is the
  /// same physical stop as the boarding stop of the next) are collapsed to a
  /// single entry so index-based progress tracking doesn't double-count it.
  List<String> get stationIds {
    final ids = <String>[];
    for (final leg in legs) {
      if (leg.mode != TransportMode.commuterRail) {
        continue;
      }
      for (final id in leg.stationIds) {
        if (ids.isNotEmpty && ids.last == id) {
          continue;
        }
        ids.add(id);
      }
    }
    return ids;
  }

  /// Positions (in [stationIds]) where the user must alight and board a
  /// different rail leg. Derived from [legs] rather than stored, so it stays
  /// in sync with the trip's actual leg composition.
  List<TransferBoundary> get transferBoundaries {
    final railLegs = legs
        .where((leg) => leg.mode == TransportMode.commuterRail)
        .toList(growable: false);
    if (railLegs.length < 2) {
      return const <TransferBoundary>[];
    }

    final ids = stationIds;
    final boundaries = <TransferBoundary>[];
    for (var i = 0; i < railLegs.length - 1; i += 1) {
      final leg = railLegs[i];
      if (leg.stationIds.isEmpty) {
        continue;
      }
      final index = ids.indexOf(leg.stationIds.last);
      if (index < 0) {
        continue;
      }
      boundaries.add(
        TransferBoundary(
          index: index,
          fromLineName: leg.lineName,
          toLineName: railLegs[i + 1].lineName,
          instruction: leg.transferInstruction,
        ),
      );
    }
    return boundaries;
  }
}

class TransferBoundary {
  const TransferBoundary({
    required this.index,
    this.fromLineName,
    this.toLineName,
    this.instruction,
  });

  /// Index into [TransitTrip.stationIds] of the shared transfer station.
  final int index;
  final String? fromLineName;
  final String? toLineName;
  final String? instruction;
}

@freezed
abstract class VehiclePosition with _$VehiclePosition {
  const factory VehiclePosition({
    required String id,
    required String tripId,
    required double latitude,
    required double longitude,
    required DateTime recordedAt,
    required DataFreshness freshness,
    required String sourceLabel,
    String? previousStationId,
    String? nextStationId,
    double? bearing,
    double? speedMetersPerSecond,
    @Default(false) bool isDemo,
  }) = _VehiclePosition;

  factory VehiclePosition.fromJson(Map<String, Object?> json) =>
      _$VehiclePositionFromJson(json);
}

@freezed
abstract class ServiceAlert with _$ServiceAlert {
  const factory ServiceAlert({
    required String id,
    required String title,
    required String description,
    required ServiceStatus status,
    required DateTime updatedAt,
    required String sourceLabel,
    String? lineId,
    @Default(false) bool isOfficial,
    @Default(false) bool isDemo,
  }) = _ServiceAlert;

  factory ServiceAlert.fromJson(Map<String, Object?> json) =>
      _$ServiceAlertFromJson(json);
}

@freezed
abstract class NearbyPlace with _$NearbyPlace {
  const factory NearbyPlace({
    required String id,
    required String stationId,
    required String name,
    required String category,
    required int distanceMeters,
    required int walkingMinutes,
    required String description,
    required String sourceLabel,
    String? address,
    @Default(false) bool isDemo,
  }) = _NearbyPlace;

  factory NearbyPlace.fromJson(Map<String, Object?> json) =>
      _$NearbyPlaceFromJson(json);
}

@freezed
abstract class TripSearchQuery with _$TripSearchQuery {
  const factory TripSearchQuery({
    required String originStationId,
    required String destinationStationId,
    required DateTime departureAt,
    @Default(2) int maximumTransfers,
    @Default(true) bool includeWalking,
  }) = _TripSearchQuery;

  factory TripSearchQuery.fromJson(Map<String, Object?> json) =>
      _$TripSearchQueryFromJson(json);
}

@freezed
abstract class PlaceFilter with _$PlaceFilter {
  const factory PlaceFilter({
    String? stationId,
    String? category,
    @Default(1500) int radiusMeters,
  }) = _PlaceFilter;

  factory PlaceFilter.fromJson(Map<String, Object?> json) =>
      _$PlaceFilterFromJson(json);
}
