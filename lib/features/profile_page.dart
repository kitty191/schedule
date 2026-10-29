import 'package:drift/drift.dart' show Value;
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/app_controller.dart';
import '../data/timetable.dart';
import 'components.dart';
import 'import_page.dart';
import 'reminder_sheet.dart';
import 'today_page.dart';
import 'timetable_settings_page.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(appProvider).asData?.value;
    return CupertinoPageScaffold(
      child: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 120),
          children: [
            const Text(
              '我的',
              style: TextStyle(fontSize: 34, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 30),
            Row(
              children: [
                Container(
                  width: 62,
                  height: 62,
                  decoration: const BoxDecoration(
                    color: Color(0xFFE4F0FF),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    CupertinoIcons.person_fill,
                    color: CupertinoColors.activeBlue,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '我的课表',
                        style: TextStyle(
                          fontSize: 23,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      MutedText(
                        '${data?.courses.where((c) => !isEvent(c)).map((c) => c.name).toSet().length ?? 0} 门课程 · 数据保存在本机',
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 30),
            WhiteCard(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                children: [
                  _tile(
                    CupertinoIcons.square_arrow_down,
                    '导入课表',
                    () => Navigator.push(
                      context,
                      CupertinoPageRoute<void>(
                        builder: (_) => const ImportPage(),
                      ),
                    ),
                  ),
                  _tile(
                    CupertinoIcons.book,
                    '全部课程',
                    () => Navigator.push(
                      context,
                      CupertinoPageRoute<void>(
                        builder: (_) => const AllCoursesPage(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            WhiteCard(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                children: [
                  _tile(
                    CupertinoIcons.slider_horizontal_3,
                    '课表设置',
                    () => Navigator.push(
                      context,
                      CupertinoPageRoute<void>(
                        builder: (_) => const TimetableSettingsPage(),
                      ),
                    ),
                  ),
                  _tile(
                    CupertinoIcons.bell,
                    '提醒设置',
                    () => showReminderSheet(context),
                  ),
                  _tile(
                    CupertinoIcons.calendar,
                    '学期起始日期',
                    () => showSemesterPicker(context, ref),
                    subtitle: data?.preferences.semesterStart == null
                        ? '未设置'
                        : dateText(data!.preferences.semesterStart!),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            WhiteCard(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: _tile(
                CupertinoIcons.info_circle,
                '关于今天课程',
                () => showMessage(
                  context,
                  '今天课程 v0.4.0\n\n日程、整周课表和本地 .ics 导入。无需登录。\n\nAndroid 支持系统实时提醒；iOS 使用普通通知，自动安排最近 60 次提醒，需要定期打开应用续排。',
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(8, 24, 8, 0),
              child: MutedText('简单安排，专注每一天。'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tile(
    IconData icon,
    String text,
    VoidCallback action, {
    String? subtitle,
  }) => CupertinoListTile(
    leading: Icon(icon, size: 22, color: CupertinoColors.activeBlue),
    title: Text(text, style: const TextStyle(fontSize: 16)),
    subtitle: subtitle == null ? null : Text(subtitle),
    trailing: const CupertinoListTileChevron(),
    onTap: action,
  );
}

Future<void> showSemesterPicker(BuildContext context, WidgetRef ref) async {
  final data = ref.read(appProvider).asData?.value;
  if (data == null) return;
  var selected = data.preferences.semesterStart ?? dateOnly(DateTime.now());
  final done = await showCupertinoModalPopup<bool>(
    context: context,
    builder: (context) => Container(
      height: 330 + MediaQuery.paddingOf(context).bottom,
      color: CupertinoColors.systemBackground,
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                CupertinoButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('取消'),
                ),
                const Text('第一周的任意一天'),
                CupertinoButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('完成'),
                ),
              ],
            ),
            Expanded(
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.date,
                initialDateTime: selected,
                minimumYear: 2020,
                maximumYear: 2100,
                onDateTimeChanged: (value) => selected = value,
              ),
            ),
          ],
        ),
      ),
    ),
  );
  if (done != true || !context.mounted) return;
  try {
    await ref
        .read(appProvider.notifier)
        .updatePreferences(
          data.preferences.copyWith(semesterStart: Value(dateOnly(selected))),
        );
  } catch (_) {
    if (context.mounted) await showMessage(context, '日期未能保存，请重试。');
  }
}
