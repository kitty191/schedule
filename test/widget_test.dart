import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schedule/data/app_controller.dart';
import 'package:schedule/data/database.dart';
import 'package:schedule/main.dart';
import 'package:schedule/live_update_bridge.dart';
import 'package:schedule/data/calendar_file.dart';
import 'package:schedule/data/ics_importer.dart';

import 'dart:io';

import 'package:drift/drift.dart' show Value;

class MemoryController extends AppController {
  static List<Course> seed = [];
  static Preference prefs = const Preference(
    id: 1,
    reminders: false,
    leadMinutes: 10,
  );
  @override
  Future<AppData> build() async => AppData([...seed], prefs);
  @override
  Future<void> saveCourse(CoursesCompanion value) async {
    final data = state.requireValue;
    final id = value.id.present ? value.id.value : 1;
    final courses = data.courses.where((c) => c.id != id).toList()
      ..add(
        Course(
          id: id,
          name: value.name.value,
          location: value.location.value,
          weekday: value.weekday.value,
          startMinute: value.startMinute.value,
          endMinute: value.endMinute.value,
          colorIndex: value.colorIndex.value,
          occurrences: value.occurrences.present
              ? value.occurrences.value
              : null,
          kind: value.kind.present ? value.kind.value : null,
          description: value.description.present
              ? value.description.value
              : null,
          importKey: value.importKey.present ? value.importKey.value : null,
          reminderMinutes: value.reminderMinutes.present
              ? value.reminderMinutes.value
              : null,
        ),
      );
    state = AsyncData(AppData(courses, data.preferences));
  }

  @override
  Future<int> importCalendar(
    ImportReport report, {
    bool keepReminders = true,
  }) async {
    for (var i = 0; i < report.courses.length; i++) {
      final entry = report.courses[i].companion(
        i,
        keepReminders: keepReminders,
      );
      await saveCourse(entry.copyWith(id: Value(100 + i)));
    }
    return report.courses.length;
  }

  @override
  Future<void> deleteCourse(int id) async {
    final data = state.requireValue;
    state = AsyncData(
      AppData(data.courses.where((c) => c.id != id).toList(), data.preferences),
    );
  }

  @override
  Future<void> updatePreferences(Preference value) async =>
      state = AsyncData(AppData(state.requireValue.courses, value));
}

class DeniedBridge extends LiveUpdateBridge {
  static const denied = LiveUpdateStatus(
    supported: true,
    notificationsEnabled: false,
    promotionAllowed: false,
    active: false,
    promoted: false,
  );
  @override
  Future<LiveUpdateStatus> status() async => denied;
  @override
  Future<LiveUpdateStatus> requestPermission() async => denied;
}

Future<void> openApp(WidgetTester tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appProvider.overrideWith(MemoryController.new),
        bridgeProvider.overrideWithValue(DeniedBridge()),
        calendarFilePickerProvider.overrideWithValue(
          () async => CalendarFile(
            'example.ics',
            File('test/fixtures/calendar.ics').readAsStringSync(),
          ),
        ),
      ],
      child: const ScheduleApp(),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    MemoryController.seed = [];
  });

  testWidgets('Add a course, validate required name, edit and delete it', (
    tester,
  ) async {
    await openApp(tester);
    expect(find.text('今天没有课程'), findsOneWidget);
    await tester.tap(find.text('添加第一门课程'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(find.text('先为课程起一个名字吧。'), findsOneWidget);
    await tester.tap(find.text('好'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('course-name')), '大学英语');
    await tester.enterText(find.byKey(const Key('course-location')), 'B402');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(find.text('大学英语'), findsWidgets);
    await tester.tap(find.text('大学英语').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('course-name')), '高等数学');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(find.text('大学英语'), findsNothing);
    expect(find.text('高等数学'), findsWidgets);
    await tester.tap(find.text('高等数学').last);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('删除课程'),
      300,
      scrollable: find
          .descendant(
            of: find.byType(ListView).last,
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('删除课程'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除课程'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();
    expect(find.text('今天没有课程'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Permission denial leaves course reminders switched off', (
    tester,
  ) async {
    await openApp(tester);
    await tester.tap(find.byKey(const Key('tab-2')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('提醒设置'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(CupertinoSwitch));
    await tester.pumpAndSettle();
    expect(
      tester.widget<CupertinoSwitch>(find.byType(CupertinoSwitch)).value,
      isFalse,
    );
    await tester.scrollUntilVisible(
      find.text('请在系统设置中允许通知后重试。'),
      250,
      scrollable: find
          .descendant(
            of: find.byType(ListView).last,
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.text('请在系统设置中允许通知后重试。'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Long course text fits a narrow screen with larger type', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });
    MemoryController.seed = [
      Course(
        id: 1,
        name: '这是一门名称比较长的计算机程序设计基础课程',
        location: '东校区综合教学楼 B402',
        weekday: DateTime.now().weekday,
        startMinute: 1430,
        endMinute: 1439,
        colorIndex: 0,
      ),
    ];
    await openApp(tester);
    expect(tester.takeException(), isNull);
    expect(find.text('今天'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'Three dock tabs, week navigation and import preview are usable',
    (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await openApp(tester);
      await tester.tap(find.byKey(const Key('tab-1')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('import-timetable')), findsOneWidget);
      await tester.tap(find.byKey(const Key('next-week')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const Key('import-timetable')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('pick-calendar')));
      await tester.pumpAndSettle();
      expect(find.text('2 门课程 · 2 组时段 · 4 次上课'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byKey(const Key('confirm-import')),
        250,
        scrollable: find
            .descendant(
              of: find.byType(ListView).last,
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('confirm-import')));
      await tester.pumpAndSettle();
      expect(find.textContaining('已导入 2 组课程'), findsWidgets);
      await tester.tap(find.text('好'));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'One-off agenda item is saved and stays out of the weekly course grid',
    (tester) async {
      await openApp(tester);
      await tester.tap(find.byKey(const Key('add-agenda')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('添加日程'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('course-name')), '学习小组讨论');
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();
      expect(find.text('学习小组讨论'), findsWidgets);
      await tester.tap(find.byKey(const Key('tab-1')));
      await tester.pumpAndSettle();
      expect(find.text('学习小组讨论'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
