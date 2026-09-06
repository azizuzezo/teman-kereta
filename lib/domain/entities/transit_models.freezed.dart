// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'transit_models.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Station {

 String get id; String get code; String get name; double get latitude; double get longitude; List<String> get lineIds; List<String> get facilities; bool get wheelchairAccessible;// Per-line stop order (`{lineCode: stopOrder}`), used to draw each
// line's real geographic polyline in station-sequence order on the live
// map. Only `SupabaseTransitProvider` populates this from the
// `station_lines` join's `stop_order` column — every other provider
// (mock/demo/GTFS importer) defaults to empty, since they don't need
// route-accurate map rendering.
 Map<String, int> get stopOrderByLine;
/// Create a copy of Station
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$StationCopyWith<Station> get copyWith => _$StationCopyWithImpl<Station>(this as Station, _$identity);

  /// Serializes this Station to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Station&&(identical(other.id, id) || other.id == id)&&(identical(other.code, code) || other.code == code)&&(identical(other.name, name) || other.name == name)&&(identical(other.latitude, latitude) || other.latitude == latitude)&&(identical(other.longitude, longitude) || other.longitude == longitude)&&const DeepCollectionEquality().equals(other.lineIds, lineIds)&&const DeepCollectionEquality().equals(other.facilities, facilities)&&(identical(other.wheelchairAccessible, wheelchairAccessible) || other.wheelchairAccessible == wheelchairAccessible)&&const DeepCollectionEquality().equals(other.stopOrderByLine, stopOrderByLine));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,code,name,latitude,longitude,const DeepCollectionEquality().hash(lineIds),const DeepCollectionEquality().hash(facilities),wheelchairAccessible,const DeepCollectionEquality().hash(stopOrderByLine));

@override
String toString() {
  return 'Station(id: $id, code: $code, name: $name, latitude: $latitude, longitude: $longitude, lineIds: $lineIds, facilities: $facilities, wheelchairAccessible: $wheelchairAccessible, stopOrderByLine: $stopOrderByLine)';
}


}

/// @nodoc
abstract mixin class $StationCopyWith<$Res>  {
  factory $StationCopyWith(Station value, $Res Function(Station) _then) = _$StationCopyWithImpl;
@useResult
$Res call({
 String id, String code, String name, double latitude, double longitude, List<String> lineIds, List<String> facilities, bool wheelchairAccessible, Map<String, int> stopOrderByLine
});




}
/// @nodoc
class _$StationCopyWithImpl<$Res>
    implements $StationCopyWith<$Res> {
  _$StationCopyWithImpl(this._self, this._then);

  final Station _self;
  final $Res Function(Station) _then;

/// Create a copy of Station
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? code = null,Object? name = null,Object? latitude = null,Object? longitude = null,Object? lineIds = null,Object? facilities = null,Object? wheelchairAccessible = null,Object? stopOrderByLine = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,code: null == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,latitude: null == latitude ? _self.latitude : latitude // ignore: cast_nullable_to_non_nullable
as double,longitude: null == longitude ? _self.longitude : longitude // ignore: cast_nullable_to_non_nullable
as double,lineIds: null == lineIds ? _self.lineIds : lineIds // ignore: cast_nullable_to_non_nullable
as List<String>,facilities: null == facilities ? _self.facilities : facilities // ignore: cast_nullable_to_non_nullable
as List<String>,wheelchairAccessible: null == wheelchairAccessible ? _self.wheelchairAccessible : wheelchairAccessible // ignore: cast_nullable_to_non_nullable
as bool,stopOrderByLine: null == stopOrderByLine ? _self.stopOrderByLine : stopOrderByLine // ignore: cast_nullable_to_non_nullable
as Map<String, int>,
  ));
}

}


/// Adds pattern-matching-related methods to [Station].
extension StationPatterns on Station {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Station value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Station() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Station value)  $default,){
final _that = this;
switch (_that) {
case _Station():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Station value)?  $default,){
final _that = this;
switch (_that) {
case _Station() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String code,  String name,  double latitude,  double longitude,  List<String> lineIds,  List<String> facilities,  bool wheelchairAccessible,  Map<String, int> stopOrderByLine)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Station() when $default != null:
return $default(_that.id,_that.code,_that.name,_that.latitude,_that.longitude,_that.lineIds,_that.facilities,_that.wheelchairAccessible,_that.stopOrderByLine);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String code,  String name,  double latitude,  double longitude,  List<String> lineIds,  List<String> facilities,  bool wheelchairAccessible,  Map<String, int> stopOrderByLine)  $default,) {final _that = this;
switch (_that) {
case _Station():
return $default(_that.id,_that.code,_that.name,_that.latitude,_that.longitude,_that.lineIds,_that.facilities,_that.wheelchairAccessible,_that.stopOrderByLine);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String code,  String name,  double latitude,  double longitude,  List<String> lineIds,  List<String> facilities,  bool wheelchairAccessible,  Map<String, int> stopOrderByLine)?  $default,) {final _that = this;
switch (_that) {
case _Station() when $default != null:
return $default(_that.id,_that.code,_that.name,_that.latitude,_that.longitude,_that.lineIds,_that.facilities,_that.wheelchairAccessible,_that.stopOrderByLine);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Station implements Station {
  const _Station({required this.id, required this.code, required this.name, required this.latitude, required this.longitude, final  List<String> lineIds = const <String>[], final  List<String> facilities = const <String>[], this.wheelchairAccessible = false, final  Map<String, int> stopOrderByLine = const <String, int>{}}): _lineIds = lineIds,_facilities = facilities,_stopOrderByLine = stopOrderByLine;
  factory _Station.fromJson(Map<String, dynamic> json) => _$StationFromJson(json);

@override final  String id;
@override final  String code;
@override final  String name;
@override final  double latitude;
@override final  double longitude;
 final  List<String> _lineIds;
@override@JsonKey() List<String> get lineIds {
  if (_lineIds is EqualUnmodifiableListView) return _lineIds;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_lineIds);
}

 final  List<String> _facilities;
@override@JsonKey() List<String> get facilities {
  if (_facilities is EqualUnmodifiableListView) return _facilities;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_facilities);
}

@override@JsonKey() final  bool wheelchairAccessible;
// Per-line stop order (`{lineCode: stopOrder}`), used to draw each
// line's real geographic polyline in station-sequence order on the live
// map. Only `SupabaseTransitProvider` populates this from the
// `station_lines` join's `stop_order` column — every other provider
// (mock/demo/GTFS importer) defaults to empty, since they don't need
// route-accurate map rendering.
 final  Map<String, int> _stopOrderByLine;
// Per-line stop order (`{lineCode: stopOrder}`), used to draw each
// line's real geographic polyline in station-sequence order on the live
// map. Only `SupabaseTransitProvider` populates this from the
// `station_lines` join's `stop_order` column — every other provider
// (mock/demo/GTFS importer) defaults to empty, since they don't need
// route-accurate map rendering.
@override@JsonKey() Map<String, int> get stopOrderByLine {
  if (_stopOrderByLine is EqualUnmodifiableMapView) return _stopOrderByLine;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_stopOrderByLine);
}


/// Create a copy of Station
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$StationCopyWith<_Station> get copyWith => __$StationCopyWithImpl<_Station>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$StationToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Station&&(identical(other.id, id) || other.id == id)&&(identical(other.code, code) || other.code == code)&&(identical(other.name, name) || other.name == name)&&(identical(other.latitude, latitude) || other.latitude == latitude)&&(identical(other.longitude, longitude) || other.longitude == longitude)&&const DeepCollectionEquality().equals(other._lineIds, _lineIds)&&const DeepCollectionEquality().equals(other._facilities, _facilities)&&(identical(other.wheelchairAccessible, wheelchairAccessible) || other.wheelchairAccessible == wheelchairAccessible)&&const DeepCollectionEquality().equals(other._stopOrderByLine, _stopOrderByLine));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,code,name,latitude,longitude,const DeepCollectionEquality().hash(_lineIds),const DeepCollectionEquality().hash(_facilities),wheelchairAccessible,const DeepCollectionEquality().hash(_stopOrderByLine));

@override
String toString() {
  return 'Station(id: $id, code: $code, name: $name, latitude: $latitude, longitude: $longitude, lineIds: $lineIds, facilities: $facilities, wheelchairAccessible: $wheelchairAccessible, stopOrderByLine: $stopOrderByLine)';
}


}

/// @nodoc
abstract mixin class _$StationCopyWith<$Res> implements $StationCopyWith<$Res> {
  factory _$StationCopyWith(_Station value, $Res Function(_Station) _then) = __$StationCopyWithImpl;
@override @useResult
$Res call({
 String id, String code, String name, double latitude, double longitude, List<String> lineIds, List<String> facilities, bool wheelchairAccessible, Map<String, int> stopOrderByLine
});




}
/// @nodoc
class __$StationCopyWithImpl<$Res>
    implements _$StationCopyWith<$Res> {
  __$StationCopyWithImpl(this._self, this._then);

  final _Station _self;
  final $Res Function(_Station) _then;

/// Create a copy of Station
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? code = null,Object? name = null,Object? latitude = null,Object? longitude = null,Object? lineIds = null,Object? facilities = null,Object? wheelchairAccessible = null,Object? stopOrderByLine = null,}) {
  return _then(_Station(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,code: null == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,latitude: null == latitude ? _self.latitude : latitude // ignore: cast_nullable_to_non_nullable
as double,longitude: null == longitude ? _self.longitude : longitude // ignore: cast_nullable_to_non_nullable
as double,lineIds: null == lineIds ? _self._lineIds : lineIds // ignore: cast_nullable_to_non_nullable
as List<String>,facilities: null == facilities ? _self._facilities : facilities // ignore: cast_nullable_to_non_nullable
as List<String>,wheelchairAccessible: null == wheelchairAccessible ? _self.wheelchairAccessible : wheelchairAccessible // ignore: cast_nullable_to_non_nullable
as bool,stopOrderByLine: null == stopOrderByLine ? _self._stopOrderByLine : stopOrderByLine // ignore: cast_nullable_to_non_nullable
as Map<String, int>,
  ));
}


}


