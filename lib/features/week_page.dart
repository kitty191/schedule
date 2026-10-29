import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/app_controller.dart';
import '../data/database.dart';
import '../data/timetable.dart';
import '../data/timetable_settings.dart';
import 'components.dart';
import 'course_editor.dart';
import 'import_page.dart';
import 'timetable_settings_page.dart';

class WeekPage extends ConsumerStatefulWidget {
  const WeekPage({super.key});
  @override
  ConsumerState<WeekPage> createState() => _WeekPageState();
}

class _WeekPageState extends ConsumerState<WeekPage> {
  DateTime _focusDate = dateOnly(DateTime.now());
  bool _tools = false;
  void _move(int days) => setState(
    () => _focusDate = DateTime(
      _focusDate.year,
      _focusDate.month,
      _focusDate.day + days,
    ),
  );
  void _open(Widget page) {
    setState(() => _tools = false);
    Navigator.push(context, CupertinoPageRoute<void>(builder: (_) => page));
  }

  Widget _tool(String title, IconData icon, Key key, Widget page) => Expanded(
    child: CupertinoButton(
      key: key,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
      onPressed: () => _open(page),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 23),
          const SizedBox(height: 8),
          Text(title, style: const TextStyle(fontSize: 13)),
        ],
      ),
    ),
  );
  @override
  Widget build(BuildContext context) {
    final data = ref.watch(appProvider).asData?.value;
    final courses =
        data?.courses.where((c) => !isEvent(c)).toList() ?? <Course>[];
    final settings = TimetableSettings.decode(
      data?.preferences.timetableConfig,
    );
    final start = startOfWeek(_focusDate, settings.weekStart);
    final end = DateTime(
      start.year,
      start.month,
      start.day + settings.visibleDays - 1,
    );
    final week = semesterWeek(
      data?.preferences.semesterStart,
      start,
      weekStart: settings.weekStart,
    );
    final hidden = [
      for (var i = settings.visibleDays; i < 7; i++)
        coursesOn(
          courses,
          DateTime(start.year, start.month, start.day + i),
        ).length,
    ].fold(0, (sum, v) => sum + v);
    return CupertinoPageScaffold(
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 24, 20, 8),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      '课表',
                      style: TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Semantics(
                    label: _tools ? '收起课表工具' : '展开课表工具',
                    button: true,
                    expanded: _tools,
                    child: CupertinoButton(
                      key: const Key('timetable-tools'),
                      padding: const EdgeInsets.all(10),
                      color: CupertinoColors.white,
                      borderRadius: BorderRadius.circular(24),
                      onPressed: () => setState(() => _tools = !_tools),
                      child: AnimatedRotation(
                        turns: _tools ? 0.125 : 0,
                        duration: const Duration(milliseconds: 180),
                        child: const Icon(CupertinoIcons.add, size: 24),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            ClipRect(
              child: AnimatedSize(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeInOut,
                alignment: Alignment.topCenter,
                child: _tools
                    ? Padding(
                        padding: const EdgeInsets.fromLTRB(20, 6, 20, 10),
                        child: WhiteCard(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Row(
                            children: [
                              _tool(
                                '添加课程',
                                CupertinoIcons.add_circled,
                                const Key('add-timetable-course'),
                                const CourseEditor(),
                              ),
                              _tool(
                                '导入课表',
                                CupertinoIcons.square_arrow_down,
                                const Key('import-timetable'),
                                const ImportPage(),
                              ),
                              _tool(
                                '课表设置',
                                CupertinoIcons.slider_horizontal_3,
                                const Key('timetable-settings'),
                                const TimetableSettingsPage(),
                              ),
                            ],
                          ),
                        ),
                      )
                    : const SizedBox(width: double.infinity),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${week == null ? '整周总览' : '第 $week 周'} · ${start.month}/${start.day} — ${end.month}/${end.day}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: CupertinoColors.secondaryLabel,
                      ),
                    ),
                  ),
                  CupertinoButton(
                    key: const Key('previous-week'),
                    padding: const EdgeInsets.all(6),
                    onPressed: () => _move(-7),
                    child: const Icon(CupertinoIcons.chevron_left, size: 16),
                  ),
                  CupertinoButton(
                    padding: const EdgeInsets.all(6),
                    onPressed: () =>
                        setState(() => _focusDate = dateOnly(DateTime.now())),
                    child: const Text('本周', style: TextStyle(fontSize: 13)),
                  ),
                  CupertinoButton(
                    key: const Key('next-week'),
                    padding: const EdgeInsets.all(6),
                    onPressed: () => _move(7),
                    child: const Icon(CupertinoIcons.chevron_right, size: 16),
                  ),
                ],
              ),
            ),
            if (courses.isEmpty)
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 4, 20, 10),
                child: MutedText('点击空白格排课，或展开右上角工具添加、导入。'),
              ),
            if (hidden > 0)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: MutedText('另有 $hidden 组课程在未显示的日期，可在课表设置中改为 7 天。'),
              ),
            Expanded(
              child: WeekGrid(
                weekStart: start,
                courses: courses,
                settings: settings,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Placement {
  _Placement(this.course, this.start, this.end, this.lane, this.lanes);
  final Course course;
  final int start, end, lane;
  int lanes;
}

List<_Placement> _placements(List<Course> courses, DateTime day) {
  final placements = <_Placement>[];
  var group = <_Placement>[];
  var laneEnds = <int>[];
  var groupEnd = -1;
  void finish() {
    for (final p in group) {
      p.lanes = laneEnds.length;
    }
    group = [];
    laneEnds = [];
  }

  for (final c in coursesOn(courses, day)) {
    final start = minuteOn(c, day), end = minuteOn(c, day, end: true);
    if (start >= groupEnd) {
      finish();
      groupEnd = -1;
    }
    var lane = laneEnds.indexWhere((last) => last <= start);
    if (lane < 0) {
      lane = laneEnds.length;
      laneEnds.add(end);
    } else {
      laneEnds[lane] = end;
    }
    final p = _Placement(c, start, end, lane, 1);
    placements.add(p);
    group.add(p);
    groupEnd = math.max(groupEnd, end);
  }
  finish();
  return placements;
}

class WeekGrid extends StatelessWidget {
  const WeekGrid({
    super.key,
    required this.weekStart,
    required this.courses,
    required this.settings,
  });
  final DateTime weekStart;
  final List<Course> courses;
  final TimetableSettings settings;
  @override
  Widget build(BuildContext context) {
    final days = List.generate(
      settings.visibleDays,
      (i) => DateTime(weekStart.year, weekStart.month, weekStart.day + i),
    );
    final placements = days.map((day) => _placements(courses, day)).toList();
    final all = placements.expand((p) => p).toList();
    final earliest = all.isEmpty
        ? settings.periods.first.start
        : all.map((p) => p.start).reduce(math.min);
    final latest = all.isEmpty
        ? settings.periods.last.end
        : all.map((p) => p.end).reduce(math.max);
    final axis = TimetableAxis(settings, earliest: earliest, latest: latest);
    final firstHour = math.min(settings.periods.first.start, earliest) ~/ 60;
    final lastHour = (math.max(settings.periods.last.end, latest) / 60).ceil();
    const left = 52.0;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final column = (width - left - 10) / settings.visibleDays;
        return Column(
          children: [
            SizedBox(
              height: 56 + MediaQuery.textScalerOf(context).scale(13) - 13,
              child: Row(
                children: [
                  SizedBox(
                    width: left,
                    child: Center(
                      child: MutedText(settings.periodView ? '节次' : '时间'),
                    ),
                  ),
                  for (final day in days)
                    SizedBox(
                      width: column,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            weekdays[day.weekday - 1].substring(1),
                            style: const TextStyle(
                              fontSize: 12,
                              color: CupertinoColors.secondaryLabel,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: sameDay(day, DateTime.now())
                                  ? CupertinoColors.activeBlue
                                  : null,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                '${day.day}',
                                maxLines: 1,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: sameDay(day, DateTime.now())
                                      ? CupertinoColors.white
                                      : CupertinoColors.label,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 120),
                child: SizedBox(
                  height: axis.height + 16,
                  width: width,
                  child: Stack(
                    children: [
                      // Touch targets sit below cards, so a card opens the existing course.
                      for (var day = 0; day < days.length; day++)
                        Positioned(
                          left: left + day * column,
                          top: 0,
                          bottom: 0,
                          width: column,
                          child: Semantics(
                            label: '${weekdays[days[day].weekday - 1]}空白格添加课程',
                            button: true,
                            child: GestureDetector(
                              key: Key('blank-weekday-${days[day].weekday}'),
                              behavior: HitTestBehavior.opaque,
                              onTapUp: (details) => Navigator.push(
                                context,
                                CupertinoPageRoute<void>(
                                  builder: (_) => CourseEditor(
                                    initialWeekday: days[day].weekday,
                                    initialPeriod: axis.periodAt(
                                      details.localPosition.dy,
                                      settings.periods,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      if (settings.periodView)
                        for (var i = 0; i < settings.periods.length; i++) ...[
                          Positioned(
                            left: 2,
                            top: axis.at(settings.periods[i].start) + 3,
                            width: left - 5,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Text(
                                  '${i + 1}',
                                  key: Key('period-label-${i + 1}'),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  clockText(settings.periods[i].start),
                                  style: const TextStyle(
                                    fontSize: 8.5,
                                    color: CupertinoColors.secondaryLabel,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  clockText(settings.periods[i].end),
                                  style: const TextStyle(
                                    fontSize: 8.5,
                                    color: CupertinoColors.secondaryLabel,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Positioned(
                            left: left,
                            right: 10,
                            top: axis.at(settings.periods[i].start),
                            child: Container(
                              height: 0.5,
                              color: const Color(0xFFE5E8F0),
                            ),
                          ),
                        ]
                      else
                        for (
                          var hour = firstHour;
                          hour <= lastHour;
                          hour++
                        ) ...[
                          Positioned(
                            left: 5,
                            top: axis.at(hour * 60),
                            child: Text(
                              clockText(hour * 60),
                              style: const TextStyle(
                                fontSize: 9,
                                color: CupertinoColors.secondaryLabel,
                              ),
                            ),
                          ),
                          Positioned(
                            left: left,
                            right: 10,
                            top: axis.at(hour * 60),
                            child: Container(
                              height: 0.5,
                              color: const Color(0xFFE5E8F0),
                            ),
                          ),
                        ],
                      for (var day = 0; day < days.length; day++)
                        for (final p in placements[day])
                          Positioned(
                            left:
                                left +
                                day * column +
                                p.lane * column / p.lanes +
                                1.5,
                            top: axis.at(p.start) + 1,
                            width: column / p.lanes - 3,
                            height: math.max(
                              22,
                              axis.at(p.end) - axis.at(p.start) - 3,
                            ),
                            child: Semantics(
                              label:
                                  '${p.course.name} ${weekdays[days[day].weekday - 1]} ${clockText(p.start)} ${p.course.location}',
                              button: true,
                              child: GestureDetector(
                                onTap: () => Navigator.push(
                                  context,
                                  CupertinoPageRoute<void>(
                                    builder: (_) =>
                                        CourseEditor(course: p.course),
                                  ),
                                ),
                                child: Container(
                                  clipBehavior: Clip.antiAlias,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color:
                                        courseColors[p.course.colorIndex %
                                                courseColors.length]
                                            .withValues(alpha: 0.79),
                                    borderRadius: BorderRadius.circular(9),
                                  ),
                                  child: LayoutBuilder(
                                    builder: (context, tile) => Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            p.course.name,
                                            maxLines: tile.maxHeight > 90
                                                ? 5
                                                : 3,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 11,
                                              height: 1.2,
                                              fontWeight: FontWeight.w600,
                                              color: CupertinoColors.white,
                                            ),
                                          ),
                                        ),
                                        if (tile.maxHeight > 68 &&
                                            p.course.location.isNotEmpty)
                                          Text(
                                            p.course.location,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 10,
                                              height: 1.2,
                                              color: CupertinoColors.white,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
