import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schedule/data/app_controller.dart';
import 'package:schedule/data/database.dart';
import 'package:schedule/main.dart';
import 'package:schedule/live_update_bridge.dart';

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
        ),
      );
    state = AsyncData(AppData(courses, data.preferences));
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
    await tester.tap(find.byKey(const Key('more-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('课程提醒'));
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
}
