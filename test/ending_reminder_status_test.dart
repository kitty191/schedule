import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schedule/data/app_controller.dart';
import 'package:schedule/data/database.dart';
import 'package:schedule/features/reminder_sheet.dart';
import 'package:schedule/live_update_bridge.dart';

import 'widget_test.dart' show MemoryController;

class _StatusBridge extends LiveUpdateBridge {
  _StatusBridge(this.value);
  final LiveUpdateStatus value;
  @override
  Future<LiveUpdateStatus> status() async => value;
}

void main() {
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

  test('Ending permission and delivery results remain distinct from global notification permission', () {
    final status = LiveUpdateStatus.fromMap({
      'supported': true,
      'notificationsEnabled': true,
      'endingNotificationsEnabled': false,
      'endingBannerEnabled': false,
      'nextEndingAt': 1793313300000,
      'lastEndingAt': 1793309700000,
      'lastEndingCourse': '大学物理',
      'lastEndingPosted': false,
    });
    expect(status.notificationsEnabled, isTrue);
    expect(status.endingNotificationsEnabled, isFalse);
    expect(status.endingBannerEnabled, isFalse);
    expect(status.nextEndingAt, 1793313300000);
    expect(status.lastEndingPosted, isFalse);
    expect(status.lastEndingCourse, '大学物理');
    final legacy = LiveUpdateStatus.fromMap({});
    expect(legacy.nextEndingAt, isNull);
    expect(legacy.lastEndingAt, isNull);
    expect(legacy.lastEndingPosted, isNull);
  });

  for (final posted in [true, false]) {
    testWidgets(
      'Reminder settings report ${posted ? 'submitted' : 'failed'} ending delivery and the next boundary',
      (tester) async {
        final status = LiveUpdateStatus(
          supported: true,
          notificationsEnabled: true,
          promotionAllowed: true,
          active: false,
          promoted: false,
          exactAllowed: true,
          endingNotificationsEnabled: true,
          endingBannerEnabled: false,
          nextEndingAt: DateTime(2026, 10, 30, 9, 15).millisecondsSinceEpoch,
          lastEndingAt: DateTime(2026, 10, 29, 9, 15).millisecondsSinceEpoch,
          lastEndingCourse: '大学物理',
          lastEndingPosted: posted,
        );
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appProvider.overrideWith(MemoryController.new),
              bridgeProvider.overrideWithValue(_StatusBridge(status)),
            ],
            child: const CupertinoApp(home: ReminderSheet()),
          ),
        );
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(find.text('最近下课提示'), 220);
        expect(find.text('10/30 09:15'), findsOneWidget);
        expect(find.text('已开启，请允许横幅提示'), findsOneWidget);
        expect(
          find.textContaining(posted ? '已提交系统' : '未发送，请检查通知权限'),
          findsOneWidget,
        );
        expect(find.textContaining('大学物理'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
      variant: TargetPlatformVariant.only(TargetPlatform.android),
    );
  }
}
