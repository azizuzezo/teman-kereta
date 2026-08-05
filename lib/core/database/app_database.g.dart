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

class $GtfsStopsTable extends GtfsStops
    with TableInfo<$GtfsStopsTable, GtfsStop> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $GtfsStopsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
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
  @override
  List<GeneratedColumn> get $columns => [id, name, latitude, longitude];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'gtfs_stops';
  @override
  VerificationContext validateIntegrity(
    Insertable<GtfsStop> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
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
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  GtfsStop map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return GtfsStop(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
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
    );
  }

  @override
  $GtfsStopsTable createAlias(String alias) {
    return $GtfsStopsTable(attachedDatabase, alias);
  }
}

class GtfsStop extends DataClass implements Insertable<GtfsStop> {
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  const GtfsStop({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['latitude'] = Variable<double>(latitude);
    map['longitude'] = Variable<double>(longitude);
    return map;
  }

  GtfsStopsCompanion toCompanion(bool nullToAbsent) {
    return GtfsStopsCompanion(
      id: Value(id),
      name: Value(name),
      latitude: Value(latitude),
      longitude: Value(longitude),
    );
  }

  factory GtfsStop.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return GtfsStop(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      latitude: serializer.fromJson<double>(json['latitude']),
      longitude: serializer.fromJson<double>(json['longitude']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'latitude': serializer.toJson<double>(latitude),
      'longitude': serializer.toJson<double>(longitude),
    };
  }

  GtfsStop copyWith({
    String? id,
    String? name,
    double? latitude,
    double? longitude,
  }) => GtfsStop(
    id: id ?? this.id,
    name: name ?? this.name,
    latitude: latitude ?? this.latitude,
    longitude: longitude ?? this.longitude,
  );
  GtfsStop copyWithCompanion(GtfsStopsCompanion data) {
    return GtfsStop(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      latitude: data.latitude.present ? data.latitude.value : this.latitude,
      longitude: data.longitude.present ? data.longitude.value : this.longitude,
    );
  }

  @override
  String toString() {
    return (StringBuffer('GtfsStop(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('latitude: $latitude, ')
          ..write('longitude: $longitude')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, latitude, longitude);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GtfsStop &&
          other.id == this.id &&
          other.name == this.name &&
          other.latitude == this.latitude &&
          other.longitude == this.longitude);
}

class GtfsStopsCompanion extends UpdateCompanion<GtfsStop> {
  final Value<String> id;
  final Value<String> name;
  final Value<double> latitude;
  final Value<double> longitude;
  final Value<int> rowid;
  const GtfsStopsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.latitude = const Value.absent(),
    this.longitude = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  GtfsStopsCompanion.insert({
    required String id,
    required String name,
    required double latitude,
    required double longitude,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       latitude = Value(latitude),
       longitude = Value(longitude);
  static Insertable<GtfsStop> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<double>? latitude,
    Expression<double>? longitude,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (rowid != null) 'rowid': rowid,
    });
  }

  GtfsStopsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<double>? latitude,
    Value<double>? longitude,
    Value<int>? rowid,
  }) {
    return GtfsStopsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
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
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('GtfsStopsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('latitude: $latitude, ')
          ..write('longitude: $longitude, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $GtfsRoutesTable extends GtfsRoutes
    with TableInfo<$GtfsRoutesTable, GtfsRoute> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $GtfsRoutesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _shortNameMeta = const VerificationMeta(
    'shortName',
  );
  @override
  late final GeneratedColumn<String> shortName = GeneratedColumn<String>(
    'short_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _longNameMeta = const VerificationMeta(
    'longName',
  );
  @override
  late final GeneratedColumn<String> longName = GeneratedColumn<String>(
    'long_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _colorMeta = const VerificationMeta('color');
  @override
  late final GeneratedColumn<String> color = GeneratedColumn<String>(
    'color',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [id, shortName, longName, color];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'gtfs_routes';
  @override
  VerificationContext validateIntegrity(
    Insertable<GtfsRoute> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('short_name')) {
      context.handle(
        _shortNameMeta,
        shortName.isAcceptableOrUnknown(data['short_name']!, _shortNameMeta),
      );
    }
    if (data.containsKey('long_name')) {
      context.handle(
        _longNameMeta,
        longName.isAcceptableOrUnknown(data['long_name']!, _longNameMeta),
      );
    }
    if (data.containsKey('color')) {
      context.handle(
        _colorMeta,
        color.isAcceptableOrUnknown(data['color']!, _colorMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  GtfsRoute map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return GtfsRoute(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      shortName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}short_name'],
      ),
      longName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}long_name'],
      ),
      color: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}color'],
      ),
    );
  }

  @override
  $GtfsRoutesTable createAlias(String alias) {
    return $GtfsRoutesTable(attachedDatabase, alias);
  }
}

class GtfsRoute extends DataClass implements Insertable<GtfsRoute> {
  final String id;
  final String? shortName;
  final String? longName;
  final String? color;
  const GtfsRoute({
    required this.id,
    this.shortName,
    this.longName,
    this.color,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || shortName != null) {
      map['short_name'] = Variable<String>(shortName);
    }
    if (!nullToAbsent || longName != null) {
      map['long_name'] = Variable<String>(longName);
    }
    if (!nullToAbsent || color != null) {
      map['color'] = Variable<String>(color);
    }
    return map;
  }

  GtfsRoutesCompanion toCompanion(bool nullToAbsent) {
    return GtfsRoutesCompanion(
      id: Value(id),
      shortName: shortName == null && nullToAbsent
          ? const Value.absent()
          : Value(shortName),
      longName: longName == null && nullToAbsent
          ? const Value.absent()
          : Value(longName),
      color: color == null && nullToAbsent
          ? const Value.absent()
          : Value(color),
    );
  }

  factory GtfsRoute.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return GtfsRoute(
      id: serializer.fromJson<String>(json['id']),
      shortName: serializer.fromJson<String?>(json['shortName']),
      longName: serializer.fromJson<String?>(json['longName']),
      color: serializer.fromJson<String?>(json['color']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'shortName': serializer.toJson<String?>(shortName),
      'longName': serializer.toJson<String?>(longName),
      'color': serializer.toJson<String?>(color),
    };
  }

  GtfsRoute copyWith({
    String? id,
    Value<String?> shortName = const Value.absent(),
    Value<String?> longName = const Value.absent(),
    Value<String?> color = const Value.absent(),
  }) => GtfsRoute(
    id: id ?? this.id,
    shortName: shortName.present ? shortName.value : this.shortName,
    longName: longName.present ? longName.value : this.longName,
    color: color.present ? color.value : this.color,
  );
  GtfsRoute copyWithCompanion(GtfsRoutesCompanion data) {
    return GtfsRoute(
      id: data.id.present ? data.id.value : this.id,
      shortName: data.shortName.present ? data.shortName.value : this.shortName,
      longName: data.longName.present ? data.longName.value : this.longName,
      color: data.color.present ? data.color.value : this.color,
    );
  }

  @override
  String toString() {
    return (StringBuffer('GtfsRoute(')
          ..write('id: $id, ')
          ..write('shortName: $shortName, ')
          ..write('longName: $longName, ')
          ..write('color: $color')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, shortName, longName, color);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GtfsRoute &&
          other.id == this.id &&
          other.shortName == this.shortName &&
          other.longName == this.longName &&
          other.color == this.color);
}

