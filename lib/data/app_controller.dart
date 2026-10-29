import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:drift/drift.dart' show Value;

import '../live_update_bridge.dart';
import 'database.dart';
import 'timetable.dart';
import 'ics_importer.dart';
import 'timetable_settings.dart';

final databaseProvider = Provider<ScheduleDatabase>((ref) {
  final database = ScheduleDatabase();
  ref.onDispose(database.close);
  return database;
});
final bridgeProvider = Provider((ref) => LiveUpdateBridge());
final appProvider = AsyncNotifierProvider<AppController, AppData>(
  AppController.new,
);

class AppData {
  const AppData(this.courses, this.preferences, {this.syncError});
  final List<Course> courses;
  final Preference preferences;
  final String? syncError;
}

class AppController extends AsyncNotifier<AppData> {
  @override
  Future<AppData> build() => _loadAndSync();

  Future<AppData> _loadAndSync() async {
    final database = ref.read(databaseProvider);
    final courses = await database.loadCourses();
    final preferences = await database.loadPreferences();
    String? error;
    try {
      await ref.read(bridgeProvider).configure({
        'courses': courses.map(coursePayload).toList(),
        'enabled': preferences.reminders,
        'leadMinutes': preferences.leadMinutes,
      });
    } on PlatformException catch (e) {
      error = e.message ?? '系统提醒暂未更新，请重新打开应用重试。';
    } on MissingPluginException {
      error = '当前平台尚未接入系统提醒。';
    }
    return AppData(courses, preferences, syncError: error);
  }

  Future<void> saveCourse(CoursesCompanion course) async {
    await ref.read(databaseProvider).saveCourse(course);
    state = AsyncData(await _loadAndSync());
  }

  Future<void> deleteCourse(int id) async {
    await ref.read(databaseProvider).removeCourse(id);
    state = AsyncData(await _loadAndSync());
  }

  Future<void> updatePreferences(Preference value) async {
    await ref.read(databaseProvider).savePreferences(value);
    state = AsyncData(await _loadAndSync());
  }

  Future<void> updateTimetable(TimetableSettings settings) async {
    await ref.read(databaseProvider).saveTimetableSettings(settings);
    state = AsyncData(await _loadAndSync());
  }

  Future<int> importCalendar(
    ImportReport report, {
    bool keepReminders = true,
  }) async {
    final db = ref.read(databaseProvider);
    final inserted = await db.importCourses(
      report.courses
          .map(
            (c) => c.companion(
              c.name.codeUnits.fold(0, (sum, v) => sum + v) % 5,
              keepReminders: keepReminders,
            ),
          )
          .toList(),
    );
    final prefs = await db.loadPreferences();
    if (prefs.semesterStart == null && report.firstDate != null) {
      await db.savePreferences(
        prefs.copyWith(
          semesterStart: Value(dateOnly(report.firstDate!.toLocal())),
        ),
      );
    }
    state = AsyncData(await _loadAndSync());
    return inserted;
  }

  Future<void> retrySync() async => state = AsyncData(await _loadAndSync());
}
