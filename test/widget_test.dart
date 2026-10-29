import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schedule/data/app_controller.dart';
import 'package:schedule/data/database.dart';
import 'package:schedule/main.dart';
import 'package:schedule/live_update_bridge.dart';
import 'package:schedule/data/calendar_file.dart';
import 'package:schedule/data/ics_importer.dart';
import 'package:schedule/data/timetable_settings.dart';

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
          startPeriod: value.startPeriod.present
              ? value.startPeriod.value
              : null,
          endPeriod: value.endPeriod.present ? value.endPeriod.value : null,
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
  Future<void> updateTimetable(TimetableSettings settings) async {
    final data = state.requireValue;
    final courses = data.courses
        .map(
          (c) => c.startPeriod == null
              ? c
              : c.copyWith(
                  startMinute: settings.periods[c.startPeriod! - 1].start,
                  endMinute: settings.periods[c.endPeriod! - 1].end,
                ),
        )
        .toList();
    state = AsyncData(
      AppData(
        courses,
        data.preferences.copyWith(timetableConfig: Value(settings.encode())),
      ),
    );
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

class EndingPreviewBridge extends LiveUpdateBridge {
  bool active = false;
  Map<String, Object>? previewed;
  @override
  Future<LiveUpdateStatus> status() async => LiveUpdateStatus(
    supported: true,
    notificationsEnabled: true,
    promotionAllowed: true,
    active: active,
    promoted: active,
  );
  @override
  Future<LiveUpdateStatus> previewEnding(Map<String, Object> course) async {
    previewed = course;
    active = true;
    return status();
  }
}

Future<void> openApp(WidgetTester tester, {LiveUpdateBridge? bridge}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appProvider.overrideWith(MemoryController.new),
        bridgeProvider.overrideWithValue(bridge ?? DeniedBridge()),
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
      expect(find.byKey(const Key('import-timetable')), findsNothing);
      await tester.tap(find.byKey(const Key('next-week')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const Key('timetable-tools')));
      await tester.pumpAndSettle();
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
  testWidgets(
    'Toolbar expands and collapses; settings save Sunday start, 5 days and a new lesson duration',
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
      expect(find.byKey(const Key('add-timetable-course')), findsNothing);
      await tester.tap(find.byKey(const Key('timetable-tools')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('add-timetable-course')), findsOneWidget);
      expect(find.byKey(const Key('import-timetable')), findsOneWidget);
      await tester.tap(find.byKey(const Key('timetable-tools')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('import-timetable')), findsNothing);
      await tester.tap(find.byKey(const Key('timetable-tools')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('timetable-settings')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('week-start')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('周日'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('5 天'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const Key('lesson-duration')),
        180,
        scrollable: find
            .descendant(
              of: find.byType(ListView).last,
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('lesson-duration')));
      await tester.pumpAndSettle();
      final picker = tester.widget<CupertinoPicker>(
        find.byType(CupertinoPicker),
      );
      picker.scrollController!.jumpToItem(45 - 5);
      await tester.pumpAndSettle();
      await tester.tap(find.text('完成'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('save-timetable')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('blank-weekday-7')), findsOneWidget);
      expect(find.byKey(const Key('blank-weekday-5')), findsNothing);
      final context = tester.element(find.byType(ScheduleApp));
      final settings = TimetableSettings.decode(
        ProviderScope.containerOf(context)
            .read(appProvider)
            .requireValue
            .preferences
            .timetableConfig,
      );
      expect(settings.lessonMinutes, 45);
      expect(settings.periods.first.end, 525);
      expect(settings.weekStart, 7);
      expect(settings.visibleDays, 5);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'A blank timetable cell creates a course with weekday and period binding',
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
      final cell = find.byKey(const Key('blank-weekday-3'));
      final top = tester.getTopLeft(cell);
      await tester.tapAt(top + const Offset(12, 25));
      await tester.pumpAndSettle();
      expect(find.text('按节次'), findsOneWidget);
      expect(find.text('第 1 节'), findsNWidgets(2));
      await tester.enterText(find.byKey(const Key('course-name')), '手动排课');
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();
      final context = tester.element(find.byType(ScheduleApp));
      final course = ProviderScope.containerOf(context)
          .read(appProvider)
          .requireValue
          .courses
          .single;
      expect(course.weekday, 3);
      expect(course.startPeriod, 1);
      expect(course.endPeriod, 1);
      expect(course.startMinute, 480);
      expect(course.endMinute, 520);
      expect(find.text('手动排课'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'Timetable tools and settings fit a narrow phone with larger text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.platformDispatcher.clearTextScaleFactorTestValue();
      });
      await openApp(tester);
      await tester.tap(find.byKey(const Key('tab-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('timetable-tools')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const Key('timetable-settings')));
      await tester.pumpAndSettle();
      expect(find.text('每周显示天数'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('Compact height is saved and visibly shortens timetable rows', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await openApp(tester);
    await tester.tap(find.byKey(const Key('tab-1')));
    await tester.pumpAndSettle();
    final before =
        tester.getTopLeft(find.byKey(const Key('period-label-2'))).dy -
        tester.getTopLeft(find.byKey(const Key('period-label-1'))).dy;
    await tester.tap(find.byKey(const Key('timetable-tools')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('timetable-settings')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('height-60')),
      180,
      scrollable: find
          .descendant(
            of: find.byType(ListView).last,
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('height-60')));
    await tester.pumpAndSettle();
    expect(find.text('60%'), findsOneWidget);
    await tester.tap(find.byKey(const Key('save-timetable')));
    await tester.pumpAndSettle();
    final after =
        tester.getTopLeft(find.byKey(const Key('period-label-2'))).dy -
        tester.getTopLeft(find.byKey(const Key('period-label-1'))).dy;
    expect(after, lessThan(before * 0.8));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'Ending reminder preview selects a real course and exposes the result',
    (tester) async {
      final bridge = EndingPreviewBridge();
      MemoryController.seed = [
        Course(
          id: 2,
          name: '下课提示课程',
          location: 'B402',
          weekday: DateTime.now().weekday,
          startMinute: 480,
          endMinute: 540,
          colorIndex: 0,
        ),
      ];
      await openApp(tester, bridge: bridge);
      await tester.tap(find.byKey(const Key('tab-2')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('提醒设置'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const Key('preview-ending')),
        240,
        scrollable: find
            .descendant(
              of: find.byType(ListView).last,
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('preview-ending')));
      await tester.pumpAndSettle();
      expect(bridge.previewed?['id'], 2);
      expect(bridge.previewed?['name'], '下课提示课程');
      await tester.scrollUntilVisible(
        find.text('下课提醒预览已发送，请回到桌面查看流体云。'),
        120,
        scrollable: find
            .descendant(
              of: find.byType(ListView).last,
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pumpAndSettle();
      expect(find.text('下课提醒预览已发送，请回到桌面查看流体云。'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
