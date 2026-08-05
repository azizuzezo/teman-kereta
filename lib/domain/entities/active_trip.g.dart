// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'active_trip.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ActiveTripSession _$ActiveTripSessionFromJson(Map<String, dynamic> json) =>
    _ActiveTripSession(
      id: json['id'] as String,
      trip: TransitTrip.fromJson(json['trip'] as Map<String, dynamic>),
      state: $enumDecode(_$ActiveTripStateEnumMap, json['state']),
      currentStationIndex: (json['currentStationIndex'] as num).toInt(),
      startedAt: DateTime.parse(json['startedAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      confidenceScore: (json['confidenceScore'] as num?)?.toInt() ?? 100,
      lowBatteryMode: json['lowBatteryMode'] as bool? ?? false,
      confirmedByUser: json['confirmedByUser'] as bool? ?? false,
    );

Map<String, dynamic> _$ActiveTripSessionToJson(_ActiveTripSession instance) =>
    <String, dynamic>{
      'id': instance.id,
      'trip': instance.trip,
      'state': _$ActiveTripStateEnumMap[instance.state]!,
      'currentStationIndex': instance.currentStationIndex,
      'startedAt': instance.startedAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
      'confidenceScore': instance.confidenceScore,
      'lowBatteryMode': instance.lowBatteryMode,
      'confirmedByUser': instance.confirmedByUser,
    };

const _$ActiveTripStateEnumMap = {
  ActiveTripState.idle: 'idle',
  ActiveTripState.nearStation: 'nearStation',
  ActiveTripState.atStation: 'atStation',
  ActiveTripState.possibleBoarding: 'possibleBoarding',
  ActiveTripState.confirmingTrip: 'confirmingTrip',
  ActiveTripState.onBoard: 'onBoard',
  ActiveTripState.approachingTransfer: 'approachingTransfer',
  ActiveTripState.transferring: 'transferring',
  ActiveTripState.approachingDestination: 'approachingDestination',
  ActiveTripState.arrived: 'arrived',
  ActiveTripState.missedDestination: 'missedDestination',
  ActiveTripState.completed: 'completed',
  ActiveTripState.cancelled: 'cancelled',
};
