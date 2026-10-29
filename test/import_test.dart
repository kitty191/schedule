import 'dart:io';
import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schedule/data/database.dart';
import 'package:schedule/data/ics_importer.dart';
import 'package:schedule/data/timetable.dart';

String event({
  String start = '20260907T080000Z',
  String end = '20260907T090000Z',
  String extra = '',
}) =>
    'BEGIN:VCALENDAR\nBEGIN:VEVENT\nUID:test\nSUMMARY:测试课程\nDTSTART:$start\nDTEND:$end\n$extra\nEND:VEVENT\nEND:VCALENDAR';

void main() {
  test('Sub-minute entries are reported before they can fail an import transaction', () {
    final report = IcsImporter().parse(
      event(start: '20260907T080010Z', end: '20260907T080050Z'),
    );
    expect(report.courses, isEmpty);
    expect(report.warnings.single, contains('同一分钟'));
  });
  test('WakeUp shape preserves Shanghai, inclusive UNTIL, descriptions, alarms and folded lines', () {
    final report = IcsImporter().parse(
      File('test/fixtures/calendar.ics').readAsStringSync(),
    );
    expect(report.warnings, isEmpty);
    expect(report.courses, hasLength(2));
    expect(report.occurrenceCount, 4);
    final maths = report.courses.first;
    expect(maths.instances.first.start, DateTime.utc(2026, 9, 7, 0));
    expect(maths.instances.last.start, DateTime.utc(2026, 9, 21, 0));
    expect(maths.description, '第1 - 2节\n教学楼 B402\n教师');
    expect(maths.reminderMinutes, 20);
    expect(report.courses.last.name, '大学英语');
    expect(report.courses.last.location, '教学楼,A203');
  });
  test('Biweekly COUNT with EXDATE and RDATE is expanded exactly', () {
    final report = IcsImporter().parse(
      event(
        extra: 'RRULE:FREQ=WEEKLY;INTERVAL=2;COUNT=3\nEXDATE:20260921T080000Z\nRDATE:20260923T080000Z',
      ),
    );
    expect(report.warnings, isEmpty);
    expect(report.courses.single.instances.map((i) => i.start), [
      DateTime.utc(2026, 9, 7, 8),
      DateTime.utc(2026, 9, 23, 8),
      DateTime.utc(2026, 10, 5, 8),
    ]);
  });
  test('Multiple weekdays and DAILY intervals preserve recurrence count', () {
    final weekly = IcsImporter().parse(
      event(extra: 'RRULE:FREQ=WEEKLY;BYDAY=MO,WE;COUNT=4'),
    );
    expect(weekly.courses.single.instances.map((i) => i.start.day), [
      7,
      9,
      14,
      16,
    ]);
    final daily = IcsImporter().parse(
      event(extra: 'RRULE:FREQ=DAILY;INTERVAL=2;COUNT=3'),
    );
    expect(daily.courses.single.instances.map((i) => i.start.day), [7, 9, 11]);
  });
  test(
    'Named timezone recurrence keeps local clock across daylight saving',
    () {
      final text =
          event(
                start: '20260301T090000',
                end: '20260301T100000',
                extra: 'RRULE:FREQ=WEEKLY;COUNT=2',
              )
              .replaceAll('DTSTART:', 'DTSTART;TZID=America/New_York:')
              .replaceAll('DTEND:', 'DTEND;TZID=America/New_York:');
      final report = IcsImporter().parse(text);
      expect(report.warnings, isEmpty);
      expect(report.courses.single.instances.map((i) => i.start.hour), [
        14,
        13,
      ]);
    },
  );
  test('Unsupported rules, invalid dates and truncated files are explicit', () {
    final unsupported = IcsImporter().parse(
      event(extra: 'RRULE:FREQ=MONTHLY;COUNT=2'),
    );
    expect(unsupported.courses, isEmpty);
    expect(unsupported.warnings, hasLength(1));
    expect(
      IcsImporter().parse(event(start: '20260230T080000Z')).warnings,
      hasLength(1),
    );
    expect(() => IcsImporter().parse('BEGIN:VCALENDAR'), throwsFormatException);
    expect(
      IcsImporter().parse(event(extra: 'RRULE:FREQ=WEEKLY')).warnings,
      hasLength(1),
    );
  });
  test('Import transaction deduplicates and finite courses never become indefinite weekly entries', () async {
    final db = ScheduleDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final report = IcsImporter().parse(
      File('test/fixtures/calendar.ics').readAsStringSync(),
    );
    final entries = report.courses.map((c) => c.companion(0)).toList();
    expect(await db.importCourses(entries), 2);
    expect(await db.importCourses(entries), 0);
    final stored = await db.loadCourses();
    expect(stored.every((c) => c.occurrences != null), isTrue);
    expect(jsonDecode(stored.first.occurrences!), hasLength(3));
    expect(coursesOn(stored, DateTime(2030, 9, 2)), isEmpty);
  });
  test('Version 1 database upgrades without losing existing courses or preferences', () async {
    final dir = await Directory.systemTemp.createTemp('schedule-v1-');
    final file = File('${dir.path}/v1.sqlite');
    final upgraded = ScheduleDatabase(
      NativeDatabase(
        file,
        setup: (raw) {
          raw.execute(
            'CREATE TABLE courses (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, location TEXT NOT NULL, weekday INTEGER NOT NULL, start_minute INTEGER NOT NULL, end_minute INTEGER NOT NULL, color_index INTEGER NOT NULL DEFAULT 0)',
          );
          raw.execute(
            'CREATE TABLE preferences (id INTEGER PRIMARY KEY, reminders INTEGER NOT NULL DEFAULT 0, lead_minutes INTEGER NOT NULL DEFAULT 10, semester_start INTEGER)',
          );
          raw.execute(
            "INSERT INTO courses VALUES (1,'原来的课','B402',4,480,540,0)",
          );
          raw.execute('INSERT INTO preferences VALUES (1,1,15,NULL)');
          raw.execute('PRAGMA user_version = 1');
        },
      ),
    );
    try {
      expect((await upgraded.loadCourses()).single.name, '原来的课');
      expect((await upgraded.loadCourses()).single.occurrences, isNull);
      expect((await upgraded.loadPreferences()).leadMinutes, 15);
      final entries = IcsImporter()
          .parse(File('test/fixtures/calendar.ics').readAsStringSync())
          .courses
          .map((c) => c.companion(0))
          .toList();
      expect(await upgraded.importCourses(entries), 2);
    } finally {
      await upgraded.close();
      await dir.delete(recursive: true);
    }
  });
  test('Two meetings on one date are both displayed and reimported without duplicates', () async {
    final report = IcsImporter().parse(event(extra: 'RDATE:20260907T120000Z'));
    expect(report.warnings, isEmpty);
    expect(report.courses, hasLength(2));
    expect(report.occurrenceCount, 2);
    final db = ScheduleDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final entries = report.courses.map((c) => c.companion(0)).toList();
    expect(await db.importCourses(entries), 2);
    expect(await db.importCourses(entries), 0);
    final stored = await db.loadCourses();
    final day = report.courses.first.instances.first.start.toLocal();
    final displayed = coursesOn(stored, day);
    expect(displayed, hasLength(2));
    expect(
      courseTime(displayed.first, day),
      isNot(courseTime(displayed.last, day)),
    );
  });
}
