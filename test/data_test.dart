import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schedule/data/app_controller.dart';
import 'package:schedule/data/database.dart';
import 'package:schedule/data/timetable.dart';
import 'package:schedule/live_update_bridge.dart';

class FailingBridge extends LiveUpdateBridge {
  @override
  Future<LiveUpdateStatus> configure(Map<String, Object> data) async =>
      throw PlatformException(code: 'failed', message: '系统提醒暂不可用');
}

void main() {
  test(
    'SQLite persists edits, preferences and deletions across reopening',
    () async {
      final temp = await Directory.systemTemp.createTemp('schedule-db-');
      final file = File('${temp.path}/test.sqlite');
      var db = ScheduleDatabase(NativeDatabase(file));
      try {
        await db.saveCourse(
          const CoursesCompanion(
            name: Value('高等数学'),
            location: Value('B402'),
            weekday: Value(4),
            startMinute: Value(510),
            endMinute: Value(600),
          ),
        );
        final course = (await db.loadCourses()).single;
        await db.saveCourse(
          course.copyWith(name: '数学分析', location: 'A101').toCompanion(false),
        );
        final prefs = await db.loadPreferences();
        await db.savePreferences(
          prefs.copyWith(reminders: true, leadMinutes: 15),
        );
        await db.close();
        db = ScheduleDatabase(NativeDatabase(file));
        expect((await db.loadCourses()).single.name, '数学分析');
        expect((await db.loadCourses()).single.location, 'A101');
        expect((await db.loadPreferences()).leadMinutes, 15);
        expect((await db.loadPreferences()).reminders, isTrue);
        await db.removeCourse(course.id);
        await db.close();
        db = ScheduleDatabase(NativeDatabase(file));
        expect(await db.loadCourses(), isEmpty);
      } finally {
        await db.close();
        await temp.delete(recursive: true);
      }
    },
  );

  test('Invalid time range cannot be persisted', () async {
    final db = ScheduleDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await expectLater(
      db.saveCourse(
        const CoursesCompanion(
          name: Value('无效课'),
          location: Value(''),
          weekday: Value(1),
          startMinute: Value(600),
          endMinute: Value(510),
        ),
      ),
      throwsArgumentError,
    );
    expect(await db.loadCourses(), isEmpty);
  });

  test('Calendar filtering, end boundary and semester weeks are correct', () {
    final thu = DateTime(2026, 10, 29, 10);
    final course = Course(
      id: 1,
      name: '数学',
      location: '',
      weekday: 4,
      startMinute: 510,
      endMinute: 600,
      colorIndex: 0,
    );
    expect(coursesOn([course], thu), hasLength(1));
    expect(coursesOn([course], thu.add(const Duration(days: 1))), isEmpty);
    expect(upcomingToday([course], thu), isNull);
    expect(upcomingToday([course], DateTime(2026, 10, 29, 9)), course);
    expect(semesterWeek(DateTime(2026, 8, 31), thu), 9);
    expect(semesterWeek(DateTime(2026, 11, 1), DateTime(2026, 11, 2)), 2);
    expect(semesterWeek(DateTime(2027), thu), isNull);
  });

  test('Native sync failure preserves course in database and exposes retry warning', () async {
    final db = ScheduleDatabase(NativeDatabase.memory());
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        bridgeProvider.overrideWithValue(FailingBridge()),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await db.close();
    });
    await container.read(appProvider.future);
    await container
        .read(appProvider.notifier)
        .saveCourse(
          const CoursesCompanion(
            name: Value('程序设计'),
            location: Value('实验楼'),
            weekday: Value(4),
            startMinute: Value(600),
            endMinute: Value(660),
          ),
        );
    final data = container.read(appProvider).requireValue;
    expect(data.courses.single.name, '程序设计');
    expect(data.syncError, '系统提醒暂不可用');
    expect((await db.loadCourses()).single.name, '程序设计');
  });
}
