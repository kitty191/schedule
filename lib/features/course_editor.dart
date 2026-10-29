import 'package:drift/drift.dart' show Value;
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/app_controller.dart';
import '../data/database.dart';
import '../data/timetable.dart';
import 'components.dart';

class CourseEditor extends ConsumerStatefulWidget {
  const CourseEditor({super.key, this.course});
  final Course? course;
  @override
  ConsumerState<CourseEditor> createState() => _CourseEditorState();
}

class _CourseEditorState extends ConsumerState<CourseEditor> {
  late final _name = TextEditingController(text: widget.course?.name ?? '');
  late final _location = TextEditingController(
    text: widget.course?.location ?? '',
  );
  late int _weekday = widget.course?.weekday ?? DateTime.now().weekday;
  late int _start = widget.course?.startMinute ?? 8 * 60 + 30;
  late int _end = widget.course?.endMinute ?? 10 * 60 + 5;
  late int _color = widget.course?.colorIndex ?? 0;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _location.dispose();
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
      await showMessage(context, '先为课程起一个名字吧。');
      return;
    }
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
        title: const Text('删除这门课程？'),
        content: const Text('每周重复的这门课程和对应提醒都会移除。'),
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
      middle: Text(widget.course == null ? '添加课程' : '编辑课程'),
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
                  placeholder: '课程名称',
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
          const MutedText('每周重复'),
          const SizedBox(height: 12),
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
          WhiteCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                CupertinoListTile(
                  title: const Text('上课'),
                  trailing: Text(clockText(_start)),
                  onTap: () => _time(true),
                  additionalInfo: const Icon(
                    CupertinoIcons.chevron_right,
                    size: 14,
                  ),
                ),
                CupertinoListTile(
                  title: const Text('下课'),
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
          const MutedText('课程按所选星期每周重复。学期起始日期用于显示教学周，暂不限定课程的生效周数。'),
          if (widget.course != null) ...[
            const SizedBox(height: 32),
            CupertinoButton(
              onPressed: _saving ? null : _delete,
              child: const Text(
                '删除课程',
                style: TextStyle(color: CupertinoColors.destructiveRed),
              ),
            ),
          ],
        ],
      ),
    ),
  );
}
