import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/app_controller.dart';
import '../data/database.dart';
import '../data/timetable.dart';
import 'components.dart';
import 'course_editor.dart';
import 'import_page.dart';

class TodayPage extends ConsumerStatefulWidget {
  const TodayPage({super.key});
  @override
  ConsumerState<TodayPage> createState() => _TodayPageState();
}

class _TodayPageState extends ConsumerState<TodayPage>
    with WidgetsBindingObserver {
  DateTime _now = DateTime.now();
  DateTime _day = dateOnly(DateTime.now());
  bool _completed = true;
  Timer? _timer;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(const Duration(seconds: 15), (_) => _refresh());
  }

  void _refresh() {
    if (!mounted) return;
    final now = DateTime.now();
    setState(() {
      if (sameDay(_day, _now)) _day = dateOnly(now);
      _now = now;
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refresh();
      if (defaultTargetPlatform == TargetPlatform.iOS &&
          ref.read(appProvider).hasValue) {
        ref.read(appProvider.notifier).retrySync();
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _edit([Course? course]) => Navigator.push(
    context,
    CupertinoPageRoute<void>(builder: (_) => CourseEditor(course: course)),
  );
  void _add() => showCupertinoModalPopup<void>(
    context: context,
    builder: (context) => CupertinoActionSheet(
      title: const Text('添加安排'),
      actions: [
        CupertinoActionSheetAction(
          onPressed: () {
            Navigator.pop(context);
            Navigator.push(
              this.context,
              CupertinoPageRoute<void>(
                builder: (_) => CourseEditor(kind: 'event', initialDate: _day),
              ),
            );
          },
          child: const Text('添加日程'),
        ),
        CupertinoActionSheetAction(
          onPressed: () {
            Navigator.pop(context);
            _edit();
          },
          child: const Text('添加课程'),
        ),
        CupertinoActionSheetAction(
          onPressed: () {
            Navigator.pop(context);
            Navigator.push(
              this.context,
              CupertinoPageRoute<void>(builder: (_) => const ImportPage()),
            );
          },
          child: const Text('导入课表'),
        ),
      ],
      cancelButton: CupertinoActionSheetAction(
        onPressed: () => Navigator.pop(context),
        child: const Text('取消'),
      ),
    ),
  );

  Future<void> _chooseDay() async {
    var selected = _day;
    final done = await showCupertinoModalPopup<bool>(
      context: context,
      builder: (context) => Container(
        height: 320 + MediaQuery.paddingOf(context).bottom,
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
                  const Text('查看日期'),
                  CupertinoButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('完成'),
                  ),
                ],
              ),
              Expanded(
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.date,
                  initialDateTime: _day,
                  minimumYear: 2020,
                  maximumYear: 2100,
                  onDateTimeChanged: (date) => selected = date,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (done == true && mounted) setState(() => _day = dateOnly(selected));
  }

  @override
  Widget build(BuildContext context) => CupertinoPageScaffold(
    child: SafeArea(
      bottom: false,
      child: ref
          .watch(appProvider)
          .when(
            loading: () => const Center(child: CupertinoActivityIndicator()),
            error: (_, _) => Center(
              child: CupertinoButton(
                onPressed: () => ref.invalidate(appProvider),
                child: const Text('读取失败，点击重试'),
              ),
            ),
            data: (data) {
              final today = coursesOn(data.courses, _day);
              final finished = today
                  .where((c) => !courseTime(c, _day, end: true).isAfter(_now))
                  .toList();
              final remaining = today
                  .where((c) => courseTime(c, _day, end: true).isAfter(_now))
                  .toList();
              final next = sameDay(_day, _now)
                  ? upcomingToday(data.courses, _now)
                  : null;
              return ListView(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 120),
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          '日程',
                          style: TextStyle(
                            fontSize: 34,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      CupertinoButton(
                        key: const Key('add-agenda'),
                        onPressed: _add,
                        padding: const EdgeInsets.all(10),
                        color: CupertinoColors.white,
                        borderRadius: BorderRadius.circular(28),
                        child: const Icon(CupertinoIcons.add, size: 24),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: CupertinoButton(
                          padding: EdgeInsets.zero,
                          alignment: Alignment.centerLeft,
                          onPressed: _chooseDay,
                          child: Text(
                            '${dateText(_day)} ${weekdays[_day.weekday - 1]}',
                            style: const TextStyle(
                              fontSize: 15,
                              color: CupertinoColors.secondaryLabel,
                            ),
                          ),
                        ),
                      ),
                      CupertinoButton(
                        padding: const EdgeInsets.all(6),
                        onPressed: () => setState(
                          () => _day = DateTime(
                            _day.year,
                            _day.month,
                            _day.day - 1,
                          ),
                        ),
                        child: const Icon(
                          CupertinoIcons.chevron_left,
                          size: 16,
                        ),
                      ),
                      CupertinoButton(
                        padding: const EdgeInsets.all(6),
                        onPressed: () => setState(() => _day = dateOnly(_now)),
                        child: const Text('今天', style: TextStyle(fontSize: 13)),
                      ),
                      CupertinoButton(
                        padding: const EdgeInsets.all(6),
                        onPressed: () => setState(
                          () => _day = DateTime(
                            _day.year,
                            _day.month,
                            _day.day + 1,
                          ),
                        ),
                        child: const Icon(
                          CupertinoIcons.chevron_right,
                          size: 16,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  if (next != null) ...[
                    Text(
                      isEvent(next)
                          ? '接下来的安排'
                          : _now.isBefore(courseTime(next, _now))
                          ? '下一节'
                          : '正在上课',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _NextCard(
                      course: next,
                      now: _now,
                      onTap: () => _edit(next),
                    ),
                    const SizedBox(height: 26),
                  ],
                  if (today.isEmpty)
                    WhiteCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            CupertinoIcons.sun_max,
                            size: 32,
                            color: CupertinoColors.activeBlue,
                          ),
                          const SizedBox(height: 18),
                          Text(
                            sameDay(_day, _now) ? '今天没有课程' : '这天还没有安排',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const MutedText('导入课表，或添加一件想做的事。'),
                          CupertinoButton(
                            padding: const EdgeInsets.only(top: 18),
                            onPressed: () => _edit(),
                            child: const Text('添加第一门课程'),
                          ),
                          CupertinoButton(
                            padding: const EdgeInsets.only(top: 10),
                            onPressed: () => Navigator.push(
                              context,
                              CupertinoPageRoute<void>(
                                builder: (_) => const ImportPage(),
                              ),
                            ),
                            child: const Text('从文件导入课表'),
                          ),
                        ],
                      ),
                    ),
                  if (finished.isNotEmpty) ...[
                    WhiteCard(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 2,
                      ),
                      child: CupertinoButton(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        onPressed: () =>
                            setState(() => _completed = !_completed),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                '已结束 (${finished.length})',
                                style: const TextStyle(
                                  fontSize: 15,
                                  color: CupertinoColors.label,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Icon(
                              _completed
                                  ? CupertinoIcons.chevron_up
                                  : CupertinoIcons.chevron_down,
                              size: 15,
                              color: CupertinoColors.secondaryLabel,
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (_completed) ...[
                      const SizedBox(height: 10),
                      WhiteCard(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          children: [
                            for (final course in finished)
                              CourseRow(
                                course: course,
                                now: _day,
                                completed: true,
                                onTap: () => _edit(course),
                              ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                  ],
                  if (remaining.isNotEmpty)
                    WhiteCard(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        children: [
                          for (var i = 0; i < remaining.length; i++) ...[
                            if (i > 0)
                              Container(
                                height: 0.5,
                                color: CupertinoColors.separator,
                              ),
                            CourseRow(
                              course: remaining[i],
                              now: _day,
                              onTap: () => _edit(remaining[i]),
                            ),
                          ],
                        ],
                      ),
                    ),
                  if (data.syncError != null) ...[
                    const SizedBox(height: 16),
                    WhiteCard(
                      child: Column(
                        children: [
                          const MutedText('安排已保存在本机，系统提醒暂未同步。'),
                          CupertinoButton(
                            onPressed: () =>
                                ref.read(appProvider.notifier).retrySync(),
                            child: const Text('重试同步'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
    ),
  );
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
                inClass
                    ? '还有$minutes分钟${isEvent(course) ? '结束' : '下课'}'
                    : '还有$minutes分钟${isEvent(course) ? '开始' : '上课'}',
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
              '${clockText(minuteOn(course, now))} — ${clockText(minuteOn(course, now, end: true))}',
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
    this.completed = false,
  });
  final Course course;
  final VoidCallback onTap;
  final DateTime? now;
  final bool showWeekday;
  final bool completed;

  @override
  Widget build(BuildContext context) {
    final finished =
        completed ||
        (now != null && !courseTime(course, now!, end: true).isAfter(now!));
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
                    clockText(minuteOn(course, now ?? DateTime.now())),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: CupertinoColors.label,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    clockText(
                      minuteOn(course, now ?? DateTime.now(), end: true),
                    ),
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
    final courses =
        [
          ...?ref
              .watch(appProvider)
              .asData
              ?.value
              .courses
              .where((c) => !isEvent(c)),
        ]..sort(
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
