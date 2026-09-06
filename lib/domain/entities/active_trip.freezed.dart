// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'active_trip.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ActiveTripSession {

 String get id; TransitTrip get trip; ActiveTripState get state; int get currentStationIndex; DateTime get startedAt; DateTime get updatedAt; int get confidenceScore; bool get lowBatteryMode; bool get confirmedByUser;// Cumulative straight-line distance covered so far, summed hop-by-hop
// from station coordinates as `currentStationIndex` advances — there's
// no track-shape/polyline data to follow the rail curve exactly.
 double get distanceMeters;// Best-known current speed in km/h: refreshed either from a real GPS fix
// (see `CrowdPositionReporter`) or, lacking one, from the previous
// hop's distance/time as a stand-in "train speed" reading. Null until
// the first hop or GPS fix is available.
 double? get currentSpeedKmh;// Optional free-text final destination (address/place name) beyond the
// destination station itself, entered by the user before starting the
// trip. Carried through to the arrived/complete screen so it can offer
// a "Buka di Google Maps ke [tujuan]" button via
// `launchMapDirectionsToQuery` — Google Maps' own geocoder resolves it,
// this app never geocodes addresses itself.
 String? get finalDestinationQuery;
/// Create a copy of ActiveTripSession
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ActiveTripSessionCopyWith<ActiveTripSession> get copyWith => _$ActiveTripSessionCopyWithImpl<ActiveTripSession>(this as ActiveTripSession, _$identity);

  /// Serializes this ActiveTripSession to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ActiveTripSession&&(identical(other.id, id) || other.id == id)&&(identical(other.trip, trip) || other.trip == trip)&&(identical(other.state, state) || other.state == state)&&(identical(other.currentStationIndex, currentStationIndex) || other.currentStationIndex == currentStationIndex)&&(identical(other.startedAt, startedAt) || other.startedAt == startedAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.confidenceScore, confidenceScore) || other.confidenceScore == confidenceScore)&&(identical(other.lowBatteryMode, lowBatteryMode) || other.lowBatteryMode == lowBatteryMode)&&(identical(other.confirmedByUser, confirmedByUser) || other.confirmedByUser == confirmedByUser)&&(identical(other.distanceMeters, distanceMeters) || other.distanceMeters == distanceMeters)&&(identical(other.currentSpeedKmh, currentSpeedKmh) || other.currentSpeedKmh == currentSpeedKmh)&&(identical(other.finalDestinationQuery, finalDestinationQuery) || other.finalDestinationQuery == finalDestinationQuery));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,trip,state,currentStationIndex,startedAt,updatedAt,confidenceScore,lowBatteryMode,confirmedByUser,distanceMeters,currentSpeedKmh,finalDestinationQuery);

@override
String toString() {
  return 'ActiveTripSession(id: $id, trip: $trip, state: $state, currentStationIndex: $currentStationIndex, startedAt: $startedAt, updatedAt: $updatedAt, confidenceScore: $confidenceScore, lowBatteryMode: $lowBatteryMode, confirmedByUser: $confirmedByUser, distanceMeters: $distanceMeters, currentSpeedKmh: $currentSpeedKmh, finalDestinationQuery: $finalDestinationQuery)';
}


}

/// @nodoc
abstract mixin class $ActiveTripSessionCopyWith<$Res>  {
  factory $ActiveTripSessionCopyWith(ActiveTripSession value, $Res Function(ActiveTripSession) _then) = _$ActiveTripSessionCopyWithImpl;
@useResult
$Res call({
 String id, TransitTrip trip, ActiveTripState state, int currentStationIndex, DateTime startedAt, DateTime updatedAt, int confidenceScore, bool lowBatteryMode, bool confirmedByUser, double distanceMeters, double? currentSpeedKmh, String? finalDestinationQuery
});


$TransitTripCopyWith<$Res> get trip;

}
/// @nodoc
class _$ActiveTripSessionCopyWithImpl<$Res>
    implements $ActiveTripSessionCopyWith<$Res> {
  _$ActiveTripSessionCopyWithImpl(this._self, this._then);

  final ActiveTripSession _self;
  final $Res Function(ActiveTripSession) _then;

/// Create a copy of ActiveTripSession
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? trip = null,Object? state = null,Object? currentStationIndex = null,Object? startedAt = null,Object? updatedAt = null,Object? confidenceScore = null,Object? lowBatteryMode = null,Object? confirmedByUser = null,Object? distanceMeters = null,Object? currentSpeedKmh = freezed,Object? finalDestinationQuery = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,trip: null == trip ? _self.trip : trip // ignore: cast_nullable_to_non_nullable
as TransitTrip,state: null == state ? _self.state : state // ignore: cast_nullable_to_non_nullable
as ActiveTripState,currentStationIndex: null == currentStationIndex ? _self.currentStationIndex : currentStationIndex // ignore: cast_nullable_to_non_nullable
as int,startedAt: null == startedAt ? _self.startedAt : startedAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,confidenceScore: null == confidenceScore ? _self.confidenceScore : confidenceScore // ignore: cast_nullable_to_non_nullable
as int,lowBatteryMode: null == lowBatteryMode ? _self.lowBatteryMode : lowBatteryMode // ignore: cast_nullable_to_non_nullable
as bool,confirmedByUser: null == confirmedByUser ? _self.confirmedByUser : confirmedByUser // ignore: cast_nullable_to_non_nullable
as bool,distanceMeters: null == distanceMeters ? _self.distanceMeters : distanceMeters // ignore: cast_nullable_to_non_nullable
as double,currentSpeedKmh: freezed == currentSpeedKmh ? _self.currentSpeedKmh : currentSpeedKmh // ignore: cast_nullable_to_non_nullable
as double?,finalDestinationQuery: freezed == finalDestinationQuery ? _self.finalDestinationQuery : finalDestinationQuery // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}
/// Create a copy of ActiveTripSession
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TransitTripCopyWith<$Res> get trip {
  
  return $TransitTripCopyWith<$Res>(_self.trip, (value) {
    return _then(_self.copyWith(trip: value));
  });
}
}


