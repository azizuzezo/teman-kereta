// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'transit_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Station _$StationFromJson(Map<String, dynamic> json) => _Station(
  id: json['id'] as String,
  code: json['code'] as String,
  name: json['name'] as String,
  latitude: (json['latitude'] as num).toDouble(),
  longitude: (json['longitude'] as num).toDouble(),
  lineIds:
      (json['lineIds'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const <String>[],
  facilities:
      (json['facilities'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      const <String>[],
  wheelchairAccessible: json['wheelchairAccessible'] as bool? ?? false,
);

Map<String, dynamic> _$StationToJson(_Station instance) => <String, dynamic>{
  'id': instance.id,
  'code': instance.code,
  'name': instance.name,
  'latitude': instance.latitude,
  'longitude': instance.longitude,
  'lineIds': instance.lineIds,
  'facilities': instance.facilities,
  'wheelchairAccessible': instance.wheelchairAccessible,
};

_Departure _$DepartureFromJson(Map<String, dynamic> json) => _Departure(
  id: json['id'] as String,
  stationId: json['stationId'] as String,
  destination: json['destination'] as String,
  lineName: json['lineName'] as String,
  scheduledAt: DateTime.parse(json['scheduledAt'] as String),
  expectedAt: DateTime.parse(json['expectedAt'] as String),
  freshness: $enumDecode(_$DataFreshnessEnumMap, json['freshness']),
  sourceLabel: json['sourceLabel'] as String,
  platform: json['platform'] as String?,
  tripNumber: json['tripNumber'] as String?,
  isDemo: json['isDemo'] as bool? ?? false,
);

Map<String, dynamic> _$DepartureToJson(_Departure instance) =>
    <String, dynamic>{
      'id': instance.id,
      'stationId': instance.stationId,
      'destination': instance.destination,
      'lineName': instance.lineName,
      'scheduledAt': instance.scheduledAt.toIso8601String(),
      'expectedAt': instance.expectedAt.toIso8601String(),
      'freshness': _$DataFreshnessEnumMap[instance.freshness]!,
      'sourceLabel': instance.sourceLabel,
      'platform': instance.platform,
      'tripNumber': instance.tripNumber,
      'isDemo': instance.isDemo,
    };

const _$DataFreshnessEnumMap = {
  DataFreshness.realtime: 'realtime',
  DataFreshness.nearRealtime: 'nearRealtime',
  DataFreshness.estimated: 'estimated',
  DataFreshness.unavailable: 'unavailable',
};

_TripLeg _$TripLegFromJson(Map<String, dynamic> json) => _TripLeg(
  id: json['id'] as String,
  mode: $enumDecode(_$TransportModeEnumMap, json['mode']),
  originName: json['originName'] as String,
  destinationName: json['destinationName'] as String,
  departureAt: DateTime.parse(json['departureAt'] as String),
  arrivalAt: DateTime.parse(json['arrivalAt'] as String),
  lineName: json['lineName'] as String?,
  headsign: json['headsign'] as String?,
  stationIds:
      (json['stationIds'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      const <String>[],
  walkingMeters: (json['walkingMeters'] as num?)?.toInt() ?? 0,
  transferInstruction: json['transferInstruction'] as String?,
  externalTripId: json['externalTripId'] as String?,
  serviceDate: json['serviceDate'] == null
      ? null
      : DateTime.parse(json['serviceDate'] as String),
);

Map<String, dynamic> _$TripLegToJson(_TripLeg instance) => <String, dynamic>{
  'id': instance.id,
  'mode': _$TransportModeEnumMap[instance.mode]!,
  'originName': instance.originName,
  'destinationName': instance.destinationName,
  'departureAt': instance.departureAt.toIso8601String(),
  'arrivalAt': instance.arrivalAt.toIso8601String(),
  'lineName': instance.lineName,
  'headsign': instance.headsign,
  'stationIds': instance.stationIds,
  'walkingMeters': instance.walkingMeters,
  'transferInstruction': instance.transferInstruction,
  'externalTripId': instance.externalTripId,
  'serviceDate': instance.serviceDate?.toIso8601String(),
};

const _$TransportModeEnumMap = {
  TransportMode.walk: 'walk',
  TransportMode.commuterRail: 'commuterRail',
  TransportMode.mrt: 'mrt',
  TransportMode.lrt: 'lrt',
  TransportMode.bus: 'bus',
  TransportMode.bicycle: 'bicycle',
  TransportMode.rideHailing: 'rideHailing',
};

_TransitTrip _$TransitTripFromJson(Map<String, dynamic> json) => _TransitTrip(
  id: json['id'] as String,
  originStationId: json['originStationId'] as String,
  destinationStationId: json['destinationStationId'] as String,
  departureAt: DateTime.parse(json['departureAt'] as String),
  arrivalAt: DateTime.parse(json['arrivalAt'] as String),
  legs: (json['legs'] as List<dynamic>)
      .map((e) => TripLeg.fromJson(e as Map<String, dynamic>))
      .toList(),
  freshness: $enumDecode(_$DataFreshnessEnumMap, json['freshness']),
  sourceLabel: json['sourceLabel'] as String,
  updatedAt: DateTime.parse(json['updatedAt'] as String),
  transfers: (json['transfers'] as num?)?.toInt() ?? 0,
  walkingMeters: (json['walkingMeters'] as num?)?.toInt() ?? 0,
  estimatedFare: (json['estimatedFare'] as num?)?.toInt() ?? 0,
  isDemo: json['isDemo'] as bool? ?? false,
  serviceStatus:
      $enumDecodeNullable(_$ServiceStatusEnumMap, json['serviceStatus']) ??
      ServiceStatus.normal,
);

Map<String, dynamic> _$TransitTripToJson(_TransitTrip instance) =>
    <String, dynamic>{
      'id': instance.id,
      'originStationId': instance.originStationId,
      'destinationStationId': instance.destinationStationId,
      'departureAt': instance.departureAt.toIso8601String(),
      'arrivalAt': instance.arrivalAt.toIso8601String(),
      'legs': instance.legs,
      'freshness': _$DataFreshnessEnumMap[instance.freshness]!,
      'sourceLabel': instance.sourceLabel,
      'updatedAt': instance.updatedAt.toIso8601String(),
      'transfers': instance.transfers,
      'walkingMeters': instance.walkingMeters,
      'estimatedFare': instance.estimatedFare,
      'isDemo': instance.isDemo,
      'serviceStatus': _$ServiceStatusEnumMap[instance.serviceStatus]!,
    };

const _$ServiceStatusEnumMap = {
  ServiceStatus.normal: 'normal',
  ServiceStatus.delayed: 'delayed',
  ServiceStatus.limited: 'limited',
  ServiceStatus.disrupted: 'disrupted',
  ServiceStatus.unavailable: 'unavailable',
};

_VehiclePosition _$VehiclePositionFromJson(Map<String, dynamic> json) =>
    _VehiclePosition(
      id: json['id'] as String,
      tripId: json['tripId'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      recordedAt: DateTime.parse(json['recordedAt'] as String),
      freshness: $enumDecode(_$DataFreshnessEnumMap, json['freshness']),
      sourceLabel: json['sourceLabel'] as String,
      previousStationId: json['previousStationId'] as String?,
      nextStationId: json['nextStationId'] as String?,
      bearing: (json['bearing'] as num?)?.toDouble(),
      speedMetersPerSecond: (json['speedMetersPerSecond'] as num?)?.toDouble(),
      isDemo: json['isDemo'] as bool? ?? false,
    );

Map<String, dynamic> _$VehiclePositionToJson(_VehiclePosition instance) =>
    <String, dynamic>{
      'id': instance.id,
      'tripId': instance.tripId,
      'latitude': instance.latitude,
      'longitude': instance.longitude,
      'recordedAt': instance.recordedAt.toIso8601String(),
      'freshness': _$DataFreshnessEnumMap[instance.freshness]!,
      'sourceLabel': instance.sourceLabel,
      'previousStationId': instance.previousStationId,
      'nextStationId': instance.nextStationId,
      'bearing': instance.bearing,
      'speedMetersPerSecond': instance.speedMetersPerSecond,
      'isDemo': instance.isDemo,
    };

_ServiceAlert _$ServiceAlertFromJson(Map<String, dynamic> json) =>
    _ServiceAlert(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      status: $enumDecode(_$ServiceStatusEnumMap, json['status']),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      sourceLabel: json['sourceLabel'] as String,
      lineId: json['lineId'] as String?,
      isOfficial: json['isOfficial'] as bool? ?? false,
      isDemo: json['isDemo'] as bool? ?? false,
    );

Map<String, dynamic> _$ServiceAlertToJson(_ServiceAlert instance) =>
    <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'description': instance.description,
      'status': _$ServiceStatusEnumMap[instance.status]!,
      'updatedAt': instance.updatedAt.toIso8601String(),
      'sourceLabel': instance.sourceLabel,
      'lineId': instance.lineId,
      'isOfficial': instance.isOfficial,
      'isDemo': instance.isDemo,
    };

_NearbyPlace _$NearbyPlaceFromJson(Map<String, dynamic> json) => _NearbyPlace(
  id: json['id'] as String,
  stationId: json['stationId'] as String,
  name: json['name'] as String,
  category: json['category'] as String,
  distanceMeters: (json['distanceMeters'] as num).toInt(),
  walkingMinutes: (json['walkingMinutes'] as num).toInt(),
  description: json['description'] as String,
  sourceLabel: json['sourceLabel'] as String,
  address: json['address'] as String?,
  isDemo: json['isDemo'] as bool? ?? false,
);

Map<String, dynamic> _$NearbyPlaceToJson(_NearbyPlace instance) =>
    <String, dynamic>{
      'id': instance.id,
      'stationId': instance.stationId,
      'name': instance.name,
      'category': instance.category,
      'distanceMeters': instance.distanceMeters,
      'walkingMinutes': instance.walkingMinutes,
      'description': instance.description,
      'sourceLabel': instance.sourceLabel,
      'address': instance.address,
      'isDemo': instance.isDemo,
    };

_TripSearchQuery _$TripSearchQueryFromJson(Map<String, dynamic> json) =>
    _TripSearchQuery(
      originStationId: json['originStationId'] as String,
      destinationStationId: json['destinationStationId'] as String,
      departureAt: DateTime.parse(json['departureAt'] as String),
      maximumTransfers: (json['maximumTransfers'] as num?)?.toInt() ?? 2,
      includeWalking: json['includeWalking'] as bool? ?? true,
    );

Map<String, dynamic> _$TripSearchQueryToJson(_TripSearchQuery instance) =>
    <String, dynamic>{
      'originStationId': instance.originStationId,
      'destinationStationId': instance.destinationStationId,
      'departureAt': instance.departureAt.toIso8601String(),
      'maximumTransfers': instance.maximumTransfers,
      'includeWalking': instance.includeWalking,
    };

_PlaceFilter _$PlaceFilterFromJson(Map<String, dynamic> json) => _PlaceFilter(
  stationId: json['stationId'] as String?,
  category: json['category'] as String?,
  radiusMeters: (json['radiusMeters'] as num?)?.toInt() ?? 1500,
);

Map<String, dynamic> _$PlaceFilterToJson(_PlaceFilter instance) =>
    <String, dynamic>{
      'stationId': instance.stationId,
      'category': instance.category,
      'radiusMeters': instance.radiusMeters,
    };
