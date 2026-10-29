// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $CoursesTable extends Courses with TableInfo<$CoursesTable, Course> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CoursesTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 60,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _locationMeta = const VerificationMeta(
    'location',
  );
  @override
  late final GeneratedColumn<String> location = GeneratedColumn<String>(
    'location',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(maxTextLength: 100),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _weekdayMeta = const VerificationMeta(
    'weekday',
  );
  @override
  late final GeneratedColumn<int> weekday = GeneratedColumn<int>(
    'weekday',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startMinuteMeta = const VerificationMeta(
    'startMinute',
  );
  @override
  late final GeneratedColumn<int> startMinute = GeneratedColumn<int>(
    'start_minute',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endMinuteMeta = const VerificationMeta(
    'endMinute',
  );
  @override
  late final GeneratedColumn<int> endMinute = GeneratedColumn<int>(
    'end_minute',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _colorIndexMeta = const VerificationMeta(
    'colorIndex',
  );
  @override
  late final GeneratedColumn<int> colorIndex = GeneratedColumn<int>(
    'color_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _occurrencesMeta = const VerificationMeta(
    'occurrences',
  );
  @override
  late final GeneratedColumn<String> occurrences = GeneratedColumn<String>(
    'occurrences',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _importKeyMeta = const VerificationMeta(
    'importKey',
  );
  @override
  late final GeneratedColumn<String> importKey = GeneratedColumn<String>(
    'import_key',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _reminderMinutesMeta = const VerificationMeta(
    'reminderMinutes',
  );
  @override
  late final GeneratedColumn<int> reminderMinutes = GeneratedColumn<int>(
    'reminder_minutes',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _startPeriodMeta = const VerificationMeta(
    'startPeriod',
  );
  @override
  late final GeneratedColumn<int> startPeriod = GeneratedColumn<int>(
    'start_period',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _endPeriodMeta = const VerificationMeta(
    'endPeriod',
  );
  @override
  late final GeneratedColumn<int> endPeriod = GeneratedColumn<int>(
    'end_period',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    location,
    weekday,
    startMinute,
    endMinute,
    colorIndex,
    occurrences,
    importKey,
    description,
    kind,
    reminderMinutes,
    startPeriod,
    endPeriod,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'courses';
  @override
  VerificationContext validateIntegrity(
    Insertable<Course> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('location')) {
      context.handle(
        _locationMeta,
        location.isAcceptableOrUnknown(data['location']!, _locationMeta),
      );
    } else if (isInserting) {
      context.missing(_locationMeta);
    }
    if (data.containsKey('weekday')) {
      context.handle(
        _weekdayMeta,
        weekday.isAcceptableOrUnknown(data['weekday']!, _weekdayMeta),
      );
    } else if (isInserting) {
      context.missing(_weekdayMeta);
    }
    if (data.containsKey('start_minute')) {
      context.handle(
        _startMinuteMeta,
        startMinute.isAcceptableOrUnknown(
          data['start_minute']!,
          _startMinuteMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_startMinuteMeta);
    }
    if (data.containsKey('end_minute')) {
      context.handle(
        _endMinuteMeta,
        endMinute.isAcceptableOrUnknown(data['end_minute']!, _endMinuteMeta),
      );
    } else if (isInserting) {
      context.missing(_endMinuteMeta);
    }
    if (data.containsKey('color_index')) {
      context.handle(
        _colorIndexMeta,
        colorIndex.isAcceptableOrUnknown(data['color_index']!, _colorIndexMeta),
      );
    }
    if (data.containsKey('occurrences')) {
      context.handle(
        _occurrencesMeta,
        occurrences.isAcceptableOrUnknown(
          data['occurrences']!,
          _occurrencesMeta,
        ),
      );
    }
    if (data.containsKey('import_key')) {
      context.handle(
        _importKeyMeta,
        importKey.isAcceptableOrUnknown(data['import_key']!, _importKeyMeta),
      );
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    }
    if (data.containsKey('reminder_minutes')) {
      context.handle(
        _reminderMinutesMeta,
        reminderMinutes.isAcceptableOrUnknown(
          data['reminder_minutes']!,
          _reminderMinutesMeta,
        ),
      );
    }
    if (data.containsKey('start_period')) {
      context.handle(
        _startPeriodMeta,
        startPeriod.isAcceptableOrUnknown(
          data['start_period']!,
          _startPeriodMeta,
        ),
      );
    }
    if (data.containsKey('end_period')) {
      context.handle(
        _endPeriodMeta,
        endPeriod.isAcceptableOrUnknown(data['end_period']!, _endPeriodMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Course map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Course(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      location: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}location'],
      )!,
      weekday: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}weekday'],
      )!,
      startMinute: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}start_minute'],
      )!,
      endMinute: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}end_minute'],
      )!,
      colorIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}color_index'],
      )!,
      occurrences: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}occurrences'],
      ),
      importKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}import_key'],
      ),
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      ),
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      ),
      reminderMinutes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}reminder_minutes'],
      ),
      startPeriod: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}start_period'],
      ),
      endPeriod: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}end_period'],
      ),
    );
  }

  @override
  $CoursesTable createAlias(String alias) {
    return $CoursesTable(attachedDatabase, alias);
  }
}