/// @nodoc
mixin _$Departure {

 String get id; String get stationId; String get destination; String get lineName; DateTime get scheduledAt; DateTime get expectedAt; DataFreshness get freshness; String get sourceLabel; String? get platform; String? get tripNumber; bool get isDemo;
/// Create a copy of Departure
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DepartureCopyWith<Departure> get copyWith => _$DepartureCopyWithImpl<Departure>(this as Departure, _$identity);

  /// Serializes this Departure to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Departure&&(identical(other.id, id) || other.id == id)&&(identical(other.stationId, stationId) || other.stationId == stationId)&&(identical(other.destination, destination) || other.destination == destination)&&(identical(other.lineName, lineName) || other.lineName == lineName)&&(identical(other.scheduledAt, scheduledAt) || other.scheduledAt == scheduledAt)&&(identical(other.expectedAt, expectedAt) || other.expectedAt == expectedAt)&&(identical(other.freshness, freshness) || other.freshness == freshness)&&(identical(other.sourceLabel, sourceLabel) || other.sourceLabel == sourceLabel)&&(identical(other.platform, platform) || other.platform == platform)&&(identical(other.tripNumber, tripNumber) || other.tripNumber == tripNumber)&&(identical(other.isDemo, isDemo) || other.isDemo == isDemo));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,stationId,destination,lineName,scheduledAt,expectedAt,freshness,sourceLabel,platform,tripNumber,isDemo);

@override
String toString() {
  return 'Departure(id: $id, stationId: $stationId, destination: $destination, lineName: $lineName, scheduledAt: $scheduledAt, expectedAt: $expectedAt, freshness: $freshness, sourceLabel: $sourceLabel, platform: $platform, tripNumber: $tripNumber, isDemo: $isDemo)';
}


}

/// @nodoc
abstract mixin class $DepartureCopyWith<$Res>  {
  factory $DepartureCopyWith(Departure value, $Res Function(Departure) _then) = _$DepartureCopyWithImpl;
@useResult
$Res call({
 String id, String stationId, String destination, String lineName, DateTime scheduledAt, DateTime expectedAt, DataFreshness freshness, String sourceLabel, String? platform, String? tripNumber, bool isDemo
});




}
/// @nodoc
class _$DepartureCopyWithImpl<$Res>
    implements $DepartureCopyWith<$Res> {
  _$DepartureCopyWithImpl(this._self, this._then);

  final Departure _self;
  final $Res Function(Departure) _then;

/// Create a copy of Departure
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? stationId = null,Object? destination = null,Object? lineName = null,Object? scheduledAt = null,Object? expectedAt = null,Object? freshness = null,Object? sourceLabel = null,Object? platform = freezed,Object? tripNumber = freezed,Object? isDemo = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,stationId: null == stationId ? _self.stationId : stationId // ignore: cast_nullable_to_non_nullable
as String,destination: null == destination ? _self.destination : destination // ignore: cast_nullable_to_non_nullable
as String,lineName: null == lineName ? _self.lineName : lineName // ignore: cast_nullable_to_non_nullable
as String,scheduledAt: null == scheduledAt ? _self.scheduledAt : scheduledAt // ignore: cast_nullable_to_non_nullable
as DateTime,expectedAt: null == expectedAt ? _self.expectedAt : expectedAt // ignore: cast_nullable_to_non_nullable
as DateTime,freshness: null == freshness ? _self.freshness : freshness // ignore: cast_nullable_to_non_nullable
as DataFreshness,sourceLabel: null == sourceLabel ? _self.sourceLabel : sourceLabel // ignore: cast_nullable_to_non_nullable
as String,platform: freezed == platform ? _self.platform : platform // ignore: cast_nullable_to_non_nullable
as String?,tripNumber: freezed == tripNumber ? _self.tripNumber : tripNumber // ignore: cast_nullable_to_non_nullable
as String?,isDemo: null == isDemo ? _self.isDemo : isDemo // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [Departure].
extension DeparturePatterns on Departure {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Departure value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Departure() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Departure value)  $default,){
final _that = this;
switch (_that) {
case _Departure():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Departure value)?  $default,){
final _that = this;
switch (_that) {
case _Departure() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String stationId,  String destination,  String lineName,  DateTime scheduledAt,  DateTime expectedAt,  DataFreshness freshness,  String sourceLabel,  String? platform,  String? tripNumber,  bool isDemo)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Departure() when $default != null:
return $default(_that.id,_that.stationId,_that.destination,_that.lineName,_that.scheduledAt,_that.expectedAt,_that.freshness,_that.sourceLabel,_that.platform,_that.tripNumber,_that.isDemo);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String stationId,  String destination,  String lineName,  DateTime scheduledAt,  DateTime expectedAt,  DataFreshness freshness,  String sourceLabel,  String? platform,  String? tripNumber,  bool isDemo)  $default,) {final _that = this;
switch (_that) {
case _Departure():
return $default(_that.id,_that.stationId,_that.destination,_that.lineName,_that.scheduledAt,_that.expectedAt,_that.freshness,_that.sourceLabel,_that.platform,_that.tripNumber,_that.isDemo);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String stationId,  String destination,  String lineName,  DateTime scheduledAt,  DateTime expectedAt,  DataFreshness freshness,  String sourceLabel,  String? platform,  String? tripNumber,  bool isDemo)?  $default,) {final _that = this;
switch (_that) {
case _Departure() when $default != null:
return $default(_that.id,_that.stationId,_that.destination,_that.lineName,_that.scheduledAt,_that.expectedAt,_that.freshness,_that.sourceLabel,_that.platform,_that.tripNumber,_that.isDemo);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Departure implements Departure {
  const _Departure({required this.id, required this.stationId, required this.destination, required this.lineName, required this.scheduledAt, required this.expectedAt, required this.freshness, required this.sourceLabel, this.platform, this.tripNumber, this.isDemo = false});
  factory _Departure.fromJson(Map<String, dynamic> json) => _$DepartureFromJson(json);

@override final  String id;
@override final  String stationId;
@override final  String destination;
@override final  String lineName;
@override final  DateTime scheduledAt;
@override final  DateTime expectedAt;
@override final  DataFreshness freshness;
@override final  String sourceLabel;
@override final  String? platform;
@override final  String? tripNumber;
@override@JsonKey() final  bool isDemo;

/// Create a copy of Departure
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DepartureCopyWith<_Departure> get copyWith => __$DepartureCopyWithImpl<_Departure>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$DepartureToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Departure&&(identical(other.id, id) || other.id == id)&&(identical(other.stationId, stationId) || other.stationId == stationId)&&(identical(other.destination, destination) || other.destination == destination)&&(identical(other.lineName, lineName) || other.lineName == lineName)&&(identical(other.scheduledAt, scheduledAt) || other.scheduledAt == scheduledAt)&&(identical(other.expectedAt, expectedAt) || other.expectedAt == expectedAt)&&(identical(other.freshness, freshness) || other.freshness == freshness)&&(identical(other.sourceLabel, sourceLabel) || other.sourceLabel == sourceLabel)&&(identical(other.platform, platform) || other.platform == platform)&&(identical(other.tripNumber, tripNumber) || other.tripNumber == tripNumber)&&(identical(other.isDemo, isDemo) || other.isDemo == isDemo));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,stationId,destination,lineName,scheduledAt,expectedAt,freshness,sourceLabel,platform,tripNumber,isDemo);

@override
String toString() {
  return 'Departure(id: $id, stationId: $stationId, destination: $destination, lineName: $lineName, scheduledAt: $scheduledAt, expectedAt: $expectedAt, freshness: $freshness, sourceLabel: $sourceLabel, platform: $platform, tripNumber: $tripNumber, isDemo: $isDemo)';
}


}

