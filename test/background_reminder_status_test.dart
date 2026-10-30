import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schedule/data/app_controller.dart';
import 'package:schedule/data/database.dart';
import 'package:schedule/features/reminder_sheet.dart';
import 'package:schedule/live_update_bridge.dart';

import 'widget_test.dart' show MemoryController;

class _BackgroundBridge extends LiveUpdateBridge {
  @override
  Future<LiveUpdateStatus> status() async => LiveUpdateStatus.fromMap({
    'backgroundRestricted': true,
    'batteryOptimizationIgnored': false,
    'scheduledBoundaryCount': 4,
    'nextBackgroundAt': DateTime(2026, 10, 30, 9, 25).millisecondsSinceEpoch,
    'lastBackgroundScheduledAt': DateTime(
      2026,
      10,
      30,
      9,
      15,
    ).millisecondsSinceEpoch,
    'lastBackgroundWakeAt': DateTime(
      2026,
      10,
      30,
      9,
      17,
    ).millisecondsSinceEpoch,
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'Background diagnostic fields are optional and do not imply delivery',
    () async {
      final status = await _BackgroundBridge().status();
      expect(status.backgroundRestricted, isTrue);
      expect(status.batteryOptimizationIgnored, isFalse);
      expect(status.scheduledBoundaryCount, 4);
      expect(
        status.lastBackgroundWakeAt! - status.lastBackgroundScheduledAt!,
        120000,
      );
      final legacy = LiveUpdateStatus.fromMap({});
      expect(legacy.lastBackgroundWakeAt, isNull);
      expect(legacy.nextBackgroundAt, isNull);
      expect(legacy.scheduledBoundaryCount, 0);
    },
  );

  testWidgets(
    'Background guidance reports restrictions and opens both settings routes',
    (tester) async {
      MemoryController.seed = [];
      MemoryController.prefs = const Preference(
        id: 1,
        reminders: true,
        leadMinutes: 10,
        endingLeadMinutes: 10,
        useFileReminders: true,
      );
      final calls = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        LiveUpdateBridge.channel,
        (MethodCall call) async {
          calls.add(call.method);
          return null;
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
          overrides: [
            appProvider.overrideWith(MemoryController.new),
            bridgeProvider.overrideWithValue(_BackgroundBridge()),
          ],
          child: const CupertinoApp(home: ReminderSheet()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('最近后台触发'), 220);
      expect(find.text('受限制，请允许后台运行'), findsOneWidget);
      expect(find.text('4 个'), findsOneWidget);
      expect(find.text('10/30 09:17\n计划 10/30 09:15'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byKey(const Key('background-settings')),
        140,
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('background-settings')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('background-settings')));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const Key('battery-settings')),
        140,
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('battery-settings')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('battery-settings')));
      await tester.pumpAndSettle();
      expect(calls, ['backgroundSettings', 'batterySettings']);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );
}