class Course extends DataClass implements Insertable<Course> {
  final int id;
  final String name;
  final String location;
  final int weekday;
  final int startMinute;
  final int endMinute;
  final int colorIndex;
  final String? occurrences;
  final String? importKey;
  final String? description;
  final String? kind;
  final int? reminderMinutes;
  final int? startPeriod;
  final int? endPeriod;
  const Course({
    required this.id,
    required this.name,
    required this.location,
    required this.weekday,
    required this.startMinute,
    required this.endMinute,
    required this.colorIndex,
    this.occurrences,
    this.importKey,
    this.description,
    this.kind,
    this.reminderMinutes,
    this.startPeriod,
    this.endPeriod,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['location'] = Variable<String>(location);
    map['weekday'] = Variable<int>(weekday);
    map['start_minute'] = Variable<int>(startMinute);
    map['end_minute'] = Variable<int>(endMinute);
    map['color_index'] = Variable<int>(colorIndex);
    if (!nullToAbsent || occurrences != null) {
      map['occurrences'] = Variable<String>(occurrences);
    }
    if (!nullToAbsent || importKey != null) {
      map['import_key'] = Variable<String>(importKey);
    }
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    if (!nullToAbsent || kind != null) {
      map['kind'] = Variable<String>(kind);
    }
    if (!nullToAbsent || reminderMinutes != null) {
      map['reminder_minutes'] = Variable<int>(reminderMinutes);
    }
    if (!nullToAbsent || startPeriod != null) {
      map['start_period'] = Variable<int>(startPeriod);
    }
    if (!nullToAbsent || endPeriod != null) {
      map['end_period'] = Variable<int>(endPeriod);
    }
    return map;
  }

  CoursesCompanion toCompanion(bool nullToAbsent) {
    return CoursesCompanion(
      id: Value(id),
      name: Value(name),
      location: Value(location),
      weekday: Value(weekday),
      startMinute: Value(startMinute),
      endMinute: Value(endMinute),
      colorIndex: Value(colorIndex),
      occurrences: occurrences == null && nullToAbsent
          ? const Value.absent()
          : Value(occurrences),
      importKey: importKey == null && nullToAbsent
          ? const Value.absent()
          : Value(importKey),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      kind: kind == null && nullToAbsent ? const Value.absent() : Value(kind),
      reminderMinutes: reminderMinutes == null && nullToAbsent
          ? const Value.absent()
          : Value(reminderMinutes),
      startPeriod: startPeriod == null && nullToAbsent
          ? const Value.absent()
          : Value(startPeriod),
      endPeriod: endPeriod == null && nullToAbsent
          ? const Value.absent()
          : Value(endPeriod),
    );
  }

  factory Course.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Course(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      location: serializer.fromJson<String>(json['location']),
      weekday: serializer.fromJson<int>(json['weekday']),
      startMinute: serializer.fromJson<int>(json['startMinute']),
      endMinute: serializer.fromJson<int>(json['endMinute']),
      colorIndex: serializer.fromJson<int>(json['colorIndex']),
      occurrences: serializer.fromJson<String?>(json['occurrences']),
      importKey: serializer.fromJson<String?>(json['importKey']),
      description: serializer.fromJson<String?>(json['description']),
      kind: serializer.fromJson<String?>(json['kind']),
      reminderMinutes: serializer.fromJson<int?>(json['reminderMinutes']),
      startPeriod: serializer.fromJson<int?>(json['startPeriod']),
      endPeriod: serializer.fromJson<int?>(json['endPeriod']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'location': serializer.toJson<String>(location),
      'weekday': serializer.toJson<int>(weekday),
      'startMinute': serializer.toJson<int>(startMinute),
      'endMinute': serializer.toJson<int>(endMinute),
      'colorIndex': serializer.toJson<int>(colorIndex),
      'occurrences': serializer.toJson<String?>(occurrences),
      'importKey': serializer.toJson<String?>(importKey),
      'description': serializer.toJson<String?>(description),
      'kind': serializer.toJson<String?>(kind),
      'reminderMinutes': serializer.toJson<int?>(reminderMinutes),
      'startPeriod': serializer.toJson<int?>(startPeriod),
      'endPeriod': serializer.toJson<int?>(endPeriod),
    };
  }

  Course copyWith({
    int? id,
    String? name,
    String? location,
    int? weekday,
    int? startMinute,
    int? endMinute,
    int? colorIndex,
    Value<String?> occurrences = const Value.absent(),
    Value<String?> importKey = const Value.absent(),
    Value<String?> description = const Value.absent(),
    Value<String?> kind = const Value.absent(),
    Value<int?> reminderMinutes = const Value.absent(),
    Value<int?> startPeriod = const Value.absent(),
    Value<int?> endPeriod = const Value.absent(),
  }) => Course(
    id: id ?? this.id,
    name: name ?? this.name,
    location: location ?? this.location,
    weekday: weekday ?? this.weekday,
    startMinute: startMinute ?? this.startMinute,
    endMinute: endMinute ?? this.endMinute,
    colorIndex: colorIndex ?? this.colorIndex,
    occurrences: occurrences.present ? occurrences.value : this.occurrences,
    importKey: importKey.present ? importKey.value : this.importKey,
    description: description.present ? description.value : this.description,
    kind: kind.present ? kind.value : this.kind,
    reminderMinutes: reminderMinutes.present
        ? reminderMinutes.value
        : this.reminderMinutes,
    startPeriod: startPeriod.present ? startPeriod.value : this.startPeriod,
    endPeriod: endPeriod.present ? endPeriod.value : this.endPeriod,
  );
  Course copyWithCompanion(CoursesCompanion data) {
    return Course(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      location: data.location.present ? data.location.value : this.location,
      weekday: data.weekday.present ? data.weekday.value : this.weekday,
      startMinute: data.startMinute.present
          ? data.startMinute.value
          : this.startMinute,
      endMinute: data.endMinute.present ? data.endMinute.value : this.endMinute,
      colorIndex: data.colorIndex.present
          ? data.colorIndex.value
          : this.colorIndex,
      occurrences: data.occurrences.present
          ? data.occurrences.value
          : this.occurrences,
      importKey: data.importKey.present ? data.importKey.value : this.importKey,
      description: data.description.present
          ? data.description.value
          : this.description,
      kind: data.kind.present ? data.kind.value : this.kind,
      reminderMinutes: data.reminderMinutes.present
          ? data.reminderMinutes.value
          : this.reminderMinutes,
      startPeriod: data.startPeriod.present
          ? data.startPeriod.value
          : this.startPeriod,
      endPeriod: data.endPeriod.present ? data.endPeriod.value : this.endPeriod,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Course(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('location: $location, ')
          ..write('weekday: $weekday, ')
          ..write('startMinute: $startMinute, ')
          ..write('endMinute: $endMinute, ')
          ..write('colorIndex: $colorIndex, ')
          ..write('occurrences: $occurrences, ')
          ..write('importKey: $importKey, ')
          ..write('description: $description, ')
          ..write('kind: $kind, ')
          ..write('reminderMinutes: $reminderMinutes, ')
          ..write('startPeriod: $startPeriod, ')
          ..write('endPeriod: $endPeriod')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    location,
    weekday,
    startMinute,
    endMinute,
    colorIndex,
    occurrences,
    importKey,
    description,
    kind,
    reminderMinutes,
    startPeriod,
    endPeriod,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Course &&
          other.id == this.id &&
          other.name == this.name &&
          other.location == this.location &&
          other.weekday == this.weekday &&
          other.startMinute == this.startMinute &&
          other.endMinute == this.endMinute &&
          other.colorIndex == this.colorIndex &&
          other.occurrences == this.occurrences &&
          other.importKey == this.importKey &&
          other.description == this.description &&
          other.kind == this.kind &&
          other.reminderMinutes == this.reminderMinutes &&
          other.startPeriod == this.startPeriod &&
          other.endPeriod == this.endPeriod);
}

class CoursesCompanion extends UpdateCompanion<Course> {
  final Value<int> id;
  final Value<String> name;
  final Value<String> location;
  final Value<int> weekday;
  final Value<int> startMinute;
  final Value<int> endMinute;
  final Value<int> colorIndex;
  final Value<String?> occurrences;
  final Value<String?> importKey;
  final Value<String?> description;
  final Value<String?> kind;
  final Value<int?> reminderMinutes;
  final Value<int?> startPeriod;
  final Value<int?> endPeriod;
  const CoursesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.location = const Value.absent(),
    this.weekday = const Value.absent(),
    this.startMinute = const Value.absent(),
    this.endMinute = const Value.absent(),
    this.colorIndex = const Value.absent(),
    this.occurrences = const Value.absent(),
    this.importKey = const Value.absent(),
    this.description = const Value.absent(),
    this.kind = const Value.absent(),
    this.reminderMinutes = const Value.absent(),
    this.startPeriod = const Value.absent(),
    this.endPeriod = const Value.absent(),
  });
  CoursesCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    required String location,
    required int weekday,
    required int startMinute,
    required int endMinute,
    this.colorIndex = const Value.absent(),
    this.occurrences = const Value.absent(),
    this.importKey = const Value.absent(),
    this.description = const Value.absent(),
    this.kind = const Value.absent(),
    this.reminderMinutes = const Value.absent(),
    this.startPeriod = const Value.absent(),
    this.endPeriod = const Value.absent(),
  }) : name = Value(name),
       location = Value(location),
       weekday = Value(weekday),
       startMinute = Value(startMinute),
       endMinute = Value(endMinute);
  static Insertable<Course> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? location,
    Expression<int>? weekday,
    Expression<int>? startMinute,
    Expression<int>? endMinute,
    Expression<int>? colorIndex,
    Expression<String>? occurrences,
    Expression<String>? importKey,
    Expression<String>? description,
    Expression<String>? kind,
    Expression<int>? reminderMinutes,
    Expression<int>? startPeriod,
    Expression<int>? endPeriod,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (location != null) 'location': location,
      if (weekday != null) 'weekday': weekday,
      if (startMinute != null) 'start_minute': startMinute,
      if (endMinute != null) 'end_minute': endMinute,
      if (colorIndex != null) 'color_index': colorIndex,
      if (occurrences != null) 'occurrences': occurrences,
      if (importKey != null) 'import_key': importKey,
      if (description != null) 'description': description,
      if (kind != null) 'kind': kind,
      if (reminderMinutes != null) 'reminder_minutes': reminderMinutes,
      if (startPeriod != null) 'start_period': startPeriod,
      if (endPeriod != null) 'end_period': endPeriod,
    });
  }

  CoursesCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<String>? location,
    Value<int>? weekday,
    Value<int>? startMinute,
    Value<int>? endMinute,
    Value<int>? colorIndex,
    Value<String?>? occurrences,
    Value<String?>? importKey,
    Value<String?>? description,
    Value<String?>? kind,
    Value<int?>? reminderMinutes,
    Value<int?>? startPeriod,
    Value<int?>? endPeriod,
  }) {
    return CoursesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      location: location ?? this.location,
      weekday: weekday ?? this.weekday,
      startMinute: startMinute ?? this.startMinute,
      endMinute: endMinute ?? this.endMinute,
      colorIndex: colorIndex ?? this.colorIndex,
      occurrences: occurrences ?? this.occurrences,
      importKey: importKey ?? this.importKey,
      description: description ?? this.description,
      kind: kind ?? this.kind,
      reminderMinutes: reminderMinutes ?? this.reminderMinutes,
      startPeriod: startPeriod ?? this.startPeriod,
      endPeriod: endPeriod ?? this.endPeriod,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (location.present) {
      map['location'] = Variable<String>(location.value);
    }
    if (weekday.present) {
      map['weekday'] = Variable<int>(weekday.value);
    }
    if (startMinute.present) {
      map['start_minute'] = Variable<int>(startMinute.value);
    }
    if (endMinute.present) {
      map['end_minute'] = Variable<int>(endMinute.value);
    }
    if (colorIndex.present) {
      map['color_index'] = Variable<int>(colorIndex.value);
    }
    if (occurrences.present) {
      map['occurrences'] = Variable<String>(occurrences.value);
    }
    if (importKey.present) {
      map['import_key'] = Variable<String>(importKey.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (reminderMinutes.present) {
      map['reminder_minutes'] = Variable<int>(reminderMinutes.value);
    }
    if (startPeriod.present) {
      map['start_period'] = Variable<int>(startPeriod.value);
    }
    if (endPeriod.present) {
      map['end_period'] = Variable<int>(endPeriod.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CoursesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('location: $location, ')
          ..write('weekday: $weekday, ')
          ..write('startMinute: $startMinute, ')
          ..write('endMinute: $endMinute, ')
          ..write('colorIndex: $colorIndex, ')
          ..write('occurrences: $occurrences, ')
          ..write('importKey: $importKey, ')
          ..write('description: $description, ')
          ..write('kind: $kind, ')
          ..write('reminderMinutes: $reminderMinutes, ')
          ..write('startPeriod: $startPeriod, ')
          ..write('endPeriod: $endPeriod')
          ..write(')'))
        .toString();
  }
}

class $PreferencesTable extends Preferences
    with TableInfo<$PreferencesTable, Preference> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PreferencesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _remindersMeta = const VerificationMeta(
    'reminders',
  );
  @override
  late final GeneratedColumn<bool> reminders = GeneratedColumn<bool>(
    'reminders',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("reminders" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _leadMinutesMeta = const VerificationMeta(
    'leadMinutes',
  );
  @override
  late final GeneratedColumn<int> leadMinutes = GeneratedColumn<int>(
    'lead_minutes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(10),
  );
  static const VerificationMeta _endingLeadMinutesMeta = const VerificationMeta(
    'endingLeadMinutes',
  );
  @override
  late final GeneratedColumn<int> endingLeadMinutes = GeneratedColumn<int>(
    'ending_lead_minutes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(10),
  );
  static const VerificationMeta _useFileRemindersMeta = const VerificationMeta(
    'useFileReminders',
  );
  @override
  late final GeneratedColumn<bool> useFileReminders = GeneratedColumn<bool>(
    'use_file_reminders',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("use_file_reminders" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _semesterStartMeta = const VerificationMeta(
    'semesterStart',
  );
  @override
  late final GeneratedColumn<DateTime> semesterStart =
      GeneratedColumn<DateTime>(
        'semester_start',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _timetableConfigMeta = const VerificationMeta(
    'timetableConfig',
  );
  @override
  late final GeneratedColumn<String> timetableConfig = GeneratedColumn<String>(
    'timetable_config',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    reminders,
    leadMinutes,
    endingLeadMinutes,
    useFileReminders,
    semesterStart,
    timetableConfig,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'preferences';
  @override
  VerificationContext validateIntegrity(
    Insertable<Preference> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('reminders')) {
      context.handle(
        _remindersMeta,
        reminders.isAcceptableOrUnknown(data['reminders']!, _remindersMeta),
      );
    }
    if (data.containsKey('lead_minutes')) {
      context.handle(
        _leadMinutesMeta,
        leadMinutes.isAcceptableOrUnknown(
          data['lead_minutes']!,
          _leadMinutesMeta,
        ),
      );
    }
    if (data.containsKey('ending_lead_minutes')) {
      context.handle(
        _endingLeadMinutesMeta,
        endingLeadMinutes.isAcceptableOrUnknown(
          data['ending_lead_minutes']!,
          _endingLeadMinutesMeta,
        ),
      );
    }
    if (data.containsKey('use_file_reminders')) {
      context.handle(
        _useFileRemindersMeta,
        useFileReminders.isAcceptableOrUnknown(
          data['use_file_reminders']!,
          _useFileRemindersMeta,
        ),
      );
    }
    if (data.containsKey('semester_start')) {
      context.handle(
        _semesterStartMeta,
        semesterStart.isAcceptableOrUnknown(
          data['semester_start']!,
          _semesterStartMeta,
        ),
      );
    }
    if (data.containsKey('timetable_config')) {
      context.handle(
        _timetableConfigMeta,
        timetableConfig.isAcceptableOrUnknown(
          data['timetable_config']!,
          _timetableConfigMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Preference map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Preference(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      reminders: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}reminders'],
      )!,
      leadMinutes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}lead_minutes'],
      )!,
      endingLeadMinutes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}ending_lead_minutes'],
      )!,
      useFileReminders: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}use_file_reminders'],
      )!,
      semesterStart: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}semester_start'],
      ),
      timetableConfig: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}timetable_config'],
      ),
    );
  }

  @override
  $PreferencesTable createAlias(String alias) {
    return $PreferencesTable(attachedDatabase, alias);
  }
}