/// @nodoc
abstract mixin class _$DepartureCopyWith<$Res> implements $DepartureCopyWith<$Res> {
  factory _$DepartureCopyWith(_Departure value, $Res Function(_Departure) _then) = __$DepartureCopyWithImpl;
@override @useResult
$Res call({
 String id, String stationId, String destination, String lineName, DateTime scheduledAt, DateTime expectedAt, DataFreshness freshness, String sourceLabel, String? platform, String? tripNumber, bool isDemo
});




}
/// @nodoc
class __$DepartureCopyWithImpl<$Res>
    implements _$DepartureCopyWith<$Res> {
  __$DepartureCopyWithImpl(this._self, this._then);

  final _Departure _self;
  final $Res Function(_Departure) _then;

/// Create a copy of Departure
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? stationId = null,Object? destination = null,Object? lineName = null,Object? scheduledAt = null,Object? expectedAt = null,Object? freshness = null,Object? sourceLabel = null,Object? platform = freezed,Object? tripNumber = freezed,Object? isDemo = null,}) {
  return _then(_Departure(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,stationId: null == stationId ? _self.stationId : stationId // ignore: cast_nullable_to_non_nullable
as String,destination: null == destination ? _self.destination : destination // ignore: cast_nullable_to_non_nullable
as String,lineName: null == lineName ? _self.lineName : lineName // ignore: cast_nullable_to_non_nullable
as String,scheduledAt: null == scheduledAt ? _self.scheduledAt : scheduledAt // ignore: cast_nullable_to_non_nullable
as DateTime,expectedAt: null == expectedAt ? _self.expectedAt : expectedAt // ignore: cast_nullable_to_non_nullable
as DateTime,freshness: null == freshness ? _self.freshness : freshness // ignore: cast_nullable_to_non_nullable
as DataFreshness,sourceLabel: null == sourceLabel ? _self.sourceLabel : sourceLabel // ignore: cast_nullable_to_non_nullable
as String,platform: freezed == platform ? _self.platform : platform // ignore: cast_nullable_to_non_nullable
as String?,tripNumber: freezed == tripNumber ? _self.tripNumber : tripNumber // ignore: cast_nullable_to_non_nullable
as String?,isDemo: null == isDemo ? _self.isDemo : isDemo // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}


/// @nodoc
mixin _$TripLeg {

 String get id; TransportMode get mode; String get originName; String get destinationName; DateTime get departureAt; DateTime get arrivalAt; String? get lineName; String? get headsign; List<String> get stationIds; int get walkingMeters; String? get transferInstruction;// The raw GTFS trip_id + service date backing this leg's physical
// vehicle, when the originating provider actually has one (real feed
// data, not mock) — the shared identifier crowd-sourced position
// reports key off. Null for mock legs, which never report a position.
 String? get externalTripId; DateTime? get serviceDate;
/// Create a copy of TripLeg
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TripLegCopyWith<TripLeg> get copyWith => _$TripLegCopyWithImpl<TripLeg>(this as TripLeg, _$identity);

  /// Serializes this TripLeg to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TripLeg&&(identical(other.id, id) || other.id == id)&&(identical(other.mode, mode) || other.mode == mode)&&(identical(other.originName, originName) || other.originName == originName)&&(identical(other.destinationName, destinationName) || other.destinationName == destinationName)&&(identical(other.departureAt, departureAt) || other.departureAt == departureAt)&&(identical(other.arrivalAt, arrivalAt) || other.arrivalAt == arrivalAt)&&(identical(other.lineName, lineName) || other.lineName == lineName)&&(identical(other.headsign, headsign) || other.headsign == headsign)&&const DeepCollectionEquality().equals(other.stationIds, stationIds)&&(identical(other.walkingMeters, walkingMeters) || other.walkingMeters == walkingMeters)&&(identical(other.transferInstruction, transferInstruction) || other.transferInstruction == transferInstruction)&&(identical(other.externalTripId, externalTripId) || other.externalTripId == externalTripId)&&(identical(other.serviceDate, serviceDate) || other.serviceDate == serviceDate));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,mode,originName,destinationName,departureAt,arrivalAt,lineName,headsign,const DeepCollectionEquality().hash(stationIds),walkingMeters,transferInstruction,externalTripId,serviceDate);

@override
String toString() {
  return 'TripLeg(id: $id, mode: $mode, originName: $originName, destinationName: $destinationName, departureAt: $departureAt, arrivalAt: $arrivalAt, lineName: $lineName, headsign: $headsign, stationIds: $stationIds, walkingMeters: $walkingMeters, transferInstruction: $transferInstruction, externalTripId: $externalTripId, serviceDate: $serviceDate)';
}


}

/// @nodoc
abstract mixin class $TripLegCopyWith<$Res>  {
  factory $TripLegCopyWith(TripLeg value, $Res Function(TripLeg) _then) = _$TripLegCopyWithImpl;
@useResult
$Res call({
 String id, TransportMode mode, String originName, String destinationName, DateTime departureAt, DateTime arrivalAt, String? lineName, String? headsign, List<String> stationIds, int walkingMeters, String? transferInstruction, String? externalTripId, DateTime? serviceDate
});




}
/// @nodoc
class _$TripLegCopyWithImpl<$Res>
    implements $TripLegCopyWith<$Res> {
  _$TripLegCopyWithImpl(this._self, this._then);

  final TripLeg _self;
  final $Res Function(TripLeg) _then;

/// Create a copy of TripLeg
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? mode = null,Object? originName = null,Object? destinationName = null,Object? departureAt = null,Object? arrivalAt = null,Object? lineName = freezed,Object? headsign = freezed,Object? stationIds = null,Object? walkingMeters = null,Object? transferInstruction = freezed,Object? externalTripId = freezed,Object? serviceDate = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,mode: null == mode ? _self.mode : mode // ignore: cast_nullable_to_non_nullable
as TransportMode,originName: null == originName ? _self.originName : originName // ignore: cast_nullable_to_non_nullable
as String,destinationName: null == destinationName ? _self.destinationName : destinationName // ignore: cast_nullable_to_non_nullable
as String,departureAt: null == departureAt ? _self.departureAt : departureAt // ignore: cast_nullable_to_non_nullable
as DateTime,arrivalAt: null == arrivalAt ? _self.arrivalAt : arrivalAt // ignore: cast_nullable_to_non_nullable
as DateTime,lineName: freezed == lineName ? _self.lineName : lineName // ignore: cast_nullable_to_non_nullable
as String?,headsign: freezed == headsign ? _self.headsign : headsign // ignore: cast_nullable_to_non_nullable
as String?,stationIds: null == stationIds ? _self.stationIds : stationIds // ignore: cast_nullable_to_non_nullable
as List<String>,walkingMeters: null == walkingMeters ? _self.walkingMeters : walkingMeters // ignore: cast_nullable_to_non_nullable
as int,transferInstruction: freezed == transferInstruction ? _self.transferInstruction : transferInstruction // ignore: cast_nullable_to_non_nullable
as String?,externalTripId: freezed == externalTripId ? _self.externalTripId : externalTripId // ignore: cast_nullable_to_non_nullable
as String?,serviceDate: freezed == serviceDate ? _self.serviceDate : serviceDate // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [TripLeg].
extension TripLegPatterns on TripLeg {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TripLeg value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TripLeg() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TripLeg value)  $default,){
final _that = this;
switch (_that) {
case _TripLeg():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TripLeg value)?  $default,){
final _that = this;
switch (_that) {
case _TripLeg() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  TransportMode mode,  String originName,  String destinationName,  DateTime departureAt,  DateTime arrivalAt,  String? lineName,  String? headsign,  List<String> stationIds,  int walkingMeters,  String? transferInstruction,  String? externalTripId,  DateTime? serviceDate)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TripLeg() when $default != null:
return $default(_that.id,_that.mode,_that.originName,_that.destinationName,_that.departureAt,_that.arrivalAt,_that.lineName,_that.headsign,_that.stationIds,_that.walkingMeters,_that.transferInstruction,_that.externalTripId,_that.serviceDate);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  TransportMode mode,  String originName,  String destinationName,  DateTime departureAt,  DateTime arrivalAt,  String? lineName,  String? headsign,  List<String> stationIds,  int walkingMeters,  String? transferInstruction,  String? externalTripId,  DateTime? serviceDate)  $default,) {final _that = this;
switch (_that) {
case _TripLeg():
return $default(_that.id,_that.mode,_that.originName,_that.destinationName,_that.departureAt,_that.arrivalAt,_that.lineName,_that.headsign,_that.stationIds,_that.walkingMeters,_that.transferInstruction,_that.externalTripId,_that.serviceDate);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  TransportMode mode,  String originName,  String destinationName,  DateTime departureAt,  DateTime arrivalAt,  String? lineName,  String? headsign,  List<String> stationIds,  int walkingMeters,  String? transferInstruction,  String? externalTripId,  DateTime? serviceDate)?  $default,) {final _that = this;
switch (_that) {
case _TripLeg() when $default != null:
return $default(_that.id,_that.mode,_that.originName,_that.destinationName,_that.departureAt,_that.arrivalAt,_that.lineName,_that.headsign,_that.stationIds,_that.walkingMeters,_that.transferInstruction,_that.externalTripId,_that.serviceDate);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TripLeg implements TripLeg {
  const _TripLeg({required this.id, required this.mode, required this.originName, required this.destinationName, required this.departureAt, required this.arrivalAt, this.lineName, this.headsign, final  List<String> stationIds = const <String>[], this.walkingMeters = 0, this.transferInstruction, this.externalTripId, this.serviceDate}): _stationIds = stationIds;
  factory _TripLeg.fromJson(Map<String, dynamic> json) => _$TripLegFromJson(json);

@override final  String id;
@override final  TransportMode mode;
@override final  String originName;
@override final  String destinationName;
@override final  DateTime departureAt;
@override final  DateTime arrivalAt;
@override final  String? lineName;
@override final  String? headsign;
 final  List<String> _stationIds;
@override@JsonKey() List<String> get stationIds {
  if (_stationIds is EqualUnmodifiableListView) return _stationIds;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_stationIds);
}

@override@JsonKey() final  int walkingMeters;
@override final  String? transferInstruction;
// The raw GTFS trip_id + service date backing this leg's physical
// vehicle, when the originating provider actually has one (real feed
// data, not mock) — the shared identifier crowd-sourced position
// reports key off. Null for mock legs, which never report a position.
@override final  String? externalTripId;
@override final  DateTime? serviceDate;

/// Create a copy of TripLeg
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TripLegCopyWith<_TripLeg> get copyWith => __$TripLegCopyWithImpl<_TripLeg>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TripLegToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TripLeg&&(identical(other.id, id) || other.id == id)&&(identical(other.mode, mode) || other.mode == mode)&&(identical(other.originName, originName) || other.originName == originName)&&(identical(other.destinationName, destinationName) || other.destinationName == destinationName)&&(identical(other.departureAt, departureAt) || other.departureAt == departureAt)&&(identical(other.arrivalAt, arrivalAt) || other.arrivalAt == arrivalAt)&&(identical(other.lineName, lineName) || other.lineName == lineName)&&(identical(other.headsign, headsign) || other.headsign == headsign)&&const DeepCollectionEquality().equals(other._stationIds, _stationIds)&&(identical(other.walkingMeters, walkingMeters) || other.walkingMeters == walkingMeters)&&(identical(other.transferInstruction, transferInstruction) || other.transferInstruction == transferInstruction)&&(identical(other.externalTripId, externalTripId) || other.externalTripId == externalTripId)&&(identical(other.serviceDate, serviceDate) || other.serviceDate == serviceDate));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,mode,originName,destinationName,departureAt,arrivalAt,lineName,headsign,const DeepCollectionEquality().hash(_stationIds),walkingMeters,transferInstruction,externalTripId,serviceDate);

@override
String toString() {
  return 'TripLeg(id: $id, mode: $mode, originName: $originName, destinationName: $destinationName, departureAt: $departureAt, arrivalAt: $arrivalAt, lineName: $lineName, headsign: $headsign, stationIds: $stationIds, walkingMeters: $walkingMeters, transferInstruction: $transferInstruction, externalTripId: $externalTripId, serviceDate: $serviceDate)';
}


}

/// @nodoc
abstract mixin class _$TripLegCopyWith<$Res> implements $TripLegCopyWith<$Res> {
  factory _$TripLegCopyWith(_TripLeg value, $Res Function(_TripLeg) _then) = __$TripLegCopyWithImpl;
@override @useResult
$Res call({
 String id, TransportMode mode, String originName, String destinationName, DateTime departureAt, DateTime arrivalAt, String? lineName, String? headsign, List<String> stationIds, int walkingMeters, String? transferInstruction, String? externalTripId, DateTime? serviceDate
});




}
/// @nodoc
class __$TripLegCopyWithImpl<$Res>
    implements _$TripLegCopyWith<$Res> {
  __$TripLegCopyWithImpl(this._self, this._then);

  final _TripLeg _self;
  final $Res Function(_TripLeg) _then;

/// Create a copy of TripLeg
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? mode = null,Object? originName = null,Object? destinationName = null,Object? departureAt = null,Object? arrivalAt = null,Object? lineName = freezed,Object? headsign = freezed,Object? stationIds = null,Object? walkingMeters = null,Object? transferInstruction = freezed,Object? externalTripId = freezed,Object? serviceDate = freezed,}) {
  return _then(_TripLeg(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,mode: null == mode ? _self.mode : mode // ignore: cast_nullable_to_non_nullable
as TransportMode,originName: null == originName ? _self.originName : originName // ignore: cast_nullable_to_non_nullable
as String,destinationName: null == destinationName ? _self.destinationName : destinationName // ignore: cast_nullable_to_non_nullable
as String,departureAt: null == departureAt ? _self.departureAt : departureAt // ignore: cast_nullable_to_non_nullable
as DateTime,arrivalAt: null == arrivalAt ? _self.arrivalAt : arrivalAt // ignore: cast_nullable_to_non_nullable
as DateTime,lineName: freezed == lineName ? _self.lineName : lineName // ignore: cast_nullable_to_non_nullable
as String?,headsign: freezed == headsign ? _self.headsign : headsign // ignore: cast_nullable_to_non_nullable
as String?,stationIds: null == stationIds ? _self._stationIds : stationIds // ignore: cast_nullable_to_non_nullable
as List<String>,walkingMeters: null == walkingMeters ? _self.walkingMeters : walkingMeters // ignore: cast_nullable_to_non_nullable
as int,transferInstruction: freezed == transferInstruction ? _self.transferInstruction : transferInstruction // ignore: cast_nullable_to_non_nullable
as String?,externalTripId: freezed == externalTripId ? _self.externalTripId : externalTripId // ignore: cast_nullable_to_non_nullable
as String?,serviceDate: freezed == serviceDate ? _self.serviceDate : serviceDate // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}


/// @nodoc
mixin _$TransitTrip {

 String get id; String get originStationId; String get destinationStationId; DateTime get departureAt; DateTime get arrivalAt; List<TripLeg> get legs; DataFreshness get freshness; String get sourceLabel; DateTime get updatedAt; int get transfers; int get walkingMeters; int get estimatedFare; bool get isDemo; ServiceStatus get serviceStatus;
/// Create a copy of TransitTrip
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TransitTripCopyWith<TransitTrip> get copyWith => _$TransitTripCopyWithImpl<TransitTrip>(this as TransitTrip, _$identity);

  /// Serializes this TransitTrip to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TransitTrip&&(identical(other.id, id) || other.id == id)&&(identical(other.originStationId, originStationId) || other.originStationId == originStationId)&&(identical(other.destinationStationId, destinationStationId) || other.destinationStationId == destinationStationId)&&(identical(other.departureAt, departureAt) || other.departureAt == departureAt)&&(identical(other.arrivalAt, arrivalAt) || other.arrivalAt == arrivalAt)&&const DeepCollectionEquality().equals(other.legs, legs)&&(identical(other.freshness, freshness) || other.freshness == freshness)&&(identical(other.sourceLabel, sourceLabel) || other.sourceLabel == sourceLabel)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.transfers, transfers) || other.transfers == transfers)&&(identical(other.walkingMeters, walkingMeters) || other.walkingMeters == walkingMeters)&&(identical(other.estimatedFare, estimatedFare) || other.estimatedFare == estimatedFare)&&(identical(other.isDemo, isDemo) || other.isDemo == isDemo)&&(identical(other.serviceStatus, serviceStatus) || other.serviceStatus == serviceStatus));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,originStationId,destinationStationId,departureAt,arrivalAt,const DeepCollectionEquality().hash(legs),freshness,sourceLabel,updatedAt,transfers,walkingMeters,estimatedFare,isDemo,serviceStatus);

@override
String toString() {
  return 'TransitTrip(id: $id, originStationId: $originStationId, destinationStationId: $destinationStationId, departureAt: $departureAt, arrivalAt: $arrivalAt, legs: $legs, freshness: $freshness, sourceLabel: $sourceLabel, updatedAt: $updatedAt, transfers: $transfers, walkingMeters: $walkingMeters, estimatedFare: $estimatedFare, isDemo: $isDemo, serviceStatus: $serviceStatus)';
}


}

/// @nodoc
abstract mixin class $TransitTripCopyWith<$Res>  {
  factory $TransitTripCopyWith(TransitTrip value, $Res Function(TransitTrip) _then) = _$TransitTripCopyWithImpl;
@useResult
$Res call({
 String id, String originStationId, String destinationStationId, DateTime departureAt, DateTime arrivalAt, List<TripLeg> legs, DataFreshness freshness, String sourceLabel, DateTime updatedAt, int transfers, int walkingMeters, int estimatedFare, bool isDemo, ServiceStatus serviceStatus
});




}
/// @nodoc
class _$TransitTripCopyWithImpl<$Res>
    implements $TransitTripCopyWith<$Res> {
  _$TransitTripCopyWithImpl(this._self, this._then);

  final TransitTrip _self;
  final $Res Function(TransitTrip) _then;

/// Create a copy of TransitTrip
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? originStationId = null,Object? destinationStationId = null,Object? departureAt = null,Object? arrivalAt = null,Object? legs = null,Object? freshness = null,Object? sourceLabel = null,Object? updatedAt = null,Object? transfers = null,Object? walkingMeters = null,Object? estimatedFare = null,Object? isDemo = null,Object? serviceStatus = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,originStationId: null == originStationId ? _self.originStationId : originStationId // ignore: cast_nullable_to_non_nullable
as String,destinationStationId: null == destinationStationId ? _self.destinationStationId : destinationStationId // ignore: cast_nullable_to_non_nullable
as String,departureAt: null == departureAt ? _self.departureAt : departureAt // ignore: cast_nullable_to_non_nullable
as DateTime,arrivalAt: null == arrivalAt ? _self.arrivalAt : arrivalAt // ignore: cast_nullable_to_non_nullable
as DateTime,legs: null == legs ? _self.legs : legs // ignore: cast_nullable_to_non_nullable
as List<TripLeg>,freshness: null == freshness ? _self.freshness : freshness // ignore: cast_nullable_to_non_nullable
as DataFreshness,sourceLabel: null == sourceLabel ? _self.sourceLabel : sourceLabel // ignore: cast_nullable_to_non_nullable
as String,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,transfers: null == transfers ? _self.transfers : transfers // ignore: cast_nullable_to_non_nullable
as int,walkingMeters: null == walkingMeters ? _self.walkingMeters : walkingMeters // ignore: cast_nullable_to_non_nullable
as int,estimatedFare: null == estimatedFare ? _self.estimatedFare : estimatedFare // ignore: cast_nullable_to_non_nullable
as int,isDemo: null == isDemo ? _self.isDemo : isDemo // ignore: cast_nullable_to_non_nullable
as bool,serviceStatus: null == serviceStatus ? _self.serviceStatus : serviceStatus // ignore: cast_nullable_to_non_nullable
as ServiceStatus,
  ));
}

}


