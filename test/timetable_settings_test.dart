import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schedule/data/app_controller.dart';
import 'package:schedule/data/database.dart';
import 'package:schedule/data/timetable_settings.dart';
import 'package:schedule/data/timetable.dart';
import 'package:schedule/live_update_bridge.dart';

class RecordingBridge extends LiveUpdateBridge {
  Map<String, Object>? configured;
  @override
  Future<LiveUpdateStatus> configure(Map<String, Object> value) async {
    configured = value;
    return const LiveUpdateStatus(
      supported: true,
      notificationsEnabled: true,
      promotionAllowed: true,
      active: false,
      promoted: false,
    );
  }
}

CoursesCompanion linked(TimetableSettings settings) => CoursesCompanion(
  name: const Value('按节次排课'),
  location: const Value('B402'),
  weekday: const Value(3),
  startPeriod: const Value(2),
  endPeriod: const Value(3),
  startMinute: Value(settings.periods[1].start),
  endMinute: Value(settings.periods[2].end),
);
void main() {
  test('Template generates durations, ordinary breaks and separate lunch/evening breaks', () {
    final settings = TimetableSettings.defaults();
    expect(settings.periods, hasLength(12));
    expect(settings.periods[0].start, 480);
    expect(settings.periods[0].end, 520);
    expect(settings.periods[1].start, 525);
    expect(settings.periods[5].start - settings.periods[4].end, 100);
    expect(settings.periods[10].start - settings.periods[9].end, 70);
    final changed = settings
        .copyWith(
          firstStart: 420,
          lessonMinutes: 50,
          breakMinutes: 10,
          lunchAfter: 4,
          lunchMinutes: 90,
          eveningAfter: 0,
        )
        .generate(8);
    expect(changed.periods[3].end, 650);
    expect(changed.periods[4].start, 740);
    expect(changed.validationError, isNull);
  });
  test('Invalid overlap, midnight and excessively long days are rejected', () {
    final s = TimetableSettings.defaults();
    expect(
      () => s.copyWith(firstStart: 1380).generate(3),
      throwsFormatException,
    );
    expect(
      s
          .copyWith(
            periods: [const ClassPeriod(480, 530), const ClassPeriod(520, 560)],
          )
          .validationError,
      isNotNull,
    );
    expect(
      s.copyWith(periods: [const ClassPeriod(600, 599)]).validationError,
      isNotNull,
    );
    expect(() => s.generate(0), throwsFormatException);
    expect(s.copyWith(eveningAfter: s.lunchAfter).validationError, isNotNull);
  });
  test(
    'Custom period edits, week start and display choices survive serialization',
    () {
      final s = TimetableSettings.defaults().copyWith(
        weekStart: 7,
        visibleDays: 5,
        periodView: false,
        periods: [const ClassPeriod(480, 525), const ClassPeriod(545, 600)],
      );
      final decoded = TimetableSettings.decode(s.encode());
      expect(decoded.weekStart, 7);
      expect(decoded.visibleDays, 5);
      expect(decoded.periodView, isFalse);
      expect(decoded.periods[1].start, 545);
      expect(decoded.periods[1].end, 600);
      expect(TimetableSettings.decode(null).periods, hasLength(12));
    },
  );
  test(
    'Sunday and Saturday week starts align displayed dates and teaching weeks',
    () {
      expect(startOfWeek(DateTime(2026, 10, 29), 7), DateTime(2026, 10, 25));
      expect(startOfWeek(DateTime(2026, 10, 29), 6), DateTime(2026, 10, 24));
      expect(
        semesterWeek(
          DateTime(2026, 10, 26),
          DateTime(2026, 11, 1),
          weekStart: 7,
        ),
        2,
      );
      expect(semesterWeek(DateTime(2026, 10, 26), DateTime(2026, 11, 1)), 1);
    },
  );
  test('Axis is monotonic, maps class/break boundaries and includes out-of-range imported courses', () {
    final s = TimetableSettings.defaults();
    final axis = TimetableAxis(s, earliest: 480, latest: s.periods.last.end);
    expect(axis.at(480), 0);
    expect(axis.at(520), 76);
    expect(axis.at(525), 88);
    final extended = TimetableAxis(s, earliest: 360, latest: 1430);
    var last = -1.0;
    for (var minute = 360; minute <= 1430; minute++) {
      final y = extended.at(minute);
      expect(y, greaterThanOrEqualTo(last));
      last = y;
      expect((extended.minuteAt(y) - minute).abs(), lessThanOrEqualTo(1));
    }
    expect(
      extended.periodAt(extended.at(s.periods[2].start) + 10, s.periods),
      3,
    );
    final hourly = TimetableAxis(
      s.copyWith(periodView: false),
      earliest: 360,
      latest: 1430,
    );
    expect(hourly.at(420) - hourly.at(360), 72);
  });
  test('Saving time settings atomically remaps linked courses and sends new times to native notifications', () async {
    final db = ScheduleDatabase(NativeDatabase.memory());
    final bridge = RecordingBridge();
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
    final old = TimetableSettings.defaults();
    await db.saveCourse(linked(old));
    await db.saveCourse(
      const CoursesCompanion(
        name: Value('自定义时间'),
        location: Value(''),
        weekday: Value(1),
        startMinute: Value(900),
        endMinute: Value(960),
      ),
    );
    await db.saveCourse(
      const CoursesCompanion(
        name: Value('导入课'),
        location: Value(''),
        weekday: Value(1),
        startMinute: Value(600),
        endMinute: Value(660),
        occurrences: Value('[{"start":1900000000000,"end":1900003600000}]'),
      ),
    );
    await container.read(appProvider.future);
    final next = old.copyWith(lessonMinutes: 50, breakMinutes: 10).generate(12);
    await container.read(appProvider.notifier).updateTimetable(next);
    final courses = container.read(appProvider).requireValue.courses;
    final bound = courses.singleWhere((c) => c.name == '按节次排课');
    expect(bound.startMinute, next.periods[1].start);
    expect(bound.endMinute, next.periods[2].end);
    expect(courses.singleWhere((c) => c.name == '自定义时间').startMinute, 900);
    expect(courses.singleWhere((c) => c.name == '导入课').startMinute, 600);
    final sent = (bridge.configured!['courses'] as List)
        .cast<Map<String, Object>>()
        .singleWhere((c) => c['name'] == '按节次排课');
    expect(sent['startMinute'], next.periods[1].start);
    expect(sent['endMinute'], next.periods[2].end);
  });
  test('Shrinking periods below an existing binding rolls back settings and course changes', () async {
    final db = ScheduleDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final original = TimetableSettings.defaults();
    await db.saveTimetableSettings(original);
    await db.saveCourse(linked(original));
    await expectLater(
      db.saveTimetableSettings(original.generate(2)),
      throwsFormatException,
    );
    expect((await db.loadPreferences()).timetableConfig, original.encode());
    expect((await db.loadCourses()).single.endMinute, original.periods[2].end);
    await expectLater(
      db.saveCourse(linked(original).copyWith(startMinute: const Value(10))),
      throwsArgumentError,
    );
  });
  test(
    'New settings and period bindings persist after reopening SQLite',
    () async {
      final dir = await Directory.systemTemp.createTemp('timetable-prefs-');
      final file = File('${dir.path}/test.sqlite');
      var db = ScheduleDatabase(NativeDatabase(file));
      try {
        final settings = TimetableSettings.defaults().copyWith(
          weekStart: 7,
          visibleDays: 5,
        );
        await db.saveTimetableSettings(settings);
        await db.saveCourse(linked(settings));
        await db.close();
        db = ScheduleDatabase(NativeDatabase(file));
        expect(
          TimetableSettings.decode((await db.loadPreferences()).timetableConfig)
              .weekStart,
          7,
        );
        expect((await db.loadCourses()).single.startPeriod, 2);
        expect((await db.loadCourses()).single.endPeriod, 3);
      } finally {
        await db.close();
        await dir.delete(recursive: true);
      }
    },
  );
  test('Version 2 upgrade retains imported dates, manual times, reminder permissions and semester', () async {
    final db = ScheduleDatabase(
      NativeDatabase.memory(
        setup: (raw) {
          raw.execute(
            'CREATE TABLE courses (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, location TEXT NOT NULL, weekday INTEGER NOT NULL, start_minute INTEGER NOT NULL, end_minute INTEGER NOT NULL, color_index INTEGER NOT NULL DEFAULT 0, occurrences TEXT, import_key TEXT, description TEXT, kind TEXT, reminder_minutes INTEGER)',
          );
          raw.execute(
            'CREATE TABLE preferences (id INTEGER PRIMARY KEY, reminders INTEGER NOT NULL DEFAULT 0, lead_minutes INTEGER NOT NULL DEFAULT 10, semester_start INTEGER)',
          );
          raw.execute(
            "INSERT INTO courses VALUES (1,'旧课程','B402',4,480,540,0,NULL,NULL,NULL,NULL,NULL)",
          );
          raw.execute(
            "INSERT INTO courses VALUES (2,'旧导入','A203',4,600,660,1,'[{\"start\":1900000000000,\"end\":1900003600000}]','key','备注','course',20)",
          );
          raw.execute('INSERT INTO preferences VALUES (1,1,15,1790000000)');
          raw.execute('PRAGMA user_version=2');
        },
      ),
    );
    addTearDown(db.close);
    final courses = await db.loadCourses();
    final prefs = await db.loadPreferences();
    expect(courses, hasLength(2));
    expect(courses.first.startPeriod, isNull);
    expect(courses.last.occurrences, isNotNull);
    expect(courses.last.reminderMinutes, 20);
    expect(prefs.reminders, isTrue);
    expect(prefs.leadMinutes, 15);
    expect(prefs.semesterStart, isNotNull);
    expect(
      TimetableSettings.decode(prefs.timetableConfig).periods,
      hasLength(12),
    );
  });
}