class Preference extends DataClass implements Insertable<Preference> {
  final int id;
  final bool reminders;
  final int leadMinutes;
  final int endingLeadMinutes;
  final bool useFileReminders;
  final DateTime? semesterStart;
  final String? timetableConfig;
  const Preference({
    required this.id,
    required this.reminders,
    required this.leadMinutes,
    required this.endingLeadMinutes,
    required this.useFileReminders,
    this.semesterStart,
    this.timetableConfig,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['reminders'] = Variable<bool>(reminders);
    map['lead_minutes'] = Variable<int>(leadMinutes);
    map['ending_lead_minutes'] = Variable<int>(endingLeadMinutes);
    map['use_file_reminders'] = Variable<bool>(useFileReminders);
    if (!nullToAbsent || semesterStart != null) {
      map['semester_start'] = Variable<DateTime>(semesterStart);
    }
    if (!nullToAbsent || timetableConfig != null) {
      map['timetable_config'] = Variable<String>(timetableConfig);
    }
    return map;
  }

  PreferencesCompanion toCompanion(bool nullToAbsent) {
    return PreferencesCompanion(
      id: Value(id),
      reminders: Value(reminders),
      leadMinutes: Value(leadMinutes),
      endingLeadMinutes: Value(endingLeadMinutes),
      useFileReminders: Value(useFileReminders),
      semesterStart: semesterStart == null && nullToAbsent
          ? const Value.absent()
          : Value(semesterStart),
      timetableConfig: timetableConfig == null && nullToAbsent
          ? const Value.absent()
          : Value(timetableConfig),
    );
  }

  factory Preference.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Preference(
      id: serializer.fromJson<int>(json['id']),
      reminders: serializer.fromJson<bool>(json['reminders']),
      leadMinutes: serializer.fromJson<int>(json['leadMinutes']),
      endingLeadMinutes: serializer.fromJson<int>(json['endingLeadMinutes']),
      useFileReminders: serializer.fromJson<bool>(json['useFileReminders']),
      semesterStart: serializer.fromJson<DateTime?>(json['semesterStart']),
      timetableConfig: serializer.fromJson<String?>(json['timetableConfig']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'reminders': serializer.toJson<bool>(reminders),
      'leadMinutes': serializer.toJson<int>(leadMinutes),
      'endingLeadMinutes': serializer.toJson<int>(endingLeadMinutes),
      'useFileReminders': serializer.toJson<bool>(useFileReminders),
      'semesterStart': serializer.toJson<DateTime?>(semesterStart),
      'timetableConfig': serializer.toJson<String?>(timetableConfig),
    };
  }

  Preference copyWith({
    int? id,
    bool? reminders,
    int? leadMinutes,
    int? endingLeadMinutes,
    bool? useFileReminders,
    Value<DateTime?> semesterStart = const Value.absent(),
    Value<String?> timetableConfig = const Value.absent(),
  }) => Preference(
    id: id ?? this.id,
    reminders: reminders ?? this.reminders,
    leadMinutes: leadMinutes ?? this.leadMinutes,
    endingLeadMinutes: endingLeadMinutes ?? this.endingLeadMinutes,
    useFileReminders: useFileReminders ?? this.useFileReminders,
    semesterStart: semesterStart.present
        ? semesterStart.value
        : this.semesterStart,
    timetableConfig: timetableConfig.present
        ? timetableConfig.value
        : this.timetableConfig,
  );
  Preference copyWithCompanion(PreferencesCompanion data) {
    return Preference(
      id: data.id.present ? data.id.value : this.id,
      reminders: data.reminders.present ? data.reminders.value : this.reminders,
      leadMinutes: data.leadMinutes.present
          ? data.leadMinutes.value
          : this.leadMinutes,
      endingLeadMinutes: data.endingLeadMinutes.present
          ? data.endingLeadMinutes.value
          : this.endingLeadMinutes,
      useFileReminders: data.useFileReminders.present
          ? data.useFileReminders.value
          : this.useFileReminders,
      semesterStart: data.semesterStart.present
          ? data.semesterStart.value
          : this.semesterStart,
      timetableConfig: data.timetableConfig.present
          ? data.timetableConfig.value
          : this.timetableConfig,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Preference(')
          ..write('id: $id, ')
          ..write('reminders: $reminders, ')
          ..write('leadMinutes: $leadMinutes, ')
          ..write('endingLeadMinutes: $endingLeadMinutes, ')
          ..write('useFileReminders: $useFileReminders, ')
          ..write('semesterStart: $semesterStart, ')
          ..write('timetableConfig: $timetableConfig')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    reminders,
    leadMinutes,
    endingLeadMinutes,
    useFileReminders,
    semesterStart,
    timetableConfig,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Preference &&
          other.id == this.id &&
          other.reminders == this.reminders &&
          other.leadMinutes == this.leadMinutes &&
          other.endingLeadMinutes == this.endingLeadMinutes &&
          other.useFileReminders == this.useFileReminders &&
          other.semesterStart == this.semesterStart &&
          other.timetableConfig == this.timetableConfig);
}

class PreferencesCompanion extends UpdateCompanion<Preference> {
  final Value<int> id;
  final Value<bool> reminders;
  final Value<int> leadMinutes;
  final Value<int> endingLeadMinutes;
  final Value<bool> useFileReminders;
  final Value<DateTime?> semesterStart;
  final Value<String?> timetableConfig;
  const PreferencesCompanion({
    this.id = const Value.absent(),
    this.reminders = const Value.absent(),
    this.leadMinutes = const Value.absent(),
    this.endingLeadMinutes = const Value.absent(),
    this.useFileReminders = const Value.absent(),
    this.semesterStart = const Value.absent(),
    this.timetableConfig = const Value.absent(),
  });
  PreferencesCompanion.insert({
    this.id = const Value.absent(),
    this.reminders = const Value.absent(),
    this.leadMinutes = const Value.absent(),
    this.endingLeadMinutes = const Value.absent(),
    this.useFileReminders = const Value.absent(),
    this.semesterStart = const Value.absent(),
    this.timetableConfig = const Value.absent(),
  });
  static Insertable<Preference> custom({
    Expression<int>? id,
    Expression<bool>? reminders,
    Expression<int>? leadMinutes,
    Expression<int>? endingLeadMinutes,
    Expression<bool>? useFileReminders,
    Expression<DateTime>? semesterStart,
    Expression<String>? timetableConfig,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (reminders != null) 'reminders': reminders,
      if (leadMinutes != null) 'lead_minutes': leadMinutes,
      if (endingLeadMinutes != null) 'ending_lead_minutes': endingLeadMinutes,
      if (useFileReminders != null) 'use_file_reminders': useFileReminders,
      if (semesterStart != null) 'semester_start': semesterStart,
      if (timetableConfig != null) 'timetable_config': timetableConfig,
    });
  }

  PreferencesCompanion copyWith({
    Value<int>? id,
    Value<bool>? reminders,
    Value<int>? leadMinutes,
    Value<int>? endingLeadMinutes,
    Value<bool>? useFileReminders,
    Value<DateTime?>? semesterStart,
    Value<String?>? timetableConfig,
  }) {
    return PreferencesCompanion(
      id: id ?? this.id,
      reminders: reminders ?? this.reminders,
      leadMinutes: leadMinutes ?? this.leadMinutes,
      endingLeadMinutes: endingLeadMinutes ?? this.endingLeadMinutes,
      useFileReminders: useFileReminders ?? this.useFileReminders,
      semesterStart: semesterStart ?? this.semesterStart,
      timetableConfig: timetableConfig ?? this.timetableConfig,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (reminders.present) {
      map['reminders'] = Variable<bool>(reminders.value);
    }
    if (leadMinutes.present) {
      map['lead_minutes'] = Variable<int>(leadMinutes.value);
    }
    if (endingLeadMinutes.present) {
      map['ending_lead_minutes'] = Variable<int>(endingLeadMinutes.value);
    }
    if (useFileReminders.present) {
      map['use_file_reminders'] = Variable<bool>(useFileReminders.value);
    }
    if (semesterStart.present) {
      map['semester_start'] = Variable<DateTime>(semesterStart.value);
    }
    if (timetableConfig.present) {
      map['timetable_config'] = Variable<String>(timetableConfig.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PreferencesCompanion(')
          ..write('id: $id, ')
          ..write('reminders: $reminders, ')
          ..write('leadMinutes: $leadMinutes, ')
          ..write('endingLeadMinutes: $endingLeadMinutes, ')
          ..write('useFileReminders: $useFileReminders, ')
          ..write('semesterStart: $semesterStart, ')
          ..write('timetableConfig: $timetableConfig')
          ..write(')'))
        .toString();
  }
}

abstract class _$ScheduleDatabase extends GeneratedDatabase {
  _$ScheduleDatabase(QueryExecutor e) : super(e);
  $ScheduleDatabaseManager get managers => $ScheduleDatabaseManager(this);
  late final $CoursesTable courses = $CoursesTable(this);
  late final $PreferencesTable preferences = $PreferencesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [courses, preferences];
}

typedef $$CoursesTableCreateCompanionBuilder = CoursesCompanion Function({
  Value<int> id,
  required String name,
  required String location,
  required int weekday,
  required int startMinute,
  required int endMinute,
  Value<int> colorIndex,
  Value<String?> occurrences,
  Value<String?> importKey,
  Value<String?> description,
  Value<String?> kind,
  Value<int?> reminderMinutes,
  Value<int?> startPeriod,
  Value<int?> endPeriod,
});
typedef $$CoursesTableUpdateCompanionBuilder = CoursesCompanion Function({
  Value<int> id,
  Value<String> name,
  Value<String> location,
  Value<int> weekday,
  Value<int> startMinute,
  Value<int> endMinute,
  Value<int> colorIndex,
  Value<String?> occurrences,
  Value<String?> importKey,
  Value<String?> description,
  Value<String?> kind,
  Value<int?> reminderMinutes,
  Value<int?> startPeriod,
  Value<int?> endPeriod,
});

class $$CoursesTableFilterComposer
    extends Composer<_$ScheduleDatabase, $CoursesTable> {
  $$CoursesTableFilterComposer({
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

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get location => $composableBuilder(
    column: $table.location,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get weekday => $composableBuilder(
    column: $table.weekday,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get startMinute => $composableBuilder(
    column: $table.startMinute,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get endMinute => $composableBuilder(
    column: $table.endMinute,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get colorIndex => $composableBuilder(
    column: $table.colorIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get occurrences => $composableBuilder(
    column: $table.occurrences,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get importKey => $composableBuilder(
    column: $table.importKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get reminderMinutes => $composableBuilder(
    column: $table.reminderMinutes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get startPeriod => $composableBuilder(
    column: $table.startPeriod,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get endPeriod => $composableBuilder(
    column: $table.endPeriod,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CoursesTableOrderingComposer
    extends Composer<_$ScheduleDatabase, $CoursesTable> {
  $$CoursesTableOrderingComposer({
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

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get location => $composableBuilder(
    column: $table.location,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get weekday => $composableBuilder(
    column: $table.weekday,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get startMinute => $composableBuilder(
    column: $table.startMinute,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get endMinute => $composableBuilder(
    column: $table.endMinute,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get colorIndex => $composableBuilder(
    column: $table.colorIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get occurrences => $composableBuilder(
    column: $table.occurrences,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get importKey => $composableBuilder(
    column: $table.importKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get reminderMinutes => $composableBuilder(
    column: $table.reminderMinutes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get startPeriod => $composableBuilder(
    column: $table.startPeriod,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get endPeriod => $composableBuilder(
    column: $table.endPeriod,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CoursesTableAnnotationComposer
    extends Composer<_$ScheduleDatabase, $CoursesTable> {
  $$CoursesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get location =>
      $composableBuilder(column: $table.location, builder: (column) => column);

  GeneratedColumn<int> get weekday =>
      $composableBuilder(column: $table.weekday, builder: (column) => column);

  GeneratedColumn<int> get startMinute => $composableBuilder(
    column: $table.startMinute,
    builder: (column) => column,
  );

  GeneratedColumn<int> get endMinute =>
      $composableBuilder(column: $table.endMinute, builder: (column) => column);

  GeneratedColumn<int> get colorIndex => $composableBuilder(
    column: $table.colorIndex,
    builder: (column) => column,
  );

  GeneratedColumn<String> get occurrences => $composableBuilder(
    column: $table.occurrences,
    builder: (column) => column,
  );

  GeneratedColumn<String> get importKey =>
      $composableBuilder(column: $table.importKey, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<int> get reminderMinutes => $composableBuilder(
    column: $table.reminderMinutes,
    builder: (column) => column,
  );

  GeneratedColumn<int> get startPeriod => $composableBuilder(
    column: $table.startPeriod,
    builder: (column) => column,
  );

  GeneratedColumn<int> get endPeriod =>
      $composableBuilder(column: $table.endPeriod, builder: (column) => column);
}

class $$CoursesTableTableManager
    extends
        RootTableManager<
          _$ScheduleDatabase,
          $CoursesTable,
          Course,
          $$CoursesTableFilterComposer,
          $$CoursesTableOrderingComposer,
          $$CoursesTableAnnotationComposer,
          $$CoursesTableCreateCompanionBuilder,
          $$CoursesTableUpdateCompanionBuilder,
          (Course, BaseReferences<_$ScheduleDatabase, $CoursesTable, Course>),
          Course,
          PrefetchHooks Function()
        > {
  $$CoursesTableTableManager(_$ScheduleDatabase db, $CoursesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CoursesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CoursesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CoursesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> location = const Value.absent(),
                Value<int> weekday = const Value.absent(),
                Value<int> startMinute = const Value.absent(),
                Value<int> endMinute = const Value.absent(),
                Value<int> colorIndex = const Value.absent(),
                Value<String?> occurrences = const Value.absent(),
                Value<String?> importKey = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<String?> kind = const Value.absent(),
                Value<int?> reminderMinutes = const Value.absent(),
                Value<int?> startPeriod = const Value.absent(),
                Value<int?> endPeriod = const Value.absent(),
              }) => CoursesCompanion(
                id: id,
                name: name,
                location: location,
                weekday: weekday,
                startMinute: startMinute,
                endMinute: endMinute,
                colorIndex: colorIndex,
                occurrences: occurrences,
                importKey: importKey,
                description: description,
                kind: kind,
                reminderMinutes: reminderMinutes,
                startPeriod: startPeriod,
                endPeriod: endPeriod,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                required String location,
                required int weekday,
                required int startMinute,
                required int endMinute,
                Value<int> colorIndex = const Value.absent(),
                Value<String?> occurrences = const Value.absent(),
                Value<String?> importKey = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<String?> kind = const Value.absent(),
                Value<int?> reminderMinutes = const Value.absent(),
                Value<int?> startPeriod = const Value.absent(),
                Value<int?> endPeriod = const Value.absent(),
              }) => CoursesCompanion.insert(
                id: id,
                name: name,
                location: location,
                weekday: weekday,
                startMinute: startMinute,
                endMinute: endMinute,
                colorIndex: colorIndex,
                occurrences: occurrences,
                importKey: importKey,
                description: description,
                kind: kind,
                reminderMinutes: reminderMinutes,
                startPeriod: startPeriod,
                endPeriod: endPeriod,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CoursesTable, Course>(table),
                  BaseReferences<_$ScheduleDatabase, $CoursesTable, Course>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CoursesTableProcessedTableManager =
    ProcessedTableManager<
      _$ScheduleDatabase,
      $CoursesTable,
      Course,
      $$CoursesTableFilterComposer,
      $$CoursesTableOrderingComposer,
      $$CoursesTableAnnotationComposer,
      $$CoursesTableCreateCompanionBuilder,
      $$CoursesTableUpdateCompanionBuilder,
      (Course, BaseReferences<_$ScheduleDatabase, $CoursesTable, Course>),
      Course,
      PrefetchHooks Function()
    >;
typedef $$PreferencesTableCreateCompanionBuilder =
    PreferencesCompanion Function({
      Value<int> id,
      Value<bool> reminders,
      Value<int> leadMinutes,
      Value<int> endingLeadMinutes,
      Value<bool> useFileReminders,
      Value<DateTime?> semesterStart,
      Value<String?> timetableConfig,
    });
typedef $$PreferencesTableUpdateCompanionBuilder =
    PreferencesCompanion Function({
      Value<int> id,
      Value<bool> reminders,
      Value<int> leadMinutes,
      Value<int> endingLeadMinutes,
      Value<bool> useFileReminders,
      Value<DateTime?> semesterStart,
      Value<String?> timetableConfig,
    });

class $$PreferencesTableFilterComposer
    extends Composer<_$ScheduleDatabase, $PreferencesTable> {
  $$PreferencesTableFilterComposer({
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

  ColumnFilters<bool> get reminders => $composableBuilder(
    column: $table.reminders,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get leadMinutes => $composableBuilder(
    column: $table.leadMinutes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get endingLeadMinutes => $composableBuilder(
    column: $table.endingLeadMinutes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get useFileReminders => $composableBuilder(
    column: $table.useFileReminders,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get semesterStart => $composableBuilder(
    column: $table.semesterStart,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get timetableConfig => $composableBuilder(
    column: $table.timetableConfig,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PreferencesTableOrderingComposer
    extends Composer<_$ScheduleDatabase, $PreferencesTable> {
  $$PreferencesTableOrderingComposer({
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

  ColumnOrderings<bool> get reminders => $composableBuilder(
    column: $table.reminders,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get leadMinutes => $composableBuilder(
    column: $table.leadMinutes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get endingLeadMinutes => $composableBuilder(
    column: $table.endingLeadMinutes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get useFileReminders => $composableBuilder(
    column: $table.useFileReminders,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get semesterStart => $composableBuilder(
    column: $table.semesterStart,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get timetableConfig => $composableBuilder(
    column: $table.timetableConfig,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PreferencesTableAnnotationComposer
    extends Composer<_$ScheduleDatabase, $PreferencesTable> {
  $$PreferencesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<bool> get reminders =>
      $composableBuilder(column: $table.reminders, builder: (column) => column);

  GeneratedColumn<int> get leadMinutes => $composableBuilder(
    column: $table.leadMinutes,
    builder: (column) => column,
  );

  GeneratedColumn<int> get endingLeadMinutes => $composableBuilder(
    column: $table.endingLeadMinutes,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get useFileReminders => $composableBuilder(
    column: $table.useFileReminders,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get semesterStart => $composableBuilder(
    column: $table.semesterStart,
    builder: (column) => column,
  );

  GeneratedColumn<String> get timetableConfig => $composableBuilder(
    column: $table.timetableConfig,
    builder: (column) => column,
  );
}

class $$PreferencesTableTableManager
    extends
        RootTableManager<
          _$ScheduleDatabase,
          $PreferencesTable,
          Preference,
          $$PreferencesTableFilterComposer,
          $$PreferencesTableOrderingComposer,
          $$PreferencesTableAnnotationComposer,
          $$PreferencesTableCreateCompanionBuilder,
          $$PreferencesTableUpdateCompanionBuilder,
          (
            Preference,
            BaseReferences<_$ScheduleDatabase, $PreferencesTable, Preference>,
          ),
          Preference,
          PrefetchHooks Function()
        > {
  $$PreferencesTableTableManager(_$ScheduleDatabase db, $PreferencesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PreferencesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PreferencesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PreferencesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<bool> reminders = const Value.absent(),
                Value<int> leadMinutes = const Value.absent(),
                Value<int> endingLeadMinutes = const Value.absent(),
                Value<bool> useFileReminders = const Value.absent(),
                Value<DateTime?> semesterStart = const Value.absent(),
                Value<String?> timetableConfig = const Value.absent(),
              }) => PreferencesCompanion(
                id: id,
                reminders: reminders,
                leadMinutes: leadMinutes,
                endingLeadMinutes: endingLeadMinutes,
                useFileReminders: useFileReminders,
                semesterStart: semesterStart,
                timetableConfig: timetableConfig,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<bool> reminders = const Value.absent(),
                Value<int> leadMinutes = const Value.absent(),
                Value<int> endingLeadMinutes = const Value.absent(),
                Value<bool> useFileReminders = const Value.absent(),
                Value<DateTime?> semesterStart = const Value.absent(),
                Value<String?> timetableConfig = const Value.absent(),
              }) => PreferencesCompanion.insert(
                id: id,
                reminders: reminders,
                leadMinutes: leadMinutes,
                endingLeadMinutes: endingLeadMinutes,
                useFileReminders: useFileReminders,
                semesterStart: semesterStart,
                timetableConfig: timetableConfig,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$PreferencesTable, Preference>(table),
                  BaseReferences<
                    _$ScheduleDatabase,
                    $PreferencesTable,
                    Preference
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PreferencesTableProcessedTableManager =
    ProcessedTableManager<
      _$ScheduleDatabase,
      $PreferencesTable,
      Preference,
      $$PreferencesTableFilterComposer,
      $$PreferencesTableOrderingComposer,
      $$PreferencesTableAnnotationComposer,
      $$PreferencesTableCreateCompanionBuilder,
      $$PreferencesTableUpdateCompanionBuilder,
      (
        Preference,
        BaseReferences<_$ScheduleDatabase, $PreferencesTable, Preference>,
      ),
      Preference,
      PrefetchHooks Function()
    >;

class $ScheduleDatabaseManager {
  final _$ScheduleDatabase _db;
  $ScheduleDatabaseManager(this._db);
  $$CoursesTableTableManager get courses =>
      $$CoursesTableTableManager(_db, _db.courses);
  $$PreferencesTableTableManager get preferences =>
      $$PreferencesTableTableManager(_db, _db.preferences);
}
