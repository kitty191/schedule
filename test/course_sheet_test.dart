import 'package:drift/drift.dart' show Value;

import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schedule/data/app_controller.dart';
import 'package:schedule/data/database.dart';
import 'package:schedule/data/timetable.dart';
import 'package:schedule/features/course_editor.dart';
import 'package:schedule/main.dart';

import 'widget_test.dart' as fixtures;

Course sample({int start = 480, int end = 565}) => Course(
  id: 1,
  name: '试验课程',
  location: 'A101',
  weekday: DateTime.now().weekday,
  startMinute: start,
  endMinute: end,
  colorIndex: 0,
);
void phone(WidgetTester tester, {bool landscape = false}) {
  tester.view.physicalSize = landscape
      ? const Size(720, 320)
      : const Size(393, 852);
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    tester.view.resetViewInsets();
  });
}

AppData data(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(ScheduleApp)))
        .read(appProvider)
        .requireValue;
Future<void> openWeekSheet(WidgetTester tester, Course course) async {
  fixtures.MemoryController.seed = [course];
  await fixtures.openApp(tester);
  await tester.tap(find.byKey(const Key('tab-1')));
  await tester.pumpAndSettle();
  final card = find.byKey(Key('course-card-1-${course.weekday - 1}'));
  await tester.ensureVisible(card);
  await tester.pumpAndSettle();
  // A long card can exceed the landscape viewport; tap its visible top.
  final rect = tester.getRect(card);
  await tester.tapAt(rect.topLeft + const Offset(10, 10));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => fixtures.MemoryController.seed = []);
  testWidgets('Existing week course uses a bottom sheet and saves edits', (
    tester,
  ) async {
    phone(tester);
    await openWeekSheet(tester, sample());
    final sheet = find.byKey(const Key('course-editor-sheet'));
    expect(sheet, findsOneWidget);
    expect(tester.getTopLeft(sheet).dy, greaterThan(20));
    expect(
      ModalRoute.of(tester.element(find.byType(CourseEditor))),
      isA<CupertinoSheetRoute<void>>(),
    );
    await tester.enterText(find.byKey(const Key('course-name')), '修改后课程');
    await tester.enterText(find.byKey(const Key('course-location')), 'B402');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(sheet, findsNothing);
    expect(data(tester).courses.single.name, '修改后课程');
    expect(data(tester).courses.single.location, 'B402');
    expect(find.byKey(const Key('week-pager')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'Dragging the sheet down discards drafts and preserves the viewed week',
    (tester) async {
      phone(tester);
      await openWeekSheet(tester, sample(start: 910, end: 1040));
      final sheet = find.byKey(const Key('course-editor-sheet'));
      final range = tester
          .widget<Text>(find.byKey(const Key('week-range')))
          .data;
      await tester.enterText(find.byKey(const Key('course-name')), '未保存内容');
      final top = tester.getTopLeft(sheet);
      await tester.dragFrom(top + const Offset(196, 8), const Offset(0, 560));
      await tester.pumpAndSettle();
      expect(sheet, findsNothing);
      expect(data(tester).courses.single.name, '试验课程');
      expect(
        tester.widget<Text>(find.byKey(const Key('week-range'))).data,
        range,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'Editing sheet scroll and nested period picker do not dismiss the editor',
    (tester) async {
      phone(tester);
      await openWeekSheet(
        tester,
        sample().copyWith(
          startPeriod: const Value(1),
          endPeriod: const Value(2),
        ),
      );
      final sheet = find.byKey(const Key('course-editor-sheet'));
      final list = find.descendant(of: sheet, matching: find.byType(ListView));
      await tester.drag(list, const Offset(0, -180));
      await tester.pumpAndSettle();
      expect(sheet, findsOneWidget);
      final target = find.byKey(const Key('course-start-period'));
      await tester.ensureVisible(target);
      await tester.pumpAndSettle();
      await tester.tap(target);
      await tester.pumpAndSettle();
      expect(find.byType(CupertinoPicker), findsOneWidget);
      await tester.drag(find.byType(CupertinoPicker), const Offset(0, -80));
      await tester.pumpAndSettle();
      expect(sheet, findsOneWidget);
      await tester.tap(find.text('取消').hitTestable().last);
      await tester.pumpAndSettle();
      expect(sheet, findsOneWidget);
      expect(find.byType(CupertinoPicker), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'All-courses entry opens a sheet and system back returns to the list',
    (tester) async {
      phone(tester);
      fixtures.MemoryController.seed = [sample()];
      await fixtures.openApp(tester);
      await tester.tap(find.byKey(const Key('tab-2')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('全部课程'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('试验课程').hitTestable());
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('course-editor-sheet')), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('course-editor-sheet')), findsNothing);
      expect(find.text('全部课程'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
  for (final imported in [true, false]) {
    testWidgets(
      'Today ${imported ? 'imported course' : 'one-off event'} edits retain finite dates',
      (tester) async {
        phone(tester);
        final now = DateTime.now();
        final times = jsonEncode([
          CourseInstance(
            DateTime(now.year, now.month, now.day, 8),
            DateTime(now.year, now.month, now.day, 9, 25),
          ).toMap(),
        ]);
        fixtures.MemoryController.seed = [
          Course(
            id: 1,
            name: '日期安排',
            location: 'A101',
            weekday: now.weekday,
            startMinute: 480,
            endMinute: 565,
            colorIndex: 0,
            occurrences: times,
            importKey: imported ? 'file-key' : null,
            kind: imported ? 'course' : 'event',
          ),
        ];
        await fixtures.openApp(tester);
        await tester.tap(find.text('日期安排').hitTestable().first);
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('course-editor-sheet')), findsOneWidget);
        await tester.enterText(
          find.byKey(const Key('course-location')),
          'C302',
        );
        await tester.tap(find.text('保存'));
        await tester.pumpAndSettle();
        final saved = data(tester).courses.single;
        expect(saved.location, 'C302');
        expect(saved.occurrences, times);
        expect(saved.importKey, imported ? 'file-key' : null);
        expect(saved.kind, imported ? 'course' : 'event');
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
  testWidgets('Landscape keyboard keeps sheet fields and save control usable', (
    tester,
  ) async {
    phone(tester, landscape: true);
    await openWeekSheet(tester, sample());
    tester.view.viewInsets = const FakeViewPadding(bottom: 140);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('保存').hitTestable(), findsOneWidget);
    await tester.enterText(find.byKey(const Key('course-name')), '横屏修改');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(data(tester).courses.single.name, '横屏修改');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
