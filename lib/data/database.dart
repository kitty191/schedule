import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'database.g.dart';

class Courses extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 60)();
  TextColumn get location => text().withLength(max: 100)();
  IntColumn get weekday => integer()();
  IntColumn get startMinute => integer()();
  IntColumn get endMinute => integer()();
  IntColumn get colorIndex => integer().withDefault(const Constant(0))();
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
  DateTimeColumn get semesterStart => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [Courses, Preferences])
class ScheduleDatabase extends _$ScheduleDatabase {
  ScheduleDatabase([QueryExecutor? executor])
    : super(executor ?? driftDatabase(name: 'schedule'));

  @override
  int get schemaVersion => 1;

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
    await into(courses).insertOnConflictUpdate(value);
  }

  Future<void> removeCourse(int id) =>
      (delete(courses)..where((t) => t.id.equals(id))).go();

  Future<void> savePreferences(Preference value) =>
      into(preferences).insertOnConflictUpdate(value);
}
