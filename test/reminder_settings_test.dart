import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schedule/data/app_controller.dart';
import 'package:schedule/data/database.dart';
import 'package:schedule/live_update_bridge.dart';

class _RecordingBridge extends LiveUpdateBridge {
  late Map<String, Object> configured;
  @override
  Future<LiveUpdateStatus> configure(Map<String, Object> data) async {
    configured = data;
    return const LiveUpdateStatus(
      supported: true,
      notificationsEnabled: true,
      promotionAllowed: true,
      active: false,
      promoted: false,
    );
  }
}

void main() {
  test('Version 3 migration retains saved settings and defaults to existing reminder behavior', () async {
    final db = ScheduleDatabase(
      NativeDatabase.memory(
        setup: (raw) {
          raw.execute(
            'CREATE TABLE courses (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, location TEXT NOT NULL, weekday INTEGER NOT NULL, start_minute INTEGER NOT NULL, end_minute INTEGER NOT NULL, color_index INTEGER NOT NULL DEFAULT 0, occurrences TEXT, import_key TEXT, description TEXT, kind TEXT, reminder_minutes INTEGER, start_period INTEGER, end_period INTEGER)',
          );
          raw.execute(
            'CREATE TABLE preferences (id INTEGER PRIMARY KEY, reminders INTEGER NOT NULL DEFAULT 0, lead_minutes INTEGER NOT NULL DEFAULT 10, semester_start INTEGER, timetable_config TEXT)',
          );
          raw.execute(
            "INSERT INTO courses VALUES (1,'导入课','B402',4,480,540,0,'[{\"start\":1900000000000,\"end\":1900003600000}]','key','备注','course',20,NULL,NULL)",
          );
          raw.execute(
            "INSERT INTO preferences VALUES (1,1,15,1790000000,'{\"heightPercent\":60}')",
          );
          raw.execute('PRAGMA user_version=3');
        },
      ),
    );
    addTearDown(db.close);
    final prefs = await db.loadPreferences();
    expect(prefs.reminders, isTrue);
    expect(prefs.leadMinutes, 15);
    expect(prefs.endingLeadMinutes, 10);
    expect(prefs.useFileReminders, isTrue);
    expect(prefs.semesterStart, isNotNull);
    expect(prefs.timetableConfig, '{"heightPercent":60}');
    final course = (await db.loadCourses()).single;
    expect(course.reminderMinutes, 20);
    expect(course.occurrences, isNotNull);
    expect(course.description, '备注');
  });

  test('Custom reminder times and file override switch reach native sync without deleting file metadata', () async {
    final db = ScheduleDatabase(NativeDatabase.memory());
    final bridge = _RecordingBridge();
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        bridgeProvider.overrideWithValue(bridge),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await db.close();
    });
    await db.saveCourse(
      const CoursesCompanion(
        name: Value('导入课'),
        location: Value('B402'),
        weekday: Value(4),
        startMinute: Value(480),
        endMinute: Value(540),
        reminderMinutes: Value(20),
      ),
    );
    final initial = await container.read(appProvider.future);
    Map<String, Object> nativeCourse() =>
        (bridge.configured['courses'] as List).single as Map<String, Object>;
    expect(nativeCourse()['leadMinutes'], 20);
    await container
        .read(appProvider.notifier)
        .updatePreferences(
          initial.preferences.copyWith(
            leadMinutes: 37,
            endingLeadMinutes: 7,
            useFileReminders: false,
          ),
        );
    expect(bridge.configured['leadMinutes'], 37);
    expect(bridge.configured['endingLeadMinutes'], 7);
    expect(nativeCourse().containsKey('leadMinutes'), isFalse);
    expect((await db.loadCourses()).single.reminderMinutes, 20);
    await container.read(appProvider.notifier).retrySync();
    expect(bridge.configured['endingLeadMinutes'], 7);
    expect(nativeCourse().containsKey('leadMinutes'), isFalse);
    await container
        .read(appProvider.notifier)
        .updatePreferences(
          container
              .read(appProvider)
              .requireValue
              .preferences
              .copyWith(useFileReminders: true),
        );
    expect(nativeCourse()['leadMinutes'], 20);
    expect(bridge.configured['endingLeadMinutes'], 7);
  });

  test('Invalid custom times do not replace saved preferences; range endpoints are accepted', () async {
    final db = ScheduleDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final prefs = await db.loadPreferences();
    for (final bad in [0, -1, 1441]) {
      await expectLater(
        db.savePreferences(prefs.copyWith(leadMinutes: bad)),
        throwsArgumentError,
      );
      await expectLater(
        db.savePreferences(prefs.copyWith(endingLeadMinutes: bad)),
        throwsArgumentError,
      );
    }
    expect((await db.loadPreferences()).leadMinutes, 10);
    expect((await db.loadPreferences()).endingLeadMinutes, 10);
    await db.savePreferences(
      prefs.copyWith(leadMinutes: 1, endingLeadMinutes: 1440),
    );
    expect((await db.loadPreferences()).leadMinutes, 1);
    expect((await db.loadPreferences()).endingLeadMinutes, 1440);
  });
}