/// Adds pattern-matching-related methods to [TransitTrip].
extension TransitTripPatterns on TransitTrip {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TransitTrip value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TransitTrip() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TransitTrip value)  $default,){
final _that = this;
switch (_that) {
case _TransitTrip():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TransitTrip value)?  $default,){
final _that = this;
switch (_that) {
case _TransitTrip() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String originStationId,  String destinationStationId,  DateTime departureAt,  DateTime arrivalAt,  List<TripLeg> legs,  DataFreshness freshness,  String sourceLabel,  DateTime updatedAt,  int transfers,  int walkingMeters,  int estimatedFare,  bool isDemo,  ServiceStatus serviceStatus)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TransitTrip() when $default != null:
return $default(_that.id,_that.originStationId,_that.destinationStationId,_that.departureAt,_that.arrivalAt,_that.legs,_that.freshness,_that.sourceLabel,_that.updatedAt,_that.transfers,_that.walkingMeters,_that.estimatedFare,_that.isDemo,_that.serviceStatus);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String originStationId,  String destinationStationId,  DateTime departureAt,  DateTime arrivalAt,  List<TripLeg> legs,  DataFreshness freshness,  String sourceLabel,  DateTime updatedAt,  int transfers,  int walkingMeters,  int estimatedFare,  bool isDemo,  ServiceStatus serviceStatus)  $default,) {final _that = this;
switch (_that) {
case _TransitTrip():
return $default(_that.id,_that.originStationId,_that.destinationStationId,_that.departureAt,_that.arrivalAt,_that.legs,_that.freshness,_that.sourceLabel,_that.updatedAt,_that.transfers,_that.walkingMeters,_that.estimatedFare,_that.isDemo,_that.serviceStatus);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String originStationId,  String destinationStationId,  DateTime departureAt,  DateTime arrivalAt,  List<TripLeg> legs,  DataFreshness freshness,  String sourceLabel,  DateTime updatedAt,  int transfers,  int walkingMeters,  int estimatedFare,  bool isDemo,  ServiceStatus serviceStatus)?  $default,) {final _that = this;
switch (_that) {
case _TransitTrip() when $default != null:
return $default(_that.id,_that.originStationId,_that.destinationStationId,_that.departureAt,_that.arrivalAt,_that.legs,_that.freshness,_that.sourceLabel,_that.updatedAt,_that.transfers,_that.walkingMeters,_that.estimatedFare,_that.isDemo,_that.serviceStatus);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TransitTrip extends TransitTrip {
  const _TransitTrip({required this.id, required this.originStationId, required this.destinationStationId, required this.departureAt, required this.arrivalAt, required final  List<TripLeg> legs, required this.freshness, required this.sourceLabel, required this.updatedAt, this.transfers = 0, this.walkingMeters = 0, this.estimatedFare = 0, this.isDemo = false, this.serviceStatus = ServiceStatus.normal}): _legs = legs,super._();
  factory _TransitTrip.fromJson(Map<String, dynamic> json) => _$TransitTripFromJson(json);

@override final  String id;
@override final  String originStationId;
@override final  String destinationStationId;
@override final  DateTime departureAt;
@override final  DateTime arrivalAt;
 final  List<TripLeg> _legs;
@override List<TripLeg> get legs {
  if (_legs is EqualUnmodifiableListView) return _legs;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_legs);
}

@override final  DataFreshness freshness;
@override final  String sourceLabel;
@override final  DateTime updatedAt;
@override@JsonKey() final  int transfers;
@override@JsonKey() final  int walkingMeters;
@override@JsonKey() final  int estimatedFare;
@override@JsonKey() final  bool isDemo;
@override@JsonKey() final  ServiceStatus serviceStatus;

/// Create a copy of TransitTrip
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TransitTripCopyWith<_TransitTrip> get copyWith => __$TransitTripCopyWithImpl<_TransitTrip>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TransitTripToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TransitTrip&&(identical(other.id, id) || other.id == id)&&(identical(other.originStationId, originStationId) || other.originStationId == originStationId)&&(identical(other.destinationStationId, destinationStationId) || other.destinationStationId == destinationStationId)&&(identical(other.departureAt, departureAt) || other.departureAt == departureAt)&&(identical(other.arrivalAt, arrivalAt) || other.arrivalAt == arrivalAt)&&const DeepCollectionEquality().equals(other._legs, _legs)&&(identical(other.freshness, freshness) || other.freshness == freshness)&&(identical(other.sourceLabel, sourceLabel) || other.sourceLabel == sourceLabel)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.transfers, transfers) || other.transfers == transfers)&&(identical(other.walkingMeters, walkingMeters) || other.walkingMeters == walkingMeters)&&(identical(other.estimatedFare, estimatedFare) || other.estimatedFare == estimatedFare)&&(identical(other.isDemo, isDemo) || other.isDemo == isDemo)&&(identical(other.serviceStatus, serviceStatus) || other.serviceStatus == serviceStatus));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,originStationId,destinationStationId,departureAt,arrivalAt,const DeepCollectionEquality().hash(_legs),freshness,sourceLabel,updatedAt,transfers,walkingMeters,estimatedFare,isDemo,serviceStatus);

