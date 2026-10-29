import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/app_controller.dart';
import '../data/database.dart';
import '../data/timetable.dart';
import 'components.dart';
import 'course_editor.dart';
import 'import_page.dart';

class WeekPage extends ConsumerStatefulWidget {
  const WeekPage({super.key});
  @override
  ConsumerState<WeekPage> createState() => _WeekPageState();
}

class _WeekPageState extends ConsumerState<WeekPage> {
  DateTime _monday = mondayOf(DateTime.now());
  void _move(int days) => setState(
    () => _monday = DateTime(_monday.year, _monday.month, _monday.day + days),
  );
  @override
  Widget build(BuildContext context) {
    final data = ref.watch(appProvider).asData?.value;
    final courses =
        data?.courses.where((c) => !isEvent(c)).toList() ?? <Course>[];
    final week = semesterWeek(data?.preferences.semesterStart, _monday);
    return CupertinoPageScaffold(
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 24, 14, 8),
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
                  CupertinoButton(
                    key: const Key('import-timetable'),
                    padding: const EdgeInsets.all(10),
                    onPressed: () => Navigator.push(
                      context,
                      CupertinoPageRoute<void>(
                        builder: (_) => const ImportPage(),
                      ),
                    ),
                    child: const Icon(
                      CupertinoIcons.square_arrow_down,
                      size: 22,
                    ),
                  ),
                  CupertinoButton(
                    padding: const EdgeInsets.all(10),
                    onPressed: () => Navigator.push(
                      context,
                      CupertinoPageRoute<void>(
                        builder: (_) => const CourseEditor(),
                      ),
                    ),
                    child: const Icon(CupertinoIcons.add, size: 24),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${week == null ? '整周总览' : '第 $week 周'} · ${_monday.month}/${_monday.day} — ${DateTime(_monday.year, _monday.month, _monday.day + 6).month}/${DateTime(_monday.year, _monday.month, _monday.day + 6).day}',
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
                        setState(() => _monday = mondayOf(DateTime.now())),
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
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: WhiteCard(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      const Expanded(child: MutedText('还没有课表，试试导入 .ics 文件。')),
                      CupertinoButton(
                        padding: const EdgeInsets.all(4),
                        onPressed: () => Navigator.push(
                          context,
                          CupertinoPageRoute<void>(
                            builder: (_) => const ImportPage(),
                          ),
                        ),
                        child: const Text('导入'),
                      ),
                    ],
                  ),
                ),
              ),
            Expanded(
              child: WeekGrid(monday: _monday, courses: courses),
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
  const WeekGrid({super.key, required this.monday, required this.courses});
  final DateTime monday;
  final List<Course> courses;
  @override
  Widget build(BuildContext context) {
    final days = List.generate(
      7,
      (i) => DateTime(monday.year, monday.month, monday.day + i),
    );
    final placements = days.map((day) => _placements(courses, day)).toList();
    final all = placements.expand((p) => p).toList();
    final firstHour = math.min(
      8,
      all.isEmpty ? 8 : all.map((p) => p.start ~/ 60).reduce(math.min),
    );
    final lastHour = math.min(
      24,
      math.max(
        20,
        all.isEmpty ? 20 : (all.map((p) => p.end).reduce(math.max) / 60).ceil(),
      ),
    );
    const hourHeight = 72.0, left = 38.0;
    final height = (lastHour - firstHour) * hourHeight;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final column = (width - left - 10) / 7;
        return Column(
          children: [
            SizedBox(
              height: 56,
              child: Row(
                children: [
                  const SizedBox(width: left),
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
                            child: Text(
                              '${day.day}',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: sameDay(day, DateTime.now())
                                    ? CupertinoColors.white
                                    : CupertinoColors.label,
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
                  height: height + 12,
                  width: width,
                  child: Stack(
                    children: [
                      for (var hour = firstHour; hour <= lastHour; hour++) ...[
                        Positioned(
                          left: 3,
                          top: (hour - firstHour) * hourHeight,
                          child: Text(
                            '${hour.toString().padLeft(2, '0')}:00',
                            style: const TextStyle(
                              fontSize: 9,
                              color: CupertinoColors.secondaryLabel,
                            ),
                          ),
                        ),
                        Positioned(
                          left: left,
                          right: 10,
                          top: (hour - firstHour) * hourHeight + 5,
                          child: Container(
                            height: 0.5,
                            color: const Color(0xFFE5E8F0),
                          ),
                        ),
                      ],
                      for (var day = 0; day < 7; day++)
                        for (final p in placements[day])
                          Positioned(
                            left:
                                left +
                                day * column +
                                p.lane * column / p.lanes +
                                1.5,
                            top:
                                (p.start - firstHour * 60) / 60 * hourHeight +
                                1,
                            width: column / p.lanes - 3,
                            height: math.max(
                              22,
                              (p.end - p.start) / 60 * hourHeight - 3,
                            ),
                            child: Semantics(
                              label:
                                  '${p.course.name} ${weekdays[day]} ${clockText(p.start)} ${p.course.location}',
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
