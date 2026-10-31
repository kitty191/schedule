import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schedule/data/app_controller.dart';
import 'package:schedule/data/database.dart';
import 'package:schedule/features/reminder_sheet.dart';
import 'package:schedule/live_update_bridge.dart';

import 'widget_test.dart' show MemoryController;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    MemoryController.seed = [];
    MemoryController.prefs = const Preference(
      id: 1,
      reminders: true,
      leadMinutes: 10,
      endingLeadMinutes: 10,
      useFileReminders: true,
    );
  });

  test('Probe callback and posting are separate, optional status fields', () {
    final status = LiveUpdateStatus.fromMap({
      'probeDueAt': 100,
      'probeUntil': 200,
      'probeLastWakeAt': 135,
      'probeLastScheduledAt': 100,
      'probeCallbackCount': 1,
      'probePosted': false,
    });
    expect(status.probeDueAt, 100);
    expect(status.probeCallbackCount, 1);
    expect(status.probeLastWakeAt, 135);
    expect(status.probeLastScheduledAt, 100);
    expect(status.probePosted, isFalse);
    expect(LiveUpdateStatus.fromMap({}).probeDueAt, isNull);
    expect(LiveUpdateStatus.fromMap({}).probePosted, isNull);
  });

  testWidgets(
    'The delayed test is scheduled without invoking immediate preview and can be cancelled',
    (tester) async {
      final calls = <String>[];
      Map<String, Object> state = {};
      final now = DateTime.now().millisecondsSinceEpoch;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        LiveUpdateBridge.channel,
        (call) async {
          calls.add(call.method);
          if (call.method == 'backgroundTest') {
            state = {
              'probeDueAt': now + 60000,
              'probeUntil': now + 240000,
              'probeCallbackCount': 0,
            };
          }
          if (call.method == 'cancelBackgroundTest') {
            state['probeCancelled'] = true;
          }
          return state;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          LiveUpdateBridge.channel,
          null,
        ),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [appProvider.overrideWith(MemoryController.new)],
          child: const CupertinoApp(home: ReminderSheet()),
        ),
      );
      await tester.pumpAndSettle();
      final start = find.byKey(const Key('background-test'));
      await tester.scrollUntilVisible(start, 250);
      await tester.pumpAndSettle();
      await tester.ensureVisible(start);
      await tester.pumpAndSettle();
      await tester.tap(start);
      await tester.pumpAndSettle();
      expect(find.text('等待系统闹钟，请离开 App'), findsOneWidget);
      final cancel = find.byKey(const Key('cancel-background-test'));
      await tester.ensureVisible(cancel);
      await tester.pumpAndSettle();
      await tester.tap(cancel);
      await tester.pumpAndSettle();
      expect(find.text('已取消'), findsOneWidget);
      expect(
        calls,
        containsAllInOrder(['backgroundTest', 'cancelBackgroundTest']),
      );
      expect(calls, isNot(contains('preview')));
      expect(calls, isNot(contains('previewEnding')));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  for (final posted in [null, false, true]) {
    testWidgets(
      'Probe diagnostic displays callback and $posted posting independently',
      (tester) async {
        final now = DateTime.now().millisecondsSinceEpoch;
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          LiveUpdateBridge.channel,
          (_) async => {
            'probeDueAt': now - 60000,
            'probeUntil': now + 180000,
            'probeLastWakeAt': now - 55000,
            'probeLastScheduledAt': now - 60000,
            'probeCallbackCount': 1,
            'probePosted': posted,
          },
        );
        addTearDown(
          () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            LiveUpdateBridge.channel,
            null,
          ),
        );
        await tester.pumpWidget(
          ProviderScope(
            overrides: [appProvider.overrideWith(MemoryController.new)],
            child: const CupertinoApp(home: ReminderSheet()),
          ),
        );
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(find.text('测试结果'), 250);
        expect(
          find.text(
            posted == null
                ? '已收到回调，尚未提交测试通知'
                : posted
                ? '已收到回调并提交通知，请核对桌面流体云'
                : '已收到回调，通知提交失败，请检查通知权限',
          ),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
      variant: TargetPlatformVariant.only(TargetPlatform.android),
    );
  }
}
