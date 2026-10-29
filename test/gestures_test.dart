import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schedule/data/database.dart';
import 'package:schedule/data/timetable.dart';
import 'package:schedule/features/glass_dock.dart';

import 'widget_test.dart' as fixtures;

String weekLabel(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(const Key('week-range'))).data!;
int selectedTab(WidgetTester tester) =>
    tester.widget<GlassDock>(find.byType(GlassDock)).selectedIndex;

void phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(393, 852);
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

Future<void> openWeek(WidgetTester tester) async {
  await fixtures.openApp(tester);
  await tester.tap(find.byKey(const Key('tab-1')));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => fixtures.MemoryController.seed = []);
  testWidgets(
    'Horizontal swipes page to adjacent weeks, arrows agree, and this-week returns to today',
    (tester) async {
      phone(tester);
      await openWeek(tester);
      final initial = weekLabel(tester);
      final monday = mondayOf(DateTime.now());
      final next = DateTime(monday.year, monday.month, monday.day + 7);
      await tester.drag(
        find.byKey(const Key('week-pager')),
        const Offset(-290, 0),
      );
      await tester.pumpAndSettle();
      expect(weekLabel(tester), contains('${next.month}/${next.day} —'));
      expect(selectedTab(tester), 1);
      expect(find.text('添加课程'), findsNothing);
      await tester.drag(
        find.byKey(const Key('week-pager')),
        const Offset(290, 0),
      );
      await tester.pumpAndSettle();
      expect(weekLabel(tester), initial);
      await tester.tap(find.byKey(const Key('previous-week')));
      await tester.pumpAndSettle();
      final previous = weekLabel(tester);
      expect(previous, isNot(initial));
      await tester.tap(find.byKey(const Key('next-week')));
      await tester.pumpAndSettle();
      expect(weekLabel(tester), initial);
      await tester.drag(
        find.byKey(const Key('week-pager')),
        const Offset(-290, 0),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('this-week')));
      await tester.pumpAndSettle();
      expect(weekLabel(tester), initial);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'Vertical timetable scroll preserves the week and its offset when returning from another week',
    (tester) async {
      phone(tester);
      await openWeek(tester);
      final initial = weekLabel(tester);
      await tester.drag(
        find.byKey(const Key('week-pager')),
        const Offset(0, -230),
      );
      await tester.pumpAndSettle();
      expect(weekLabel(tester), initial);
      final storageKey = PageStorageKey(
        'week-scroll-${dayKey(mondayOf(DateTime.now()))}',
      );
      final scrollable = find.descendant(
        of: find.byKey(storageKey),
        matching: find.byType(Scrollable),
      );
      final before = tester.state<ScrollableState>(scrollable).position.pixels;
      expect(before, greaterThan(100));
      await tester.drag(
        find.byKey(const Key('week-pager')),
        const Offset(-290, 0),
      );
      await tester.pumpAndSettle();
      await tester.drag(
        find.byKey(const Key('week-pager')),
        const Offset(290, 0),
      );
      await tester.pumpAndSettle();
      expect(
        tester.state<ScrollableState>(scrollable).position.pixels,
        closeTo(before, 1),
      );
      expect(weekLabel(tester), initial);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'Swiping on a course pages the week; tapping the course still edits it',
    (tester) async {
      phone(tester);
      fixtures.MemoryController.seed = [
        Course(
          id: 1,
          name: '手势课',
          location: 'B402',
          weekday: DateTime.now().weekday,
          startMinute: 480,
          endMinute: 565,
          colorIndex: 0,
        ),
      ];
      await openWeek(tester);
      final initial = weekLabel(tester);
      final card = find.text('手势课').hitTestable();
      await tester.drag(card, const Offset(-250, 0));
      await tester.pumpAndSettle();
      expect(weekLabel(tester), isNot(initial));
      expect(find.text('编辑课程'), findsNothing);
      await tester.tap(find.byKey(const Key('this-week')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('手势课').hitTestable());
      await tester.pumpAndSettle();
      expect(find.text('编辑课程'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'Glass lens follows the drag, commits only on release, and clamps outside the dock',
    (tester) async {
      phone(tester);
      await fixtures.openApp(tester);
      final first = tester.getCenter(find.byKey(const Key('tab-0')));
      final last = tester.getCenter(find.byKey(const Key('tab-2')));
      final before = tester
          .getCenter(find.byKey(const Key('dock-indicator')))
          .dx;
      final pointer = await tester.startGesture(first);
      await pointer.moveBy(const Offset(25, 0));
      await tester.pump();
      await pointer.moveTo(last);
      await tester.pump();
      expect(
        tester.getCenter(find.byKey(const Key('dock-indicator'))).dx,
        greaterThan(before + 100),
      );
      expect(selectedTab(tester), 0);
      await pointer.up();
      await tester.pumpAndSettle();
      expect(selectedTab(tester), 2);
      final reverse = await tester.startGesture(
        tester.getCenter(find.byKey(const Key('tab-2'))),
      );
      await reverse.moveBy(const Offset(-25, 0));
      await tester.pump();
      await reverse.moveTo(Offset(0, first.dy));
      await tester.pump();
      await reverse.up();
      await tester.pumpAndSettle();
      expect(selectedTab(tester), 0);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'Cancelling dock scrubbing restores the old selection without opening another page',
    (tester) async {
      phone(tester);
      await openWeek(tester);
      final initial = weekLabel(tester);
      final original = tester.getCenter(
        find.byKey(const Key('dock-indicator')),
      );
      final pointer = await tester.startGesture(
        tester.getCenter(find.byKey(const Key('tab-1'))),
      );
      await pointer.moveBy(const Offset(25, 0));
      await tester.pump();
      await pointer.moveTo(tester.getCenter(find.byKey(const Key('tab-2'))));
      await tester.pump();
      await pointer.cancel();
      await tester.pumpAndSettle();
      expect(selectedTab(tester), 1);
      expect(
        tester.getCenter(find.byKey(const Key('dock-indicator'))).dx,
        closeTo(original.dx, 0.5),
      );
      expect(weekLabel(tester), initial);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'Dock drag switches pages while leaving the viewed timetable week intact',
    (tester) async {
      phone(tester);
      await openWeek(tester);
      await tester.drag(
        find.byKey(const Key('week-pager')),
        const Offset(-290, 0),
      );
      await tester.pumpAndSettle();
      final viewed = weekLabel(tester);
      final from = tester.getCenter(find.byKey(const Key('tab-1')));
      final to = tester.getCenter(find.byKey(const Key('tab-2')));
      final pointer = await tester.startGesture(from);
      await pointer.moveBy(const Offset(25, 0));
      await tester.pump();
      await pointer.moveTo(to);
      await pointer.up();
      await tester.pumpAndSettle();
      expect(selectedTab(tester), 2);
      expect(find.text('我的课表'), findsOneWidget);
      await tester.tap(find.byKey(const Key('tab-1')));
      await tester.pumpAndSettle();
      expect(weekLabel(tester), viewed);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'Glass dock remains usable with large text, high contrast and reduced motion',
    (tester) async {
      var selected = 0;
      await tester.pumpWidget(
        CupertinoApp(
          home: StatefulBuilder(
            builder: (context, setState) => MediaQuery(
              data: const MediaQueryData(
                size: Size(320, 700),
                highContrast: true,
                disableAnimations: true,
                textScaler: TextScaler.linear(1.8),
              ),
              child: CupertinoPageScaffold(
                child: Center(
                  child: SizedBox(
                    width: 240,
                    child: GlassDock(
                      selectedIndex: selected,
                      onSelected: (index) => setState(() => selected = index),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('tab-2')));
      await tester.pumpAndSettle();
      expect(selected, 2);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
