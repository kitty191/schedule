import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/app_controller.dart';
import '../data/timetable.dart';
import '../data/timetable_settings.dart';
import 'components.dart';

class TimetableSettingsPage extends ConsumerStatefulWidget {
  const TimetableSettingsPage({super.key});
  @override
  ConsumerState<TimetableSettingsPage> createState() =>
      _TimetableSettingsPageState();
}

class _TimetableSettingsPageState extends ConsumerState<TimetableSettingsPage> {
  late TimetableSettings _settings = TimetableSettings.decode(
    ref.read(appProvider).requireValue.preferences.timetableConfig,
  );
  late int _count = _settings.periods.length;
  String? _templateError;
  bool _busy = false;

  void _template(TimetableSettings next, {int? count}) {
    setState(() {
      _count = count ?? _count;
      try {
        _settings = next.generate(_count);
        _templateError = null;
      } on FormatException catch (error) {
        _settings = next;
        _templateError = error.message;
      }
    });
  }

  Future<void> _number(
    String title,
    int value,
    int min,
    int max,
    void Function(int) update, {
    String unit = '',
  }) async {
    final chosen = await pickNumber(
      context,
      title,
      value,
      min,
      max,
      unit: unit,
    );
    if (chosen != null && mounted) update(chosen);
  }

  Future<void> _editPeriod(int index, bool start) async {
    final period = _settings.periods[index];
    final time = await pickClock(
      context,
      '第 ${index + 1} 节${start ? '上课' : '下课'}',
      start ? period.start : period.end,
    );
    if (time == null || !mounted) return;
    final periods = [..._settings.periods];
    periods[index] = start
        ? period.copyWith(start: time)
        : period.copyWith(end: time);
    setState(
      () => _settings = _settings.copyWith(
        periods: periods,
        firstStart: periods.first.start,
      ),
    );
  }

