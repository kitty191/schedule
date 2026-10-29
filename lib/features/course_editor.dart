import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/app_controller.dart';
import '../data/database.dart';
import '../data/timetable.dart';
import '../data/timetable_settings.dart';
import 'components.dart';

class CourseEditor extends ConsumerStatefulWidget {
  const CourseEditor({
    super.key,
    this.course,
    this.kind = 'course',
    this.initialDate,
    this.initialWeekday,
    this.initialPeriod,
  });
  final Course? course;
  final String kind;
  final DateTime? initialDate;
  final int? initialWeekday, initialPeriod;
  @override
  ConsumerState<CourseEditor> createState() => _CourseEditorState();
}

class _CourseEditorState extends ConsumerState<CourseEditor> {
  late final _name = TextEditingController(text: widget.course?.name ?? '');
  late final _location = TextEditingController(
    text: widget.course?.location ?? '',
  );
  late int _weekday =
      widget.course?.weekday ?? widget.initialWeekday ?? DateTime.now().weekday;
  late int _start = widget.course?.startMinute ?? 8 * 60 + 30;
  late int _end = widget.course?.endMinute ?? 10 * 60 + 5;
  late int _color = widget.course?.colorIndex ?? 0;
  bool _saving = false;
  bool get _event =>
      widget.course == null ? widget.kind == 'event' : isEvent(widget.course!);
  bool get _imported => widget.course?.importKey != null;
  late DateTime _date = widget.course?.occurrences == null
      ? widget.initialDate ?? dateOnly(DateTime.now())
      : dateOnly(instancesOf(widget.course!).first.start);
  late final _notes = TextEditingController(
    text: widget.course?.description ?? '',
  );

  late final TimetableSettings _timetable = TimetableSettings.decode(
    ref.read(appProvider).requireValue.preferences.timetableConfig,
  );
  late bool _byPeriod =
      !_event &&
      !_imported &&
      (widget.course == null || widget.course?.startPeriod != null);
  late int _startPeriod =
      widget.course?.startPeriod ??
      (widget.initialPeriod ?? 1).clamp(1, _timetable.periods.length);
  late int _endPeriod =
      widget.course?.endPeriod ??
      (widget.initialPeriod ?? 2).clamp(
        _startPeriod,
        _timetable.periods.length,
      );

  @override
  void initState() {
    super.initState();
    if (_byPeriod) _assignPeriods(_startPeriod, _endPeriod);
  }

  void _assignPeriods(int first, int last) {
    _startPeriod = first;
    _endPeriod = last;
    _start = _timetable.periods[first - 1].start;
    _end = _timetable.periods[last - 1].end;
  }

  Future<void> _pickPeriod(bool first) async {
    final chosen = await pickNumber(
      context,
      first ? '开始节次' : '结束节次',
      first ? _startPeriod : _endPeriod,
      first ? 1 : _startPeriod,
      _timetable.periods.length,
      unit: ' 节',
    );
    if (chosen == null || !mounted) return;
    setState(() {
      if (first) {
        _assignPeriods(chosen, _endPeriod < chosen ? chosen : _endPeriod);
      } else {
        _assignPeriods(_startPeriod, chosen);
      }
    });
  }

  Future<void> _chooseDate() async {
    var selected = _date;
    final done = await showCupertinoModalPopup<bool>(
      context: context,
      builder: (context) => Container(
        color: CupertinoColors.systemBackground,
        height: 320 + MediaQuery.paddingOf(context).bottom,
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
                  const Text('日程日期'),
                  CupertinoButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('完成'),
                  ),
                ],
              ),
              Expanded(
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.date,
                  initialDateTime: _date,
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
    if (done == true && mounted) setState(() => _date = dateOnly(selected));
  }