@override
String toString() {
  return 'TransitTrip(id: $id, originStationId: $originStationId, destinationStationId: $destinationStationId, departureAt: $departureAt, arrivalAt: $arrivalAt, legs: $legs, freshness: $freshness, sourceLabel: $sourceLabel, updatedAt: $updatedAt, transfers: $transfers, walkingMeters: $walkingMeters, estimatedFare: $estimatedFare, isDemo: $isDemo, serviceStatus: $serviceStatus)';
}


}

/// @nodoc
abstract mixin class _$TransitTripCopyWith<$Res> implements $TransitTripCopyWith<$Res> {
  factory _$TransitTripCopyWith(_TransitTrip value, $Res Function(_TransitTrip) _then) = __$TransitTripCopyWithImpl;
@override @useResult
$Res call({
 String id, String originStationId, String destinationStationId, DateTime departureAt, DateTime arrivalAt, List<TripLeg> legs, DataFreshness freshness, String sourceLabel, DateTime updatedAt, int transfers, int walkingMeters, int estimatedFare, bool isDemo, ServiceStatus serviceStatus
});




}
/// @nodoc
class __$TransitTripCopyWithImpl<$Res>
    implements _$TransitTripCopyWith<$Res> {
  __$TransitTripCopyWithImpl(this._self, this._then);

  final _TransitTrip _self;
  final $Res Function(_TransitTrip) _then;

/// Create a copy of TransitTrip
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? originStationId = null,Object? destinationStationId = null,Object? departureAt = null,Object? arrivalAt = null,Object? legs = null,Object? freshness = null,Object? sourceLabel = null,Object? updatedAt = null,Object? transfers = null,Object? walkingMeters = null,Object? estimatedFare = null,Object? isDemo = null,Object? serviceStatus = null,}) {
  return _then(_TransitTrip(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,originStationId: null == originStationId ? _self.originStationId : originStationId // ignore: cast_nullable_to_non_nullable
as String,destinationStationId: null == destinationStationId ? _self.destinationStationId : destinationStationId // ignore: cast_nullable_to_non_nullable
as String,departureAt: null == departureAt ? _self.departureAt : departureAt // ignore: cast_nullable_to_non_nullable
as DateTime,arrivalAt: null == arrivalAt ? _self.arrivalAt : arrivalAt // ignore: cast_nullable_to_non_nullable
as DateTime,legs: null == legs ? _self._legs : legs // ignore: cast_nullable_to_non_nullable
as List<TripLeg>,freshness: null == freshness ? _self.freshness : freshness // ignore: cast_nullable_to_non_nullable
as DataFreshness,sourceLabel: null == sourceLabel ? _self.sourceLabel : sourceLabel // ignore: cast_nullable_to_non_nullable
as String,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,transfers: null == transfers ? _self.transfers : transfers // ignore: cast_nullable_to_non_nullable
as int,walkingMeters: null == walkingMeters ? _self.walkingMeters : walkingMeters // ignore: cast_nullable_to_non_nullable
as int,estimatedFare: null == estimatedFare ? _self.estimatedFare : estimatedFare // ignore: cast_nullable_to_non_nullable
as int,isDemo: null == isDemo ? _self.isDemo : isDemo // ignore: cast_nullable_to_non_nullable
as bool,serviceStatus: null == serviceStatus ? _self.serviceStatus : serviceStatus // ignore: cast_nullable_to_non_nullable
as ServiceStatus,
  ));
}


}


/// @nodoc
mixin _$VehiclePosition {

 String get id; String get tripId; double get latitude; double get longitude; DateTime get recordedAt; DataFreshness get freshness; String get sourceLabel; String? get previousStationId; String? get nextStationId; double? get bearing; double? get speedMetersPerSecond; bool get isDemo;
/// Create a copy of VehiclePosition
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VehiclePositionCopyWith<VehiclePosition> get copyWith => _$VehiclePositionCopyWithImpl<VehiclePosition>(this as VehiclePosition, _$identity);

  /// Serializes this VehiclePosition to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is VehiclePosition&&(identical(other.id, id) || other.id == id)&&(identical(other.tripId, tripId) || other.tripId == tripId)&&(identical(other.latitude, latitude) || other.latitude == latitude)&&(identical(other.longitude, longitude) || other.longitude == longitude)&&(identical(other.recordedAt, recordedAt) || other.recordedAt == recordedAt)&&(identical(other.freshness, freshness) || other.freshness == freshness)&&(identical(other.sourceLabel, sourceLabel) || other.sourceLabel == sourceLabel)&&(identical(other.previousStationId, previousStationId) || other.previousStationId == previousStationId)&&(identical(other.nextStationId, nextStationId) || other.nextStationId == nextStationId)&&(identical(other.bearing, bearing) || other.bearing == bearing)&&(identical(other.speedMetersPerSecond, speedMetersPerSecond) || other.speedMetersPerSecond == speedMetersPerSecond)&&(identical(other.isDemo, isDemo) || other.isDemo == isDemo));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,tripId,latitude,longitude,recordedAt,freshness,sourceLabel,previousStationId,nextStationId,bearing,speedMetersPerSecond,isDemo);

@override
String toString() {
  return 'VehiclePosition(id: $id, tripId: $tripId, latitude: $latitude, longitude: $longitude, recordedAt: $recordedAt, freshness: $freshness, sourceLabel: $sourceLabel, previousStationId: $previousStationId, nextStationId: $nextStationId, bearing: $bearing, speedMetersPerSecond: $speedMetersPerSecond, isDemo: $isDemo)';
}


}

/// @nodoc
abstract mixin class $VehiclePositionCopyWith<$Res>  {
  factory $VehiclePositionCopyWith(VehiclePosition value, $Res Function(VehiclePosition) _then) = _$VehiclePositionCopyWithImpl;
@useResult
$Res call({
 String id, String tripId, double latitude, double longitude, DateTime recordedAt, DataFreshness freshness, String sourceLabel, String? previousStationId, String? nextStationId, double? bearing, double? speedMetersPerSecond, bool isDemo
});




}
/// @nodoc
class _$VehiclePositionCopyWithImpl<$Res>
    implements $VehiclePositionCopyWith<$Res> {
  _$VehiclePositionCopyWithImpl(this._self, this._then);

  final VehiclePosition _self;
  final $Res Function(VehiclePosition) _then;

/// Create a copy of VehiclePosition
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? tripId = null,Object? latitude = null,Object? longitude = null,Object? recordedAt = null,Object? freshness = null,Object? sourceLabel = null,Object? previousStationId = freezed,Object? nextStationId = freezed,Object? bearing = freezed,Object? speedMetersPerSecond = freezed,Object? isDemo = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,tripId: null == tripId ? _self.tripId : tripId // ignore: cast_nullable_to_non_nullable
as String,latitude: null == latitude ? _self.latitude : latitude // ignore: cast_nullable_to_non_nullable
as double,longitude: null == longitude ? _self.longitude : longitude // ignore: cast_nullable_to_non_nullable
as double,recordedAt: null == recordedAt ? _self.recordedAt : recordedAt // ignore: cast_nullable_to_non_nullable
as DateTime,freshness: null == freshness ? _self.freshness : freshness // ignore: cast_nullable_to_non_nullable
as DataFreshness,sourceLabel: null == sourceLabel ? _self.sourceLabel : sourceLabel // ignore: cast_nullable_to_non_nullable
as String,previousStationId: freezed == previousStationId ? _self.previousStationId : previousStationId // ignore: cast_nullable_to_non_nullable
as String?,nextStationId: freezed == nextStationId ? _self.nextStationId : nextStationId // ignore: cast_nullable_to_non_nullable
as String?,bearing: freezed == bearing ? _self.bearing : bearing // ignore: cast_nullable_to_non_nullable
as double?,speedMetersPerSecond: freezed == speedMetersPerSecond ? _self.speedMetersPerSecond : speedMetersPerSecond // ignore: cast_nullable_to_non_nullable
as double?,isDemo: null == isDemo ? _self.isDemo : isDemo // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [VehiclePosition].
extension VehiclePositionPatterns on VehiclePosition {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _VehiclePosition value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _VehiclePosition() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _VehiclePosition value)  $default,){
final _that = this;
switch (_that) {
case _VehiclePosition():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _VehiclePosition value)?  $default,){
final _that = this;
switch (_that) {
case _VehiclePosition() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String tripId,  double latitude,  double longitude,  DateTime recordedAt,  DataFreshness freshness,  String sourceLabel,  String? previousStationId,  String? nextStationId,  double? bearing,  double? speedMetersPerSecond,  bool isDemo)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _VehiclePosition() when $default != null:
return $default(_that.id,_that.tripId,_that.latitude,_that.longitude,_that.recordedAt,_that.freshness,_that.sourceLabel,_that.previousStationId,_that.nextStationId,_that.bearing,_that.speedMetersPerSecond,_that.isDemo);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String tripId,  double latitude,  double longitude,  DateTime recordedAt,  DataFreshness freshness,  String sourceLabel,  String? previousStationId,  String? nextStationId,  double? bearing,  double? speedMetersPerSecond,  bool isDemo)  $default,) {final _that = this;
switch (_that) {
case _VehiclePosition():
return $default(_that.id,_that.tripId,_that.latitude,_that.longitude,_that.recordedAt,_that.freshness,_that.sourceLabel,_that.previousStationId,_that.nextStationId,_that.bearing,_that.speedMetersPerSecond,_that.isDemo);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String tripId,  double latitude,  double longitude,  DateTime recordedAt,  DataFreshness freshness,  String sourceLabel,  String? previousStationId,  String? nextStationId,  double? bearing,  double? speedMetersPerSecond,  bool isDemo)?  $default,) {final _that = this;
switch (_that) {
case _VehiclePosition() when $default != null:
return $default(_that.id,_that.tripId,_that.latitude,_that.longitude,_that.recordedAt,_that.freshness,_that.sourceLabel,_that.previousStationId,_that.nextStationId,_that.bearing,_that.speedMetersPerSecond,_that.isDemo);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _VehiclePosition implements VehiclePosition {
  const _VehiclePosition({required this.id, required this.tripId, required this.latitude, required this.longitude, required this.recordedAt, required this.freshness, required this.sourceLabel, this.previousStationId, this.nextStationId, this.bearing, this.speedMetersPerSecond, this.isDemo = false});
  factory _VehiclePosition.fromJson(Map<String, dynamic> json) => _$VehiclePositionFromJson(json);

@override final  String id;
@override final  String tripId;
@override final  double latitude;
@override final  double longitude;
@override final  DateTime recordedAt;
@override final  DataFreshness freshness;
@override final  String sourceLabel;
@override final  String? previousStationId;
@override final  String? nextStationId;
@override final  double? bearing;
@override final  double? speedMetersPerSecond;
@override@JsonKey() final  bool isDemo;

/// Create a copy of VehiclePosition
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$VehiclePositionCopyWith<_VehiclePosition> get copyWith => __$VehiclePositionCopyWithImpl<_VehiclePosition>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$VehiclePositionToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _VehiclePosition&&(identical(other.id, id) || other.id == id)&&(identical(other.tripId, tripId) || other.tripId == tripId)&&(identical(other.latitude, latitude) || other.latitude == latitude)&&(identical(other.longitude, longitude) || other.longitude == longitude)&&(identical(other.recordedAt, recordedAt) || other.recordedAt == recordedAt)&&(identical(other.freshness, freshness) || other.freshness == freshness)&&(identical(other.sourceLabel, sourceLabel) || other.sourceLabel == sourceLabel)&&(identical(other.previousStationId, previousStationId) || other.previousStationId == previousStationId)&&(identical(other.nextStationId, nextStationId) || other.nextStationId == nextStationId)&&(identical(other.bearing, bearing) || other.bearing == bearing)&&(identical(other.speedMetersPerSecond, speedMetersPerSecond) || other.speedMetersPerSecond == speedMetersPerSecond)&&(identical(other.isDemo, isDemo) || other.isDemo == isDemo));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,tripId,latitude,longitude,recordedAt,freshness,sourceLabel,previousStationId,nextStationId,bearing,speedMetersPerSecond,isDemo);

@override
String toString() {
  return 'VehiclePosition(id: $id, tripId: $tripId, latitude: $latitude, longitude: $longitude, recordedAt: $recordedAt, freshness: $freshness, sourceLabel: $sourceLabel, previousStationId: $previousStationId, nextStationId: $nextStationId, bearing: $bearing, speedMetersPerSecond: $speedMetersPerSecond, isDemo: $isDemo)';
}


}