  Future<void> _save() async {
    final error = _templateError ?? _settings.validationError;
    if (error != null) {
      await showMessage(context, error);
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(appProvider.notifier).updateTimetable(_settings);
      if (mounted) Navigator.pop(context);
    } on FormatException catch (e) {
      if (mounted) await showMessage(context, e.message);
    } catch (_) {
      if (mounted) await showMessage(context, '课表设置未能保存，请重试。');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _weekday() async {
    final day = await showCupertinoModalPopup<int>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('每周起始日'),
        actions: [
          for (var i = 1; i <= 7; i++)
            CupertinoActionSheetAction(
              onPressed: () => Navigator.pop(context, i),
              child: Text(weekdays[i - 1]),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
      ),
    );
    if (day != null && mounted) {
      setState(() => _settings = _settings.copyWith(weekStart: day));
    }
  }

  Widget _row(String label, String value, VoidCallback action, {Key? key}) =>
      CupertinoListTile(
        key: key,
        title: Text(label, style: const TextStyle(fontSize: 15)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                color: CupertinoColors.secondaryLabel,
              ),
            ),
            const SizedBox(width: 5),
            const CupertinoListTileChevron(),
          ],
        ),
        onTap: _busy ? null : action,
      );
  @override
  Widget build(BuildContext context) {
    final error = _templateError ?? _settings.validationError;
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('课表设置'),
        trailing: CupertinoButton(
          key: const Key('save-timetable'),
          padding: EdgeInsets.zero,
          onPressed: _busy ? null : _save,
          child: _busy ? const CupertinoActivityIndicator() : const Text('保存'),
        ),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          children: [
            WhiteCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '按自己的时间上课',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  MutedText(
                    '每天 ${_settings.periods.length} 节 · ${clockText(_settings.periods.first.start)} — ${clockText(_settings.periods.last.end)}',
                  ),
                  const SizedBox(height: 8),
                  const MutedText('保存后会同步调整按节次添加的课程及提醒。导入和自定义时间课程继续使用各自的时间。'),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const MutedText('每周与显示'),
            const SizedBox(height: 10),
            WhiteCard(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                children: [
                  _row(
                    '每周起始日',
                    weekdays[_settings.weekStart - 1],
                    _weekday,
                    key: const Key('week-start'),
                  ),
                  CupertinoListTile(
                    title: const Text('每周显示天数', style: TextStyle(fontSize: 15)),
                    trailing: CupertinoSlidingSegmentedControl<int>(
                      groupValue: _settings.visibleDays,
                      children: const {
                        5: Text('5 天', style: TextStyle(fontSize: 13)),
                        7: Text('7 天', style: TextStyle(fontSize: 13)),
                      },
                      onValueChanged: (value) {
                        if (!_busy && value != null) {
                          setState(
                            () => _settings = _settings.copyWith(
                              visibleDays: value,
                            ),
                          );
                        }
                      },
                    ),
                  ),
                  CupertinoListTile(
                    title: const Text('按节次显示', style: TextStyle(fontSize: 15)),
                    trailing: CupertinoSwitch(
                      value: _settings.periodView,
                      onChanged: _busy
                          ? null
                          : (value) => setState(
                              () => _settings = _settings.copyWith(
                                periodView: value,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(8, 10, 8, 22),
              child: MutedText(
                '从起始日起连续显示 5 或 7 天；关闭按节次显示后，课表改用小时刻度。教学周也按起始日计算。',
              ),
            ),
            const MutedText('批量设置上课时间'),
            const SizedBox(height: 10),
            WhiteCard(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                children: [
                  _row(
                    '每天课程节数',
                    '$_count 节',
                    () => _number(
                      '每天课程节数',
                      _count,
                      1,
                      24,
                      (value) => _template(_settings, count: value),
                      unit: ' 节',
                    ),
                    key: const Key('period-count'),
                  ),
                  _row('第一节上课', clockText(_settings.firstStart), () async {
                    final time = await pickClock(
                      context,
                      '第一节上课',
                      _settings.firstStart,
                    );
                    if (time != null && mounted) {
                      _template(_settings.copyWith(firstStart: time));
                    }
                  }, key: const Key('first-start')),
                  _row(
                    '每节课时长',
                    '${_settings.lessonMinutes} 分钟',
                    () => _number(
                      '每节课时长',
                      _settings.lessonMinutes,
                      5,
                      180,
                      (value) =>
                          _template(_settings.copyWith(lessonMinutes: value)),
                      unit: ' 分钟',
                    ),
                    key: const Key('lesson-duration'),
                  ),
                  _row(
                    '普通课间',
                    '${_settings.breakMinutes} 分钟',
                    () => _number(
                      '普通课间',
                      _settings.breakMinutes,
                      0,
                      120,
                      (value) =>
                          _template(_settings.copyWith(breakMinutes: value)),
                      unit: ' 分钟',
                    ),
                  ),
                  _row(
                    '午休从哪节后',
                    _settings.lunchAfter == 0
                        ? '不设置'
                        : '第 ${_settings.lunchAfter} 节后',
                    () => _number(
                      '午休节次（0 为不设置）',
                      _settings.lunchAfter,
                      0,
                      24,
                      (value) =>
                          _template(_settings.copyWith(lunchAfter: value)),
                    ),
                  ),
                  _row(
                    '午休时长',
                    '${_settings.lunchMinutes} 分钟',
                    () => _number(
                      '午休时长',
                      _settings.lunchMinutes,
                      0,
                      240,
                      (value) =>
                          _template(_settings.copyWith(lunchMinutes: value)),
                      unit: ' 分钟',
                    ),
                  ),
                  _row(
                    '晚休从哪节后',
                    _settings.eveningAfter == 0
                        ? '不设置'
                        : '第 ${_settings.eveningAfter} 节后',
                    () => _number(
                      '晚休节次（0 为不设置）',
                      _settings.eveningAfter,
                      0,
                      24,
                      (value) =>
                          _template(_settings.copyWith(eveningAfter: value)),
                    ),
                  ),
                  _row(
                    '晚休时长',
                    '${_settings.eveningMinutes} 分钟',
                    () => _number(
                      '晚休时长',
                      _settings.eveningMinutes,
                      0,
                      240,
                      (value) =>
                          _template(_settings.copyWith(eveningMinutes: value)),
                      unit: ' 分钟',
                    ),
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(8, 10, 8, 24),
              child: MutedText(
                '调整模板会重新生成各节时间；午休/晚休替代对应的普通课间。0 表示不设置；超出每天节数的休息不生效。需要特殊安排时，可在下方逐节微调。',
              ),
            ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Text(
                  error,
                  key: const Key('timetable-error'),
                  style: const TextStyle(
                    color: CupertinoColors.destructiveRed,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
              ),
            const MutedText('逐节调整上课 / 下课时间'),
            const SizedBox(height: 10),
            WhiteCard(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              child: Column(
                children: [
                  for (var i = 0; i < _settings.periods.length; i++) ...[
                    if (i > 0)
                      Container(height: 0.5, color: CupertinoColors.separator),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '第 ${i + 1} 节',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        CupertinoButton(
                          key: Key('period-${i + 1}-start'),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 12,
                          ),
                          onPressed: _busy || _templateError != null
                              ? null
                              : () => _editPeriod(i, true),
                          child: Text(
                            clockText(_settings.periods[i].start),
                            style: const TextStyle(fontSize: 15),
                          ),
                        ),
                        const MutedText('—'),
                        CupertinoButton(
                          key: Key('period-${i + 1}-end'),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 12,
                          ),
                          onPressed: _busy || _templateError != null
                              ? null
                              : () => _editPeriod(i, false),
                          child: Text(
                            clockText(_settings.periods[i].end),
                            style: const TextStyle(fontSize: 15),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),
            const MutedText(
              '节次按实际时间排列，允许午休与不同长度的课程，但不能重叠或跨午夜。已有课程使用的节次不能直接删减，请先调整对应课程。',
            ),
          ],
        ),
      ),
    );
  }
}
