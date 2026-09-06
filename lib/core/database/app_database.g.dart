// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $CachedStationsTable extends CachedStations
    with TableInfo<$CachedStationsTable, CachedStation> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CachedStationsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _codeMeta = const VerificationMeta('code');
  @override
  late final GeneratedColumn<String> code = GeneratedColumn<String>(
    'code',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _latitudeMeta = const VerificationMeta(
    'latitude',
  );
  @override
  late final GeneratedColumn<double> latitude = GeneratedColumn<double>(
    'latitude',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _longitudeMeta = const VerificationMeta(
    'longitude',
  );
  @override
  late final GeneratedColumn<double> longitude = GeneratedColumn<double>(
    'longitude',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadJsonMeta = const VerificationMeta(
    'payloadJson',
  );
  @override
  late final GeneratedColumn<String> payloadJson = GeneratedColumn<String>(
    'payload_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    code,
    name,
    latitude,
    longitude,
    payloadJson,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cached_stations';
  @override
  VerificationContext validateIntegrity(
    Insertable<CachedStation> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('code')) {
      context.handle(
        _codeMeta,
        code.isAcceptableOrUnknown(data['code']!, _codeMeta),
      );
    } else if (isInserting) {
      context.missing(_codeMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('latitude')) {
      context.handle(
        _latitudeMeta,
        latitude.isAcceptableOrUnknown(data['latitude']!, _latitudeMeta),
      );
    } else if (isInserting) {
      context.missing(_latitudeMeta);
    }
    if (data.containsKey('longitude')) {
      context.handle(
        _longitudeMeta,
        longitude.isAcceptableOrUnknown(data['longitude']!, _longitudeMeta),
      );
    } else if (isInserting) {
      context.missing(_longitudeMeta);
    }
    if (data.containsKey('payload_json')) {
      context.handle(
        _payloadJsonMeta,
        payloadJson.isAcceptableOrUnknown(
          data['payload_json']!,
          _payloadJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_payloadJsonMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CachedStation map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CachedStation(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      code: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}code'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      latitude: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}latitude'],
      )!,
      longitude: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}longitude'],
      )!,
      payloadJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload_json'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $CachedStationsTable createAlias(String alias) {
    return $CachedStationsTable(attachedDatabase, alias);
  }
}

class CachedStation extends DataClass implements Insertable<CachedStation> {
  final String id;
  final String code;
  final String name;
  final double latitude;
  final double longitude;
  final String payloadJson;
  final DateTime updatedAt;
  const CachedStation({
    required this.id,
    required this.code,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.payloadJson,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['code'] = Variable<String>(code);
    map['name'] = Variable<String>(name);
    map['latitude'] = Variable<double>(latitude);
    map['longitude'] = Variable<double>(longitude);
    map['payload_json'] = Variable<String>(payloadJson);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  CachedStationsCompanion toCompanion(bool nullToAbsent) {
    return CachedStationsCompanion(
      id: Value(id),
      code: Value(code),
      name: Value(name),
      latitude: Value(latitude),
      longitude: Value(longitude),
      payloadJson: Value(payloadJson),
      updatedAt: Value(updatedAt),
    );
  }

  factory CachedStation.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CachedStation(
      id: serializer.fromJson<String>(json['id']),
      code: serializer.fromJson<String>(json['code']),
      name: serializer.fromJson<String>(json['name']),
      latitude: serializer.fromJson<double>(json['latitude']),
      longitude: serializer.fromJson<double>(json['longitude']),
      payloadJson: serializer.fromJson<String>(json['payloadJson']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'code': serializer.toJson<String>(code),
      'name': serializer.toJson<String>(name),
      'latitude': serializer.toJson<double>(latitude),
      'longitude': serializer.toJson<double>(longitude),
      'payloadJson': serializer.toJson<String>(payloadJson),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  CachedStation copyWith({
    String? id,
    String? code,
    String? name,
    double? latitude,
    double? longitude,
    String? payloadJson,
    DateTime? updatedAt,
  }) => CachedStation(
    id: id ?? this.id,
    code: code ?? this.code,
    name: name ?? this.name,
    latitude: latitude ?? this.latitude,
    longitude: longitude ?? this.longitude,
    payloadJson: payloadJson ?? this.payloadJson,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  CachedStation copyWithCompanion(CachedStationsCompanion data) {
    return CachedStation(
      id: data.id.present ? data.id.value : this.id,
      code: data.code.present ? data.code.value : this.code,
      name: data.name.present ? data.name.value : this.name,
      latitude: data.latitude.present ? data.latitude.value : this.latitude,
      longitude: data.longitude.present ? data.longitude.value : this.longitude,
      payloadJson: data.payloadJson.present
          ? data.payloadJson.value
          : this.payloadJson,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CachedStation(')
          ..write('id: $id, ')
          ..write('code: $code, ')
          ..write('name: $name, ')
          ..write('latitude: $latitude, ')
          ..write('longitude: $longitude, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, code, name, latitude, longitude, payloadJson, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CachedStation &&
          other.id == this.id &&
          other.code == this.code &&
          other.name == this.name &&
          other.latitude == this.latitude &&
          other.longitude == this.longitude &&
          other.payloadJson == this.payloadJson &&
          other.updatedAt == this.updatedAt);
}

class CachedStationsCompanion extends UpdateCompanion<CachedStation> {
  final Value<String> id;
  final Value<String> code;
  final Value<String> name;
  final Value<double> latitude;
  final Value<double> longitude;
  final Value<String> payloadJson;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const CachedStationsCompanion({
    this.id = const Value.absent(),
    this.code = const Value.absent(),
    this.name = const Value.absent(),
    this.latitude = const Value.absent(),
    this.longitude = const Value.absent(),
    this.payloadJson = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CachedStationsCompanion.insert({
    required String id,
    required String code,
    required String name,
    required double latitude,
    required double longitude,
    required String payloadJson,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       code = Value(code),
       name = Value(name),
       latitude = Value(latitude),
       longitude = Value(longitude),
       payloadJson = Value(payloadJson),
       updatedAt = Value(updatedAt);
  static Insertable<CachedStation> custom({
    Expression<String>? id,
    Expression<String>? code,
    Expression<String>? name,
    Expression<double>? latitude,
    Expression<double>? longitude,
    Expression<String>? payloadJson,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (code != null) 'code': code,
      if (name != null) 'name': name,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (payloadJson != null) 'payload_json': payloadJson,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CachedStationsCompanion copyWith({
    Value<String>? id,
    Value<String>? code,
    Value<String>? name,
    Value<double>? latitude,
    Value<double>? longitude,
    Value<String>? payloadJson,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return CachedStationsCompanion(
      id: id ?? this.id,
      code: code ?? this.code,
      name: name ?? this.name,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      payloadJson: payloadJson ?? this.payloadJson,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (code.present) {
      map['code'] = Variable<String>(code.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (latitude.present) {
      map['latitude'] = Variable<double>(latitude.value);
    }
    if (longitude.present) {
      map['longitude'] = Variable<double>(longitude.value);
    }
    if (payloadJson.present) {
      map['payload_json'] = Variable<String>(payloadJson.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CachedStationsCompanion(')
          ..write('id: $id, ')
          ..write('code: $code, ')
          ..write('name: $name, ')
          ..write('latitude: $latitude, ')
          ..write('longitude: $longitude, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $FavoriteRoutesTable extends FavoriteRoutes
    with TableInfo<$FavoriteRoutesTable, FavoriteRoute> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FavoriteRoutesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _originStationIdMeta = const VerificationMeta(
    'originStationId',
  );
  @override
  late final GeneratedColumn<String> originStationId = GeneratedColumn<String>(
    'origin_station_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _destinationStationIdMeta =
      const VerificationMeta('destinationStationId');
  @override
  late final GeneratedColumn<String> destinationStationId =
      GeneratedColumn<String>(
        'destination_station_id',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _labelMeta = const VerificationMeta('label');
  @override
  late final GeneratedColumn<String> label = GeneratedColumn<String>(
    'label',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    originStationId,
    destinationStationId,
    label,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'favorite_routes';
  @override
  VerificationContext validateIntegrity(
    Insertable<FavoriteRoute> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('origin_station_id')) {
      context.handle(
        _originStationIdMeta,
        originStationId.isAcceptableOrUnknown(
          data['origin_station_id']!,
          _originStationIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_originStationIdMeta);
    }
    if (data.containsKey('destination_station_id')) {
      context.handle(
        _destinationStationIdMeta,
        destinationStationId.isAcceptableOrUnknown(
          data['destination_station_id']!,
          _destinationStationIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_destinationStationIdMeta);
    }
    if (data.containsKey('label')) {
      context.handle(
        _labelMeta,
        label.isAcceptableOrUnknown(data['label']!, _labelMeta),
      );
    } else if (isInserting) {
      context.missing(_labelMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  FavoriteRoute map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FavoriteRoute(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      originStationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}origin_station_id'],
      )!,
      destinationStationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}destination_station_id'],
      )!,
      label: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}label'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $FavoriteRoutesTable createAlias(String alias) {
    return $FavoriteRoutesTable(attachedDatabase, alias);
  }
}

class FavoriteRoute extends DataClass implements Insertable<FavoriteRoute> {
  final String id;
  final String originStationId;
  final String destinationStationId;
  final String label;
  final DateTime createdAt;
  const FavoriteRoute({
    required this.id,
    required this.originStationId,
    required this.destinationStationId,
    required this.label,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['origin_station_id'] = Variable<String>(originStationId);
    map['destination_station_id'] = Variable<String>(destinationStationId);
    map['label'] = Variable<String>(label);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  FavoriteRoutesCompanion toCompanion(bool nullToAbsent) {
    return FavoriteRoutesCompanion(
      id: Value(id),
      originStationId: Value(originStationId),
      destinationStationId: Value(destinationStationId),
      label: Value(label),
      createdAt: Value(createdAt),
    );
  }

  factory FavoriteRoute.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FavoriteRoute(
      id: serializer.fromJson<String>(json['id']),
      originStationId: serializer.fromJson<String>(json['originStationId']),
      destinationStationId: serializer.fromJson<String>(
        json['destinationStationId'],
      ),
      label: serializer.fromJson<String>(json['label']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'originStationId': serializer.toJson<String>(originStationId),
      'destinationStationId': serializer.toJson<String>(destinationStationId),
      'label': serializer.toJson<String>(label),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  FavoriteRoute copyWith({
    String? id,
    String? originStationId,
    String? destinationStationId,
    String? label,
    DateTime? createdAt,
  }) => FavoriteRoute(
    id: id ?? this.id,
    originStationId: originStationId ?? this.originStationId,
    destinationStationId: destinationStationId ?? this.destinationStationId,
    label: label ?? this.label,
    createdAt: createdAt ?? this.createdAt,
  );
  FavoriteRoute copyWithCompanion(FavoriteRoutesCompanion data) {
    return FavoriteRoute(
      id: data.id.present ? data.id.value : this.id,
      originStationId: data.originStationId.present
          ? data.originStationId.value
          : this.originStationId,
      destinationStationId: data.destinationStationId.present
          ? data.destinationStationId.value
          : this.destinationStationId,
      label: data.label.present ? data.label.value : this.label,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FavoriteRoute(')
          ..write('id: $id, ')
          ..write('originStationId: $originStationId, ')
          ..write('destinationStationId: $destinationStationId, ')
          ..write('label: $label, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, originStationId, destinationStationId, label, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FavoriteRoute &&
          other.id == this.id &&
          other.originStationId == this.originStationId &&
          other.destinationStationId == this.destinationStationId &&
          other.label == this.label &&
          other.createdAt == this.createdAt);
}

class FavoriteRoutesCompanion extends UpdateCompanion<FavoriteRoute> {
  final Value<String> id;
  final Value<String> originStationId;
  final Value<String> destinationStationId;
  final Value<String> label;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const FavoriteRoutesCompanion({
    this.id = const Value.absent(),
    this.originStationId = const Value.absent(),
    this.destinationStationId = const Value.absent(),
    this.label = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  FavoriteRoutesCompanion.insert({
    required String id,
    required String originStationId,
    required String destinationStationId,
    required String label,
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       originStationId = Value(originStationId),
       destinationStationId = Value(destinationStationId),
       label = Value(label),
       createdAt = Value(createdAt);
  static Insertable<FavoriteRoute> custom({
    Expression<String>? id,
    Expression<String>? originStationId,
    Expression<String>? destinationStationId,
    Expression<String>? label,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (originStationId != null) 'origin_station_id': originStationId,
      if (destinationStationId != null)
        'destination_station_id': destinationStationId,
      if (label != null) 'label': label,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  FavoriteRoutesCompanion copyWith({
    Value<String>? id,
    Value<String>? originStationId,
    Value<String>? destinationStationId,
    Value<String>? label,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return FavoriteRoutesCompanion(
      id: id ?? this.id,
      originStationId: originStationId ?? this.originStationId,
      destinationStationId: destinationStationId ?? this.destinationStationId,
      label: label ?? this.label,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (originStationId.present) {
      map['origin_station_id'] = Variable<String>(originStationId.value);
    }
    if (destinationStationId.present) {
      map['destination_station_id'] = Variable<String>(
        destinationStationId.value,
      );
    }
    if (label.present) {
      map['label'] = Variable<String>(label.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FavoriteRoutesCompanion(')
          ..write('id: $id, ')
          ..write('originStationId: $originStationId, ')
          ..write('destinationStationId: $destinationStationId, ')
          ..write('label: $label, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ActiveTripSnapshotsTable extends ActiveTripSnapshots
    with TableInfo<$ActiveTripSnapshotsTable, ActiveTripSnapshot> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ActiveTripSnapshotsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadJsonMeta = const VerificationMeta(
    'payloadJson',
  );
  @override
  late final GeneratedColumn<String> payloadJson = GeneratedColumn<String>(
    'payload_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, payloadJson, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'active_trip_snapshots';
  @override
  VerificationContext validateIntegrity(
    Insertable<ActiveTripSnapshot> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('payload_json')) {
      context.handle(
        _payloadJsonMeta,
        payloadJson.isAcceptableOrUnknown(
          data['payload_json']!,
          _payloadJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_payloadJsonMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ActiveTripSnapshot map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ActiveTripSnapshot(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      payloadJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload_json'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $ActiveTripSnapshotsTable createAlias(String alias) {
    return $ActiveTripSnapshotsTable(attachedDatabase, alias);
  }
}

class ActiveTripSnapshot extends DataClass
    implements Insertable<ActiveTripSnapshot> {
  final String id;
  final String payloadJson;
  final DateTime updatedAt;
  const ActiveTripSnapshot({
    required this.id,
    required this.payloadJson,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['payload_json'] = Variable<String>(payloadJson);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  ActiveTripSnapshotsCompanion toCompanion(bool nullToAbsent) {
    return ActiveTripSnapshotsCompanion(
      id: Value(id),
      payloadJson: Value(payloadJson),
      updatedAt: Value(updatedAt),
    );
  }

  factory ActiveTripSnapshot.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ActiveTripSnapshot(
      id: serializer.fromJson<String>(json['id']),
      payloadJson: serializer.fromJson<String>(json['payloadJson']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'payloadJson': serializer.toJson<String>(payloadJson),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  ActiveTripSnapshot copyWith({
    String? id,
    String? payloadJson,
    DateTime? updatedAt,
  }) => ActiveTripSnapshot(
    id: id ?? this.id,
    payloadJson: payloadJson ?? this.payloadJson,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  ActiveTripSnapshot copyWithCompanion(ActiveTripSnapshotsCompanion data) {
    return ActiveTripSnapshot(
      id: data.id.present ? data.id.value : this.id,
      payloadJson: data.payloadJson.present
          ? data.payloadJson.value
          : this.payloadJson,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ActiveTripSnapshot(')
          ..write('id: $id, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, payloadJson, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ActiveTripSnapshot &&
          other.id == this.id &&
          other.payloadJson == this.payloadJson &&
          other.updatedAt == this.updatedAt);
}

class ActiveTripSnapshotsCompanion extends UpdateCompanion<ActiveTripSnapshot> {
  final Value<String> id;
  final Value<String> payloadJson;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const ActiveTripSnapshotsCompanion({
    this.id = const Value.absent(),
    this.payloadJson = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ActiveTripSnapshotsCompanion.insert({
    required String id,
    required String payloadJson,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       payloadJson = Value(payloadJson),
       updatedAt = Value(updatedAt);
  static Insertable<ActiveTripSnapshot> custom({
    Expression<String>? id,
    Expression<String>? payloadJson,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (payloadJson != null) 'payload_json': payloadJson,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ActiveTripSnapshotsCompanion copyWith({
    Value<String>? id,
    Value<String>? payloadJson,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return ActiveTripSnapshotsCompanion(
      id: id ?? this.id,
      payloadJson: payloadJson ?? this.payloadJson,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (payloadJson.present) {
      map['payload_json'] = Variable<String>(payloadJson.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ActiveTripSnapshotsCompanion(')
          ..write('id: $id, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CompletedTripsTable extends CompletedTrips
    with TableInfo<$CompletedTripsTable, CompletedTrip> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CompletedTripsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _originStationIdMeta = const VerificationMeta(
    'originStationId',
  );
  @override
  late final GeneratedColumn<String> originStationId = GeneratedColumn<String>(
    'origin_station_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _originNameMeta = const VerificationMeta(
    'originName',
  );
  @override
  late final GeneratedColumn<String> originName = GeneratedColumn<String>(
    'origin_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _destinationStationIdMeta =
      const VerificationMeta('destinationStationId');
  @override
  late final GeneratedColumn<String> destinationStationId =
      GeneratedColumn<String>(
        'destination_station_id',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _destinationNameMeta = const VerificationMeta(
    'destinationName',
  );
  @override
  late final GeneratedColumn<String> destinationName = GeneratedColumn<String>(
    'destination_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lineNameMeta = const VerificationMeta(
    'lineName',
  );
  @override
  late final GeneratedColumn<String> lineName = GeneratedColumn<String>(
    'line_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _departedAtMeta = const VerificationMeta(
    'departedAt',
  );
  @override
  late final GeneratedColumn<DateTime> departedAt = GeneratedColumn<DateTime>(
    'departed_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _arrivedAtMeta = const VerificationMeta(
    'arrivedAt',
  );
  @override
  late final GeneratedColumn<DateTime> arrivedAt = GeneratedColumn<DateTime>(
    'arrived_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isDemoMeta = const VerificationMeta('isDemo');
  @override
  late final GeneratedColumn<bool> isDemo = GeneratedColumn<bool>(
    'is_demo',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_demo" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _completedAtMeta = const VerificationMeta(
    'completedAt',
  );
  @override
  late final GeneratedColumn<DateTime> completedAt = GeneratedColumn<DateTime>(
    'completed_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    originStationId,
    originName,
    destinationStationId,
    destinationName,
    lineName,
    departedAt,
    arrivedAt,
    isDemo,
    completedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'completed_trips';
  @override
  VerificationContext validateIntegrity(
    Insertable<CompletedTrip> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('origin_station_id')) {
      context.handle(
        _originStationIdMeta,
        originStationId.isAcceptableOrUnknown(
          data['origin_station_id']!,
          _originStationIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_originStationIdMeta);
    }
    if (data.containsKey('origin_name')) {
      context.handle(
        _originNameMeta,
        originName.isAcceptableOrUnknown(data['origin_name']!, _originNameMeta),
      );
    } else if (isInserting) {
      context.missing(_originNameMeta);
    }
    if (data.containsKey('destination_station_id')) {
      context.handle(
        _destinationStationIdMeta,
        destinationStationId.isAcceptableOrUnknown(
          data['destination_station_id']!,
          _destinationStationIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_destinationStationIdMeta);
    }
    if (data.containsKey('destination_name')) {
      context.handle(
        _destinationNameMeta,
        destinationName.isAcceptableOrUnknown(
          data['destination_name']!,
          _destinationNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_destinationNameMeta);
    }
    if (data.containsKey('line_name')) {
      context.handle(
        _lineNameMeta,
        lineName.isAcceptableOrUnknown(data['line_name']!, _lineNameMeta),
      );
    }
    if (data.containsKey('departed_at')) {
      context.handle(
        _departedAtMeta,
        departedAt.isAcceptableOrUnknown(data['departed_at']!, _departedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_departedAtMeta);
    }
    if (data.containsKey('arrived_at')) {
      context.handle(
        _arrivedAtMeta,
        arrivedAt.isAcceptableOrUnknown(data['arrived_at']!, _arrivedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_arrivedAtMeta);
    }
    if (data.containsKey('is_demo')) {
      context.handle(
        _isDemoMeta,
        isDemo.isAcceptableOrUnknown(data['is_demo']!, _isDemoMeta),
      );
    }
    if (data.containsKey('completed_at')) {
      context.handle(
        _completedAtMeta,
        completedAt.isAcceptableOrUnknown(
          data['completed_at']!,
          _completedAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_completedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CompletedTrip map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CompletedTrip(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      originStationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}origin_station_id'],
      )!,
      originName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}origin_name'],
      )!,
      destinationStationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}destination_station_id'],
      )!,
      destinationName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}destination_name'],
      )!,
      lineName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}line_name'],
      ),
      departedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}departed_at'],
      )!,
      arrivedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}arrived_at'],
      )!,
      isDemo: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_demo'],
      )!,
      completedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}completed_at'],
      )!,
    );
  }

  @override
  $CompletedTripsTable createAlias(String alias) {
    return $CompletedTripsTable(attachedDatabase, alias);
  }
}

class CompletedTrip extends DataClass implements Insertable<CompletedTrip> {
  final String id;
  final String originStationId;
  final String originName;
  final String destinationStationId;
  final String destinationName;
  final String? lineName;
  final DateTime departedAt;
  final DateTime arrivedAt;
  final bool isDemo;
  final DateTime completedAt;
  const CompletedTrip({
    required this.id,
    required this.originStationId,
    required this.originName,
    required this.destinationStationId,
    required this.destinationName,
    this.lineName,
    required this.departedAt,
    required this.arrivedAt,
    required this.isDemo,
    required this.completedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['origin_station_id'] = Variable<String>(originStationId);
    map['origin_name'] = Variable<String>(originName);
    map['destination_station_id'] = Variable<String>(destinationStationId);
    map['destination_name'] = Variable<String>(destinationName);
    if (!nullToAbsent || lineName != null) {
      map['line_name'] = Variable<String>(lineName);
    }
    map['departed_at'] = Variable<DateTime>(departedAt);
    map['arrived_at'] = Variable<DateTime>(arrivedAt);
    map['is_demo'] = Variable<bool>(isDemo);
    map['completed_at'] = Variable<DateTime>(completedAt);
    return map;
  }

  CompletedTripsCompanion toCompanion(bool nullToAbsent) {
    return CompletedTripsCompanion(
      id: Value(id),
      originStationId: Value(originStationId),
      originName: Value(originName),
      destinationStationId: Value(destinationStationId),
      destinationName: Value(destinationName),
      lineName: lineName == null && nullToAbsent
          ? const Value.absent()
          : Value(lineName),
      departedAt: Value(departedAt),
      arrivedAt: Value(arrivedAt),
      isDemo: Value(isDemo),
      completedAt: Value(completedAt),
    );
  }

  factory CompletedTrip.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CompletedTrip(
      id: serializer.fromJson<String>(json['id']),
      originStationId: serializer.fromJson<String>(json['originStationId']),
      originName: serializer.fromJson<String>(json['originName']),
      destinationStationId: serializer.fromJson<String>(
        json['destinationStationId'],
      ),
      destinationName: serializer.fromJson<String>(json['destinationName']),
      lineName: serializer.fromJson<String?>(json['lineName']),
      departedAt: serializer.fromJson<DateTime>(json['departedAt']),
      arrivedAt: serializer.fromJson<DateTime>(json['arrivedAt']),
      isDemo: serializer.fromJson<bool>(json['isDemo']),
      completedAt: serializer.fromJson<DateTime>(json['completedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'originStationId': serializer.toJson<String>(originStationId),
      'originName': serializer.toJson<String>(originName),
      'destinationStationId': serializer.toJson<String>(destinationStationId),
      'destinationName': serializer.toJson<String>(destinationName),
      'lineName': serializer.toJson<String?>(lineName),
      'departedAt': serializer.toJson<DateTime>(departedAt),
      'arrivedAt': serializer.toJson<DateTime>(arrivedAt),
      'isDemo': serializer.toJson<bool>(isDemo),
      'completedAt': serializer.toJson<DateTime>(completedAt),
    };
  }

  CompletedTrip copyWith({
    String? id,
    String? originStationId,
    String? originName,
    String? destinationStationId,
    String? destinationName,
    Value<String?> lineName = const Value.absent(),
    DateTime? departedAt,
    DateTime? arrivedAt,
    bool? isDemo,
    DateTime? completedAt,
  }) => CompletedTrip(
    id: id ?? this.id,
    originStationId: originStationId ?? this.originStationId,
    originName: originName ?? this.originName,
    destinationStationId: destinationStationId ?? this.destinationStationId,
    destinationName: destinationName ?? this.destinationName,
    lineName: lineName.present ? lineName.value : this.lineName,
    departedAt: departedAt ?? this.departedAt,
    arrivedAt: arrivedAt ?? this.arrivedAt,
    isDemo: isDemo ?? this.isDemo,
    completedAt: completedAt ?? this.completedAt,
  );
  CompletedTrip copyWithCompanion(CompletedTripsCompanion data) {
    return CompletedTrip(
      id: data.id.present ? data.id.value : this.id,
      originStationId: data.originStationId.present
          ? data.originStationId.value
          : this.originStationId,
      originName: data.originName.present
          ? data.originName.value
          : this.originName,
      destinationStationId: data.destinationStationId.present
          ? data.destinationStationId.value
          : this.destinationStationId,
      destinationName: data.destinationName.present
          ? data.destinationName.value
          : this.destinationName,
      lineName: data.lineName.present ? data.lineName.value : this.lineName,
      departedAt: data.departedAt.present
          ? data.departedAt.value
          : this.departedAt,
      arrivedAt: data.arrivedAt.present ? data.arrivedAt.value : this.arrivedAt,
      isDemo: data.isDemo.present ? data.isDemo.value : this.isDemo,
      completedAt: data.completedAt.present
          ? data.completedAt.value
          : this.completedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CompletedTrip(')
          ..write('id: $id, ')
          ..write('originStationId: $originStationId, ')
          ..write('originName: $originName, ')
          ..write('destinationStationId: $destinationStationId, ')
          ..write('destinationName: $destinationName, ')
          ..write('lineName: $lineName, ')
          ..write('departedAt: $departedAt, ')
          ..write('arrivedAt: $arrivedAt, ')
          ..write('isDemo: $isDemo, ')
          ..write('completedAt: $completedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    originStationId,
    originName,
    destinationStationId,
    destinationName,
    lineName,
    departedAt,
    arrivedAt,
    isDemo,
    completedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CompletedTrip &&
          other.id == this.id &&
          other.originStationId == this.originStationId &&
          other.originName == this.originName &&
          other.destinationStationId == this.destinationStationId &&
          other.destinationName == this.destinationName &&
          other.lineName == this.lineName &&
          other.departedAt == this.departedAt &&
          other.arrivedAt == this.arrivedAt &&
          other.isDemo == this.isDemo &&
          other.completedAt == this.completedAt);
}

class CompletedTripsCompanion extends UpdateCompanion<CompletedTrip> {
  final Value<String> id;
  final Value<String> originStationId;
  final Value<String> originName;
  final Value<String> destinationStationId;
  final Value<String> destinationName;
  final Value<String?> lineName;
  final Value<DateTime> departedAt;
  final Value<DateTime> arrivedAt;
  final Value<bool> isDemo;
  final Value<DateTime> completedAt;
  final Value<int> rowid;
  const CompletedTripsCompanion({
    this.id = const Value.absent(),
    this.originStationId = const Value.absent(),
    this.originName = const Value.absent(),
    this.destinationStationId = const Value.absent(),
    this.destinationName = const Value.absent(),
    this.lineName = const Value.absent(),
    this.departedAt = const Value.absent(),
    this.arrivedAt = const Value.absent(),
    this.isDemo = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CompletedTripsCompanion.insert({
    required String id,
    required String originStationId,
    required String originName,
    required String destinationStationId,
    required String destinationName,
    this.lineName = const Value.absent(),
    required DateTime departedAt,
    required DateTime arrivedAt,
    this.isDemo = const Value.absent(),
    required DateTime completedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       originStationId = Value(originStationId),
       originName = Value(originName),
       destinationStationId = Value(destinationStationId),
       destinationName = Value(destinationName),
       departedAt = Value(departedAt),
       arrivedAt = Value(arrivedAt),
       completedAt = Value(completedAt);
  static Insertable<CompletedTrip> custom({
    Expression<String>? id,
    Expression<String>? originStationId,
    Expression<String>? originName,
    Expression<String>? destinationStationId,
    Expression<String>? destinationName,
    Expression<String>? lineName,
    Expression<DateTime>? departedAt,
    Expression<DateTime>? arrivedAt,
    Expression<bool>? isDemo,
    Expression<DateTime>? completedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (originStationId != null) 'origin_station_id': originStationId,
      if (originName != null) 'origin_name': originName,
      if (destinationStationId != null)
        'destination_station_id': destinationStationId,
      if (destinationName != null) 'destination_name': destinationName,
      if (lineName != null) 'line_name': lineName,
      if (departedAt != null) 'departed_at': departedAt,
      if (arrivedAt != null) 'arrived_at': arrivedAt,
      if (isDemo != null) 'is_demo': isDemo,
      if (completedAt != null) 'completed_at': completedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CompletedTripsCompanion copyWith({
    Value<String>? id,
    Value<String>? originStationId,
    Value<String>? originName,
    Value<String>? destinationStationId,
    Value<String>? destinationName,
    Value<String?>? lineName,
    Value<DateTime>? departedAt,
    Value<DateTime>? arrivedAt,
    Value<bool>? isDemo,
    Value<DateTime>? completedAt,
    Value<int>? rowid,
  }) {
    return CompletedTripsCompanion(
      id: id ?? this.id,
      originStationId: originStationId ?? this.originStationId,
      originName: originName ?? this.originName,
      destinationStationId: destinationStationId ?? this.destinationStationId,
      destinationName: destinationName ?? this.destinationName,
      lineName: lineName ?? this.lineName,
      departedAt: departedAt ?? this.departedAt,
      arrivedAt: arrivedAt ?? this.arrivedAt,
      isDemo: isDemo ?? this.isDemo,
      completedAt: completedAt ?? this.completedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (originStationId.present) {
      map['origin_station_id'] = Variable<String>(originStationId.value);
    }
    if (originName.present) {
      map['origin_name'] = Variable<String>(originName.value);
    }
    if (destinationStationId.present) {
      map['destination_station_id'] = Variable<String>(
        destinationStationId.value,
      );
    }
    if (destinationName.present) {
      map['destination_name'] = Variable<String>(destinationName.value);
    }
    if (lineName.present) {
      map['line_name'] = Variable<String>(lineName.value);
    }
    if (departedAt.present) {
      map['departed_at'] = Variable<DateTime>(departedAt.value);
    }
    if (arrivedAt.present) {
      map['arrived_at'] = Variable<DateTime>(arrivedAt.value);
    }
    if (isDemo.present) {
      map['is_demo'] = Variable<bool>(isDemo.value);
    }
    if (completedAt.present) {
      map['completed_at'] = Variable<DateTime>(completedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CompletedTripsCompanion(')
          ..write('id: $id, ')
          ..write('originStationId: $originStationId, ')
          ..write('originName: $originName, ')
          ..write('destinationStationId: $destinationStationId, ')
          ..write('destinationName: $destinationName, ')
          ..write('lineName: $lineName, ')
          ..write('departedAt: $departedAt, ')
          ..write('arrivedAt: $arrivedAt, ')
          ..write('isDemo: $isDemo, ')
          ..write('completedAt: $completedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $NotificationLogEntriesTable extends NotificationLogEntries
    with TableInfo<$NotificationLogEntriesTable, NotificationLogEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $NotificationLogEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _notificationTypeMeta = const VerificationMeta(
    'notificationType',
  );
  @override
  late final GeneratedColumn<String> notificationType = GeneratedColumn<String>(
    'notification_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bodyMeta = const VerificationMeta('body');
  @override
  late final GeneratedColumn<String> body = GeneratedColumn<String>(
    'body',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sentAtMeta = const VerificationMeta('sentAt');
  @override
  late final GeneratedColumn<DateTime> sentAt = GeneratedColumn<DateTime>(
    'sent_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    notificationType,
    title,
    body,
    sentAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'notification_log_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<NotificationLogEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('notification_type')) {
      context.handle(
        _notificationTypeMeta,
        notificationType.isAcceptableOrUnknown(
          data['notification_type']!,
          _notificationTypeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_notificationTypeMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('body')) {
      context.handle(
        _bodyMeta,
        body.isAcceptableOrUnknown(data['body']!, _bodyMeta),
      );
    } else if (isInserting) {
      context.missing(_bodyMeta);
    }
    if (data.containsKey('sent_at')) {
      context.handle(
        _sentAtMeta,
        sentAt.isAcceptableOrUnknown(data['sent_at']!, _sentAtMeta),
      );
    } else if (isInserting) {
      context.missing(_sentAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  NotificationLogEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return NotificationLogEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      notificationType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notification_type'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      body: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}body'],
      )!,
      sentAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}sent_at'],
      )!,
    );
  }

  @override
  $NotificationLogEntriesTable createAlias(String alias) {
    return $NotificationLogEntriesTable(attachedDatabase, alias);
  }
}

class NotificationLogEntry extends DataClass
    implements Insertable<NotificationLogEntry> {
  final int id;
  final String notificationType;
  final String title;
  final String body;
  final DateTime sentAt;
  const NotificationLogEntry({
    required this.id,
    required this.notificationType,
    required this.title,
    required this.body,
    required this.sentAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['notification_type'] = Variable<String>(notificationType);
    map['title'] = Variable<String>(title);
    map['body'] = Variable<String>(body);
    map['sent_at'] = Variable<DateTime>(sentAt);
    return map;
  }

  NotificationLogEntriesCompanion toCompanion(bool nullToAbsent) {
    return NotificationLogEntriesCompanion(
      id: Value(id),
      notificationType: Value(notificationType),
      title: Value(title),
      body: Value(body),
      sentAt: Value(sentAt),
    );
  }

  factory NotificationLogEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return NotificationLogEntry(
      id: serializer.fromJson<int>(json['id']),
      notificationType: serializer.fromJson<String>(json['notificationType']),
      title: serializer.fromJson<String>(json['title']),
      body: serializer.fromJson<String>(json['body']),
      sentAt: serializer.fromJson<DateTime>(json['sentAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'notificationType': serializer.toJson<String>(notificationType),
      'title': serializer.toJson<String>(title),
      'body': serializer.toJson<String>(body),
      'sentAt': serializer.toJson<DateTime>(sentAt),
    };
  }

  NotificationLogEntry copyWith({
    int? id,
    String? notificationType,
    String? title,
    String? body,
    DateTime? sentAt,
  }) => NotificationLogEntry(
    id: id ?? this.id,
    notificationType: notificationType ?? this.notificationType,
    title: title ?? this.title,
    body: body ?? this.body,
    sentAt: sentAt ?? this.sentAt,
  );
  NotificationLogEntry copyWithCompanion(NotificationLogEntriesCompanion data) {
    return NotificationLogEntry(
      id: data.id.present ? data.id.value : this.id,
      notificationType: data.notificationType.present
          ? data.notificationType.value
          : this.notificationType,
      title: data.title.present ? data.title.value : this.title,
      body: data.body.present ? data.body.value : this.body,
      sentAt: data.sentAt.present ? data.sentAt.value : this.sentAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('NotificationLogEntry(')
          ..write('id: $id, ')
          ..write('notificationType: $notificationType, ')
          ..write('title: $title, ')
          ..write('body: $body, ')
          ..write('sentAt: $sentAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, notificationType, title, body, sentAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is NotificationLogEntry &&
          other.id == this.id &&
          other.notificationType == this.notificationType &&
          other.title == this.title &&
          other.body == this.body &&
          other.sentAt == this.sentAt);
}

class NotificationLogEntriesCompanion
    extends UpdateCompanion<NotificationLogEntry> {
  final Value<int> id;
  final Value<String> notificationType;
  final Value<String> title;
  final Value<String> body;
  final Value<DateTime> sentAt;
  const NotificationLogEntriesCompanion({
    this.id = const Value.absent(),
    this.notificationType = const Value.absent(),
    this.title = const Value.absent(),
    this.body = const Value.absent(),
    this.sentAt = const Value.absent(),
  });
  NotificationLogEntriesCompanion.insert({
    this.id = const Value.absent(),
    required String notificationType,
    required String title,
    required String body,
    required DateTime sentAt,
  }) : notificationType = Value(notificationType),
       title = Value(title),
       body = Value(body),
       sentAt = Value(sentAt);
  static Insertable<NotificationLogEntry> custom({
    Expression<int>? id,
    Expression<String>? notificationType,
    Expression<String>? title,
    Expression<String>? body,
    Expression<DateTime>? sentAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (notificationType != null) 'notification_type': notificationType,
      if (title != null) 'title': title,
      if (body != null) 'body': body,
      if (sentAt != null) 'sent_at': sentAt,
    });
  }

  NotificationLogEntriesCompanion copyWith({
    Value<int>? id,
    Value<String>? notificationType,
    Value<String>? title,
    Value<String>? body,
    Value<DateTime>? sentAt,
  }) {
    return NotificationLogEntriesCompanion(
      id: id ?? this.id,
      notificationType: notificationType ?? this.notificationType,
      title: title ?? this.title,
      body: body ?? this.body,
      sentAt: sentAt ?? this.sentAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (notificationType.present) {
      map['notification_type'] = Variable<String>(notificationType.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (body.present) {
      map['body'] = Variable<String>(body.value);
    }
    if (sentAt.present) {
      map['sent_at'] = Variable<DateTime>(sentAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('NotificationLogEntriesCompanion(')
          ..write('id: $id, ')
          ..write('notificationType: $notificationType, ')
          ..write('title: $title, ')
          ..write('body: $body, ')
          ..write('sentAt: $sentAt')
          ..write(')'))
        .toString();
  }
}

class $UserReportsTable extends UserReports
    with TableInfo<$UserReportsTable, UserReport> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $UserReportsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _categoryMeta = const VerificationMeta(
    'category',
  );
  @override
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
    'category',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, category, description, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_user_reports';
  @override
  VerificationContext validateIntegrity(
    Insertable<UserReport> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('category')) {
      context.handle(
        _categoryMeta,
        category.isAcceptableOrUnknown(data['category']!, _categoryMeta),
      );
    } else if (isInserting) {
      context.missing(_categoryMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_descriptionMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  UserReport map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return UserReport(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      category: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $UserReportsTable createAlias(String alias) {
    return $UserReportsTable(attachedDatabase, alias);
  }
}

class UserReport extends DataClass implements Insertable<UserReport> {
  final int id;
  final String category;
  final String description;
  final DateTime createdAt;
  const UserReport({
    required this.id,
    required this.category,
    required this.description,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['category'] = Variable<String>(category);
    map['description'] = Variable<String>(description);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  UserReportsCompanion toCompanion(bool nullToAbsent) {
    return UserReportsCompanion(
      id: Value(id),
      category: Value(category),
      description: Value(description),
      createdAt: Value(createdAt),
    );
  }

  factory UserReport.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return UserReport(
      id: serializer.fromJson<int>(json['id']),
      category: serializer.fromJson<String>(json['category']),
      description: serializer.fromJson<String>(json['description']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'category': serializer.toJson<String>(category),
      'description': serializer.toJson<String>(description),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  UserReport copyWith({
    int? id,
    String? category,
    String? description,
    DateTime? createdAt,
  }) => UserReport(
    id: id ?? this.id,
    category: category ?? this.category,
    description: description ?? this.description,
    createdAt: createdAt ?? this.createdAt,
  );
  UserReport copyWithCompanion(UserReportsCompanion data) {
    return UserReport(
      id: data.id.present ? data.id.value : this.id,
      category: data.category.present ? data.category.value : this.category,
      description: data.description.present
          ? data.description.value
          : this.description,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('UserReport(')
          ..write('id: $id, ')
          ..write('category: $category, ')
          ..write('description: $description, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, category, description, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UserReport &&
          other.id == this.id &&
          other.category == this.category &&
          other.description == this.description &&
          other.createdAt == this.createdAt);
}

class UserReportsCompanion extends UpdateCompanion<UserReport> {
  final Value<int> id;
  final Value<String> category;
  final Value<String> description;
  final Value<DateTime> createdAt;
  const UserReportsCompanion({
    this.id = const Value.absent(),
    this.category = const Value.absent(),
    this.description = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  UserReportsCompanion.insert({
    this.id = const Value.absent(),
    required String category,
    required String description,
    required DateTime createdAt,
  }) : category = Value(category),
       description = Value(description),
       createdAt = Value(createdAt);
  static Insertable<UserReport> custom({
    Expression<int>? id,
    Expression<String>? category,
    Expression<String>? description,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (category != null) 'category': category,
      if (description != null) 'description': description,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  UserReportsCompanion copyWith({
    Value<int>? id,
    Value<String>? category,
    Value<String>? description,
    Value<DateTime>? createdAt,
  }) {
    return UserReportsCompanion(
      id: id ?? this.id,
      category: category ?? this.category,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UserReportsCompanion(')
          ..write('id: $id, ')
          ..write('category: $category, ')
          ..write('description: $description, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $CachedStationsTable cachedStations = $CachedStationsTable(this);
  late final $FavoriteRoutesTable favoriteRoutes = $FavoriteRoutesTable(this);
  late final $ActiveTripSnapshotsTable activeTripSnapshots =
      $ActiveTripSnapshotsTable(this);
  late final $CompletedTripsTable completedTrips = $CompletedTripsTable(this);
  late final $NotificationLogEntriesTable notificationLogEntries =
      $NotificationLogEntriesTable(this);
  late final $UserReportsTable userReports = $UserReportsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    cachedStations,
    favoriteRoutes,
    activeTripSnapshots,
    completedTrips,
    notificationLogEntries,
    userReports,
  ];
}

typedef $$CachedStationsTableCreateCompanionBuilder =
    CachedStationsCompanion Function({
      required String id,
      required String code,
      required String name,
      required double latitude,
      required double longitude,
      required String payloadJson,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$CachedStationsTableUpdateCompanionBuilder =
    CachedStationsCompanion Function({
      Value<String> id,
      Value<String> code,
      Value<String> name,
      Value<double> latitude,
      Value<double> longitude,
      Value<String> payloadJson,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$CachedStationsTableFilterComposer
    extends Composer<_$AppDatabase, $CachedStationsTable> {
  $$CachedStationsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get code => $composableBuilder(
    column: $table.code,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get latitude => $composableBuilder(
    column: $table.latitude,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get longitude => $composableBuilder(
    column: $table.longitude,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CachedStationsTableOrderingComposer
    extends Composer<_$AppDatabase, $CachedStationsTable> {
  $$CachedStationsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get code => $composableBuilder(
    column: $table.code,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get latitude => $composableBuilder(
    column: $table.latitude,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get longitude => $composableBuilder(
    column: $table.longitude,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CachedStationsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CachedStationsTable> {
  $$CachedStationsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get code =>
      $composableBuilder(column: $table.code, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<double> get latitude =>
      $composableBuilder(column: $table.latitude, builder: (column) => column);

  GeneratedColumn<double> get longitude =>
      $composableBuilder(column: $table.longitude, builder: (column) => column);

  GeneratedColumn<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$CachedStationsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CachedStationsTable,
          CachedStation,
          $$CachedStationsTableFilterComposer,
          $$CachedStationsTableOrderingComposer,
          $$CachedStationsTableAnnotationComposer,
          $$CachedStationsTableCreateCompanionBuilder,
          $$CachedStationsTableUpdateCompanionBuilder,
          (
            CachedStation,
            BaseReferences<_$AppDatabase, $CachedStationsTable, CachedStation>,
          ),
          CachedStation,
          PrefetchHooks Function()
        > {
  $$CachedStationsTableTableManager(
    _$AppDatabase db,
    $CachedStationsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CachedStationsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CachedStationsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CachedStationsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> code = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<double> latitude = const Value.absent(),
                Value<double> longitude = const Value.absent(),
                Value<String> payloadJson = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CachedStationsCompanion(
                id: id,
                code: code,
                name: name,
                latitude: latitude,
                longitude: longitude,
                payloadJson: payloadJson,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String code,
                required String name,
                required double latitude,
                required double longitude,
                required String payloadJson,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => CachedStationsCompanion.insert(
                id: id,
                code: code,
                name: name,
                latitude: latitude,
                longitude: longitude,
                payloadJson: payloadJson,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CachedStationsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CachedStationsTable,
      CachedStation,
      $$CachedStationsTableFilterComposer,
      $$CachedStationsTableOrderingComposer,
      $$CachedStationsTableAnnotationComposer,
      $$CachedStationsTableCreateCompanionBuilder,
      $$CachedStationsTableUpdateCompanionBuilder,
      (
        CachedStation,
        BaseReferences<_$AppDatabase, $CachedStationsTable, CachedStation>,
      ),
      CachedStation,
      PrefetchHooks Function()
    >;
typedef $$FavoriteRoutesTableCreateCompanionBuilder =
    FavoriteRoutesCompanion Function({
      required String id,
      required String originStationId,
      required String destinationStationId,
      required String label,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$FavoriteRoutesTableUpdateCompanionBuilder =
    FavoriteRoutesCompanion Function({
      Value<String> id,
      Value<String> originStationId,
      Value<String> destinationStationId,
      Value<String> label,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

class $$FavoriteRoutesTableFilterComposer
    extends Composer<_$AppDatabase, $FavoriteRoutesTable> {
  $$FavoriteRoutesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get originStationId => $composableBuilder(
    column: $table.originStationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get destinationStationId => $composableBuilder(
    column: $table.destinationStationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$FavoriteRoutesTableOrderingComposer
    extends Composer<_$AppDatabase, $FavoriteRoutesTable> {
  $$FavoriteRoutesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get originStationId => $composableBuilder(
    column: $table.originStationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get destinationStationId => $composableBuilder(
    column: $table.destinationStationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$FavoriteRoutesTableAnnotationComposer
    extends Composer<_$AppDatabase, $FavoriteRoutesTable> {
  $$FavoriteRoutesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get originStationId => $composableBuilder(
    column: $table.originStationId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get destinationStationId => $composableBuilder(
    column: $table.destinationStationId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get label =>
      $composableBuilder(column: $table.label, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$FavoriteRoutesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $FavoriteRoutesTable,
          FavoriteRoute,
          $$FavoriteRoutesTableFilterComposer,
          $$FavoriteRoutesTableOrderingComposer,
          $$FavoriteRoutesTableAnnotationComposer,
          $$FavoriteRoutesTableCreateCompanionBuilder,
          $$FavoriteRoutesTableUpdateCompanionBuilder,
          (
            FavoriteRoute,
            BaseReferences<_$AppDatabase, $FavoriteRoutesTable, FavoriteRoute>,
          ),
          FavoriteRoute,
          PrefetchHooks Function()
        > {
  $$FavoriteRoutesTableTableManager(
    _$AppDatabase db,
    $FavoriteRoutesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FavoriteRoutesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FavoriteRoutesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FavoriteRoutesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> originStationId = const Value.absent(),
                Value<String> destinationStationId = const Value.absent(),
                Value<String> label = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FavoriteRoutesCompanion(
                id: id,
                originStationId: originStationId,
                destinationStationId: destinationStationId,
                label: label,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String originStationId,
                required String destinationStationId,
                required String label,
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => FavoriteRoutesCompanion.insert(
                id: id,
                originStationId: originStationId,
                destinationStationId: destinationStationId,
                label: label,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$FavoriteRoutesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $FavoriteRoutesTable,
      FavoriteRoute,
      $$FavoriteRoutesTableFilterComposer,
      $$FavoriteRoutesTableOrderingComposer,
      $$FavoriteRoutesTableAnnotationComposer,
      $$FavoriteRoutesTableCreateCompanionBuilder,
      $$FavoriteRoutesTableUpdateCompanionBuilder,
      (
        FavoriteRoute,
        BaseReferences<_$AppDatabase, $FavoriteRoutesTable, FavoriteRoute>,
      ),
      FavoriteRoute,
      PrefetchHooks Function()
    >;
typedef $$ActiveTripSnapshotsTableCreateCompanionBuilder =
    ActiveTripSnapshotsCompanion Function({
      required String id,
      required String payloadJson,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$ActiveTripSnapshotsTableUpdateCompanionBuilder =
    ActiveTripSnapshotsCompanion Function({
      Value<String> id,
      Value<String> payloadJson,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$ActiveTripSnapshotsTableFilterComposer
    extends Composer<_$AppDatabase, $ActiveTripSnapshotsTable> {
  $$ActiveTripSnapshotsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ActiveTripSnapshotsTableOrderingComposer
    extends Composer<_$AppDatabase, $ActiveTripSnapshotsTable> {
  $$ActiveTripSnapshotsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ActiveTripSnapshotsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ActiveTripSnapshotsTable> {
  $$ActiveTripSnapshotsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$ActiveTripSnapshotsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ActiveTripSnapshotsTable,
          ActiveTripSnapshot,
          $$ActiveTripSnapshotsTableFilterComposer,
          $$ActiveTripSnapshotsTableOrderingComposer,
          $$ActiveTripSnapshotsTableAnnotationComposer,
          $$ActiveTripSnapshotsTableCreateCompanionBuilder,
          $$ActiveTripSnapshotsTableUpdateCompanionBuilder,
          (
            ActiveTripSnapshot,
            BaseReferences<
              _$AppDatabase,
              $ActiveTripSnapshotsTable,
              ActiveTripSnapshot
            >,
          ),
          ActiveTripSnapshot,
          PrefetchHooks Function()
        > {
  $$ActiveTripSnapshotsTableTableManager(
    _$AppDatabase db,
    $ActiveTripSnapshotsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ActiveTripSnapshotsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ActiveTripSnapshotsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$ActiveTripSnapshotsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> payloadJson = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ActiveTripSnapshotsCompanion(
                id: id,
                payloadJson: payloadJson,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String payloadJson,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => ActiveTripSnapshotsCompanion.insert(
                id: id,
                payloadJson: payloadJson,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ActiveTripSnapshotsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ActiveTripSnapshotsTable,
      ActiveTripSnapshot,
      $$ActiveTripSnapshotsTableFilterComposer,
      $$ActiveTripSnapshotsTableOrderingComposer,
      $$ActiveTripSnapshotsTableAnnotationComposer,
      $$ActiveTripSnapshotsTableCreateCompanionBuilder,
      $$ActiveTripSnapshotsTableUpdateCompanionBuilder,
      (
        ActiveTripSnapshot,
        BaseReferences<
          _$AppDatabase,
          $ActiveTripSnapshotsTable,
          ActiveTripSnapshot
        >,
      ),
      ActiveTripSnapshot,
      PrefetchHooks Function()
    >;
typedef $$CompletedTripsTableCreateCompanionBuilder =
    CompletedTripsCompanion Function({
      required String id,
      required String originStationId,
      required String originName,
      required String destinationStationId,
      required String destinationName,
      Value<String?> lineName,
      required DateTime departedAt,
      required DateTime arrivedAt,
      Value<bool> isDemo,
      required DateTime completedAt,
      Value<int> rowid,
    });
typedef $$CompletedTripsTableUpdateCompanionBuilder =
    CompletedTripsCompanion Function({
      Value<String> id,
      Value<String> originStationId,
      Value<String> originName,
      Value<String> destinationStationId,
      Value<String> destinationName,
      Value<String?> lineName,
      Value<DateTime> departedAt,
      Value<DateTime> arrivedAt,
      Value<bool> isDemo,
      Value<DateTime> completedAt,
      Value<int> rowid,
    });

class $$CompletedTripsTableFilterComposer
    extends Composer<_$AppDatabase, $CompletedTripsTable> {
  $$CompletedTripsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get originStationId => $composableBuilder(
    column: $table.originStationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get originName => $composableBuilder(
    column: $table.originName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get destinationStationId => $composableBuilder(
    column: $table.destinationStationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get destinationName => $composableBuilder(
    column: $table.destinationName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lineName => $composableBuilder(
    column: $table.lineName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get departedAt => $composableBuilder(
    column: $table.departedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get arrivedAt => $composableBuilder(
    column: $table.arrivedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isDemo => $composableBuilder(
    column: $table.isDemo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CompletedTripsTableOrderingComposer
    extends Composer<_$AppDatabase, $CompletedTripsTable> {
  $$CompletedTripsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get originStationId => $composableBuilder(
    column: $table.originStationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get originName => $composableBuilder(
    column: $table.originName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get destinationStationId => $composableBuilder(
    column: $table.destinationStationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get destinationName => $composableBuilder(
    column: $table.destinationName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lineName => $composableBuilder(
    column: $table.lineName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get departedAt => $composableBuilder(
    column: $table.departedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get arrivedAt => $composableBuilder(
    column: $table.arrivedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isDemo => $composableBuilder(
    column: $table.isDemo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CompletedTripsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CompletedTripsTable> {
  $$CompletedTripsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get originStationId => $composableBuilder(
    column: $table.originStationId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get originName => $composableBuilder(
    column: $table.originName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get destinationStationId => $composableBuilder(
    column: $table.destinationStationId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get destinationName => $composableBuilder(
    column: $table.destinationName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lineName =>
      $composableBuilder(column: $table.lineName, builder: (column) => column);

  GeneratedColumn<DateTime> get departedAt => $composableBuilder(
    column: $table.departedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get arrivedAt =>
      $composableBuilder(column: $table.arrivedAt, builder: (column) => column);

  GeneratedColumn<bool> get isDemo =>
      $composableBuilder(column: $table.isDemo, builder: (column) => column);

  GeneratedColumn<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => column,
  );
}

class $$CompletedTripsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CompletedTripsTable,
          CompletedTrip,
          $$CompletedTripsTableFilterComposer,
          $$CompletedTripsTableOrderingComposer,
          $$CompletedTripsTableAnnotationComposer,
          $$CompletedTripsTableCreateCompanionBuilder,
          $$CompletedTripsTableUpdateCompanionBuilder,
          (
            CompletedTrip,
            BaseReferences<_$AppDatabase, $CompletedTripsTable, CompletedTrip>,
          ),
          CompletedTrip,
          PrefetchHooks Function()
        > {
  $$CompletedTripsTableTableManager(
    _$AppDatabase db,
    $CompletedTripsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CompletedTripsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CompletedTripsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CompletedTripsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> originStationId = const Value.absent(),
                Value<String> originName = const Value.absent(),
                Value<String> destinationStationId = const Value.absent(),
                Value<String> destinationName = const Value.absent(),
                Value<String?> lineName = const Value.absent(),
                Value<DateTime> departedAt = const Value.absent(),
                Value<DateTime> arrivedAt = const Value.absent(),
                Value<bool> isDemo = const Value.absent(),
                Value<DateTime> completedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CompletedTripsCompanion(
                id: id,
                originStationId: originStationId,
                originName: originName,
                destinationStationId: destinationStationId,
                destinationName: destinationName,
                lineName: lineName,
                departedAt: departedAt,
                arrivedAt: arrivedAt,
                isDemo: isDemo,
                completedAt: completedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String originStationId,
                required String originName,
                required String destinationStationId,
                required String destinationName,
                Value<String?> lineName = const Value.absent(),
                required DateTime departedAt,
                required DateTime arrivedAt,
                Value<bool> isDemo = const Value.absent(),
                required DateTime completedAt,
                Value<int> rowid = const Value.absent(),
              }) => CompletedTripsCompanion.insert(
                id: id,
                originStationId: originStationId,
                originName: originName,
                destinationStationId: destinationStationId,
                destinationName: destinationName,
                lineName: lineName,
                departedAt: departedAt,
                arrivedAt: arrivedAt,
                isDemo: isDemo,
                completedAt: completedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CompletedTripsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CompletedTripsTable,
      CompletedTrip,
      $$CompletedTripsTableFilterComposer,
      $$CompletedTripsTableOrderingComposer,
      $$CompletedTripsTableAnnotationComposer,
      $$CompletedTripsTableCreateCompanionBuilder,
      $$CompletedTripsTableUpdateCompanionBuilder,
      (
        CompletedTrip,
        BaseReferences<_$AppDatabase, $CompletedTripsTable, CompletedTrip>,
      ),
      CompletedTrip,
      PrefetchHooks Function()
    >;
typedef $$NotificationLogEntriesTableCreateCompanionBuilder =
    NotificationLogEntriesCompanion Function({
      Value<int> id,
      required String notificationType,
      required String title,
      required String body,
      required DateTime sentAt,
    });
typedef $$NotificationLogEntriesTableUpdateCompanionBuilder =
    NotificationLogEntriesCompanion Function({
      Value<int> id,
      Value<String> notificationType,
      Value<String> title,
      Value<String> body,
      Value<DateTime> sentAt,
    });

class $$NotificationLogEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $NotificationLogEntriesTable> {
  $$NotificationLogEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notificationType => $composableBuilder(
    column: $table.notificationType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get sentAt => $composableBuilder(
    column: $table.sentAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$NotificationLogEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $NotificationLogEntriesTable> {
  $$NotificationLogEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notificationType => $composableBuilder(
    column: $table.notificationType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get sentAt => $composableBuilder(
    column: $table.sentAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$NotificationLogEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $NotificationLogEntriesTable> {
  $$NotificationLogEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get notificationType => $composableBuilder(
    column: $table.notificationType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get body =>
      $composableBuilder(column: $table.body, builder: (column) => column);

  GeneratedColumn<DateTime> get sentAt =>
      $composableBuilder(column: $table.sentAt, builder: (column) => column);
}

class $$NotificationLogEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $NotificationLogEntriesTable,
          NotificationLogEntry,
          $$NotificationLogEntriesTableFilterComposer,
          $$NotificationLogEntriesTableOrderingComposer,
          $$NotificationLogEntriesTableAnnotationComposer,
          $$NotificationLogEntriesTableCreateCompanionBuilder,
          $$NotificationLogEntriesTableUpdateCompanionBuilder,
          (
            NotificationLogEntry,
            BaseReferences<
              _$AppDatabase,
              $NotificationLogEntriesTable,
              NotificationLogEntry
            >,
          ),
          NotificationLogEntry,
          PrefetchHooks Function()
        > {
  $$NotificationLogEntriesTableTableManager(
    _$AppDatabase db,
    $NotificationLogEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$NotificationLogEntriesTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$NotificationLogEntriesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$NotificationLogEntriesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> notificationType = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> body = const Value.absent(),
                Value<DateTime> sentAt = const Value.absent(),
              }) => NotificationLogEntriesCompanion(
                id: id,
                notificationType: notificationType,
                title: title,
                body: body,
                sentAt: sentAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String notificationType,
                required String title,
                required String body,
                required DateTime sentAt,
              }) => NotificationLogEntriesCompanion.insert(
                id: id,
                notificationType: notificationType,
                title: title,
                body: body,
                sentAt: sentAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$NotificationLogEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $NotificationLogEntriesTable,
      NotificationLogEntry,
      $$NotificationLogEntriesTableFilterComposer,
      $$NotificationLogEntriesTableOrderingComposer,
      $$NotificationLogEntriesTableAnnotationComposer,
      $$NotificationLogEntriesTableCreateCompanionBuilder,
      $$NotificationLogEntriesTableUpdateCompanionBuilder,
      (
        NotificationLogEntry,
        BaseReferences<
          _$AppDatabase,
          $NotificationLogEntriesTable,
          NotificationLogEntry
        >,
      ),
      NotificationLogEntry,
      PrefetchHooks Function()
    >;
typedef $$UserReportsTableCreateCompanionBuilder =
    UserReportsCompanion Function({
      Value<int> id,
      required String category,
      required String description,
      required DateTime createdAt,
    });
typedef $$UserReportsTableUpdateCompanionBuilder =
    UserReportsCompanion Function({
      Value<int> id,
      Value<String> category,
      Value<String> description,
      Value<DateTime> createdAt,
    });

class $$UserReportsTableFilterComposer
    extends Composer<_$AppDatabase, $UserReportsTable> {
  $$UserReportsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$UserReportsTableOrderingComposer
    extends Composer<_$AppDatabase, $UserReportsTable> {
  $$UserReportsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$UserReportsTableAnnotationComposer
    extends Composer<_$AppDatabase, $UserReportsTable> {
  $$UserReportsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$UserReportsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $UserReportsTable,
          UserReport,
          $$UserReportsTableFilterComposer,
          $$UserReportsTableOrderingComposer,
          $$UserReportsTableAnnotationComposer,
          $$UserReportsTableCreateCompanionBuilder,
          $$UserReportsTableUpdateCompanionBuilder,
          (
            UserReport,
            BaseReferences<_$AppDatabase, $UserReportsTable, UserReport>,
          ),
          UserReport,
          PrefetchHooks Function()
        > {
  $$UserReportsTableTableManager(_$AppDatabase db, $UserReportsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$UserReportsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$UserReportsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$UserReportsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> category = const Value.absent(),
                Value<String> description = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => UserReportsCompanion(
                id: id,
                category: category,
                description: description,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String category,
                required String description,
                required DateTime createdAt,
              }) => UserReportsCompanion.insert(
                id: id,
                category: category,
                description: description,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$UserReportsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $UserReportsTable,
      UserReport,
      $$UserReportsTableFilterComposer,
      $$UserReportsTableOrderingComposer,
      $$UserReportsTableAnnotationComposer,
      $$UserReportsTableCreateCompanionBuilder,
      $$UserReportsTableUpdateCompanionBuilder,
      (
        UserReport,
        BaseReferences<_$AppDatabase, $UserReportsTable, UserReport>,
      ),
      UserReport,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$CachedStationsTableTableManager get cachedStations =>
      $$CachedStationsTableTableManager(_db, _db.cachedStations);
  $$FavoriteRoutesTableTableManager get favoriteRoutes =>
      $$FavoriteRoutesTableTableManager(_db, _db.favoriteRoutes);
  $$ActiveTripSnapshotsTableTableManager get activeTripSnapshots =>
      $$ActiveTripSnapshotsTableTableManager(_db, _db.activeTripSnapshots);
  $$CompletedTripsTableTableManager get completedTrips =>
      $$CompletedTripsTableTableManager(_db, _db.completedTrips);
  $$NotificationLogEntriesTableTableManager get notificationLogEntries =>
      $$NotificationLogEntriesTableTableManager(
        _db,
        _db.notificationLogEntries,
      );
  $$UserReportsTableTableManager get userReports =>
      $$UserReportsTableTableManager(_db, _db.userReports);
}