class GtfsRoutesCompanion extends UpdateCompanion<GtfsRoute> {
  final Value<String> id;
  final Value<String?> shortName;
  final Value<String?> longName;
  final Value<String?> color;
  final Value<int> rowid;
  const GtfsRoutesCompanion({
    this.id = const Value.absent(),
    this.shortName = const Value.absent(),
    this.longName = const Value.absent(),
    this.color = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  GtfsRoutesCompanion.insert({
    required String id,
    this.shortName = const Value.absent(),
    this.longName = const Value.absent(),
    this.color = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id);
  static Insertable<GtfsRoute> custom({
    Expression<String>? id,
    Expression<String>? shortName,
    Expression<String>? longName,
    Expression<String>? color,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (shortName != null) 'short_name': shortName,
      if (longName != null) 'long_name': longName,
      if (color != null) 'color': color,
      if (rowid != null) 'rowid': rowid,
    });
  }

  GtfsRoutesCompanion copyWith({
    Value<String>? id,
    Value<String?>? shortName,
    Value<String?>? longName,
    Value<String?>? color,
    Value<int>? rowid,
  }) {
    return GtfsRoutesCompanion(
      id: id ?? this.id,
      shortName: shortName ?? this.shortName,
      longName: longName ?? this.longName,
      color: color ?? this.color,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (shortName.present) {
      map['short_name'] = Variable<String>(shortName.value);
    }
    if (longName.present) {
      map['long_name'] = Variable<String>(longName.value);
    }
    if (color.present) {
      map['color'] = Variable<String>(color.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('GtfsRoutesCompanion(')
          ..write('id: $id, ')
          ..write('shortName: $shortName, ')
          ..write('longName: $longName, ')
          ..write('color: $color, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $GtfsTripsTable extends GtfsTrips
    with TableInfo<$GtfsTripsTable, GtfsTrip> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $GtfsTripsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _routeIdMeta = const VerificationMeta(
    'routeId',
  );
  @override
  late final GeneratedColumn<String> routeId = GeneratedColumn<String>(
    'route_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _serviceIdMeta = const VerificationMeta(
    'serviceId',
  );
  @override
  late final GeneratedColumn<String> serviceId = GeneratedColumn<String>(
    'service_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _headsignMeta = const VerificationMeta(
    'headsign',
  );
  @override
  late final GeneratedColumn<String> headsign = GeneratedColumn<String>(
    'headsign',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _tripShortNameMeta = const VerificationMeta(
    'tripShortName',
  );
  @override
  late final GeneratedColumn<String> tripShortName = GeneratedColumn<String>(
    'trip_short_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    routeId,
    serviceId,
    headsign,
    tripShortName,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'gtfs_trips';
  @override
  VerificationContext validateIntegrity(
    Insertable<GtfsTrip> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('route_id')) {
      context.handle(
        _routeIdMeta,
        routeId.isAcceptableOrUnknown(data['route_id']!, _routeIdMeta),
      );
    } else if (isInserting) {
      context.missing(_routeIdMeta);
    }
    if (data.containsKey('service_id')) {
      context.handle(
        _serviceIdMeta,
        serviceId.isAcceptableOrUnknown(data['service_id']!, _serviceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_serviceIdMeta);
    }
    if (data.containsKey('headsign')) {
      context.handle(
        _headsignMeta,
        headsign.isAcceptableOrUnknown(data['headsign']!, _headsignMeta),
      );
    }
    if (data.containsKey('trip_short_name')) {
      context.handle(
        _tripShortNameMeta,
        tripShortName.isAcceptableOrUnknown(
          data['trip_short_name']!,
          _tripShortNameMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  GtfsTrip map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return GtfsTrip(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      routeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}route_id'],
      )!,
      serviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}service_id'],
      )!,
      headsign: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}headsign'],
      ),
      tripShortName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}trip_short_name'],
      ),
    );
  }

  @override
  $GtfsTripsTable createAlias(String alias) {
    return $GtfsTripsTable(attachedDatabase, alias);
  }
}

class GtfsTrip extends DataClass implements Insertable<GtfsTrip> {
  final String id;
  final String routeId;
  final String serviceId;
  final String? headsign;
  final String? tripShortName;
  const GtfsTrip({
    required this.id,
    required this.routeId,
    required this.serviceId,
    this.headsign,
    this.tripShortName,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['route_id'] = Variable<String>(routeId);
    map['service_id'] = Variable<String>(serviceId);
    if (!nullToAbsent || headsign != null) {
      map['headsign'] = Variable<String>(headsign);
    }
    if (!nullToAbsent || tripShortName != null) {
      map['trip_short_name'] = Variable<String>(tripShortName);
    }
    return map;
  }

  GtfsTripsCompanion toCompanion(bool nullToAbsent) {
    return GtfsTripsCompanion(
      id: Value(id),
      routeId: Value(routeId),
      serviceId: Value(serviceId),
      headsign: headsign == null && nullToAbsent
          ? const Value.absent()
          : Value(headsign),
      tripShortName: tripShortName == null && nullToAbsent
          ? const Value.absent()
          : Value(tripShortName),
    );
  }

  factory GtfsTrip.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return GtfsTrip(
      id: serializer.fromJson<String>(json['id']),
      routeId: serializer.fromJson<String>(json['routeId']),
      serviceId: serializer.fromJson<String>(json['serviceId']),
      headsign: serializer.fromJson<String?>(json['headsign']),
      tripShortName: serializer.fromJson<String?>(json['tripShortName']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'routeId': serializer.toJson<String>(routeId),
      'serviceId': serializer.toJson<String>(serviceId),
      'headsign': serializer.toJson<String?>(headsign),
      'tripShortName': serializer.toJson<String?>(tripShortName),
    };
  }

  GtfsTrip copyWith({
    String? id,
    String? routeId,
    String? serviceId,
    Value<String?> headsign = const Value.absent(),
    Value<String?> tripShortName = const Value.absent(),
  }) => GtfsTrip(
    id: id ?? this.id,
    routeId: routeId ?? this.routeId,
    serviceId: serviceId ?? this.serviceId,
    headsign: headsign.present ? headsign.value : this.headsign,
    tripShortName: tripShortName.present
        ? tripShortName.value
        : this.tripShortName,
  );
  GtfsTrip copyWithCompanion(GtfsTripsCompanion data) {
    return GtfsTrip(
      id: data.id.present ? data.id.value : this.id,
      routeId: data.routeId.present ? data.routeId.value : this.routeId,
      serviceId: data.serviceId.present ? data.serviceId.value : this.serviceId,
      headsign: data.headsign.present ? data.headsign.value : this.headsign,
      tripShortName: data.tripShortName.present
          ? data.tripShortName.value
          : this.tripShortName,
    );
  }

  @override
  String toString() {
    return (StringBuffer('GtfsTrip(')
          ..write('id: $id, ')
          ..write('routeId: $routeId, ')
          ..write('serviceId: $serviceId, ')
          ..write('headsign: $headsign, ')
          ..write('tripShortName: $tripShortName')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, routeId, serviceId, headsign, tripShortName);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GtfsTrip &&
          other.id == this.id &&
          other.routeId == this.routeId &&
          other.serviceId == this.serviceId &&
          other.headsign == this.headsign &&
          other.tripShortName == this.tripShortName);
}

class GtfsTripsCompanion extends UpdateCompanion<GtfsTrip> {
  final Value<String> id;
  final Value<String> routeId;
  final Value<String> serviceId;
  final Value<String?> headsign;
  final Value<String?> tripShortName;
  final Value<int> rowid;
  const GtfsTripsCompanion({
    this.id = const Value.absent(),
    this.routeId = const Value.absent(),
    this.serviceId = const Value.absent(),
    this.headsign = const Value.absent(),
    this.tripShortName = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  GtfsTripsCompanion.insert({
    required String id,
    required String routeId,
    required String serviceId,
    this.headsign = const Value.absent(),
    this.tripShortName = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       routeId = Value(routeId),
       serviceId = Value(serviceId);
  static Insertable<GtfsTrip> custom({
    Expression<String>? id,
    Expression<String>? routeId,
    Expression<String>? serviceId,
    Expression<String>? headsign,
    Expression<String>? tripShortName,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (routeId != null) 'route_id': routeId,
      if (serviceId != null) 'service_id': serviceId,
      if (headsign != null) 'headsign': headsign,
      if (tripShortName != null) 'trip_short_name': tripShortName,
      if (rowid != null) 'rowid': rowid,
    });
  }

  GtfsTripsCompanion copyWith({
    Value<String>? id,
    Value<String>? routeId,
    Value<String>? serviceId,
    Value<String?>? headsign,
    Value<String?>? tripShortName,
    Value<int>? rowid,
  }) {
    return GtfsTripsCompanion(
      id: id ?? this.id,
      routeId: routeId ?? this.routeId,
      serviceId: serviceId ?? this.serviceId,
      headsign: headsign ?? this.headsign,
      tripShortName: tripShortName ?? this.tripShortName,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (routeId.present) {
      map['route_id'] = Variable<String>(routeId.value);
    }
    if (serviceId.present) {
      map['service_id'] = Variable<String>(serviceId.value);
    }
    if (headsign.present) {
      map['headsign'] = Variable<String>(headsign.value);
    }
    if (tripShortName.present) {
      map['trip_short_name'] = Variable<String>(tripShortName.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('GtfsTripsCompanion(')
          ..write('id: $id, ')
          ..write('routeId: $routeId, ')
          ..write('serviceId: $serviceId, ')
          ..write('headsign: $headsign, ')
          ..write('tripShortName: $tripShortName, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $GtfsStopTimesTable extends GtfsStopTimes
    with TableInfo<$GtfsStopTimesTable, GtfsStopTime> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $GtfsStopTimesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _tripIdMeta = const VerificationMeta('tripId');
  @override
  late final GeneratedColumn<String> tripId = GeneratedColumn<String>(
    'trip_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _stopIdMeta = const VerificationMeta('stopId');
  @override
  late final GeneratedColumn<String> stopId = GeneratedColumn<String>(
    'stop_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _stopSequenceMeta = const VerificationMeta(
    'stopSequence',
  );
  @override
  late final GeneratedColumn<int> stopSequence = GeneratedColumn<int>(
    'stop_sequence',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _arrivalSecondsMeta = const VerificationMeta(
    'arrivalSeconds',
  );
  @override
  late final GeneratedColumn<int> arrivalSeconds = GeneratedColumn<int>(
    'arrival_seconds',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _departureSecondsMeta = const VerificationMeta(
    'departureSeconds',
  );
  @override
  late final GeneratedColumn<int> departureSeconds = GeneratedColumn<int>(
    'departure_seconds',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    tripId,
    stopId,
    stopSequence,
    arrivalSeconds,
    departureSeconds,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'gtfs_stop_times';
  @override
  VerificationContext validateIntegrity(
    Insertable<GtfsStopTime> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('trip_id')) {
      context.handle(
        _tripIdMeta,
        tripId.isAcceptableOrUnknown(data['trip_id']!, _tripIdMeta),
      );
    } else if (isInserting) {
      context.missing(_tripIdMeta);
    }
    if (data.containsKey('stop_id')) {
      context.handle(
        _stopIdMeta,
        stopId.isAcceptableOrUnknown(data['stop_id']!, _stopIdMeta),
      );
    } else if (isInserting) {
      context.missing(_stopIdMeta);
    }
    if (data.containsKey('stop_sequence')) {
      context.handle(
        _stopSequenceMeta,
        stopSequence.isAcceptableOrUnknown(
          data['stop_sequence']!,
          _stopSequenceMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_stopSequenceMeta);
    }
    if (data.containsKey('arrival_seconds')) {
      context.handle(
        _arrivalSecondsMeta,
        arrivalSeconds.isAcceptableOrUnknown(
          data['arrival_seconds']!,
          _arrivalSecondsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_arrivalSecondsMeta);
    }
    if (data.containsKey('departure_seconds')) {
      context.handle(
        _departureSecondsMeta,
        departureSeconds.isAcceptableOrUnknown(
          data['departure_seconds']!,
          _departureSecondsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_departureSecondsMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {tripId, stopSequence};
  @override
  GtfsStopTime map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return GtfsStopTime(
      tripId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}trip_id'],
      )!,
      stopId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}stop_id'],
      )!,
      stopSequence: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}stop_sequence'],
      )!,
      arrivalSeconds: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}arrival_seconds'],
      )!,
      departureSeconds: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}departure_seconds'],
      )!,
    );
  }

  @override
  $GtfsStopTimesTable createAlias(String alias) {
    return $GtfsStopTimesTable(attachedDatabase, alias);
  }
}

class GtfsStopTime extends DataClass implements Insertable<GtfsStopTime> {
  final String tripId;
  final String stopId;
  final int stopSequence;
  final int arrivalSeconds;
  final int departureSeconds;
  const GtfsStopTime({
    required this.tripId,
    required this.stopId,
    required this.stopSequence,
    required this.arrivalSeconds,
    required this.departureSeconds,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['trip_id'] = Variable<String>(tripId);
    map['stop_id'] = Variable<String>(stopId);
    map['stop_sequence'] = Variable<int>(stopSequence);
    map['arrival_seconds'] = Variable<int>(arrivalSeconds);
    map['departure_seconds'] = Variable<int>(departureSeconds);
    return map;
  }

  GtfsStopTimesCompanion toCompanion(bool nullToAbsent) {
    return GtfsStopTimesCompanion(
      tripId: Value(tripId),
      stopId: Value(stopId),
      stopSequence: Value(stopSequence),
      arrivalSeconds: Value(arrivalSeconds),
      departureSeconds: Value(departureSeconds),
    );
  }

  factory GtfsStopTime.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return GtfsStopTime(
      tripId: serializer.fromJson<String>(json['tripId']),
      stopId: serializer.fromJson<String>(json['stopId']),
      stopSequence: serializer.fromJson<int>(json['stopSequence']),
      arrivalSeconds: serializer.fromJson<int>(json['arrivalSeconds']),
      departureSeconds: serializer.fromJson<int>(json['departureSeconds']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'tripId': serializer.toJson<String>(tripId),
      'stopId': serializer.toJson<String>(stopId),
      'stopSequence': serializer.toJson<int>(stopSequence),
      'arrivalSeconds': serializer.toJson<int>(arrivalSeconds),
      'departureSeconds': serializer.toJson<int>(departureSeconds),
    };
  }

  GtfsStopTime copyWith({
    String? tripId,
    String? stopId,
    int? stopSequence,
    int? arrivalSeconds,
    int? departureSeconds,
  }) => GtfsStopTime(
    tripId: tripId ?? this.tripId,
    stopId: stopId ?? this.stopId,
    stopSequence: stopSequence ?? this.stopSequence,
    arrivalSeconds: arrivalSeconds ?? this.arrivalSeconds,
    departureSeconds: departureSeconds ?? this.departureSeconds,
  );
  GtfsStopTime copyWithCompanion(GtfsStopTimesCompanion data) {
    return GtfsStopTime(
      tripId: data.tripId.present ? data.tripId.value : this.tripId,
      stopId: data.stopId.present ? data.stopId.value : this.stopId,
      stopSequence: data.stopSequence.present
          ? data.stopSequence.value
          : this.stopSequence,
      arrivalSeconds: data.arrivalSeconds.present
          ? data.arrivalSeconds.value
          : this.arrivalSeconds,
      departureSeconds: data.departureSeconds.present
          ? data.departureSeconds.value
          : this.departureSeconds,
    );
  }

  @override
  String toString() {
    return (StringBuffer('GtfsStopTime(')
          ..write('tripId: $tripId, ')
          ..write('stopId: $stopId, ')
          ..write('stopSequence: $stopSequence, ')
          ..write('arrivalSeconds: $arrivalSeconds, ')
          ..write('departureSeconds: $departureSeconds')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    tripId,
    stopId,
    stopSequence,
    arrivalSeconds,
    departureSeconds,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GtfsStopTime &&
          other.tripId == this.tripId &&
          other.stopId == this.stopId &&
          other.stopSequence == this.stopSequence &&
          other.arrivalSeconds == this.arrivalSeconds &&
          other.departureSeconds == this.departureSeconds);
}

class GtfsStopTimesCompanion extends UpdateCompanion<GtfsStopTime> {
  final Value<String> tripId;
  final Value<String> stopId;
  final Value<int> stopSequence;
  final Value<int> arrivalSeconds;
  final Value<int> departureSeconds;
  final Value<int> rowid;
  const GtfsStopTimesCompanion({
    this.tripId = const Value.absent(),
    this.stopId = const Value.absent(),
    this.stopSequence = const Value.absent(),
    this.arrivalSeconds = const Value.absent(),
    this.departureSeconds = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  GtfsStopTimesCompanion.insert({
    required String tripId,
    required String stopId,
    required int stopSequence,
    required int arrivalSeconds,
    required int departureSeconds,
    this.rowid = const Value.absent(),
  }) : tripId = Value(tripId),
       stopId = Value(stopId),
       stopSequence = Value(stopSequence),
       arrivalSeconds = Value(arrivalSeconds),
       departureSeconds = Value(departureSeconds);
  static Insertable<GtfsStopTime> custom({
    Expression<String>? tripId,
    Expression<String>? stopId,
    Expression<int>? stopSequence,
    Expression<int>? arrivalSeconds,
    Expression<int>? departureSeconds,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (tripId != null) 'trip_id': tripId,
      if (stopId != null) 'stop_id': stopId,
      if (stopSequence != null) 'stop_sequence': stopSequence,
      if (arrivalSeconds != null) 'arrival_seconds': arrivalSeconds,
      if (departureSeconds != null) 'departure_seconds': departureSeconds,
      if (rowid != null) 'rowid': rowid,
    });
  }

  GtfsStopTimesCompanion copyWith({
    Value<String>? tripId,
    Value<String>? stopId,
    Value<int>? stopSequence,
    Value<int>? arrivalSeconds,
    Value<int>? departureSeconds,
    Value<int>? rowid,
  }) {
    return GtfsStopTimesCompanion(
      tripId: tripId ?? this.tripId,
      stopId: stopId ?? this.stopId,
      stopSequence: stopSequence ?? this.stopSequence,
      arrivalSeconds: arrivalSeconds ?? this.arrivalSeconds,
      departureSeconds: departureSeconds ?? this.departureSeconds,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (tripId.present) {
      map['trip_id'] = Variable<String>(tripId.value);
    }
    if (stopId.present) {
      map['stop_id'] = Variable<String>(stopId.value);
    }
    if (stopSequence.present) {
      map['stop_sequence'] = Variable<int>(stopSequence.value);
    }
    if (arrivalSeconds.present) {
      map['arrival_seconds'] = Variable<int>(arrivalSeconds.value);
    }
    if (departureSeconds.present) {
      map['departure_seconds'] = Variable<int>(departureSeconds.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('GtfsStopTimesCompanion(')
          ..write('tripId: $tripId, ')
          ..write('stopId: $stopId, ')
          ..write('stopSequence: $stopSequence, ')
          ..write('arrivalSeconds: $arrivalSeconds, ')
          ..write('departureSeconds: $departureSeconds, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $GtfsCalendarEntriesTable extends GtfsCalendarEntries
    with TableInfo<$GtfsCalendarEntriesTable, GtfsCalendarEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $GtfsCalendarEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _serviceIdMeta = const VerificationMeta(
    'serviceId',
  );
  @override
  late final GeneratedColumn<String> serviceId = GeneratedColumn<String>(
    'service_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _mondayMeta = const VerificationMeta('monday');
  @override
  late final GeneratedColumn<bool> monday = GeneratedColumn<bool>(
    'monday',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("monday" IN (0, 1))',
    ),
  );
  static const VerificationMeta _tuesdayMeta = const VerificationMeta(
    'tuesday',
  );
  @override
  late final GeneratedColumn<bool> tuesday = GeneratedColumn<bool>(
    'tuesday',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("tuesday" IN (0, 1))',
    ),
  );
  static const VerificationMeta _wednesdayMeta = const VerificationMeta(
    'wednesday',
  );
  @override
  late final GeneratedColumn<bool> wednesday = GeneratedColumn<bool>(
    'wednesday',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("wednesday" IN (0, 1))',
    ),
  );
  static const VerificationMeta _thursdayMeta = const VerificationMeta(
    'thursday',
  );
  @override
  late final GeneratedColumn<bool> thursday = GeneratedColumn<bool>(
    'thursday',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("thursday" IN (0, 1))',
    ),
  );
  static const VerificationMeta _fridayMeta = const VerificationMeta('friday');
  @override
  late final GeneratedColumn<bool> friday = GeneratedColumn<bool>(
    'friday',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("friday" IN (0, 1))',
    ),
  );
  static const VerificationMeta _saturdayMeta = const VerificationMeta(
    'saturday',
  );
  @override
  late final GeneratedColumn<bool> saturday = GeneratedColumn<bool>(
    'saturday',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("saturday" IN (0, 1))',
    ),
  );
  static const VerificationMeta _sundayMeta = const VerificationMeta('sunday');
  @override
  late final GeneratedColumn<bool> sunday = GeneratedColumn<bool>(
    'sunday',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("sunday" IN (0, 1))',
    ),
  );
  static const VerificationMeta _startDateMeta = const VerificationMeta(
    'startDate',
  );
  @override
  late final GeneratedColumn<DateTime> startDate = GeneratedColumn<DateTime>(
    'start_date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endDateMeta = const VerificationMeta(
    'endDate',
  );
  @override
  late final GeneratedColumn<DateTime> endDate = GeneratedColumn<DateTime>(
    'end_date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    serviceId,
    monday,
    tuesday,
    wednesday,
    thursday,
    friday,
    saturday,
    sunday,
    startDate,
    endDate,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'gtfs_calendar_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<GtfsCalendarEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('service_id')) {
      context.handle(
        _serviceIdMeta,
        serviceId.isAcceptableOrUnknown(data['service_id']!, _serviceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_serviceIdMeta);
    }
    if (data.containsKey('monday')) {
      context.handle(
        _mondayMeta,
        monday.isAcceptableOrUnknown(data['monday']!, _mondayMeta),
      );
    } else if (isInserting) {
      context.missing(_mondayMeta);
    }
    if (data.containsKey('tuesday')) {
      context.handle(
        _tuesdayMeta,
        tuesday.isAcceptableOrUnknown(data['tuesday']!, _tuesdayMeta),
      );
    } else if (isInserting) {
      context.missing(_tuesdayMeta);
    }
    if (data.containsKey('wednesday')) {
      context.handle(
        _wednesdayMeta,
        wednesday.isAcceptableOrUnknown(data['wednesday']!, _wednesdayMeta),
      );
    } else if (isInserting) {
      context.missing(_wednesdayMeta);
    }
    if (data.containsKey('thursday')) {
      context.handle(
        _thursdayMeta,
        thursday.isAcceptableOrUnknown(data['thursday']!, _thursdayMeta),
      );
    } else if (isInserting) {
      context.missing(_thursdayMeta);
    }
    if (data.containsKey('friday')) {
      context.handle(
        _fridayMeta,
        friday.isAcceptableOrUnknown(data['friday']!, _fridayMeta),
      );
    } else if (isInserting) {
      context.missing(_fridayMeta);
    }
    if (data.containsKey('saturday')) {
      context.handle(
        _saturdayMeta,
        saturday.isAcceptableOrUnknown(data['saturday']!, _saturdayMeta),
      );
    } else if (isInserting) {
      context.missing(_saturdayMeta);
    }
    if (data.containsKey('sunday')) {
      context.handle(
        _sundayMeta,
        sunday.isAcceptableOrUnknown(data['sunday']!, _sundayMeta),
      );
    } else if (isInserting) {
      context.missing(_sundayMeta);
    }
    if (data.containsKey('start_date')) {
      context.handle(
        _startDateMeta,
        startDate.isAcceptableOrUnknown(data['start_date']!, _startDateMeta),
      );
    } else if (isInserting) {
      context.missing(_startDateMeta);
    }
    if (data.containsKey('end_date')) {
      context.handle(
        _endDateMeta,
        endDate.isAcceptableOrUnknown(data['end_date']!, _endDateMeta),
      );
    } else if (isInserting) {
      context.missing(_endDateMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {serviceId};
  @override
  GtfsCalendarEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return GtfsCalendarEntry(
      serviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}service_id'],
      )!,
      monday: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}monday'],
      )!,
      tuesday: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}tuesday'],
      )!,
      wednesday: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}wednesday'],
      )!,
      thursday: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}thursday'],
      )!,
      friday: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}friday'],
      )!,
      saturday: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}saturday'],
      )!,
      sunday: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}sunday'],
      )!,
      startDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}start_date'],
      )!,
      endDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}end_date'],
      )!,
    );
  }

  @override
  $GtfsCalendarEntriesTable createAlias(String alias) {
    return $GtfsCalendarEntriesTable(attachedDatabase, alias);
  }
}

