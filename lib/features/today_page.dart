import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/app_controller.dart';
import '../data/database.dart';
import '../data/timetable.dart';
import 'components.dart';
import 'course_editor.dart';
import 'reminder_sheet.dart';

class TodayPage extends ConsumerStatefulWidget {
  const TodayPage({super.key});
  @override
  ConsumerState<TodayPage> createState() => _TodayPageState();
}

class _TodayPageState extends ConsumerState<TodayPage>
    with WidgetsBindingObserver {
  late DateTime _now = DateTime.now();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(const Duration(seconds: 15), (_) => _refreshTime());
  }

  void _refreshTime() {
    if (mounted) setState(() => _now = DateTime.now());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshTime();
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _edit([Course? course]) => Navigator.of(context).push(
    CupertinoPageRoute<void>(builder: (_) => CourseEditor(course: course)),
  );

  void _menu() {
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: '关闭菜单',
      barrierColor: const Color(0x18000000),
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (context, animation, secondaryAnimation) => SafeArea(
        child: Align(
          alignment: Alignment.topRight,
          child: Padding(
            padding: const EdgeInsets.only(top: 64, right: 20),
            child: SizedBox(
              width: 238,
              child: WhiteCard(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _menuItem(
                      context,
                      CupertinoIcons.add_circled,
                      '添加课程',
                      () => _edit(),
                    ),
                    _menuItem(
                      context,
                      CupertinoIcons.square_list,
                      '全部课程',
                      () => Navigator.of(this.context).push(
                        CupertinoPageRoute<void>(
                          builder: (_) => const AllCoursesPage(),
                        ),
                      ),
                    ),
                    _menuItem(
                      context,
                      CupertinoIcons.bell,
                      '课程提醒',
                      () => showReminderSheet(this.context),
                    ),
                    _menuItem(
                      context,
                      CupertinoIcons.calendar,
                      '学期起始日期',
                      _semester,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _menuItem(
    BuildContext menuContext,
    IconData icon,
    String text,
    VoidCallback action,
  ) => CupertinoButton(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
    onPressed: () {
      Navigator.pop(menuContext);
      action();
    },
    child: Row(
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: 14),
        Text(
          text,
          style: const TextStyle(fontSize: 16, color: CupertinoColors.label),
        ),
      ],
    ),
  );

  Future<void> _semester() async {
    final data = ref.read(appProvider).asData?.value;
    if (data == null) return;
    var selected =
        data.preferences.semesterStart ??
        DateTime(_now.year, _now.month, _now.day);
    final saved = await showCupertinoModalPopup<bool>(
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
                    onPressed: () => Navigator.pop(context, false),
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
    if (saved != true || !mounted) return;
    try {
      await ref
          .read(appProvider.notifier)
          .updatePreferences(
            data.preferences.copyWith(semesterStart: Value(selected)),
          );
    } catch (_) {
      if (mounted) await showMessage(context, '学期起始日期未能保存，请重试。');
    }
  }

  @override
  Widget build(BuildContext context) {
    final value = ref.watch(appProvider);
    return CupertinoPageScaffold(
      child: SafeArea(
        child: value.when(
          loading: () => const Center(child: CupertinoActivityIndicator()),
          error: (_, _) => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('暂时无法读取课程'),
                CupertinoButton(
                  onPressed: () => ref.invalidate(appProvider),
                  child: const Text('重试'),
                ),
              ],
            ),
          ),
          data: (data) {
            final today = coursesOn(data.courses, _now);
            final next = upcomingToday(data.courses, _now);
            final week = semesterWeek(data.preferences.semesterStart, _now);
            return ListView(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '今天',
                            style: TextStyle(
                              fontSize: 34,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -1,
                            ),
                          ),
                          const SizedBox(height: 8),
                          MutedText(
                            '${_now.month}月${_now.day}日 ${weekdays[_now.weekday - 1]}${week == null ? '' : ' · 第$week周'}',
                          ),
                        ],
                      ),
                    ),
                    CupertinoButton(
                      key: const Key('more-menu'),
                      padding: const EdgeInsets.all(10),
                      onPressed: _menu,
                      color: CupertinoColors.white,
                      borderRadius: BorderRadius.circular(30),
                      child: const Icon(CupertinoIcons.ellipsis, size: 24),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                if (next != null) ...[
                  Text(
                    _now.isBefore(courseTime(next, _now)) ? '下一节' : '正在上课',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _NextCard(course: next, now: _now, onTap: () => _edit(next)),
                ] else
                  WhiteCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          CupertinoIcons.sun_max,
                          color: CupertinoColors.activeBlue,
                          size: 32,
                        ),
                        const SizedBox(height: 18),
                        Text(
                          today.isEmpty ? '今天没有课程' : '今天的课程结束啦',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        MutedText(
                          data.courses.isEmpty
                              ? '从添加第一门课程开始，安排你的每一天。'
                              : '留一点时间，做自己喜欢的事。',
                        ),
                        if (data.courses.isEmpty)
                          CupertinoButton(
                            padding: const EdgeInsets.only(top: 18),
                            onPressed: () => _edit(),
                            child: const Text('添加第一门课程'),
                          ),
                      ],
                    ),
                  ),
                const SizedBox(height: 30),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        '今天的课程',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    MutedText('共${today.length}节'),
                  ],
                ),
                const SizedBox(height: 14),
                if (today.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 36),
                    child: Center(child: MutedText('空白的一天，也很好。')),
                  )
                else
                  WhiteCard(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    child: Column(
                      children: [
                        for (var i = 0; i < today.length; i++) ...[
                          if (i > 0)
                            Container(
                              height: 0.5,
                              color: CupertinoColors.separator,
                            ),
                          CourseRow(
                            course: today[i],
                            now: _now,
                            onTap: () => _edit(today[i]),
                          ),
                        ],
                      ],
                    ),
                  ),
                const SizedBox(height: 24),
                CupertinoButton(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  onPressed: () => _edit(),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(CupertinoIcons.add_circled, size: 18),
                      SizedBox(width: 8),
                      Text('添加课程', style: TextStyle(fontSize: 15)),
                    ],
                  ),
                ),
                if (!data.preferences.reminders && data.courses.isNotEmpty)
                  CupertinoButton(
                    onPressed: () => showReminderSheet(context),
                    child: const Text('开启课前提醒', style: TextStyle(fontSize: 14)),
                  ),
                if (data.syncError != null)
                  WhiteCard(
                    child: Column(
                      children: [
                        const MutedText('课程已保存在本机，系统提醒暂未同步。'),
                        CupertinoButton(
                          onPressed: () async {
                            await ref.read(appProvider.notifier).retrySync();
                            if (!context.mounted) return;
                            final error = ref
                                .read(appProvider)
                                .asData
                                ?.value
                                .syncError;
                            if (error != null) {
                              await showMessage(context, error);
                            }
                          },
                          child: const Text('重试提醒同步'),
                        ),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _NextCard extends StatelessWidget {
  const _NextCard({
    required this.course,
    required this.now,
    required this.onTap,
  });
  final Course course;
  final DateTime now;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final start = courseTime(course, now);
    final inClass = !now.isBefore(start);
    final minutes =
        ((inClass ? courseTime(course, now, end: true) : start)
                    .difference(now)
                    .inSeconds /
                60)
            .ceil();
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFE2F1FF), Color(0xFFEEF4FF)],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFD1E7FF),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                inClass ? '还有$minutes分钟下课' : '还有$minutes分钟上课',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF007AFF),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: Text(
                    course.name,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w600,
                      color: CupertinoColors.label,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 16),
                const Icon(
                  CupertinoIcons.book,
                  color: CupertinoColors.activeBlue,
                  size: 27,
                ),
              ],
            ),
            const SizedBox(height: 10),
            MutedText(
              '${clockText(course.startMinute)} — ${clockText(course.endMinute)}',
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(
                  CupertinoIcons.location_solid,
                  size: 12,
                  color: CupertinoColors.secondaryLabel,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: MutedText(
                    course.location.isEmpty ? '未设置教室' : course.location,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class CourseRow extends StatelessWidget {
  const CourseRow({
    super.key,
    required this.course,
    required this.onTap,
    this.now,
    this.showWeekday = false,
  });
  final Course course;
  final VoidCallback onTap;
  final DateTime? now;
  final bool showWeekday;

  @override
  Widget build(BuildContext context) {
    final finished =
        now != null && !courseTime(course, now!, end: true).isAfter(now!);
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(vertical: 16),
      onPressed: onTap,
      child: Opacity(
        opacity: finished ? 0.45 : 1,
        child: Row(
          children: [
            SizedBox(
              width: 48,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    clockText(course.startMinute),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: CupertinoColors.label,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    clockText(course.endMinute),
                    style: const TextStyle(
                      fontSize: 12,
                      color: CupertinoColors.secondaryLabel,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              width: 3,
              height: 36,
              decoration: BoxDecoration(
                color: courseColors[course.colorIndex % courseColors.length],
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    course.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: CupertinoColors.label,
                    ),
                  ),
                  const SizedBox(height: 5),
                  MutedText(
                    '${showWeekday ? '${weekdays[course.weekday - 1]} · ' : ''}${course.location.isEmpty ? '未设置教室' : course.location}',
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              finished
                  ? CupertinoIcons.check_mark_circled
                  : CupertinoIcons.chevron_right,
              size: 15,
              color: CupertinoColors.tertiaryLabel,
            ),
          ],
        ),
      ),
    );
  }
}

class AllCoursesPage extends ConsumerWidget {
  const AllCoursesPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final courses = [...?ref.watch(appProvider).asData?.value.courses]
      ..sort(
        (a, b) => a.weekday == b.weekday
            ? a.startMinute.compareTo(b.startMinute)
            : a.weekday.compareTo(b.weekday),
      );
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('全部课程'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.push(
            context,
            CupertinoPageRoute<void>(builder: (_) => const CourseEditor()),
          ),
          child: const Icon(CupertinoIcons.add),
        ),
      ),
      child: SafeArea(
        child: courses.isEmpty
            ? const Center(child: MutedText('还没有课程，点击右上角添加。'))
            : ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  const MutedText('每周重复 · 点击课程可编辑或删除'),
                  const SizedBox(height: 16),
                  WhiteCard(
                    child: Column(
                      children: [
                        for (final course in courses)
                          CourseRow(
                            course: course,
                            showWeekday: true,
                            onTap: () => Navigator.push(
                              context,
                              CupertinoPageRoute<void>(
                                builder: (_) => CourseEditor(course: course),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
