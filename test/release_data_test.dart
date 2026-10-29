import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schedule/data/app_controller.dart';
import 'package:schedule/data/database.dart';
import 'package:schedule/live_update_bridge.dart';

class SlowBridge extends LiveUpdateBridge {
  bool blockNext = false;
  final entered = Completer<void>();
  final release = Completer<void>();
  int inFlight = 0, maxInFlight = 0;
  Map<String, Object>? latest;
  @override
  Future<LiveUpdateStatus> configure(Map<String, Object> data) async {
    inFlight++;
    if (inFlight > maxInFlight) maxInFlight = inFlight;
    if (blockNext) {
      blockNext = false;
      entered.complete();
      await release.future;
    }
    latest = data;
    inFlight--;
    return const LiveUpdateStatus(
      supported: true,
      notificationsEnabled: true,
      promotionAllowed: true,
      active: false,
      promoted: false,
    );
  }
}

void main() {
  test('Resume sync and concurrent saves preserve the latest database and native state', () async {
    final db = ScheduleDatabase(NativeDatabase.memory());
    final bridge = SlowBridge();
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        bridgeProvider.overrideWithValue(bridge),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await db.close();
    });
    final initial = await container.read(appProvider.future);
    final controller = container.read(appProvider.notifier);
    bridge.blockNext = true;
    final resume = controller.retrySync();
    await bridge.entered.future;
    final save = controller.saveCourse(
      const CoursesCompanion(
        name: Value('并发保存课程'),
        location: Value('B402'),
        weekday: Value(4),
        startMinute: Value(480),
        endMinute: Value(540),
      ),
    );
    final prefs = controller.updatePreferences(
      initial.preferences.copyWith(leadMinutes: 37),
    );
    await Future<void>.delayed(const Duration(milliseconds: 20));
    bridge.release.complete();
    await Future.wait([resume, save, prefs]);
    expect(bridge.maxInFlight, 1);
    final result = container.read(appProvider).requireValue;
    expect(result.courses.single.name, '并发保存课程');
    expect(result.preferences.leadMinutes, 37);
    expect((bridge.latest!['courses'] as List).single['name'], '并发保存课程');
    expect(bridge.latest!['leadMinutes'], 37);
    expect((await db.loadCourses()).single.name, '并发保存课程');
  });

  test(
    'A rejected write does not poison later saves or reminder sync',
    () async {
      final db = ScheduleDatabase(NativeDatabase.memory());
      final bridge = SlowBridge();
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          bridgeProvider.overrideWithValue(bridge),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await db.close();
      });
      await container.read(appProvider.future);
      final controller = container.read(appProvider.notifier);
      const invalid = CoursesCompanion(
        name: Value('无效课'),
        location: Value(''),
        weekday: Value(4),
        startMinute: Value(600),
        endMinute: Value(500),
      );
      await expectLater(controller.saveCourse(invalid), throwsArgumentError);
      await controller.saveCourse(
        invalid.copyWith(endMinute: const Value(660)),
      );
      expect(container.read(appProvider).requireValue.courses, hasLength(1));
      expect((bridge.latest!['courses'] as List).single['endMinute'], 660);
    },
  );
}
