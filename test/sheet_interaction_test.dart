import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schedule/features/reminder_sheet.dart';

import 'widget_test.dart' as fixtures;

Future<void> openReminders(WidgetTester tester) async {
  tester.view.physicalSize = const Size(393, 852);
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await fixtures.openApp(tester);
  await tester.tap(find.byKey(const Key('tab-2')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('提醒设置'));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => fixtures.MemoryController.seed = []);
  testWidgets('Reminder handle follows a downward drag and closes the panel', (
    tester,
  ) async {
    await openReminders(tester);
    final sheet = find.byKey(const Key('reminder-sheet'));
    final top = tester.getTopLeft(sheet);
    final gesture = await tester.startGesture(top + const Offset(196, 8));
    await gesture.moveBy(const Offset(0, 220));
    await tester.pump();
    expect(tester.getTopLeft(sheet).dy, greaterThan(top.dy + 100));
    await gesture.moveBy(const Offset(0, 300));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(find.byType(ReminderSheet), findsNothing);
    expect(find.text('我的课表'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'List scrolls without dismissing, then pulling at its top dismisses',
    (tester) async {
      await openReminders(tester);
      final sheet = find.byKey(const Key('reminder-sheet'));
      final list = find.descendant(of: sheet, matching: find.byType(ListView));
      final controller = tester.widget<ListView>(list).controller!;
      final top = tester.getTopLeft(sheet).dy;
      await tester.drag(list, const Offset(0, -260));
      await tester.pumpAndSettle();
      expect(controller.offset, greaterThan(100));
      expect(tester.getTopLeft(sheet).dy, closeTo(top, 0.1));
      await tester.drag(list, const Offset(0, 80));
      await tester.pumpAndSettle();
      expect(controller.offset, greaterThan(0));
      expect(tester.getTopLeft(sheet).dy, closeTo(top, 0.1));
      controller.jumpTo(0);
      await tester.pump();
      await tester.dragFrom(Offset(196, top + 220), const Offset(0, 520));
      await tester.pumpAndSettle();
      expect(find.byType(ReminderSheet), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('Short handle pull springs back; barrier tap still closes', (
    tester,
  ) async {
    await openReminders(tester);
    final sheet = find.byKey(const Key('reminder-sheet'));
    final top = tester.getTopLeft(sheet).dy;
    final gesture = await tester.startGesture(Offset(196, top + 8));
    await gesture.moveBy(const Offset(0, 40));
    await tester.pump(const Duration(milliseconds: 400));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(sheet).dy, closeTo(top, 0.1));
    await tester.tapAt(const Offset(196, 25));
    await tester.pumpAndSettle();
    expect(find.byType(ReminderSheet), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
}