class GtfsCalendarEntry extends DataClass
    implements Insertable<GtfsCalendarEntry> {
  final String serviceId;
  final bool monday;
  final bool tuesday;
  final bool wednesday;
  final bool thursday;
  final bool friday;
  final bool saturday;
  final bool sunday;
  final DateTime startDate;
  final DateTime endDate;
  const GtfsCalendarEntry({
    required this.serviceId,
    required this.monday,
    required this.tuesday,
    required this.wednesday,
    required this.thursday,
    required this.friday,
    required this.saturday,
    required this.sunday,
    required this.startDate,
    required this.endDate,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['service_id'] = Variable<String>(serviceId);
    map['monday'] = Variable<bool>(monday);
    map['tuesday'] = Variable<bool>(tuesday);
    map['wednesday'] = Variable<bool>(wednesday);
    map['thursday'] = Variable<bool>(thursday);
    map['friday'] = Variable<bool>(friday);
    map['saturday'] = Variable<bool>(saturday);
    map['sunday'] = Variable<bool>(sunday);
    map['start_date'] = Variable<DateTime>(startDate);
    map['end_date'] = Variable<DateTime>(endDate);
    return map;
  }

  GtfsCalendarEntriesCompanion toCompanion(bool nullToAbsent) {
    return GtfsCalendarEntriesCompanion(
      serviceId: Value(serviceId),
      monday: Value(monday),
      tuesday: Value(tuesday),
      wednesday: Value(wednesday),
      thursday: Value(thursday),
      friday: Value(friday),
      saturday: Value(saturday),
      sunday: Value(sunday),
      startDate: Value(startDate),
      endDate: Value(endDate),
    );
  }

  factory GtfsCalendarEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return GtfsCalendarEntry(
      serviceId: serializer.fromJson<String>(json['serviceId']),
      monday: serializer.fromJson<bool>(json['monday']),
      tuesday: serializer.fromJson<bool>(json['tuesday']),
      wednesday: serializer.fromJson<bool>(json['wednesday']),
      thursday: serializer.fromJson<bool>(json['thursday']),
      friday: serializer.fromJson<bool>(json['friday']),
      saturday: serializer.fromJson<bool>(json['saturday']),
      sunday: serializer.fromJson<bool>(json['sunday']),
      startDate: serializer.fromJson<DateTime>(json['startDate']),
      endDate: serializer.fromJson<DateTime>(json['endDate']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'serviceId': serializer.toJson<String>(serviceId),
      'monday': serializer.toJson<bool>(monday),
      'tuesday': serializer.toJson<bool>(tuesday),
      'wednesday': serializer.toJson<bool>(wednesday),
      'thursday': serializer.toJson<bool>(thursday),
      'friday': serializer.toJson<bool>(friday),
      'saturday': serializer.toJson<bool>(saturday),
      'sunday': serializer.toJson<bool>(sunday),
      'startDate': serializer.toJson<DateTime>(startDate),
      'endDate': serializer.toJson<DateTime>(endDate),
    };
  }

  GtfsCalendarEntry copyWith({
    String? serviceId,
    bool? monday,
    bool? tuesday,
    bool? wednesday,
    bool? thursday,
    bool? friday,
    bool? saturday,
    bool? sunday,
    DateTime? startDate,
    DateTime? endDate,
  }) => GtfsCalendarEntry(
    serviceId: serviceId ?? this.serviceId,
    monday: monday ?? this.monday,
    tuesday: tuesday ?? this.tuesday,
    wednesday: wednesday ?? this.wednesday,
    thursday: thursday ?? this.thursday,
    friday: friday ?? this.friday,
    saturday: saturday ?? this.saturday,
    sunday: sunday ?? this.sunday,
    startDate: startDate ?? this.startDate,
    endDate: endDate ?? this.endDate,
  );
  GtfsCalendarEntry copyWithCompanion(GtfsCalendarEntriesCompanion data) {
    return GtfsCalendarEntry(
      serviceId: data.serviceId.present ? data.serviceId.value : this.serviceId,
      monday: data.monday.present ? data.monday.value : this.monday,
      tuesday: data.tuesday.present ? data.tuesday.value : this.tuesday,
      wednesday: data.wednesday.present ? data.wednesday.value : this.wednesday,
      thursday: data.thursday.present ? data.thursday.value : this.thursday,
      friday: data.friday.present ? data.friday.value : this.friday,
      saturday: data.saturday.present ? data.saturday.value : this.saturday,
      sunday: data.sunday.present ? data.sunday.value : this.sunday,
      startDate: data.startDate.present ? data.startDate.value : this.startDate,
      endDate: data.endDate.present ? data.endDate.value : this.endDate,
    );
  }

  @override
  String toString() {
    return (StringBuffer('GtfsCalendarEntry(')
          ..write('serviceId: $serviceId, ')
          ..write('monday: $monday, ')
          ..write('tuesday: $tuesday, ')
          ..write('wednesday: $wednesday, ')
          ..write('thursday: $thursday, ')
          ..write('friday: $friday, ')
          ..write('saturday: $saturday, ')
          ..write('sunday: $sunday, ')
          ..write('startDate: $startDate, ')
          ..write('endDate: $endDate')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    serviceId,
    monday,
    tuesday,
    wednesday,
    thursday,
    friday,
    saturday,
    sunday,
    startDate,
    endDate,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GtfsCalendarEntry &&
          other.serviceId == this.serviceId &&
          other.monday == this.monday &&
          other.tuesday == this.tuesday &&
          other.wednesday == this.wednesday &&
          other.thursday == this.thursday &&
          other.friday == this.friday &&
          other.saturday == this.saturday &&
          other.sunday == this.sunday &&
          other.startDate == this.startDate &&
          other.endDate == this.endDate);
}

class GtfsCalendarEntriesCompanion extends UpdateCompanion<GtfsCalendarEntry> {
  final Value<String> serviceId;
  final Value<bool> monday;
  final Value<bool> tuesday;
  final Value<bool> wednesday;
  final Value<bool> thursday;
  final Value<bool> friday;
  final Value<bool> saturday;
  final Value<bool> sunday;
  final Value<DateTime> startDate;
  final Value<DateTime> endDate;
  final Value<int> rowid;
  const GtfsCalendarEntriesCompanion({
    this.serviceId = const Value.absent(),
    this.monday = const Value.absent(),
    this.tuesday = const Value.absent(),
    this.wednesday = const Value.absent(),
    this.thursday = const Value.absent(),
    this.friday = const Value.absent(),
    this.saturday = const Value.absent(),
    this.sunday = const Value.absent(),
    this.startDate = const Value.absent(),
    this.endDate = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  GtfsCalendarEntriesCompanion.insert({
    required String serviceId,
    required bool monday,
    required bool tuesday,
    required bool wednesday,
    required bool thursday,
    required bool friday,
    required bool saturday,
    required bool sunday,
    required DateTime startDate,
    required DateTime endDate,
    this.rowid = const Value.absent(),
  }) : serviceId = Value(serviceId),
       monday = Value(monday),
       tuesday = Value(tuesday),
       wednesday = Value(wednesday),
       thursday = Value(thursday),
       friday = Value(friday),
       saturday = Value(saturday),
       sunday = Value(sunday),
       startDate = Value(startDate),
       endDate = Value(endDate);
  static Insertable<GtfsCalendarEntry> custom({
    Expression<String>? serviceId,
    Expression<bool>? monday,
    Expression<bool>? tuesday,
    Expression<bool>? wednesday,
    Expression<bool>? thursday,
    Expression<bool>? friday,
    Expression<bool>? saturday,
    Expression<bool>? sunday,
    Expression<DateTime>? startDate,
    Expression<DateTime>? endDate,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (serviceId != null) 'service_id': serviceId,
      if (monday != null) 'monday': monday,
      if (tuesday != null) 'tuesday': tuesday,
      if (wednesday != null) 'wednesday': wednesday,
      if (thursday != null) 'thursday': thursday,
      if (friday != null) 'friday': friday,
      if (saturday != null) 'saturday': saturday,
      if (sunday != null) 'sunday': sunday,
      if (startDate != null) 'start_date': startDate,
      if (endDate != null) 'end_date': endDate,
      if (rowid != null) 'rowid': rowid,
    });
  }

  GtfsCalendarEntriesCompanion copyWith({
    Value<String>? serviceId,
    Value<bool>? monday,
    Value<bool>? tuesday,
    Value<bool>? wednesday,
    Value<bool>? thursday,
    Value<bool>? friday,
    Value<bool>? saturday,
    Value<bool>? sunday,
    Value<DateTime>? startDate,
    Value<DateTime>? endDate,
    Value<int>? rowid,
  }) {
    return GtfsCalendarEntriesCompanion(
      serviceId: serviceId ?? this.serviceId,
      monday: monday ?? this.monday,
      tuesday: tuesday ?? this.tuesday,
      wednesday: wednesday ?? this.wednesday,
      thursday: thursday ?? this.thursday,
      friday: friday ?? this.friday,
      saturday: saturday ?? this.saturday,
      sunday: sunday ?? this.sunday,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (serviceId.present) {
      map['service_id'] = Variable<String>(serviceId.value);
    }
    if (monday.present) {
      map['monday'] = Variable<bool>(monday.value);
    }
    if (tuesday.present) {
      map['tuesday'] = Variable<bool>(tuesday.value);
    }
    if (wednesday.present) {
      map['wednesday'] = Variable<bool>(wednesday.value);
    }
    if (thursday.present) {
      map['thursday'] = Variable<bool>(thursday.value);
    }
    if (friday.present) {
      map['friday'] = Variable<bool>(friday.value);
    }
    if (saturday.present) {
      map['saturday'] = Variable<bool>(saturday.value);
    }
    if (sunday.present) {
      map['sunday'] = Variable<bool>(sunday.value);
    }
    if (startDate.present) {
      map['start_date'] = Variable<DateTime>(startDate.value);
    }
    if (endDate.present) {
      map['end_date'] = Variable<DateTime>(endDate.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('GtfsCalendarEntriesCompanion(')
          ..write('serviceId: $serviceId, ')
          ..write('monday: $monday, ')
          ..write('tuesday: $tuesday, ')
          ..write('wednesday: $wednesday, ')
          ..write('thursday: $thursday, ')
          ..write('friday: $friday, ')
          ..write('saturday: $saturday, ')
          ..write('sunday: $sunday, ')
          ..write('startDate: $startDate, ')
          ..write('endDate: $endDate, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $GtfsCalendarDateEntriesTable extends GtfsCalendarDateEntries
    with TableInfo<$GtfsCalendarDateEntriesTable, GtfsCalendarDateEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $GtfsCalendarDateEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _serviceIdMeta = const VerificationMeta(
    'serviceId',
  );
  @override
  late final GeneratedColumn<String> serviceId = GeneratedColumn<String>(
    'service_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<DateTime> date = GeneratedColumn<DateTime>(
    'date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _exceptionTypeMeta = const VerificationMeta(
    'exceptionType',
  );
  @override
  late final GeneratedColumn<int> exceptionType = GeneratedColumn<int>(
    'exception_type',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [serviceId, date, exceptionType];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'gtfs_calendar_date_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<GtfsCalendarDateEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('service_id')) {
      context.handle(
        _serviceIdMeta,
        serviceId.isAcceptableOrUnknown(data['service_id']!, _serviceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_serviceIdMeta);
    }
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('exception_type')) {
      context.handle(
        _exceptionTypeMeta,
        exceptionType.isAcceptableOrUnknown(
          data['exception_type']!,
          _exceptionTypeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_exceptionTypeMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {serviceId, date};
  @override
  GtfsCalendarDateEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return GtfsCalendarDateEntry(
      serviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}service_id'],
      )!,
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}date'],
      )!,
      exceptionType: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}exception_type'],
      )!,
    );
  }

  @override
  $GtfsCalendarDateEntriesTable createAlias(String alias) {
    return $GtfsCalendarDateEntriesTable(attachedDatabase, alias);
  }
}

class GtfsCalendarDateEntry extends DataClass
    implements Insertable<GtfsCalendarDateEntry> {
  final String serviceId;
  final DateTime date;

  /// 1 = service added on this date, 2 = service removed on this date
  /// (matches the raw GTFS `exception_type` values).
  final int exceptionType;
  const GtfsCalendarDateEntry({
    required this.serviceId,
    required this.date,
    required this.exceptionType,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['service_id'] = Variable<String>(serviceId);
    map['date'] = Variable<DateTime>(date);
    map['exception_type'] = Variable<int>(exceptionType);
    return map;
  }

  GtfsCalendarDateEntriesCompanion toCompanion(bool nullToAbsent) {
    return GtfsCalendarDateEntriesCompanion(
      serviceId: Value(serviceId),
      date: Value(date),
      exceptionType: Value(exceptionType),
    );
  }

  factory GtfsCalendarDateEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return GtfsCalendarDateEntry(
      serviceId: serializer.fromJson<String>(json['serviceId']),
      date: serializer.fromJson<DateTime>(json['date']),
      exceptionType: serializer.fromJson<int>(json['exceptionType']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'serviceId': serializer.toJson<String>(serviceId),
      'date': serializer.toJson<DateTime>(date),
      'exceptionType': serializer.toJson<int>(exceptionType),
    };
  }

  GtfsCalendarDateEntry copyWith({
    String? serviceId,
    DateTime? date,
    int? exceptionType,
  }) => GtfsCalendarDateEntry(
    serviceId: serviceId ?? this.serviceId,
    date: date ?? this.date,
    exceptionType: exceptionType ?? this.exceptionType,
  );
  GtfsCalendarDateEntry copyWithCompanion(
    GtfsCalendarDateEntriesCompanion data,
  ) {
    return GtfsCalendarDateEntry(
      serviceId: data.serviceId.present ? data.serviceId.value : this.serviceId,
      date: data.date.present ? data.date.value : this.date,
      exceptionType: data.exceptionType.present
          ? data.exceptionType.value
          : this.exceptionType,
    );
  }

  @override
  String toString() {
    return (StringBuffer('GtfsCalendarDateEntry(')
          ..write('serviceId: $serviceId, ')
          ..write('date: $date, ')
          ..write('exceptionType: $exceptionType')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(serviceId, date, exceptionType);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GtfsCalendarDateEntry &&
          other.serviceId == this.serviceId &&
          other.date == this.date &&
          other.exceptionType == this.exceptionType);
}

class GtfsCalendarDateEntriesCompanion
    extends UpdateCompanion<GtfsCalendarDateEntry> {
  final Value<String> serviceId;
  final Value<DateTime> date;
  final Value<int> exceptionType;
  final Value<int> rowid;
  const GtfsCalendarDateEntriesCompanion({
    this.serviceId = const Value.absent(),
    this.date = const Value.absent(),
    this.exceptionType = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  GtfsCalendarDateEntriesCompanion.insert({
    required String serviceId,
    required DateTime date,
    required int exceptionType,
    this.rowid = const Value.absent(),
  }) : serviceId = Value(serviceId),
       date = Value(date),
       exceptionType = Value(exceptionType);
  static Insertable<GtfsCalendarDateEntry> custom({
    Expression<String>? serviceId,
    Expression<DateTime>? date,
    Expression<int>? exceptionType,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (serviceId != null) 'service_id': serviceId,
      if (date != null) 'date': date,
      if (exceptionType != null) 'exception_type': exceptionType,
      if (rowid != null) 'rowid': rowid,
    });
  }

  GtfsCalendarDateEntriesCompanion copyWith({
    Value<String>? serviceId,
    Value<DateTime>? date,
    Value<int>? exceptionType,
    Value<int>? rowid,
  }) {
    return GtfsCalendarDateEntriesCompanion(
      serviceId: serviceId ?? this.serviceId,
      date: date ?? this.date,
      exceptionType: exceptionType ?? this.exceptionType,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (serviceId.present) {
      map['service_id'] = Variable<String>(serviceId.value);
    }
    if (date.present) {
      map['date'] = Variable<DateTime>(date.value);
    }
    if (exceptionType.present) {
      map['exception_type'] = Variable<int>(exceptionType.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('GtfsCalendarDateEntriesCompanion(')
          ..write('serviceId: $serviceId, ')
          ..write('date: $date, ')
          ..write('exceptionType: $exceptionType, ')
          ..write('rowid: $rowid')
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
  late final $GtfsStopsTable gtfsStops = $GtfsStopsTable(this);
  late final $GtfsRoutesTable gtfsRoutes = $GtfsRoutesTable(this);
  late final $GtfsTripsTable gtfsTrips = $GtfsTripsTable(this);
  late final $GtfsStopTimesTable gtfsStopTimes = $GtfsStopTimesTable(this);
  late final $GtfsCalendarEntriesTable gtfsCalendarEntries =
      $GtfsCalendarEntriesTable(this);
  late final $GtfsCalendarDateEntriesTable gtfsCalendarDateEntries =
      $GtfsCalendarDateEntriesTable(this);
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
    gtfsStops,
    gtfsRoutes,
    gtfsTrips,
    gtfsStopTimes,
    gtfsCalendarEntries,
    gtfsCalendarDateEntries,
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
typedef $$GtfsStopsTableCreateCompanionBuilder =
    GtfsStopsCompanion Function({
      required String id,
      required String name,
      required double latitude,
      required double longitude,
      Value<int> rowid,
    });
typedef $$GtfsStopsTableUpdateCompanionBuilder =
    GtfsStopsCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<double> latitude,
      Value<double> longitude,
      Value<int> rowid,
    });

class $$GtfsStopsTableFilterComposer
    extends Composer<_$AppDatabase, $GtfsStopsTable> {
  $$GtfsStopsTableFilterComposer({
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
}

class $$GtfsStopsTableOrderingComposer
    extends Composer<_$AppDatabase, $GtfsStopsTable> {
  $$GtfsStopsTableOrderingComposer({
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
}

class $$GtfsStopsTableAnnotationComposer
    extends Composer<_$AppDatabase, $GtfsStopsTable> {
  $$GtfsStopsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<double> get latitude =>
      $composableBuilder(column: $table.latitude, builder: (column) => column);

  GeneratedColumn<double> get longitude =>
      $composableBuilder(column: $table.longitude, builder: (column) => column);
}

class $$GtfsStopsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $GtfsStopsTable,
          GtfsStop,
          $$GtfsStopsTableFilterComposer,
          $$GtfsStopsTableOrderingComposer,
          $$GtfsStopsTableAnnotationComposer,
          $$GtfsStopsTableCreateCompanionBuilder,
          $$GtfsStopsTableUpdateCompanionBuilder,
          (GtfsStop, BaseReferences<_$AppDatabase, $GtfsStopsTable, GtfsStop>),
          GtfsStop,
          PrefetchHooks Function()
        > {
  $$GtfsStopsTableTableManager(_$AppDatabase db, $GtfsStopsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$GtfsStopsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$GtfsStopsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$GtfsStopsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<double> latitude = const Value.absent(),
                Value<double> longitude = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => GtfsStopsCompanion(
                id: id,
                name: name,
                latitude: latitude,
                longitude: longitude,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required double latitude,
                required double longitude,
                Value<int> rowid = const Value.absent(),
              }) => GtfsStopsCompanion.insert(
                id: id,
                name: name,
                latitude: latitude,
                longitude: longitude,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$GtfsStopsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $GtfsStopsTable,
      GtfsStop,
      $$GtfsStopsTableFilterComposer,
      $$GtfsStopsTableOrderingComposer,
      $$GtfsStopsTableAnnotationComposer,
      $$GtfsStopsTableCreateCompanionBuilder,
      $$GtfsStopsTableUpdateCompanionBuilder,
      (GtfsStop, BaseReferences<_$AppDatabase, $GtfsStopsTable, GtfsStop>),
      GtfsStop,
      PrefetchHooks Function()
    >;
typedef $$GtfsRoutesTableCreateCompanionBuilder =
    GtfsRoutesCompanion Function({
      required String id,
      Value<String?> shortName,
      Value<String?> longName,
      Value<String?> color,
      Value<int> rowid,
    });
typedef $$GtfsRoutesTableUpdateCompanionBuilder =
    GtfsRoutesCompanion Function({
      Value<String> id,
      Value<String?> shortName,
      Value<String?> longName,
      Value<String?> color,
      Value<int> rowid,
    });

class $$GtfsRoutesTableFilterComposer
    extends Composer<_$AppDatabase, $GtfsRoutesTable> {
  $$GtfsRoutesTableFilterComposer({
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

  ColumnFilters<String> get shortName => $composableBuilder(
    column: $table.shortName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get longName => $composableBuilder(
    column: $table.longName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnFilters(column),
  );
}

class $$GtfsRoutesTableOrderingComposer
    extends Composer<_$AppDatabase, $GtfsRoutesTable> {
  $$GtfsRoutesTableOrderingComposer({
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

  ColumnOrderings<String> get shortName => $composableBuilder(
    column: $table.shortName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get longName => $composableBuilder(
    column: $table.longName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$GtfsRoutesTableAnnotationComposer
    extends Composer<_$AppDatabase, $GtfsRoutesTable> {
  $$GtfsRoutesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get shortName =>
      $composableBuilder(column: $table.shortName, builder: (column) => column);

  GeneratedColumn<String> get longName =>
      $composableBuilder(column: $table.longName, builder: (column) => column);

  GeneratedColumn<String> get color =>
      $composableBuilder(column: $table.color, builder: (column) => column);
}

class $$GtfsRoutesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $GtfsRoutesTable,
          GtfsRoute,
          $$GtfsRoutesTableFilterComposer,
          $$GtfsRoutesTableOrderingComposer,
          $$GtfsRoutesTableAnnotationComposer,
          $$GtfsRoutesTableCreateCompanionBuilder,
          $$GtfsRoutesTableUpdateCompanionBuilder,
          (
            GtfsRoute,
            BaseReferences<_$AppDatabase, $GtfsRoutesTable, GtfsRoute>,
          ),
          GtfsRoute,
          PrefetchHooks Function()
        > {
  $$GtfsRoutesTableTableManager(_$AppDatabase db, $GtfsRoutesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$GtfsRoutesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$GtfsRoutesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$GtfsRoutesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String?> shortName = const Value.absent(),
                Value<String?> longName = const Value.absent(),
                Value<String?> color = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => GtfsRoutesCompanion(
                id: id,
                shortName: shortName,
                longName: longName,
                color: color,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String?> shortName = const Value.absent(),
                Value<String?> longName = const Value.absent(),
                Value<String?> color = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => GtfsRoutesCompanion.insert(
                id: id,
                shortName: shortName,
                longName: longName,
                color: color,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$GtfsRoutesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $GtfsRoutesTable,
      GtfsRoute,
      $$GtfsRoutesTableFilterComposer,
      $$GtfsRoutesTableOrderingComposer,
      $$GtfsRoutesTableAnnotationComposer,
      $$GtfsRoutesTableCreateCompanionBuilder,
      $$GtfsRoutesTableUpdateCompanionBuilder,
      (GtfsRoute, BaseReferences<_$AppDatabase, $GtfsRoutesTable, GtfsRoute>),
      GtfsRoute,
      PrefetchHooks Function()
    >;
typedef $$GtfsTripsTableCreateCompanionBuilder =
    GtfsTripsCompanion Function({
      required String id,
      required String routeId,
      required String serviceId,
      Value<String?> headsign,
      Value<String?> tripShortName,
      Value<int> rowid,
    });
typedef $$GtfsTripsTableUpdateCompanionBuilder =
    GtfsTripsCompanion Function({
      Value<String> id,
      Value<String> routeId,
      Value<String> serviceId,
      Value<String?> headsign,
      Value<String?> tripShortName,
      Value<int> rowid,
    });

class $$GtfsTripsTableFilterComposer
    extends Composer<_$AppDatabase, $GtfsTripsTable> {
  $$GtfsTripsTableFilterComposer({
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

  ColumnFilters<String> get routeId => $composableBuilder(
    column: $table.routeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get serviceId => $composableBuilder(
    column: $table.serviceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get headsign => $composableBuilder(
    column: $table.headsign,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tripShortName => $composableBuilder(
    column: $table.tripShortName,
    builder: (column) => ColumnFilters(column),
  );
}

class $$GtfsTripsTableOrderingComposer
    extends Composer<_$AppDatabase, $GtfsTripsTable> {
  $$GtfsTripsTableOrderingComposer({
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

  ColumnOrderings<String> get routeId => $composableBuilder(
    column: $table.routeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get serviceId => $composableBuilder(
    column: $table.serviceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get headsign => $composableBuilder(
    column: $table.headsign,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tripShortName => $composableBuilder(
    column: $table.tripShortName,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$GtfsTripsTableAnnotationComposer
    extends Composer<_$AppDatabase, $GtfsTripsTable> {
  $$GtfsTripsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get routeId =>
      $composableBuilder(column: $table.routeId, builder: (column) => column);

  GeneratedColumn<String> get serviceId =>
      $composableBuilder(column: $table.serviceId, builder: (column) => column);

  GeneratedColumn<String> get headsign =>
      $composableBuilder(column: $table.headsign, builder: (column) => column);

  GeneratedColumn<String> get tripShortName => $composableBuilder(
    column: $table.tripShortName,
    builder: (column) => column,
  );
}

class $$GtfsTripsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $GtfsTripsTable,
          GtfsTrip,
          $$GtfsTripsTableFilterComposer,
          $$GtfsTripsTableOrderingComposer,
          $$GtfsTripsTableAnnotationComposer,
          $$GtfsTripsTableCreateCompanionBuilder,
          $$GtfsTripsTableUpdateCompanionBuilder,
          (GtfsTrip, BaseReferences<_$AppDatabase, $GtfsTripsTable, GtfsTrip>),
          GtfsTrip,
          PrefetchHooks Function()
        > {
  $$GtfsTripsTableTableManager(_$AppDatabase db, $GtfsTripsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$GtfsTripsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$GtfsTripsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$GtfsTripsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> routeId = const Value.absent(),
                Value<String> serviceId = const Value.absent(),
                Value<String?> headsign = const Value.absent(),
                Value<String?> tripShortName = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => GtfsTripsCompanion(
                id: id,
                routeId: routeId,
                serviceId: serviceId,
                headsign: headsign,
                tripShortName: tripShortName,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String routeId,
                required String serviceId,
                Value<String?> headsign = const Value.absent(),
                Value<String?> tripShortName = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => GtfsTripsCompanion.insert(
                id: id,
                routeId: routeId,
                serviceId: serviceId,
                headsign: headsign,
                tripShortName: tripShortName,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$GtfsTripsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $GtfsTripsTable,
      GtfsTrip,
      $$GtfsTripsTableFilterComposer,
      $$GtfsTripsTableOrderingComposer,
      $$GtfsTripsTableAnnotationComposer,
      $$GtfsTripsTableCreateCompanionBuilder,
      $$GtfsTripsTableUpdateCompanionBuilder,
      (GtfsTrip, BaseReferences<_$AppDatabase, $GtfsTripsTable, GtfsTrip>),
      GtfsTrip,
      PrefetchHooks Function()
    >;
typedef $$GtfsStopTimesTableCreateCompanionBuilder =
    GtfsStopTimesCompanion Function({
      required String tripId,
      required String stopId,
      required int stopSequence,
      required int arrivalSeconds,
      required int departureSeconds,
      Value<int> rowid,
    });
typedef $$GtfsStopTimesTableUpdateCompanionBuilder =
    GtfsStopTimesCompanion Function({
      Value<String> tripId,
      Value<String> stopId,
      Value<int> stopSequence,
      Value<int> arrivalSeconds,
      Value<int> departureSeconds,
      Value<int> rowid,
    });

class $$GtfsStopTimesTableFilterComposer
    extends Composer<_$AppDatabase, $GtfsStopTimesTable> {
  $$GtfsStopTimesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get tripId => $composableBuilder(
    column: $table.tripId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get stopId => $composableBuilder(
    column: $table.stopId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get stopSequence => $composableBuilder(
    column: $table.stopSequence,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get arrivalSeconds => $composableBuilder(
    column: $table.arrivalSeconds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get departureSeconds => $composableBuilder(
    column: $table.departureSeconds,
    builder: (column) => ColumnFilters(column),
  );
}

class $$GtfsStopTimesTableOrderingComposer
    extends Composer<_$AppDatabase, $GtfsStopTimesTable> {
  $$GtfsStopTimesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get tripId => $composableBuilder(
    column: $table.tripId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get stopId => $composableBuilder(
    column: $table.stopId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get stopSequence => $composableBuilder(
    column: $table.stopSequence,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get arrivalSeconds => $composableBuilder(
    column: $table.arrivalSeconds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get departureSeconds => $composableBuilder(
    column: $table.departureSeconds,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$GtfsStopTimesTableAnnotationComposer
    extends Composer<_$AppDatabase, $GtfsStopTimesTable> {
  $$GtfsStopTimesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get tripId =>
      $composableBuilder(column: $table.tripId, builder: (column) => column);

  GeneratedColumn<String> get stopId =>
      $composableBuilder(column: $table.stopId, builder: (column) => column);

  GeneratedColumn<int> get stopSequence => $composableBuilder(
    column: $table.stopSequence,
    builder: (column) => column,
  );

  GeneratedColumn<int> get arrivalSeconds => $composableBuilder(
    column: $table.arrivalSeconds,
    builder: (column) => column,
  );

  GeneratedColumn<int> get departureSeconds => $composableBuilder(
    column: $table.departureSeconds,
    builder: (column) => column,
  );
}

class $$GtfsStopTimesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $GtfsStopTimesTable,
          GtfsStopTime,
          $$GtfsStopTimesTableFilterComposer,
          $$GtfsStopTimesTableOrderingComposer,
          $$GtfsStopTimesTableAnnotationComposer,
          $$GtfsStopTimesTableCreateCompanionBuilder,
          $$GtfsStopTimesTableUpdateCompanionBuilder,
          (
            GtfsStopTime,
            BaseReferences<_$AppDatabase, $GtfsStopTimesTable, GtfsStopTime>,
          ),
          GtfsStopTime,
          PrefetchHooks Function()
        > {
  $$GtfsStopTimesTableTableManager(_$AppDatabase db, $GtfsStopTimesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$GtfsStopTimesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$GtfsStopTimesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$GtfsStopTimesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> tripId = const Value.absent(),
                Value<String> stopId = const Value.absent(),
                Value<int> stopSequence = const Value.absent(),
                Value<int> arrivalSeconds = const Value.absent(),
                Value<int> departureSeconds = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => GtfsStopTimesCompanion(
                tripId: tripId,
                stopId: stopId,
                stopSequence: stopSequence,
                arrivalSeconds: arrivalSeconds,
                departureSeconds: departureSeconds,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String tripId,
                required String stopId,
                required int stopSequence,
                required int arrivalSeconds,
                required int departureSeconds,
                Value<int> rowid = const Value.absent(),
              }) => GtfsStopTimesCompanion.insert(
                tripId: tripId,
                stopId: stopId,
                stopSequence: stopSequence,
                arrivalSeconds: arrivalSeconds,
                departureSeconds: departureSeconds,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$GtfsStopTimesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $GtfsStopTimesTable,
      GtfsStopTime,
      $$GtfsStopTimesTableFilterComposer,
      $$GtfsStopTimesTableOrderingComposer,
      $$GtfsStopTimesTableAnnotationComposer,
      $$GtfsStopTimesTableCreateCompanionBuilder,
      $$GtfsStopTimesTableUpdateCompanionBuilder,
      (
        GtfsStopTime,
        BaseReferences<_$AppDatabase, $GtfsStopTimesTable, GtfsStopTime>,
      ),
      GtfsStopTime,
      PrefetchHooks Function()
    >;
typedef $$GtfsCalendarEntriesTableCreateCompanionBuilder =
    GtfsCalendarEntriesCompanion Function({
      required String serviceId,
      required bool monday,
      required bool tuesday,
      required bool wednesday,
      required bool thursday,
      required bool friday,
      required bool saturday,
      required bool sunday,
      required DateTime startDate,
      required DateTime endDate,
      Value<int> rowid,
    });
typedef $$GtfsCalendarEntriesTableUpdateCompanionBuilder =
    GtfsCalendarEntriesCompanion Function({
      Value<String> serviceId,
      Value<bool> monday,
      Value<bool> tuesday,
      Value<bool> wednesday,
      Value<bool> thursday,
      Value<bool> friday,
      Value<bool> saturday,
      Value<bool> sunday,
      Value<DateTime> startDate,
      Value<DateTime> endDate,
      Value<int> rowid,
    });

class $$GtfsCalendarEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $GtfsCalendarEntriesTable> {
  $$GtfsCalendarEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get serviceId => $composableBuilder(
    column: $table.serviceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get monday => $composableBuilder(
    column: $table.monday,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get tuesday => $composableBuilder(
    column: $table.tuesday,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get wednesday => $composableBuilder(
    column: $table.wednesday,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get thursday => $composableBuilder(
    column: $table.thursday,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get friday => $composableBuilder(
    column: $table.friday,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get saturday => $composableBuilder(
    column: $table.saturday,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get sunday => $composableBuilder(
    column: $table.sunday,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get startDate => $composableBuilder(
    column: $table.startDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get endDate => $composableBuilder(
    column: $table.endDate,
    builder: (column) => ColumnFilters(column),
  );
}

class $$GtfsCalendarEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $GtfsCalendarEntriesTable> {
  $$GtfsCalendarEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get serviceId => $composableBuilder(
    column: $table.serviceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get monday => $composableBuilder(
    column: $table.monday,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get tuesday => $composableBuilder(
    column: $table.tuesday,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get wednesday => $composableBuilder(
    column: $table.wednesday,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get thursday => $composableBuilder(
    column: $table.thursday,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get friday => $composableBuilder(
    column: $table.friday,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get saturday => $composableBuilder(
    column: $table.saturday,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get sunday => $composableBuilder(
    column: $table.sunday,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get startDate => $composableBuilder(
    column: $table.startDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get endDate => $composableBuilder(
    column: $table.endDate,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$GtfsCalendarEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $GtfsCalendarEntriesTable> {
  $$GtfsCalendarEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get serviceId =>
      $composableBuilder(column: $table.serviceId, builder: (column) => column);

  GeneratedColumn<bool> get monday =>
      $composableBuilder(column: $table.monday, builder: (column) => column);

  GeneratedColumn<bool> get tuesday =>
      $composableBuilder(column: $table.tuesday, builder: (column) => column);

  GeneratedColumn<bool> get wednesday =>
      $composableBuilder(column: $table.wednesday, builder: (column) => column);

  GeneratedColumn<bool> get thursday =>
      $composableBuilder(column: $table.thursday, builder: (column) => column);

  GeneratedColumn<bool> get friday =>
      $composableBuilder(column: $table.friday, builder: (column) => column);

  GeneratedColumn<bool> get saturday =>
      $composableBuilder(column: $table.saturday, builder: (column) => column);

  GeneratedColumn<bool> get sunday =>
      $composableBuilder(column: $table.sunday, builder: (column) => column);

  GeneratedColumn<DateTime> get startDate =>
      $composableBuilder(column: $table.startDate, builder: (column) => column);

  GeneratedColumn<DateTime> get endDate =>
      $composableBuilder(column: $table.endDate, builder: (column) => column);
}

class $$GtfsCalendarEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $GtfsCalendarEntriesTable,
          GtfsCalendarEntry,
          $$GtfsCalendarEntriesTableFilterComposer,
          $$GtfsCalendarEntriesTableOrderingComposer,
          $$GtfsCalendarEntriesTableAnnotationComposer,
          $$GtfsCalendarEntriesTableCreateCompanionBuilder,
          $$GtfsCalendarEntriesTableUpdateCompanionBuilder,
          (
            GtfsCalendarEntry,
            BaseReferences<
              _$AppDatabase,
              $GtfsCalendarEntriesTable,
              GtfsCalendarEntry
            >,
          ),
          GtfsCalendarEntry,
          PrefetchHooks Function()
        > {
  $$GtfsCalendarEntriesTableTableManager(
    _$AppDatabase db,
    $GtfsCalendarEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$GtfsCalendarEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$GtfsCalendarEntriesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$GtfsCalendarEntriesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> serviceId = const Value.absent(),
                Value<bool> monday = const Value.absent(),
                Value<bool> tuesday = const Value.absent(),
                Value<bool> wednesday = const Value.absent(),
                Value<bool> thursday = const Value.absent(),
                Value<bool> friday = const Value.absent(),
                Value<bool> saturday = const Value.absent(),
                Value<bool> sunday = const Value.absent(),
                Value<DateTime> startDate = const Value.absent(),
                Value<DateTime> endDate = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => GtfsCalendarEntriesCompanion(
                serviceId: serviceId,
                monday: monday,
                tuesday: tuesday,
                wednesday: wednesday,
                thursday: thursday,
                friday: friday,
                saturday: saturday,
                sunday: sunday,
                startDate: startDate,
                endDate: endDate,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String serviceId,
                required bool monday,
                required bool tuesday,
                required bool wednesday,
                required bool thursday,
                required bool friday,
                required bool saturday,
                required bool sunday,
                required DateTime startDate,
                required DateTime endDate,
                Value<int> rowid = const Value.absent(),
              }) => GtfsCalendarEntriesCompanion.insert(
                serviceId: serviceId,
                monday: monday,
                tuesday: tuesday,
                wednesday: wednesday,
                thursday: thursday,
                friday: friday,
                saturday: saturday,
                sunday: sunday,
                startDate: startDate,
                endDate: endDate,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$GtfsCalendarEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $GtfsCalendarEntriesTable,
      GtfsCalendarEntry,
      $$GtfsCalendarEntriesTableFilterComposer,
      $$GtfsCalendarEntriesTableOrderingComposer,
      $$GtfsCalendarEntriesTableAnnotationComposer,
      $$GtfsCalendarEntriesTableCreateCompanionBuilder,
      $$GtfsCalendarEntriesTableUpdateCompanionBuilder,
      (
        GtfsCalendarEntry,
        BaseReferences<
          _$AppDatabase,
          $GtfsCalendarEntriesTable,
          GtfsCalendarEntry
        >,
      ),
      GtfsCalendarEntry,
      PrefetchHooks Function()
    >;
typedef $$GtfsCalendarDateEntriesTableCreateCompanionBuilder =
    GtfsCalendarDateEntriesCompanion Function({
      required String serviceId,
      required DateTime date,
      required int exceptionType,
      Value<int> rowid,
    });
typedef $$GtfsCalendarDateEntriesTableUpdateCompanionBuilder =
    GtfsCalendarDateEntriesCompanion Function({
      Value<String> serviceId,
      Value<DateTime> date,
      Value<int> exceptionType,
      Value<int> rowid,
    });

class $$GtfsCalendarDateEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $GtfsCalendarDateEntriesTable> {
  $$GtfsCalendarDateEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get serviceId => $composableBuilder(
    column: $table.serviceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get exceptionType => $composableBuilder(
    column: $table.exceptionType,
    builder: (column) => ColumnFilters(column),
  );
}

class $$GtfsCalendarDateEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $GtfsCalendarDateEntriesTable> {
  $$GtfsCalendarDateEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get serviceId => $composableBuilder(
    column: $table.serviceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get exceptionType => $composableBuilder(
    column: $table.exceptionType,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$GtfsCalendarDateEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $GtfsCalendarDateEntriesTable> {
  $$GtfsCalendarDateEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get serviceId =>
      $composableBuilder(column: $table.serviceId, builder: (column) => column);

  GeneratedColumn<DateTime> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<int> get exceptionType => $composableBuilder(
    column: $table.exceptionType,
    builder: (column) => column,
  );
}

class $$GtfsCalendarDateEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $GtfsCalendarDateEntriesTable,
          GtfsCalendarDateEntry,
          $$GtfsCalendarDateEntriesTableFilterComposer,
          $$GtfsCalendarDateEntriesTableOrderingComposer,
          $$GtfsCalendarDateEntriesTableAnnotationComposer,
          $$GtfsCalendarDateEntriesTableCreateCompanionBuilder,
          $$GtfsCalendarDateEntriesTableUpdateCompanionBuilder,
          (
            GtfsCalendarDateEntry,
            BaseReferences<
              _$AppDatabase,
              $GtfsCalendarDateEntriesTable,
              GtfsCalendarDateEntry
            >,
          ),
          GtfsCalendarDateEntry,
          PrefetchHooks Function()
        > {
  $$GtfsCalendarDateEntriesTableTableManager(
    _$AppDatabase db,
    $GtfsCalendarDateEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$GtfsCalendarDateEntriesTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$GtfsCalendarDateEntriesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$GtfsCalendarDateEntriesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> serviceId = const Value.absent(),
                Value<DateTime> date = const Value.absent(),
                Value<int> exceptionType = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => GtfsCalendarDateEntriesCompanion(
                serviceId: serviceId,
                date: date,
                exceptionType: exceptionType,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String serviceId,
                required DateTime date,
                required int exceptionType,
                Value<int> rowid = const Value.absent(),
              }) => GtfsCalendarDateEntriesCompanion.insert(
                serviceId: serviceId,
                date: date,
                exceptionType: exceptionType,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$GtfsCalendarDateEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $GtfsCalendarDateEntriesTable,
      GtfsCalendarDateEntry,
      $$GtfsCalendarDateEntriesTableFilterComposer,
      $$GtfsCalendarDateEntriesTableOrderingComposer,
      $$GtfsCalendarDateEntriesTableAnnotationComposer,
      $$GtfsCalendarDateEntriesTableCreateCompanionBuilder,
      $$GtfsCalendarDateEntriesTableUpdateCompanionBuilder,
      (
        GtfsCalendarDateEntry,
        BaseReferences<
          _$AppDatabase,
          $GtfsCalendarDateEntriesTable,
          GtfsCalendarDateEntry
        >,
      ),
      GtfsCalendarDateEntry,
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
  $$GtfsStopsTableTableManager get gtfsStops =>
      $$GtfsStopsTableTableManager(_db, _db.gtfsStops);
  $$GtfsRoutesTableTableManager get gtfsRoutes =>
      $$GtfsRoutesTableTableManager(_db, _db.gtfsRoutes);
  $$GtfsTripsTableTableManager get gtfsTrips =>
      $$GtfsTripsTableTableManager(_db, _db.gtfsTrips);
  $$GtfsStopTimesTableTableManager get gtfsStopTimes =>
      $$GtfsStopTimesTableTableManager(_db, _db.gtfsStopTimes);
  $$GtfsCalendarEntriesTableTableManager get gtfsCalendarEntries =>
      $$GtfsCalendarEntriesTableTableManager(_db, _db.gtfsCalendarEntries);
  $$GtfsCalendarDateEntriesTableTableManager get gtfsCalendarDateEntries =>
      $$GtfsCalendarDateEntriesTableTableManager(
        _db,
        _db.gtfsCalendarDateEntries,
      );
}
