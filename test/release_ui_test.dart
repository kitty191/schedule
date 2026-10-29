import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:schedule/data/app_controller.dart';
import 'package:schedule/data/calendar_file.dart';
import 'package:schedule/data/timetable_settings.dart';
import 'package:schedule/features/course_editor.dart';
import 'package:schedule/main.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schedule/data/database.dart';

import 'widget_test.dart' as fixtures;

void phone(WidgetTester tester, Size size, double scale) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.view.padding = const FakeViewPadding(top: 24, bottom: 24);
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    tester.view.resetViewInsets();
    tester.view.resetPadding();
    tester.platformDispatcher.clearTextScaleFactorTestValue();
  });
}

class FailOnceController extends AppController {
  static int attempts = 0;
  @override
  Future<AppData> build() async {
    if (attempts++ == 0) {
      throw StateError('test database temporarily unavailable');
    }
    return AppData([], fixtures.MemoryController.prefs);
  }
}

Future<void> showImport(
  WidgetTester tester,
  Future<CalendarFile?> Function() pick,
) async {
  await fixtures.openApp(tester, pickCalendar: pick);
  await tester.tap(find.byKey(const Key('tab-2')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('导入课表'));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('pick-calendar')));
  await tester.pumpAndSettle();
}

Future<void> scrollTo(
  WidgetTester tester,
  Finder target, {
  double delta = 180,
}) async {
  await tester.scrollUntilVisible(
    target,
    delta,
    scrollable: find
        .descendant(
          of: find.byType(ListView).last,
          matching: find.byType(Scrollable),
        )
        .first,
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    WidgetController.hitTestWarningShouldBeFatal = true;
    fixtures.MemoryController.seed = [];
    fixtures.MemoryController.prefs = const Preference(
      id: 1,
      reminders: false,
      leadMinutes: 10,
      endingLeadMinutes: 10,
      useFileReminders: true,
    );
  });

  for (final entry in [
    (const Size(320, 700), 1.6),
    (const Size(720, 320), 1.3),
  ]) {
    testWidgets(
      'Main pages, tools and settings fit ${entry.$1} at ${entry.$2}',
      (tester) async {
        phone(tester, entry.$1, entry.$2);
        await fixtures.openApp(tester);
        expect(tester.takeException(), isNull);
        await tester.tap(find.byKey(const Key('tab-1')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('timetable-tools')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        if (entry.$1.width > entry.$1.height) {
          expect(
            tester.getSize(find.byKey(const Key('week-pager'))).height,
            greaterThan(110),
          );
          expect(
            tester.getBottomRight(find.byKey(const Key('week-pager'))).dy,
            lessThan(tester.getTopLeft(find.byKey(const Key('glass-dock'))).dy),
          );
        }
        await tester.tap(find.byKey(const Key('timetable-settings')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await scrollTo(tester, find.byKey(const Key('period-count')));
        await tester.tap(find.byKey(const Key('period-count')));
        await tester.pumpAndSettle();
        expect(find.byType(CupertinoPicker), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('取消'));
        await tester.pumpAndSettle();
        await tester.pageBack();
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('tab-2')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.scrollUntilVisible(
          find.text('提醒设置'),
          120,
          scrollable: find
              .descendant(
                of: find.byType(ListView).last,
                matching: find.byType(Scrollable),
              )
              .first,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('提醒设置'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('课程提醒'), findsOneWidget);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  testWidgets(
    'Course editor stays usable when the keyboard reduces the viewport',
    (tester) async {
      phone(tester, const Size(320, 700), 1.3);
      await fixtures.openApp(tester);
      await tester.tap(find.byKey(const Key('add-agenda')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('添加课程'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('course-name')));
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.enterText(find.byKey(const Key('course-name')), '键盘输入课程');
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();
      tester.view.resetViewInsets();
      await tester.pumpAndSettle();
      expect(find.text('键盘输入课程'), findsWidgets);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('Expanded hour cell creates a course at the tapped time', (
    tester,
  ) async {
    phone(tester, const Size(393, 852), 1);
    final today = DateTime.now().weekday;
    final emptyDay = today % 7 + 1;
    fixtures.MemoryController.seed = [
      Course(
        id: 50,
        name: '晚课',
        location: '',
        weekday: today,
        startMinute: 1200,
        endMinute: 1290,
        colorIndex: 0,
      ),
    ];
    await fixtures.openApp(tester);
    await tester.tap(find.byKey(const Key('tab-1')));
    await tester.pumpAndSettle();
    final time = find.byKey(const Key('extended-time-20'));
    await tester.ensureVisible(time);
    await tester.pumpAndSettle();
    final cell = find.byKey(Key('blank-weekday-$emptyDay'));
    await tester.tapAt(
      Offset(tester.getCenter(cell).dx, tester.getCenter(time).dy + 1),
    );
    await tester.pumpAndSettle();
    expect(find.text('自定义时间'), findsOneWidget);
    expect(
      tester
          .widget<CupertinoSlidingSegmentedControl<bool>>(
            find.byKey(const Key('course-time-mode')),
          )
          .groupValue,
      isFalse,
    );
    await tester.enterText(find.byKey(const Key('course-name')), '晚间新增');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(ScheduleApp)),
    );
    final added = container
        .read(appProvider)
        .requireValue
        .courses
        .firstWhere((c) => c.name == '晚间新增');
    expect(added.startMinute, 1200);
    expect(added.endMinute, 1240);
    expect(added.startPeriod, isNull);
    expect(added.weekday, emptyDay);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Hourly mode uses tapped minutes instead of a nearby period', (
    tester,
  ) async {
    phone(tester, const Size(393, 852), 1);
    fixtures.MemoryController.prefs = fixtures.MemoryController.prefs.copyWith(
      timetableConfig: Value(
        TimetableSettings.defaults().copyWith(periodView: false).encode(),
      ),
    );
    await fixtures.openApp(tester);
    await tester.tap(find.byKey(const Key('tab-1')));
    await tester.pumpAndSettle();
    final time = find.byKey(const Key('hour-time-10'));
    await tester.ensureVisible(time);
    await tester.pumpAndSettle();
    final cell = find.byKey(const Key('blank-weekday-1'));
    await tester.tapAt(
      Offset(tester.getCenter(cell).dx, tester.getCenter(time).dy + 18),
    );
    await tester.pumpAndSettle();
    expect(find.text('10:15'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'Many overlaps stay tappable and editing the list updates the grid',
    (tester) async {
      phone(tester, const Size(393, 852), 1);
      fixtures.MemoryController.seed = List.generate(
        30,
        (i) => Course(
          id: i + 1,
          name: '重叠课${i + 1}',
          location: 'B402',
          weekday: DateTime.now().weekday,
          startMinute: 480,
          endMinute: 565,
          colorIndex: i % 5,
        ),
      );
      await fixtures.openApp(tester);
      await tester.tap(find.byKey(const Key('tab-1')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('30门课程重叠').hitTestable());
      await tester.pumpAndSettle();
      expect(find.text('重叠课程'), findsOneWidget);
      await scrollTo(tester, find.text('重叠课30'));
      await tester.tap(find.text('重叠课30').hitTestable());
      await tester.pumpAndSettle();
      expect(find.byType(CourseEditor), findsOneWidget);
      await scrollTo(tester, find.text('删除课程'));
      await tester.tap(find.text('删除课程'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('删除'));
      await tester.pumpAndSettle();
      expect(find.text('重叠课30'), findsNothing);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('29门课程重叠'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('File read error clears a previous calendar preview', (
    tester,
  ) async {
    var count = 0;
    await showImport(tester, () async {
      if (count++ > 0) throw StateError('file read failed');
      return CalendarFile(
        'first.ics',
        File('test/fixtures/calendar.ics').readAsStringSync(),
      );
    });
    expect(find.text('first.ics'), findsOneWidget);
    await tester.tap(find.byKey(const Key('pick-calendar')));
    await tester.pumpAndSettle();
    expect(find.text('first.ics'), findsNothing);
    expect(find.byKey(const Key('confirm-import')), findsNothing);
    expect(find.text('暂时无法读取文件，请先将它下载到手机后重试。'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'Canceling file selection preserves the successful import result',
    (tester) async {
      var count = 0;
      await showImport(
        tester,
        () async => count++ == 0
            ? CalendarFile(
                'first.ics',
                File('test/fixtures/calendar.ics').readAsStringSync(),
              )
            : null,
      );
      await scrollTo(tester, find.byKey(const Key('confirm-import')));
      await tester.tap(find.byKey(const Key('confirm-import')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('好'));
      await tester.pumpAndSettle();
      await scrollTo(
        tester,
        find.byKey(const Key('pick-calendar')),
        delta: -200,
      );
      await tester.tap(find.byKey(const Key('pick-calendar')));
      await tester.pumpAndSettle();
      await scrollTo(tester, find.byKey(const Key('confirm-import')));
      expect(
        tester
            .widget<CupertinoButton>(find.byKey(const Key('confirm-import')))
            .onPressed,
        isNull,
      );
      expect(find.textContaining('已导入 2 组课程'), findsWidgets);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('Database load error is recoverable from every main tab', (
    tester,
  ) async {
    phone(tester, const Size(393, 852), 1);
    FailOnceController.attempts = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appProvider.overrideWith(FailOnceController.new)],
        child: const ScheduleApp(),
      ),
    );
    await tester.pumpAndSettle();
    for (final tab in [1, 2, 0]) {
      await tester.tap(find.byKey(Key('tab-$tab')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('retry-load')), findsOneWidget);
      expect(find.byType(CourseEditor), findsNothing);
      expect(tester.takeException(), isNull);
    }
    await tester.tap(find.byKey(const Key('retry-load')));
    await tester.pumpAndSettle();
    expect(find.text('今天没有课程'), findsOneWidget);
    expect(FailOnceController.attempts, 2);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'Historical semester date and large title remain selectable on a narrow screen',
    (tester) async {
      phone(tester, const Size(320, 700), 1.6);
      fixtures.MemoryController.prefs = fixtures.MemoryController.prefs
          .copyWith(semesterStart: Value(DateTime(2019, 9, 1)));
      await fixtures.openApp(tester);
      await tester.tap(find.byKey(const Key('tab-2')));
      await tester.pumpAndSettle();
      await scrollTo(tester, find.text('学期起始日期'));
      await tester.tap(find.text('学期起始日期'));
      await tester.pumpAndSettle();
      expect(find.text('第一周的任意一天'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('完成'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('Two overlapping courses retain separate cards and tap targets', (
    tester,
  ) async {
    phone(tester, const Size(393, 852), 1);
    final day = DateTime.now().weekday;
    fixtures.MemoryController.seed = [
      Course(
        id: 1,
        name: '并行A',
        location: 'A101',
        weekday: day,
        startMinute: 480,
        endMinute: 565,
        colorIndex: 0,
      ),
      Course(
        id: 2,
        name: '并行B',
        location: 'B402',
        weekday: day,
        startMinute: 480,
        endMinute: 565,
        colorIndex: 1,
      ),
    ];
    await fixtures.openApp(tester);
    await tester.tap(find.byKey(const Key('tab-1')));
    await tester.pumpAndSettle();
    final first = find.byKey(Key('course-card-1-${day - 1}'));
    final second = find.byKey(Key('course-card-2-${day - 1}'));
    expect(tester.getRect(first).overlaps(tester.getRect(second)), isFalse);
    expect(find.text('2门课程重叠'), findsNothing);
    await tester.tap(second);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<CupertinoTextField>(find.byKey(const Key('course-name')))
          .controller!
          .text,
      '并行B',
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'Landscape editor keyboard does not overflow the underlying main pages',
    (tester) async {
      phone(tester, const Size(720, 320), 1.3);
      await fixtures.openApp(tester);
      await tester.tap(find.byKey(const Key('add-agenda')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('添加课程'));
      await tester.pumpAndSettle();
      tester.view.viewInsets = const FakeViewPadding(bottom: 140);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