/// Adds pattern-matching-related methods to [ActiveTripSession].
extension ActiveTripSessionPatterns on ActiveTripSession {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ActiveTripSession value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ActiveTripSession() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ActiveTripSession value)  $default,){
final _that = this;
switch (_that) {
case _ActiveTripSession():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ActiveTripSession value)?  $default,){
final _that = this;
switch (_that) {
case _ActiveTripSession() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  TransitTrip trip,  ActiveTripState state,  int currentStationIndex,  DateTime startedAt,  DateTime updatedAt,  int confidenceScore,  bool lowBatteryMode,  bool confirmedByUser,  double distanceMeters,  double? currentSpeedKmh,  String? finalDestinationQuery)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ActiveTripSession() when $default != null:
return $default(_that.id,_that.trip,_that.state,_that.currentStationIndex,_that.startedAt,_that.updatedAt,_that.confidenceScore,_that.lowBatteryMode,_that.confirmedByUser,_that.distanceMeters,_that.currentSpeedKmh,_that.finalDestinationQuery);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  TransitTrip trip,  ActiveTripState state,  int currentStationIndex,  DateTime startedAt,  DateTime updatedAt,  int confidenceScore,  bool lowBatteryMode,  bool confirmedByUser,  double distanceMeters,  double? currentSpeedKmh,  String? finalDestinationQuery)  $default,) {final _that = this;
switch (_that) {
case _ActiveTripSession():
return $default(_that.id,_that.trip,_that.state,_that.currentStationIndex,_that.startedAt,_that.updatedAt,_that.confidenceScore,_that.lowBatteryMode,_that.confirmedByUser,_that.distanceMeters,_that.currentSpeedKmh,_that.finalDestinationQuery);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  TransitTrip trip,  ActiveTripState state,  int currentStationIndex,  DateTime startedAt,  DateTime updatedAt,  int confidenceScore,  bool lowBatteryMode,  bool confirmedByUser,  double distanceMeters,  double? currentSpeedKmh,  String? finalDestinationQuery)?  $default,) {final _that = this;
switch (_that) {
case _ActiveTripSession() when $default != null:
return $default(_that.id,_that.trip,_that.state,_that.currentStationIndex,_that.startedAt,_that.updatedAt,_that.confidenceScore,_that.lowBatteryMode,_that.confirmedByUser,_that.distanceMeters,_that.currentSpeedKmh,_that.finalDestinationQuery);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ActiveTripSession extends ActiveTripSession {
  const _ActiveTripSession({required this.id, required this.trip, required this.state, required this.currentStationIndex, required this.startedAt, required this.updatedAt, this.confidenceScore = 100, this.lowBatteryMode = false, this.confirmedByUser = false, this.distanceMeters = 0, this.currentSpeedKmh, this.finalDestinationQuery}): super._();
  factory _ActiveTripSession.fromJson(Map<String, dynamic> json) => _$ActiveTripSessionFromJson(json);

@override final  String id;
@override final  TransitTrip trip;
@override final  ActiveTripState state;
@override final  int currentStationIndex;
@override final  DateTime startedAt;
@override final  DateTime updatedAt;
@override@JsonKey() final  int confidenceScore;
@override@JsonKey() final  bool lowBatteryMode;
@override@JsonKey() final  bool confirmedByUser;
// Cumulative straight-line distance covered so far, summed hop-by-hop
// from station coordinates as `currentStationIndex` advances — there's
// no track-shape/polyline data to follow the rail curve exactly.
@override@JsonKey() final  double distanceMeters;
// Best-known current speed in km/h: refreshed either from a real GPS fix
// (see `CrowdPositionReporter`) or, lacking one, from the previous
// hop's distance/time as a stand-in "train speed" reading. Null until
// the first hop or GPS fix is available.
@override final  double? currentSpeedKmh;
// Optional free-text final destination (address/place name) beyond the
// destination station itself, entered by the user before starting the
// trip. Carried through to the arrived/complete screen so it can offer
// a "Buka di Google Maps ke [tujuan]" button via
// `launchMapDirectionsToQuery` — Google Maps' own geocoder resolves it,
// this app never geocodes addresses itself.
@override final  String? finalDestinationQuery;

/// Create a copy of ActiveTripSession
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ActiveTripSessionCopyWith<_ActiveTripSession> get copyWith => __$ActiveTripSessionCopyWithImpl<_ActiveTripSession>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ActiveTripSessionToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ActiveTripSession&&(identical(other.id, id) || other.id == id)&&(identical(other.trip, trip) || other.trip == trip)&&(identical(other.state, state) || other.state == state)&&(identical(other.currentStationIndex, currentStationIndex) || other.currentStationIndex == currentStationIndex)&&(identical(other.startedAt, startedAt) || other.startedAt == startedAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.confidenceScore, confidenceScore) || other.confidenceScore == confidenceScore)&&(identical(other.lowBatteryMode, lowBatteryMode) || other.lowBatteryMode == lowBatteryMode)&&(identical(other.confirmedByUser, confirmedByUser) || other.confirmedByUser == confirmedByUser)&&(identical(other.distanceMeters, distanceMeters) || other.distanceMeters == distanceMeters)&&(identical(other.currentSpeedKmh, currentSpeedKmh) || other.currentSpeedKmh == currentSpeedKmh)&&(identical(other.finalDestinationQuery, finalDestinationQuery) || other.finalDestinationQuery == finalDestinationQuery));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,trip,state,currentStationIndex,startedAt,updatedAt,confidenceScore,lowBatteryMode,confirmedByUser,distanceMeters,currentSpeedKmh,finalDestinationQuery);