  @override
  void dispose() {
    _name.dispose();
    _location.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _time(bool start) async {
    var selected = start ? _start : _end;
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (context) => Container(
        color: CupertinoColors.systemBackground,
        height: 300 + MediaQuery.paddingOf(context).bottom,
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
                  Text(start ? '上课时间' : '下课时间'),
                  CupertinoButton(
                    onPressed: () {
                      setState(() {
                        if (start) {
                          _start = selected;
                        } else {
                          _end = selected;
                        }
                      });
                      Navigator.pop(context);
                    },
                    child: const Text('完成'),
                  ),
                ],
              ),
              Expanded(
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.time,
                  use24hFormat: true,
                  initialDateTime: DateTime(
                    2026,
                    1,
                    1,
                    selected ~/ 60,
                    selected % 60,
                  ),
                  onDateTimeChanged: (value) =>
                      selected = value.hour * 60 + value.minute,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      await showMessage(context, _event ? '先为日程起一个名字吧。' : '先为课程起一个名字吧。');
      return;
    }
    if (_byPeriod) _assignPeriods(_startPeriod, _endPeriod);
    if (_end <= _start) {
      await showMessage(context, '下课时间需要晚于上课时间。跨午夜的课程请拆成两门添加。');
      return;
    }
    setState(() => _saving = true);
    try {
      await ref
          .read(appProvider.notifier)
          .saveCourse(
            CoursesCompanion(
              id: widget.course == null
                  ? const Value.absent()
                  : Value(widget.course!.id),
              name: Value(_name.text.trim()),
              location: Value(_location.text.trim()),
              weekday: Value(_weekday),
              startMinute: Value(_start),
              endMinute: Value(_end),
              colorIndex: Value(_color),
              startPeriod: Value(_byPeriod ? _startPeriod : null),
              endPeriod: Value(_byPeriod ? _endPeriod : null),
              kind: Value(_event ? 'event' : 'course'),
              description: Value(_notes.text.trim()),
              importKey: Value(widget.course?.importKey),
              reminderMinutes: Value(widget.course?.reminderMinutes),
              occurrences: Value(
                _imported
                    ? widget.course!.occurrences
                    : !_event
                    ? null
                    : jsonEncode([
                        CourseInstance(
                          DateTime(
                            _date.year,
                            _date.month,
                            _date.day,
                            _start ~/ 60,
                            _start % 60,
                          ),
                          DateTime(
                            _date.year,
                            _date.month,
                            _date.day,
                            _end ~/ 60,
                            _end % 60,
                          ),
                        ).toMap(),
                      ]),
              ),
            ),
          );
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) await showMessage(context, '课程未能保存，请重试。');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(_event ? '删除这个日程？' : '删除这门课程？'),
        content: Text(_event ? '这个日程和对应提醒会移除。' : '这组课程的所有上课日期和对应提醒都会移除。'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _saving = true);
    try {
      await ref.read(appProvider.notifier).deleteCourse(widget.course!.id);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) await showMessage(context, '删除未完成，请重试。');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => CupertinoPageScaffold(
    navigationBar: CupertinoNavigationBar(
      middle: Text(
        widget.course == null
            ? (_event ? '添加日程' : '添加课程')
            : (_event ? '编辑日程' : '编辑课程'),
      ),
      trailing: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: _saving ? null : _save,
        child: _saving ? const CupertinoActivityIndicator() : const Text('保存'),
      ),
    ),
    child: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const SizedBox(height: 12),
          WhiteCard(
            child: Column(
              children: [
                CupertinoTextField(
                  key: const Key('course-name'),
                  controller: _name,
                  placeholder: _event ? '日程名称' : '课程名称',
                  maxLength: 60,
                  padding: const EdgeInsets.all(14),
                  decoration: null,
                  textInputAction: TextInputAction.next,
                ),
                Container(height: 0.5, color: CupertinoColors.separator),
                CupertinoTextField(
                  key: const Key('course-location'),
                  controller: _location,
                  placeholder: '教室 / 地点（选填）',
                  maxLength: 100,
                  padding: const EdgeInsets.all(14),
                  decoration: null,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          if (_imported)
            WhiteCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('来自课表文件 · ${instancesOf(widget.course!).length} 次上课'),
                  const SizedBox(height: 8),
                  MutedText(
                    '${dateText(instancesOf(widget.course!).first.start)} — ${dateText(instancesOf(widget.course!).last.start)}',
                  ),
                  const MutedText(
                    '按文件中的实际日期上课；可编辑名称、地点、备注和颜色。时间如有变化，请删除这组课程后重新导入。',
                  ),
                ],
              ),
            ),
          if (_event)
            WhiteCard(
              padding: EdgeInsets.zero,
              child: CupertinoListTile(
                title: const Text('日期'),
                trailing: Text(dateText(_date)),
                onTap: _chooseDate,
              ),
            ),
          if (!_event && !_imported) const MutedText('每周重复'),
          const SizedBox(height: 12),
          if (!_event && !_imported)
            Wrap(
              spacing: 6,
              runSpacing: 8,
              children: List.generate(
                7,
                (index) => CupertinoButton(
                  key: Key('weekday-${index + 1}'),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  color: _weekday == index + 1
                      ? CupertinoColors.activeBlue
                      : CupertinoColors.white,
                  onPressed: () => setState(() => _weekday = index + 1),
                  child: Text(
                    weekdays[index],
                    style: TextStyle(
                      fontSize: 14,
                      color: _weekday == index + 1
                          ? CupertinoColors.white
                          : CupertinoColors.label,
                    ),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 24),
          if (!_event && !_imported) ...[
            CupertinoSlidingSegmentedControl<bool>(
              key: const Key('course-time-mode'),
              groupValue: _byPeriod,
              children: const {true: Text('按节次'), false: Text('自定义时间')},
              onValueChanged: (value) {
                if (value != null) {
                  setState(() {
                    _byPeriod = value;
                    if (value) _assignPeriods(_startPeriod, _endPeriod);
                  });
                }
              },
            ),
            const SizedBox(height: 14),
            if (_byPeriod)
              WhiteCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    CupertinoListTile(
                      key: const Key('course-start-period'),
                      title: const Text('开始节次'),
                      trailing: Text('第 $_startPeriod 节'),
                      additionalInfo: const CupertinoListTileChevron(),
                      onTap: () => _pickPeriod(true),
                    ),
                    CupertinoListTile(
                      key: const Key('course-end-period'),
                      title: const Text('结束节次'),
                      trailing: Text('第 $_endPeriod 节'),
                      additionalInfo: const CupertinoListTileChevron(),
                      onTap: () => _pickPeriod(false),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
                      child: MutedText(
                        '${clockText(_start)} — ${clockText(_end)} · 跟随课表设置自动调整',
                      ),
                    ),
                  ],
                ),
              ),
          ],
          if (!_imported && (_event || !_byPeriod))
            WhiteCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  CupertinoListTile(
                    title: Text(_event ? '开始' : '上课'),
                    trailing: Text(clockText(_start)),
                    onTap: () => _time(true),
                    additionalInfo: const Icon(
                      CupertinoIcons.chevron_right,
                      size: 14,
                    ),
                  ),
                  CupertinoListTile(
                    title: Text(_event ? '结束' : '下课'),
                    trailing: Text(clockText(_end)),
                    onTap: () => _time(false),
                    additionalInfo: const Icon(
                      CupertinoIcons.chevron_right,
                      size: 14,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 24),
          const MutedText('课程颜色'),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            children: List.generate(
              courseColors.length,
              (index) => CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () => setState(() => _color = index),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: courseColors[index],
                    shape: BoxShape.circle,
                  ),
                  child: _color == index
                      ? const Icon(
                          CupertinoIcons.check_mark,
                          color: CupertinoColors.white,
                          size: 20,
                        )
                      : null,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          WhiteCard(
            child: CupertinoTextField(
              controller: _notes,
              maxLines: 4,
              maxLength: 2000,
              placeholder: '备注 / 教师 / 节次',
              padding: const EdgeInsets.all(8),
              decoration: null,
            ),
          ),
          if (!_event && !_imported)
            const MutedText('课程按所选星期每周重复。按节次课程会跟随课表设置更新；自定义时间可自由安排。'),
          if (widget.course != null) ...[
            const SizedBox(height: 32),
            CupertinoButton(
              onPressed: _saving ? null : _delete,
              child: Text(
                _event ? '删除日程' : '删除课程',
                style: TextStyle(color: CupertinoColors.destructiveRed),
              ),
            ),
          ],
        ],
      ),
    ),
  );
}
