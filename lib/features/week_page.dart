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
  static const _origin = 10000;
  final DateTime _anchor = dateOnly(DateTime.now());
  final PageController _weekController = PageController(initialPage: _origin);
  int _page = _origin;
  bool _tools = false;

  DateTime _dateForPage(int page) =>
      DateTime(_anchor.year, _anchor.month, _anchor.day + (page - _origin) * 7);

  void _goTo(int page) {
    if (!_weekController.hasClients) return;
    final target = page.clamp(0, 20000);
    if (MediaQuery.disableAnimationsOf(context)) {
      _weekController.jumpToPage(target);
    } else {
      _weekController.animateToPage(
        target,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _move(int days) => _goTo(_page + days ~/ 7);
  void _thisWeek(int weekStart) {
    final anchor = startOfWeek(_anchor, weekStart);
    final now = startOfWeek(DateTime.now(), weekStart);
    final days = DateTime.utc(
      now.year,
      now.month,
      now.day,
    ).difference(DateTime.utc(anchor.year, anchor.month, anchor.day)).inDays;
    _goTo(_origin + days ~/ 7);
  }

  @override
  void dispose() {
    _weekController.dispose();
    super.dispose();
  }

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
    final start = startOfWeek(_dateForPage(_page), settings.weekStart);
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
                      key: const Key('week-range'),
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
                    key: const Key('this-week'),
                    onPressed: () => _thisWeek(settings.weekStart),
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
              child: PageView.builder(
                key: const Key('week-pager'),
                controller: _weekController,
                itemCount: 20001,
                onPageChanged: (page) => setState(() => _page = page),
                itemBuilder: (context, page) {
                  final pageStart = startOfWeek(
                    _dateForPage(page),
                    settings.weekStart,
                  );
                  return WeekGrid(
                    key: ValueKey('week-${dayKey(pageStart)}'),
                    weekStart: pageStart,
                    courses: courses,
                    settings: settings,
                  );
                },
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
    final textScale = MediaQuery.textScalerOf(context);
    final labelHeight =
        3 + textScale.scale(14) * 1.05 + 4 + textScale.scale(8.5) * 1.1 * 2 + 4;
    final axis = TimetableAxis(
      settings,
      earliest: earliest,
      latest: latest,
      minimumPeriodHeight: labelHeight,
    );
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
                key: PageStorageKey('week-scroll-${dayKey(weekStart)}'),
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
                                    height: 1.05,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  clockText(settings.periods[i].start),
                                  style: const TextStyle(
                                    fontSize: 8.5,
                                    height: 1.1,
                                    color: CupertinoColors.secondaryLabel,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  clockText(settings.periods[i].end),
                                  style: const TextStyle(
                                    fontSize: 8.5,
                                    height: 1.1,
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
                      if (settings.periodView)
                        for (var hour = firstHour; hour <= lastHour; hour++)
                          if (hour * 60 >= earliest &&
                              hour * 60 <= latest &&
                              (hour * 60 < settings.periods.first.start ||
                                  hour * 60 > settings.periods.last.end)) ...[
                            Positioned(
                              left: 5,
                              top: axis.at(hour * 60),
                              child: Text(
                                clockText(hour * 60),
                                key: Key('extended-time-$hour'),
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
                            key: Key('course-card-${p.course.id}-$day'),
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
                                  child: _CourseText(course: p.course),
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

/// Fit complete text lines to the real card height, never clip half a line.
class _CourseText extends StatelessWidget {
  const _CourseText({required this.course});
  final Course course;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final scaler = MediaQuery.textScalerOf(context);
      final baseStyle = DefaultTextStyle.of(context).style;
      TextStyle style(double size, {bool title = false}) => baseStyle.copyWith(
        fontSize: size,
        height: 1.2,
        color: CupertinoColors.white,
        fontWeight: title ? FontWeight.w600 : FontWeight.normal,
      );
      double measure(String text, TextStyle textStyle, {int? maxLines}) {
        final painter = TextPainter(
          text: TextSpan(text: text, style: textStyle),
          textDirection: Directionality.of(context),
          textScaler: scaler,
          maxLines: maxLines,
          ellipsis: maxLines == null ? null : '…',
        )..layout(maxWidth: box.maxWidth);
        final height = painter.height;
        painter.dispose();
        return height;
      }

      var font = 11.0;
      final locationStyle = style(9);
      final locationHeight = course.location.isEmpty
          ? 0.0
          : measure(course.location, locationStyle, maxLines: 2);
      final reserve = locationHeight == 0 ? 0.0 : locationHeight + 4;
      while (font > 9 &&
          measure(course.name, style(font, title: true)) + reserve >
              box.maxHeight) {
        font -= 0.5;
      }
      final line = measure('字', style(font, title: true));
      // Preserve at least two title lines before adding classroom details.
      var locationLines = course.location.isEmpty ? 0 : 2;
      var usedLocationHeight = locationHeight;
      if (box.maxHeight < line * 2 + usedLocationHeight + 4) {
        locationLines = course.location.isEmpty ? 0 : 1;
        usedLocationHeight = course.location.isEmpty
            ? 0
            : measure(course.location, locationStyle, maxLines: 1);
      }
      if (box.maxHeight < line * 2 + usedLocationHeight + 4) {
        locationLines = 0;
        usedLocationHeight = 0;
      }
      final titleSpace =
          box.maxHeight - usedLocationHeight - (locationLines > 0 ? 4 : 0);
      final nameLines = math.max(1, ((titleSpace + 0.001) / line).floor());
      final name = Text(
        course.name,
        maxLines: nameLines,
        overflow: TextOverflow.ellipsis,
        style: style(font, title: true),
      );
      if (box.maxHeight < line) {
        return FittedBox(
          alignment: Alignment.topLeft,
          fit: BoxFit.scaleDown,
          child: Text(
            course.name,
            maxLines: 1,
            style: style(font, title: true),
          ),
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: name),
          if (locationLines > 0) ...[
            const SizedBox(height: 4),
            Text(
              course.location,
              maxLines: locationLines,
              overflow: TextOverflow.ellipsis,
              style: locationStyle,
            ),
          ],
        ],
      );
    },
  );
}