@override
String toString() {
  return 'ActiveTripSession(id: $id, trip: $trip, state: $state, currentStationIndex: $currentStationIndex, startedAt: $startedAt, updatedAt: $updatedAt, confidenceScore: $confidenceScore, lowBatteryMode: $lowBatteryMode, confirmedByUser: $confirmedByUser, distanceMeters: $distanceMeters, currentSpeedKmh: $currentSpeedKmh, finalDestinationQuery: $finalDestinationQuery)';
}


}

/// @nodoc
abstract mixin class _$ActiveTripSessionCopyWith<$Res> implements $ActiveTripSessionCopyWith<$Res> {
  factory _$ActiveTripSessionCopyWith(_ActiveTripSession value, $Res Function(_ActiveTripSession) _then) = __$ActiveTripSessionCopyWithImpl;
@override @useResult
$Res call({
 String id, TransitTrip trip, ActiveTripState state, int currentStationIndex, DateTime startedAt, DateTime updatedAt, int confidenceScore, bool lowBatteryMode, bool confirmedByUser, double distanceMeters, double? currentSpeedKmh, String? finalDestinationQuery
});


@override $TransitTripCopyWith<$Res> get trip;

}
/// @nodoc
class __$ActiveTripSessionCopyWithImpl<$Res>
    implements _$ActiveTripSessionCopyWith<$Res> {
  __$ActiveTripSessionCopyWithImpl(this._self, this._then);

  final _ActiveTripSession _self;
  final $Res Function(_ActiveTripSession) _then;

/// Create a copy of ActiveTripSession
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? trip = null,Object? state = null,Object? currentStationIndex = null,Object? startedAt = null,Object? updatedAt = null,Object? confidenceScore = null,Object? lowBatteryMode = null,Object? confirmedByUser = null,Object? distanceMeters = null,Object? currentSpeedKmh = freezed,Object? finalDestinationQuery = freezed,}) {
  return _then(_ActiveTripSession(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,trip: null == trip ? _self.trip : trip // ignore: cast_nullable_to_non_nullable
as TransitTrip,state: null == state ? _self.state : state // ignore: cast_nullable_to_non_nullable
as ActiveTripState,currentStationIndex: null == currentStationIndex ? _self.currentStationIndex : currentStationIndex // ignore: cast_nullable_to_non_nullable
as int,startedAt: null == startedAt ? _self.startedAt : startedAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,confidenceScore: null == confidenceScore ? _self.confidenceScore : confidenceScore // ignore: cast_nullable_to_non_nullable
as int,lowBatteryMode: null == lowBatteryMode ? _self.lowBatteryMode : lowBatteryMode // ignore: cast_nullable_to_non_nullable
as bool,confirmedByUser: null == confirmedByUser ? _self.confirmedByUser : confirmedByUser // ignore: cast_nullable_to_non_nullable
as bool,distanceMeters: null == distanceMeters ? _self.distanceMeters : distanceMeters // ignore: cast_nullable_to_non_nullable
as double,currentSpeedKmh: freezed == currentSpeedKmh ? _self.currentSpeedKmh : currentSpeedKmh // ignore: cast_nullable_to_non_nullable
as double?,finalDestinationQuery: freezed == finalDestinationQuery ? _self.finalDestinationQuery : finalDestinationQuery // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

/// Create a copy of ActiveTripSession
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TransitTripCopyWith<$Res> get trip {
  
  return $TransitTripCopyWith<$Res>(_self.trip, (value) {
    return _then(_self.copyWith(trip: value));
  });
}
}

// dart format on
