import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'timetable_settings.dart';

part 'database.g.dart';

class Courses extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 60)();
  TextColumn get location => text().withLength(max: 100)();
  IntColumn get weekday => integer()();
  IntColumn get startMinute => integer()();
  IntColumn get endMinute => integer()();
  IntColumn get colorIndex => integer().withDefault(const Constant(0))();
  TextColumn get occurrences => text().nullable()();
  TextColumn get importKey => text().nullable()();
  TextColumn get description => text().nullable()();
  TextColumn get kind => text().nullable()();
  IntColumn get reminderMinutes => integer().nullable()();
  IntColumn get startPeriod => integer().nullable()();
  IntColumn get endPeriod => integer().nullable()();
  @override
  List<String> get customConstraints => [
    'CHECK (weekday BETWEEN 1 AND 7)',
    'CHECK (start_minute BETWEEN 0 AND 1438)',
    'CHECK (end_minute BETWEEN 1 AND 1439)',
    'CHECK (end_minute > start_minute)',
  ];
}

class Preferences extends Table {
  IntColumn get id => integer()();
  BoolColumn get reminders => boolean().withDefault(const Constant(false))();
  IntColumn get leadMinutes => integer().withDefault(const Constant(10))();
  IntColumn get endingLeadMinutes =>
      integer().withDefault(const Constant(10))();
  BoolColumn get useFileReminders =>
      boolean().withDefault(const Constant(true))();
  DateTimeColumn get semesterStart => dateTime().nullable()();
  TextColumn get timetableConfig => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [Courses, Preferences])
class ScheduleDatabase extends _$ScheduleDatabase {
  ScheduleDatabase([QueryExecutor? executor])
    : super(executor ?? driftDatabase(name: 'schedule'));

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await customStatement(
        'CREATE UNIQUE INDEX courses_import_key ON courses(import_key)',
      );
    },
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.addColumn(courses, courses.occurrences);
        await m.addColumn(courses, courses.importKey);
        await m.addColumn(courses, courses.description);
        await m.addColumn(courses, courses.kind);
        await m.addColumn(courses, courses.reminderMinutes);
        await customStatement(
          'CREATE UNIQUE INDEX courses_import_key ON courses(import_key)',
        );
      }
      if (from < 3) {
        await m.addColumn(courses, courses.startPeriod);
        await m.addColumn(courses, courses.endPeriod);
        await m.addColumn(preferences, preferences.timetableConfig);
      }
      if (from < 4) {
        await m.addColumn(preferences, preferences.endingLeadMinutes);
        await m.addColumn(preferences, preferences.useFileReminders);
      }
    },
  );

  Future<List<Course>> loadCourses() => (select(
    courses,
  )..orderBy([(t) => OrderingTerm.asc(t.startMinute)])).get();

  Future<Preference> loadPreferences() async {
    await into(preferences).insert(
      const PreferencesCompanion(id: Value(1)),
      mode: InsertMode.insertOrIgnore,
    );
    return (select(preferences)..where((t) => t.id.equals(1))).getSingle();
  }

  Future<void> saveCourse(CoursesCompanion value) async {
    final start = value.startMinute.value;
    final end = value.endMinute.value;
    if (start < 0 ||
        end > 1439 ||
        end <= start ||
        value.name.value.trim().isEmpty) {
      throw ArgumentError('请填写课程名称，并确保下课时间晚于上课时间。');
    }
    if (value.startPeriod.present && value.startPeriod.value != null) {
      final settings = TimetableSettings.decode(
        (await loadPreferences()).timetableConfig,
      );
      final first = value.startPeriod.value!,
          last = value.endPeriod.present ? value.endPeriod.value : null;
      if ((value.occurrences.present && value.occurrences.value != null) ||
          (value.kind.present && value.kind.value == 'event') ||
          last == null ||
          first < 1 ||
          last < first ||
          last > settings.periods.length ||
          start != settings.periods[first - 1].start ||
          end != settings.periods[last - 1].end) {
        throw ArgumentError('课程节次与当前课表时间不匹配，请重新选择。');
      }
    } else if (value.endPeriod.present && value.endPeriod.value != null) {
      throw ArgumentError('请选择完整的开始和结束节次。');
    }
    await into(courses).insertOnConflictUpdate(value);
  }

  Future<int> importCourses(List<CoursesCompanion> entries) =>
      transaction(() async {
        var inserted = 0;
        for (final entry in entries) {
          final key = entry.importKey.value;
          if (key == null) throw ArgumentError('导入课程缺少标识');
          final existing = await (select(
            courses,
          )..where((c) => c.importKey.equals(key))).getSingleOrNull();
          if (existing != null) continue;
          await into(courses).insert(entry);
          inserted++;
        }
        return inserted;
      });

  Future<void> saveTimetableSettings(TimetableSettings settings) async {
    final error = settings.validationError;
    if (error != null) throw FormatException(error);
    await transaction(() async {
      final linked = await (select(
        courses,
      )..where((c) => c.startPeriod.isNotNull())).get();
      for (final course in linked) {
        final first = course.startPeriod!, last = course.endPeriod;
        if (last == null ||
            first < 1 ||
            last < first ||
            last > settings.periods.length) {
          throw FormatException(
            '“${course.name}”使用第 $first–${last ?? first} 节，请先修改该课程的节次或增加每天节数。',
          );
        }
      }
      final prefs = await loadPreferences();
      await savePreferences(
        prefs.copyWith(timetableConfig: Value(settings.encode())),
      );
      for (final course in linked) {
        await (update(courses)..where((c) => c.id.equals(course.id))).write(
          CoursesCompanion(
            startMinute: Value(settings.periods[course.startPeriod! - 1].start),
            endMinute: Value(settings.periods[course.endPeriod! - 1].end),
          ),
        );
      }
    });
  }

  Future<void> removeCourse(int id) =>
      (delete(courses)..where((t) => t.id.equals(id))).go();

  Future<void> savePreferences(Preference value) async {
    if (value.leadMinutes < 1 ||
        value.leadMinutes > 1440 ||
        value.endingLeadMinutes < 1 ||
        value.endingLeadMinutes > 1440) {
      throw ArgumentError('提醒时间应为 1–1440 分钟。');
    }
    // This is a full settings snapshot. Explicit nulls must clear old nullable
    // fields (for example a removed semester date), rather than be omitted.
    await into(preferences).insertOnConflictUpdate(value.toCompanion(false));
  }
}