/// @nodoc
abstract mixin class _$VehiclePositionCopyWith<$Res> implements $VehiclePositionCopyWith<$Res> {
  factory _$VehiclePositionCopyWith(_VehiclePosition value, $Res Function(_VehiclePosition) _then) = __$VehiclePositionCopyWithImpl;
@override @useResult
$Res call({
 String id, String tripId, double latitude, double longitude, DateTime recordedAt, DataFreshness freshness, String sourceLabel, String? previousStationId, String? nextStationId, double? bearing, double? speedMetersPerSecond, bool isDemo
});




}
/// @nodoc
class __$VehiclePositionCopyWithImpl<$Res>
    implements _$VehiclePositionCopyWith<$Res> {
  __$VehiclePositionCopyWithImpl(this._self, this._then);

  final _VehiclePosition _self;
  final $Res Function(_VehiclePosition) _then;

/// Create a copy of VehiclePosition
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? tripId = null,Object? latitude = null,Object? longitude = null,Object? recordedAt = null,Object? freshness = null,Object? sourceLabel = null,Object? previousStationId = freezed,Object? nextStationId = freezed,Object? bearing = freezed,Object? speedMetersPerSecond = freezed,Object? isDemo = null,}) {
  return _then(_VehiclePosition(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,tripId: null == tripId ? _self.tripId : tripId // ignore: cast_nullable_to_non_nullable
as String,latitude: null == latitude ? _self.latitude : latitude // ignore: cast_nullable_to_non_nullable
as double,longitude: null == longitude ? _self.longitude : longitude // ignore: cast_nullable_to_non_nullable
as double,recordedAt: null == recordedAt ? _self.recordedAt : recordedAt // ignore: cast_nullable_to_non_nullable
as DateTime,freshness: null == freshness ? _self.freshness : freshness // ignore: cast_nullable_to_non_nullable
as DataFreshness,sourceLabel: null == sourceLabel ? _self.sourceLabel : sourceLabel // ignore: cast_nullable_to_non_nullable
as String,previousStationId: freezed == previousStationId ? _self.previousStationId : previousStationId // ignore: cast_nullable_to_non_nullable
as String?,nextStationId: freezed == nextStationId ? _self.nextStationId : nextStationId // ignore: cast_nullable_to_non_nullable
as String?,bearing: freezed == bearing ? _self.bearing : bearing // ignore: cast_nullable_to_non_nullable
as double?,speedMetersPerSecond: freezed == speedMetersPerSecond ? _self.speedMetersPerSecond : speedMetersPerSecond // ignore: cast_nullable_to_non_nullable
as double?,isDemo: null == isDemo ? _self.isDemo : isDemo // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}


/// @nodoc
mixin _$ServiceAlert {

 String get id; String get title; String get description; ServiceStatus get status; DateTime get updatedAt; String get sourceLabel; String? get lineId; bool get isOfficial; bool get isDemo;
/// Create a copy of ServiceAlert
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ServiceAlertCopyWith<ServiceAlert> get copyWith => _$ServiceAlertCopyWithImpl<ServiceAlert>(this as ServiceAlert, _$identity);

  /// Serializes this ServiceAlert to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ServiceAlert&&(identical(other.id, id) || other.id == id)&&(identical(other.title, title) || other.title == title)&&(identical(other.description, description) || other.description == description)&&(identical(other.status, status) || other.status == status)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.sourceLabel, sourceLabel) || other.sourceLabel == sourceLabel)&&(identical(other.lineId, lineId) || other.lineId == lineId)&&(identical(other.isOfficial, isOfficial) || other.isOfficial == isOfficial)&&(identical(other.isDemo, isDemo) || other.isDemo == isDemo));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,title,description,status,updatedAt,sourceLabel,lineId,isOfficial,isDemo);

@override
String toString() {
  return 'ServiceAlert(id: $id, title: $title, description: $description, status: $status, updatedAt: $updatedAt, sourceLabel: $sourceLabel, lineId: $lineId, isOfficial: $isOfficial, isDemo: $isDemo)';
}


}

/// @nodoc
abstract mixin class $ServiceAlertCopyWith<$Res>  {
  factory $ServiceAlertCopyWith(ServiceAlert value, $Res Function(ServiceAlert) _then) = _$ServiceAlertCopyWithImpl;
@useResult
$Res call({
 String id, String title, String description, ServiceStatus status, DateTime updatedAt, String sourceLabel, String? lineId, bool isOfficial, bool isDemo
});




}
/// @nodoc
class _$ServiceAlertCopyWithImpl<$Res>
    implements $ServiceAlertCopyWith<$Res> {
  _$ServiceAlertCopyWithImpl(this._self, this._then);

  final ServiceAlert _self;
  final $Res Function(ServiceAlert) _then;

/// Create a copy of ServiceAlert
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? title = null,Object? description = null,Object? status = null,Object? updatedAt = null,Object? sourceLabel = null,Object? lineId = freezed,Object? isOfficial = null,Object? isDemo = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as ServiceStatus,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,sourceLabel: null == sourceLabel ? _self.sourceLabel : sourceLabel // ignore: cast_nullable_to_non_nullable
as String,lineId: freezed == lineId ? _self.lineId : lineId // ignore: cast_nullable_to_non_nullable
as String?,isOfficial: null == isOfficial ? _self.isOfficial : isOfficial // ignore: cast_nullable_to_non_nullable
as bool,isDemo: null == isDemo ? _self.isDemo : isDemo // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [ServiceAlert].
extension ServiceAlertPatterns on ServiceAlert {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ServiceAlert value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ServiceAlert() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ServiceAlert value)  $default,){
final _that = this;
switch (_that) {
case _ServiceAlert():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ServiceAlert value)?  $default,){
final _that = this;
switch (_that) {
case _ServiceAlert() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String title,  String description,  ServiceStatus status,  DateTime updatedAt,  String sourceLabel,  String? lineId,  bool isOfficial,  bool isDemo)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ServiceAlert() when $default != null:
return $default(_that.id,_that.title,_that.description,_that.status,_that.updatedAt,_that.sourceLabel,_that.lineId,_that.isOfficial,_that.isDemo);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String title,  String description,  ServiceStatus status,  DateTime updatedAt,  String sourceLabel,  String? lineId,  bool isOfficial,  bool isDemo)  $default,) {final _that = this;
switch (_that) {
case _ServiceAlert():
return $default(_that.id,_that.title,_that.description,_that.status,_that.updatedAt,_that.sourceLabel,_that.lineId,_that.isOfficial,_that.isDemo);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String title,  String description,  ServiceStatus status,  DateTime updatedAt,  String sourceLabel,  String? lineId,  bool isOfficial,  bool isDemo)?  $default,) {final _that = this;
switch (_that) {
case _ServiceAlert() when $default != null:
return $default(_that.id,_that.title,_that.description,_that.status,_that.updatedAt,_that.sourceLabel,_that.lineId,_that.isOfficial,_that.isDemo);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ServiceAlert implements ServiceAlert {
  const _ServiceAlert({required this.id, required this.title, required this.description, required this.status, required this.updatedAt, required this.sourceLabel, this.lineId, this.isOfficial = false, this.isDemo = false});
  factory _ServiceAlert.fromJson(Map<String, dynamic> json) => _$ServiceAlertFromJson(json);

@override final  String id;
@override final  String title;
@override final  String description;
@override final  ServiceStatus status;
@override final  DateTime updatedAt;
@override final  String sourceLabel;
@override final  String? lineId;
@override@JsonKey() final  bool isOfficial;
@override@JsonKey() final  bool isDemo;

/// Create a copy of ServiceAlert
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ServiceAlertCopyWith<_ServiceAlert> get copyWith => __$ServiceAlertCopyWithImpl<_ServiceAlert>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ServiceAlertToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ServiceAlert&&(identical(other.id, id) || other.id == id)&&(identical(other.title, title) || other.title == title)&&(identical(other.description, description) || other.description == description)&&(identical(other.status, status) || other.status == status)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.sourceLabel, sourceLabel) || other.sourceLabel == sourceLabel)&&(identical(other.lineId, lineId) || other.lineId == lineId)&&(identical(other.isOfficial, isOfficial) || other.isOfficial == isOfficial)&&(identical(other.isDemo, isDemo) || other.isDemo == isDemo));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,title,description,status,updatedAt,sourceLabel,lineId,isOfficial,isDemo);

@override
String toString() {
  return 'ServiceAlert(id: $id, title: $title, description: $description, status: $status, updatedAt: $updatedAt, sourceLabel: $sourceLabel, lineId: $lineId, isOfficial: $isOfficial, isDemo: $isDemo)';
}


}

