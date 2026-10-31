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
  Future<void> _pending = Future.value();

  // A resume/retry may arrive while a save is still syncing. Keep database
  // snapshots and native configurations in order so stale data cannot win.
  Future<T> _serial<T>(Future<T> Function() action) {
    final result = _pending.then((_) => action());
    _pending = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  @override
  Future<AppData> build() => _serial(_loadAndSync);

  Future<AppData> _loadAndSync({bool syncNotifications = true}) async {
    final database = ref.read(databaseProvider);
    final courses = await database.loadCourses();
    final preferences = await database.loadPreferences();
    if (!syncNotifications) {
      return AppData(
        courses,
        preferences,
        syncError: state.asData?.value.syncError,
      );
    }
    String? error;
    try {
      final timetable = TimetableSettings.decode(preferences.timetableConfig);
      await ref.read(bridgeProvider).configure({
        'courses': courses
            .map(
              (course) => coursePayload(
                course,
                includeFileReminder: preferences.useFileReminders,
                timetable: timetable,
              ),
            )
            .toList(),
        'enabled': preferences.reminders,
        'leadMinutes': preferences.leadMinutes,
        'endingLeadMinutes': preferences.endingLeadMinutes,
        'weekStart': timetable.weekStart,
        if (preferences.semesterStart != null)
          'semesterStart': dayKey(preferences.semesterStart!),
      });
    } on PlatformException catch (e) {
      error = e.message ?? '系统提醒暂未更新，请重新打开应用重试。';
    } on MissingPluginException {
      error = '当前平台尚未接入系统提醒。';
    }
    return AppData(courses, preferences, syncError: error);
  }

  Future<void> saveCourse(CoursesCompanion course) => _serial(() async {
    await ref.read(databaseProvider).saveCourse(course);
    state = AsyncData(await _loadAndSync());
  });

  Future<void> deleteCourse(int id) => _serial(() async {
    await ref.read(databaseProvider).removeCourse(id);
    state = AsyncData(await _loadAndSync());
  });

  Future<void> updatePreferences(Preference value) => _serial(() async {
    await ref.read(databaseProvider).savePreferences(value);
    state = AsyncData(await _loadAndSync());
  });

  Future<void> updateTimetable(TimetableSettings settings) => _serial(() async {
    final database = ref.read(databaseProvider);
    final previous = TimetableSettings.decode(
      (await database.loadPreferences()).timetableConfig,
    );
    final timesChanged =
        previous.periods.length != settings.periods.length ||
        List.generate(settings.periods.length, (i) => i).any(
          (i) =>
              previous.periods[i].start != settings.periods[i].start ||
              previous.periods[i].end != settings.periods[i].end,
        );
    await database.saveTimetableSettings(settings);
    state = AsyncData(
      await _loadAndSync(
        syncNotifications:
            timesChanged || previous.weekStart != settings.weekStart,
      ),
    );
  });

  Future<int> importCalendar(
    ImportReport report, {
    bool keepReminders = true,
  }) => _serial(() async {
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
  });

  Future<void> retrySync() => _serial(() async {
    state = AsyncData(await _loadAndSync());
  });
}