/// @nodoc
abstract mixin class _$ServiceAlertCopyWith<$Res> implements $ServiceAlertCopyWith<$Res> {
  factory _$ServiceAlertCopyWith(_ServiceAlert value, $Res Function(_ServiceAlert) _then) = __$ServiceAlertCopyWithImpl;
@override @useResult
$Res call({
 String id, String title, String description, ServiceStatus status, DateTime updatedAt, String sourceLabel, String? lineId, bool isOfficial, bool isDemo
});




}
/// @nodoc
class __$ServiceAlertCopyWithImpl<$Res>
    implements _$ServiceAlertCopyWith<$Res> {
  __$ServiceAlertCopyWithImpl(this._self, this._then);

  final _ServiceAlert _self;
  final $Res Function(_ServiceAlert) _then;

/// Create a copy of ServiceAlert
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? title = null,Object? description = null,Object? status = null,Object? updatedAt = null,Object? sourceLabel = null,Object? lineId = freezed,Object? isOfficial = null,Object? isDemo = null,}) {
  return _then(_ServiceAlert(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as ServiceStatus,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,sourceLabel: null == sourceLabel ? _self.sourceLabel : sourceLabel // ignore: cast_nullable_to_non_nullable
as String,lineId: freezed == lineId ? _self.lineId : lineId // ignore: cast_nullable_to_non_nullable
as String?,isOfficial: null == isOfficial ? _self.isOfficial : isOfficial // ignore: cast_nullable_to_non_nullable
as bool,isDemo: null == isDemo ? _self.isDemo : isDemo // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}


/// @nodoc
mixin _$NearbyPlace {

 String get id; String get stationId; String get name; String get category; int get distanceMeters; int get walkingMinutes; String get description; String get sourceLabel; String? get address; bool get isDemo;
/// Create a copy of NearbyPlace
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$NearbyPlaceCopyWith<NearbyPlace> get copyWith => _$NearbyPlaceCopyWithImpl<NearbyPlace>(this as NearbyPlace, _$identity);

  /// Serializes this NearbyPlace to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is NearbyPlace&&(identical(other.id, id) || other.id == id)&&(identical(other.stationId, stationId) || other.stationId == stationId)&&(identical(other.name, name) || other.name == name)&&(identical(other.category, category) || other.category == category)&&(identical(other.distanceMeters, distanceMeters) || other.distanceMeters == distanceMeters)&&(identical(other.walkingMinutes, walkingMinutes) || other.walkingMinutes == walkingMinutes)&&(identical(other.description, description) || other.description == description)&&(identical(other.sourceLabel, sourceLabel) || other.sourceLabel == sourceLabel)&&(identical(other.address, address) || other.address == address)&&(identical(other.isDemo, isDemo) || other.isDemo == isDemo));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,stationId,name,category,distanceMeters,walkingMinutes,description,sourceLabel,address,isDemo);

@override
String toString() {
  return 'NearbyPlace(id: $id, stationId: $stationId, name: $name, category: $category, distanceMeters: $distanceMeters, walkingMinutes: $walkingMinutes, description: $description, sourceLabel: $sourceLabel, address: $address, isDemo: $isDemo)';
}


}

/// @nodoc
abstract mixin class $NearbyPlaceCopyWith<$Res>  {
  factory $NearbyPlaceCopyWith(NearbyPlace value, $Res Function(NearbyPlace) _then) = _$NearbyPlaceCopyWithImpl;
@useResult
$Res call({
 String id, String stationId, String name, String category, int distanceMeters, int walkingMinutes, String description, String sourceLabel, String? address, bool isDemo
});




}
/// @nodoc
class _$NearbyPlaceCopyWithImpl<$Res>
    implements $NearbyPlaceCopyWith<$Res> {
  _$NearbyPlaceCopyWithImpl(this._self, this._then);

  final NearbyPlace _self;
  final $Res Function(NearbyPlace) _then;

/// Create a copy of NearbyPlace
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? stationId = null,Object? name = null,Object? category = null,Object? distanceMeters = null,Object? walkingMinutes = null,Object? description = null,Object? sourceLabel = null,Object? address = freezed,Object? isDemo = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,stationId: null == stationId ? _self.stationId : stationId // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,category: null == category ? _self.category : category // ignore: cast_nullable_to_non_nullable
as String,distanceMeters: null == distanceMeters ? _self.distanceMeters : distanceMeters // ignore: cast_nullable_to_non_nullable
as int,walkingMinutes: null == walkingMinutes ? _self.walkingMinutes : walkingMinutes // ignore: cast_nullable_to_non_nullable
as int,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,sourceLabel: null == sourceLabel ? _self.sourceLabel : sourceLabel // ignore: cast_nullable_to_non_nullable
as String,address: freezed == address ? _self.address : address // ignore: cast_nullable_to_non_nullable
as String?,isDemo: null == isDemo ? _self.isDemo : isDemo // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [NearbyPlace].
extension NearbyPlacePatterns on NearbyPlace {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _NearbyPlace value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _NearbyPlace() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _NearbyPlace value)  $default,){
final _that = this;
switch (_that) {
case _NearbyPlace():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _NearbyPlace value)?  $default,){
final _that = this;
switch (_that) {
case _NearbyPlace() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String stationId,  String name,  String category,  int distanceMeters,  int walkingMinutes,  String description,  String sourceLabel,  String? address,  bool isDemo)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _NearbyPlace() when $default != null:
return $default(_that.id,_that.stationId,_that.name,_that.category,_that.distanceMeters,_that.walkingMinutes,_that.description,_that.sourceLabel,_that.address,_that.isDemo);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String stationId,  String name,  String category,  int distanceMeters,  int walkingMinutes,  String description,  String sourceLabel,  String? address,  bool isDemo)  $default,) {final _that = this;
switch (_that) {
case _NearbyPlace():
return $default(_that.id,_that.stationId,_that.name,_that.category,_that.distanceMeters,_that.walkingMinutes,_that.description,_that.sourceLabel,_that.address,_that.isDemo);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String stationId,  String name,  String category,  int distanceMeters,  int walkingMinutes,  String description,  String sourceLabel,  String? address,  bool isDemo)?  $default,) {final _that = this;
switch (_that) {
case _NearbyPlace() when $default != null:
return $default(_that.id,_that.stationId,_that.name,_that.category,_that.distanceMeters,_that.walkingMinutes,_that.description,_that.sourceLabel,_that.address,_that.isDemo);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _NearbyPlace implements NearbyPlace {
  const _NearbyPlace({required this.id, required this.stationId, required this.name, required this.category, required this.distanceMeters, required this.walkingMinutes, required this.description, required this.sourceLabel, this.address, this.isDemo = false});
  factory _NearbyPlace.fromJson(Map<String, dynamic> json) => _$NearbyPlaceFromJson(json);

@override final  String id;
@override final  String stationId;
@override final  String name;
@override final  String category;
@override final  int distanceMeters;
@override final  int walkingMinutes;
@override final  String description;
@override final  String sourceLabel;
@override final  String? address;
@override@JsonKey() final  bool isDemo;

/// Create a copy of NearbyPlace
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$NearbyPlaceCopyWith<_NearbyPlace> get copyWith => __$NearbyPlaceCopyWithImpl<_NearbyPlace>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$NearbyPlaceToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _NearbyPlace&&(identical(other.id, id) || other.id == id)&&(identical(other.stationId, stationId) || other.stationId == stationId)&&(identical(other.name, name) || other.name == name)&&(identical(other.category, category) || other.category == category)&&(identical(other.distanceMeters, distanceMeters) || other.distanceMeters == distanceMeters)&&(identical(other.walkingMinutes, walkingMinutes) || other.walkingMinutes == walkingMinutes)&&(identical(other.description, description) || other.description == description)&&(identical(other.sourceLabel, sourceLabel) || other.sourceLabel == sourceLabel)&&(identical(other.address, address) || other.address == address)&&(identical(other.isDemo, isDemo) || other.isDemo == isDemo));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,stationId,name,category,distanceMeters,walkingMinutes,description,sourceLabel,address,isDemo);

@override
String toString() {
  return 'NearbyPlace(id: $id, stationId: $stationId, name: $name, category: $category, distanceMeters: $distanceMeters, walkingMinutes: $walkingMinutes, description: $description, sourceLabel: $sourceLabel, address: $address, isDemo: $isDemo)';
}


}

/// @nodoc
abstract mixin class _$NearbyPlaceCopyWith<$Res> implements $NearbyPlaceCopyWith<$Res> {
  factory _$NearbyPlaceCopyWith(_NearbyPlace value, $Res Function(_NearbyPlace) _then) = __$NearbyPlaceCopyWithImpl;
@override @useResult
$Res call({
 String id, String stationId, String name, String category, int distanceMeters, int walkingMinutes, String description, String sourceLabel, String? address, bool isDemo
});




}
/// @nodoc
class __$NearbyPlaceCopyWithImpl<$Res>
    implements _$NearbyPlaceCopyWith<$Res> {
  __$NearbyPlaceCopyWithImpl(this._self, this._then);

  final _NearbyPlace _self;
  final $Res Function(_NearbyPlace) _then;

/// Create a copy of NearbyPlace
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? stationId = null,Object? name = null,Object? category = null,Object? distanceMeters = null,Object? walkingMinutes = null,Object? description = null,Object? sourceLabel = null,Object? address = freezed,Object? isDemo = null,}) {
  return _then(_NearbyPlace(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,stationId: null == stationId ? _self.stationId : stationId // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,category: null == category ? _self.category : category // ignore: cast_nullable_to_non_nullable
as String,distanceMeters: null == distanceMeters ? _self.distanceMeters : distanceMeters // ignore: cast_nullable_to_non_nullable
as int,walkingMinutes: null == walkingMinutes ? _self.walkingMinutes : walkingMinutes // ignore: cast_nullable_to_non_nullable
as int,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,sourceLabel: null == sourceLabel ? _self.sourceLabel : sourceLabel // ignore: cast_nullable_to_non_nullable
as String,address: freezed == address ? _self.address : address // ignore: cast_nullable_to_non_nullable
as String?,isDemo: null == isDemo ? _self.isDemo : isDemo // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}


/// @nodoc
mixin _$TripSearchQuery {

 String get originStationId; String get destinationStationId; DateTime get departureAt; int get maximumTransfers; bool get includeWalking;
/// Create a copy of TripSearchQuery
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TripSearchQueryCopyWith<TripSearchQuery> get copyWith => _$TripSearchQueryCopyWithImpl<TripSearchQuery>(this as TripSearchQuery, _$identity);

  /// Serializes this TripSearchQuery to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TripSearchQuery&&(identical(other.originStationId, originStationId) || other.originStationId == originStationId)&&(identical(other.destinationStationId, destinationStationId) || other.destinationStationId == destinationStationId)&&(identical(other.departureAt, departureAt) || other.departureAt == departureAt)&&(identical(other.maximumTransfers, maximumTransfers) || other.maximumTransfers == maximumTransfers)&&(identical(other.includeWalking, includeWalking) || other.includeWalking == includeWalking));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,originStationId,destinationStationId,departureAt,maximumTransfers,includeWalking);

@override
String toString() {
  return 'TripSearchQuery(originStationId: $originStationId, destinationStationId: $destinationStationId, departureAt: $departureAt, maximumTransfers: $maximumTransfers, includeWalking: $includeWalking)';
}


}

/// @nodoc
abstract mixin class $TripSearchQueryCopyWith<$Res>  {
  factory $TripSearchQueryCopyWith(TripSearchQuery value, $Res Function(TripSearchQuery) _then) = _$TripSearchQueryCopyWithImpl;
@useResult
$Res call({
 String originStationId, String destinationStationId, DateTime departureAt, int maximumTransfers, bool includeWalking
});




}
/// @nodoc
class _$TripSearchQueryCopyWithImpl<$Res>
    implements $TripSearchQueryCopyWith<$Res> {
  _$TripSearchQueryCopyWithImpl(this._self, this._then);

  final TripSearchQuery _self;
  final $Res Function(TripSearchQuery) _then;

/// Create a copy of TripSearchQuery
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? originStationId = null,Object? destinationStationId = null,Object? departureAt = null,Object? maximumTransfers = null,Object? includeWalking = null,}) {
  return _then(_self.copyWith(
originStationId: null == originStationId ? _self.originStationId : originStationId // ignore: cast_nullable_to_non_nullable
as String,destinationStationId: null == destinationStationId ? _self.destinationStationId : destinationStationId // ignore: cast_nullable_to_non_nullable
as String,departureAt: null == departureAt ? _self.departureAt : departureAt // ignore: cast_nullable_to_non_nullable
as DateTime,maximumTransfers: null == maximumTransfers ? _self.maximumTransfers : maximumTransfers // ignore: cast_nullable_to_non_nullable
as int,includeWalking: null == includeWalking ? _self.includeWalking : includeWalking // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [TripSearchQuery].
extension TripSearchQueryPatterns on TripSearchQuery {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TripSearchQuery value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TripSearchQuery() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TripSearchQuery value)  $default,){
final _that = this;
switch (_that) {
case _TripSearchQuery():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TripSearchQuery value)?  $default,){
final _that = this;
switch (_that) {
case _TripSearchQuery() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String originStationId,  String destinationStationId,  DateTime departureAt,  int maximumTransfers,  bool includeWalking)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TripSearchQuery() when $default != null:
return $default(_that.originStationId,_that.destinationStationId,_that.departureAt,_that.maximumTransfers,_that.includeWalking);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String originStationId,  String destinationStationId,  DateTime departureAt,  int maximumTransfers,  bool includeWalking)  $default,) {final _that = this;
switch (_that) {
case _TripSearchQuery():
return $default(_that.originStationId,_that.destinationStationId,_that.departureAt,_that.maximumTransfers,_that.includeWalking);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String originStationId,  String destinationStationId,  DateTime departureAt,  int maximumTransfers,  bool includeWalking)?  $default,) {final _that = this;
switch (_that) {
case _TripSearchQuery() when $default != null:
return $default(_that.originStationId,_that.destinationStationId,_that.departureAt,_that.maximumTransfers,_that.includeWalking);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TripSearchQuery implements TripSearchQuery {
  const _TripSearchQuery({required this.originStationId, required this.destinationStationId, required this.departureAt, this.maximumTransfers = 2, this.includeWalking = true});
  factory _TripSearchQuery.fromJson(Map<String, dynamic> json) => _$TripSearchQueryFromJson(json);

@override final  String originStationId;
@override final  String destinationStationId;
@override final  DateTime departureAt;
@override@JsonKey() final  int maximumTransfers;
@override@JsonKey() final  bool includeWalking;

/// Create a copy of TripSearchQuery
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TripSearchQueryCopyWith<_TripSearchQuery> get copyWith => __$TripSearchQueryCopyWithImpl<_TripSearchQuery>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TripSearchQueryToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TripSearchQuery&&(identical(other.originStationId, originStationId) || other.originStationId == originStationId)&&(identical(other.destinationStationId, destinationStationId) || other.destinationStationId == destinationStationId)&&(identical(other.departureAt, departureAt) || other.departureAt == departureAt)&&(identical(other.maximumTransfers, maximumTransfers) || other.maximumTransfers == maximumTransfers)&&(identical(other.includeWalking, includeWalking) || other.includeWalking == includeWalking));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,originStationId,destinationStationId,departureAt,maximumTransfers,includeWalking);

@override
String toString() {
  return 'TripSearchQuery(originStationId: $originStationId, destinationStationId: $destinationStationId, departureAt: $departureAt, maximumTransfers: $maximumTransfers, includeWalking: $includeWalking)';
}


}

/// @nodoc
abstract mixin class _$TripSearchQueryCopyWith<$Res> implements $TripSearchQueryCopyWith<$Res> {
  factory _$TripSearchQueryCopyWith(_TripSearchQuery value, $Res Function(_TripSearchQuery) _then) = __$TripSearchQueryCopyWithImpl;
@override @useResult
$Res call({
 String originStationId, String destinationStationId, DateTime departureAt, int maximumTransfers, bool includeWalking
});




}
/// @nodoc
class __$TripSearchQueryCopyWithImpl<$Res>
    implements _$TripSearchQueryCopyWith<$Res> {
  __$TripSearchQueryCopyWithImpl(this._self, this._then);

  final _TripSearchQuery _self;
  final $Res Function(_TripSearchQuery) _then;

/// Create a copy of TripSearchQuery
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? originStationId = null,Object? destinationStationId = null,Object? departureAt = null,Object? maximumTransfers = null,Object? includeWalking = null,}) {
  return _then(_TripSearchQuery(
originStationId: null == originStationId ? _self.originStationId : originStationId // ignore: cast_nullable_to_non_nullable
as String,destinationStationId: null == destinationStationId ? _self.destinationStationId : destinationStationId // ignore: cast_nullable_to_non_nullable
as String,departureAt: null == departureAt ? _self.departureAt : departureAt // ignore: cast_nullable_to_non_nullable
as DateTime,maximumTransfers: null == maximumTransfers ? _self.maximumTransfers : maximumTransfers // ignore: cast_nullable_to_non_nullable
as int,includeWalking: null == includeWalking ? _self.includeWalking : includeWalking // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}


/// @nodoc
mixin _$PlaceFilter {

 String? get stationId; String? get category; int get radiusMeters;
/// Create a copy of PlaceFilter
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PlaceFilterCopyWith<PlaceFilter> get copyWith => _$PlaceFilterCopyWithImpl<PlaceFilter>(this as PlaceFilter, _$identity);

  /// Serializes this PlaceFilter to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PlaceFilter&&(identical(other.stationId, stationId) || other.stationId == stationId)&&(identical(other.category, category) || other.category == category)&&(identical(other.radiusMeters, radiusMeters) || other.radiusMeters == radiusMeters));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,stationId,category,radiusMeters);

@override
String toString() {
  return 'PlaceFilter(stationId: $stationId, category: $category, radiusMeters: $radiusMeters)';
}


}

/// @nodoc
abstract mixin class $PlaceFilterCopyWith<$Res>  {
  factory $PlaceFilterCopyWith(PlaceFilter value, $Res Function(PlaceFilter) _then) = _$PlaceFilterCopyWithImpl;
@useResult
$Res call({
 String? stationId, String? category, int radiusMeters
});




}
/// @nodoc
class _$PlaceFilterCopyWithImpl<$Res>
    implements $PlaceFilterCopyWith<$Res> {
  _$PlaceFilterCopyWithImpl(this._self, this._then);

  final PlaceFilter _self;
  final $Res Function(PlaceFilter) _then;

/// Create a copy of PlaceFilter
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? stationId = freezed,Object? category = freezed,Object? radiusMeters = null,}) {
  return _then(_self.copyWith(
stationId: freezed == stationId ? _self.stationId : stationId // ignore: cast_nullable_to_non_nullable
as String?,category: freezed == category ? _self.category : category // ignore: cast_nullable_to_non_nullable
as String?,radiusMeters: null == radiusMeters ? _self.radiusMeters : radiusMeters // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [PlaceFilter].
extension PlaceFilterPatterns on PlaceFilter {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PlaceFilter value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PlaceFilter() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PlaceFilter value)  $default,){
final _that = this;
switch (_that) {
case _PlaceFilter():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PlaceFilter value)?  $default,){
final _that = this;
switch (_that) {
case _PlaceFilter() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String? stationId,  String? category,  int radiusMeters)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PlaceFilter() when $default != null:
return $default(_that.stationId,_that.category,_that.radiusMeters);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String? stationId,  String? category,  int radiusMeters)  $default,) {final _that = this;
switch (_that) {
case _PlaceFilter():
return $default(_that.stationId,_that.category,_that.radiusMeters);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String? stationId,  String? category,  int radiusMeters)?  $default,) {final _that = this;
switch (_that) {
case _PlaceFilter() when $default != null:
return $default(_that.stationId,_that.category,_that.radiusMeters);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _PlaceFilter implements PlaceFilter {
  const _PlaceFilter({this.stationId, this.category, this.radiusMeters = 1500});
  factory _PlaceFilter.fromJson(Map<String, dynamic> json) => _$PlaceFilterFromJson(json);

@override final  String? stationId;
@override final  String? category;
@override@JsonKey() final  int radiusMeters;

/// Create a copy of PlaceFilter
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PlaceFilterCopyWith<_PlaceFilter> get copyWith => __$PlaceFilterCopyWithImpl<_PlaceFilter>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PlaceFilterToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PlaceFilter&&(identical(other.stationId, stationId) || other.stationId == stationId)&&(identical(other.category, category) || other.category == category)&&(identical(other.radiusMeters, radiusMeters) || other.radiusMeters == radiusMeters));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,stationId,category,radiusMeters);

@override
String toString() {
  return 'PlaceFilter(stationId: $stationId, category: $category, radiusMeters: $radiusMeters)';
}


}

/// @nodoc
abstract mixin class _$PlaceFilterCopyWith<$Res> implements $PlaceFilterCopyWith<$Res> {
  factory _$PlaceFilterCopyWith(_PlaceFilter value, $Res Function(_PlaceFilter) _then) = __$PlaceFilterCopyWithImpl;
@override @useResult
$Res call({
 String? stationId, String? category, int radiusMeters
});




}
/// @nodoc
class __$PlaceFilterCopyWithImpl<$Res>
    implements _$PlaceFilterCopyWith<$Res> {
  __$PlaceFilterCopyWithImpl(this._self, this._then);

  final _PlaceFilter _self;
  final $Res Function(_PlaceFilter) _then;

/// Create a copy of PlaceFilter
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? stationId = freezed,Object? category = freezed,Object? radiusMeters = null,}) {
  return _then(_PlaceFilter(
stationId: freezed == stationId ? _self.stationId : stationId // ignore: cast_nullable_to_non_nullable
as String?,category: freezed == category ? _self.category : category // ignore: cast_nullable_to_non_nullable
as String?,radiusMeters: null == radiusMeters ? _self.radiusMeters : radiusMeters // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
