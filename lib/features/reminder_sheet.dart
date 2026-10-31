import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/app_controller.dart';
import '../data/timetable.dart';
import '../data/timetable_settings.dart';
import '../live_update_bridge.dart';
import 'components.dart';
import 'reminder_time_picker.dart';
import 'editable_sheet.dart';

Future<void> showReminderSheet(BuildContext context) => showEditableSheet<void>(
  context,
  topGap: 0.14,
  builder: (_, controller) => ReminderSheet(scrollController: controller),
);

class ReminderSheet extends ConsumerStatefulWidget {
  const ReminderSheet({super.key, this.scrollController});
  final ScrollController? scrollController;
  @override
  ConsumerState<ReminderSheet> createState() => _ReminderSheetState();
}

class _ReminderSheetState extends ConsumerState<ReminderSheet>
    with WidgetsBindingObserver {
  LiveUpdateStatus? _status;
  bool _busy = false;
  String? _message;
  bool get _android => defaultTargetPlatform == TargetPlatform.android;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _run(() async {
        await ref.read(appProvider.notifier).retrySync();
      });
    }
  }

  Future<void> _refresh() async {
    try {
      final status = await ref.read(bridgeProvider).status();
      if (mounted) setState(() => _status = status);
    } on PlatformException catch (e) {
      if (mounted) setState(() => _message = e.message);
    } on MissingPluginException {
      if (mounted) setState(() => _message = '当前平台尚未接入系统提醒。');
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await action();
      await _refresh();
    } on PlatformException catch (e) {
      if (mounted) setState(() => _message = e.message ?? '操作未完成，请重试。');
    } catch (_) {
      if (mounted) setState(() => _message = '操作未完成，请重试。');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(appProvider).asData?.value;
    final preferences = data?.preferences;
    return CupertinoPageScaffold(
      key: const Key('reminder-sheet'),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 12, 8),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      '课程提醒',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  CupertinoButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('完成'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                controller: widget.scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  WhiteCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        CupertinoListTile(
                          title: const Text('课程与日程提醒'),
                          trailing: CupertinoSwitch(
                            key: const Key('reminders-enabled'),
                            value: preferences?.reminders ?? false,
                            onChanged: _busy || preferences == null
                                ? null
                                : (enabled) => _run(() async {
                                    if (enabled) {
                                      final status = await ref
                                          .read(bridgeProvider)
                                          .requestPermission();
                                      if (!status.notificationsEnabled) {
                                        throw PlatformException(
                                          code: 'permission_denied',
                                          message: '请在系统设置中允许通知后重试。',
                                        );
                                      }
                                    }
                                    await ref
                                        .read(appProvider.notifier)
                                        .updatePreferences(
                                          preferences.copyWith(
                                            reminders: enabled,
                                          ),
                                        );
                                  }),
                          ),
                        ),
                        CupertinoListTile(
                          title: const Text('上课前提醒'),
                          trailing: CupertinoButton(
                            key: const Key('pre-reminder-time'),
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            onPressed: _busy || preferences == null
                                ? null
                                : () async {
                                    final minutes = await pickReminderMinutes(
                                      context,
                                      title: '上课前多久提醒',
                                      current: preferences.leadMinutes,
                                    );
                                    if (minutes != null && mounted) {
                                      await _run(
                                        () => ref
                                            .read(appProvider.notifier)
                                            .updatePreferences(
                                              preferences.copyWith(
                                                leadMinutes: minutes,
                                                useFileReminders: false,
                                              ),
                                            ),
                                      );
                                    }
                                  },
                            child: Text('${preferences?.leadMinutes ?? 10} 分钟'),
                          ),
                        ),
                        if (_android)
                          CupertinoListTile(
                            title: const Text('下课前提醒'),
                            trailing: CupertinoButton(
                              key: const Key('end-reminder-time'),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                              onPressed: _busy || preferences == null
                                  ? null
                                  : () async {
                                      final minutes = await pickReminderMinutes(
                                        context,
                                        title: '下课前多久提醒',
                                        current: preferences.endingLeadMinutes,
                                      );
                                      if (minutes != null && mounted) {
                                        await _run(
                                          () => ref
                                              .read(appProvider.notifier)
                                              .updatePreferences(
                                                preferences.copyWith(
                                                  endingLeadMinutes: minutes,
                                                ),
                                              ),
                                        );
                                      }
                                    },
                              child: Text(
                                '${preferences?.endingLeadMinutes ?? 10} 分钟',
                              ),
                            ),
                          ),
                        CupertinoListTile(
                          title: const Text('沿用文件课前提醒'),
                          trailing: CupertinoSwitch(
                            key: const Key('use-file-reminders'),
                            value: preferences?.useFileReminders ?? true,
                            onChanged: _busy || preferences == null
                                ? null
                                : (enabled) => _run(
                                    () => ref
                                        .read(appProvider.notifier)
                                        .updatePreferences(
                                          preferences.copyWith(
                                            useFileReminders: enabled,
                                          ),
                                        ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 12, 8, 24),
                    child: MutedText(
                      _android
                          ? '课前或课中提醒可收起，下课前 ${preferences?.endingLeadMinutes ?? 10} 分钟仍会单独提示一次，默认无声音和振动。请允许“下课前提示”通知、横幅和准时提醒。结束下课提示后，本次不再重复，下课后自动撤下。新到期的下课提示优先展示，其他时间显示最早开始的一项。沿用文件提醒时文件课前时间优先，修改上课前时间会统一使用新设置。下课提前量超过课程长度时从上课开始提示。日程仅使用开始前提醒。'
                          : 'iOS 使用普通课前通知。开启“沿用文件课前提醒”时，文件时间优先；修改上课前时间会自动关闭此项并统一使用新时间。',
                    ),
                  ),
                  if (_status != null)
                    WhiteCard(
                      child: Column(
                        children: [
                          _row(
                            '通知权限',
                            _status!.notificationsEnabled ? '已允许' : '未允许',
                          ),
                          if (_android) ...[
                            _row(
                              '顶部实时提醒',
                              !_status!.supported
                                  ? '当前系统使用普通通知'
                                  : _status!.promotionAllowed
                                  ? '已允许'
                                  : '未允许',
                            ),
                            _row(
                              '准时提醒权限',
                              _status!.exactAllowed ? '已允许' : '未允许，提示可能延后',
                            ),
                            _row(
                              '下课提示通知',
                              !_status!.endingNotificationsEnabled
                                  ? '未允许，请打开系统通知设置'
                                  : _status!.endingBannerEnabled
                                  ? '已允许'
                                  : '已开启，请允许横幅提示',
                            ),
                            _row(
                              '下次下课提示',
                              _status!.nextEndingAt == null
                                  ? '暂无待触发提示'
                                  : _reminderTime(_status!.nextEndingAt!),
                            ),
                            if (_status!.lastEndingAt != null)
                              _row(
                                '最近下课提示',
                                '${_reminderTime(_status!.lastEndingAt!)}\n${_status!.lastEndingCourse ?? ''}\n${_status!.lastEndingPosted == true ? '已提交系统' : '未发送，请检查通知权限'}',
                              ),
                          ],
                          _row('当前提醒', _status!.active ? '正在显示' : '未显示'),
                        ],
                      ),
                    ),
                  const SizedBox(height: 12),
                  CupertinoButton(
                    onPressed: _busy
                        ? null
                        : () => _run(
                            () => ref.read(bridgeProvider).openSettings(),
                          ),
                    child: const Text('打开系统通知设置'),
                  ),
                  if (_android)
                    CupertinoButton(
                      onPressed: _busy
                          ? null
                          : () => _run(
                              () =>
                                  ref.read(bridgeProvider).openExactSettings(),
                            ),
                      child: const Text('允许准时提醒'),
                    ),
                  if (_android) ...[
                    WhiteCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '后台提醒',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 8),
                          const MutedText(
                            '保存课表时会提前安排多次系统提醒，无需一直打开应用。OPPO / ColorOS 请在应用信息的耗电或电池管理中允许后台活动、自启动（若提供），并在最近任务中锁定本应用，避免被一键清理。菜单名称可能因系统版本而异。',
                          ),
                          if (_status != null) ...[
                            _row(
                              '系统后台限制',
                              _status!.backgroundRestricted
                                  ? '受限制，请允许后台运行'
                                  : '未报告限制',
                            ),
                            _row(
                              '电池优化',
                              _status!.batteryOptimizationIgnored
                                  ? '已豁免'
                                  : '未豁免，可能影响后台提醒',
                            ),
                            _row(
                              '已登记提醒时点',
                              '${_status!.scheduledBoundaryCount} 个',
                            ),
                            if (_status!.nextBackgroundAt != null)
                              _row(
                                '下次后台唤醒',
                                _reminderTime(_status!.nextBackgroundAt!),
                              ),
                            _row(
                              '最近后台触发',
                              _status!.lastBackgroundWakeAt == null
                                  ? '尚未收到系统闹钟回调'
                                  : '${_reminderTime(_status!.lastBackgroundWakeAt!)}'
                                        '\n计划 ${_status!.lastBackgroundScheduledAt == null ? '未知' : _reminderTime(_status!.lastBackgroundScheduledAt!)}',
                            ),
                          ],
                          const SizedBox(height: 8),
                          const MutedText(
                            '这些状态无法读取 ColorOS 的全部清理策略；已登记不代表系统一定会放行。若只有打开 App 才出现提醒，请查看“最近后台触发”是否仍停留在之前的时间。强行停止后，系统会撤销闹钟和通知，需重新打开应用才能恢复。',
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            '离开 App 后自动测试',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 8),
                          const MutedText(
                            '点下面按钮后直接回桌面，不要打开 App 或点击预览。第 1 分钟应出现“后台自动提醒测试”，第 2 分钟切换计时，第 3 分钟提示快下课，第 4 分钟撤下。测试不保存到课表，真实课程优先。测试后再回来查看结果。',
                          ),
                          if (_status?.probeDueAt != null) ...[
                            _row('测试计划', _reminderTime(_status!.probeDueAt!)),
                            _row('测试结果', _probeResult(_status!)),
                            if (_status!.probeLastWakeAt != null)
                              _row(
                                '测试实际回调',
                                '${_reminderTime(_status!.probeLastWakeAt!)}\n计划 ${_reminderTime(_status!.probeLastScheduledAt!)}\n共 ${_status!.probeCallbackCount} 个时点',
                              ),
                          ],
                          CupertinoButton(
                            key: const Key('background-test'),
                            onPressed: _busy
                                ? null
                                : () => _run(() async {
                                    final status = await ref
                                        .read(bridgeProvider)
                                        .scheduleBackgroundTest();
                                    if (mounted) {
                                      setState(() {
                                        _status = status;
                                        _message =
                                            '已安排，请回到桌面等待 1 分钟，期间不要重新打开应用。';
                                      });
                                    }
                                  }),
                            child: const Text('1 分钟后自动测试'),
                          ),
                          if (_status?.probeUntil != null &&
                              !_status!.probeCancelled &&
                              _status!.probeUntil! >
                                  DateTime.now().millisecondsSinceEpoch)
                            CupertinoButton(
                              key: const Key('cancel-background-test'),
                              onPressed: _busy
                                  ? null
                                  : () => _run(() async {
                                      await ref
                                          .read(bridgeProvider)
                                          .cancelBackgroundTest();
                                    }),
                              child: const Text('取消后台测试'),
                            ),
                          CupertinoButton(
                            key: const Key('background-settings'),
                            onPressed: _busy
                                ? null
                                : () => _run(
                                    () => ref
                                        .read(bridgeProvider)
                                        .openBackgroundSettings(),
                                  ),
                            child: const Text('打开后台运行设置'),
                          ),
                          CupertinoButton(
                            key: const Key('battery-settings'),
                            onPressed: _busy
                                ? null
                                : () => _run(
                                    () => ref
                                        .read(bridgeProvider)
                                        .openBatterySettings(),
                                  ),
                            child: const Text('打开电池优化设置'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  const Padding(
                    padding: EdgeInsets.fromLTRB(8, 0, 8, 20),
                    child: MutedText(
                      'Android 可在系统支持时显示顶部实时提醒；省电策略可能延后后台更新。iOS 使用普通通知，安排最近 60 次提醒，请定期打开应用续排。强制停止 App 后请重新打开，以恢复调度。',
                    ),
                  ),
                  WhiteCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '预览课程提醒',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        MutedText(
                          _android
                              ? '使用已有课程的名称和教室，模拟即将上课或下课。预览中的时刻仅用于测试，最多显示 5 分钟。返回桌面并展开顶部提醒查看；卡片样式由手机系统决定。'
                              : '用今天下一节或已有课程发送一条普通通知预览。',
                        ),
                        CupertinoButton(
                          key: const Key('preview-reminder'),
                          padding: const EdgeInsets.only(top: 16),
                          onPressed:
                              _busy || data == null || data.courses.isEmpty
                              ? null
                              : () => _run(() async {
                                  final course =
                                      upcomingToday(
                                        data.courses,
                                        DateTime.now(),
                                      ) ??
                                      data.courses.first;
                                  final status = await ref
                                      .read(bridgeProvider)
                                      .preview(
                                        coursePayload(
                                          course,
                                          includeFileReminder:
                                              data.preferences.useFileReminders,
                                          timetable: TimetableSettings.decode(
                                            data.preferences.timetableConfig,
                                          ),
                                        ),
                                      );
                                  if (mounted) {
                                    setState(() {
                                      _message = status.active
                                          ? '提醒已发送，请返回桌面查看。'
                                          : '系统未显示提醒，请检查通知设置。';
                                    });
                                  }
                                }),
                          child: const Text('发送课程预览'),
                        ),
                        if (_android)
                          CupertinoButton(
                            key: const Key('preview-ending'),
                            padding: const EdgeInsets.only(top: 8),
                            onPressed:
                                _busy ||
                                    data == null ||
                                    !data.courses.any((c) => !isEvent(c))
                                ? null
                                : () => _run(() async {
                                    final course =
                                        upcomingToday(
                                          data.courses
                                              .where((c) => !isEvent(c))
                                              .toList(),
                                          DateTime.now(),
                                        ) ??
                                        data.courses.firstWhere(
                                          (c) => !isEvent(c),
                                        );
                                    final status = await ref
                                        .read(bridgeProvider)
                                        .previewEnding(
                                          coursePayload(
                                            course,
                                            includeFileReminder: data
                                                .preferences
                                                .useFileReminders,
                                            timetable: TimetableSettings.decode(
                                              data.preferences.timetableConfig,
                                            ),
                                          ),
                                        );
                                    if (mounted) {
                                      setState(
                                        () => _message = status.active
                                            ? '下课提醒预览已发送，请回到桌面查看流体云。'
                                            : '系统未显示提醒，请检查通知设置。',
                                      );
                                    }
                                  }),
                            child: Text(
                              '预览下课前 ${preferences?.endingLeadMinutes ?? 10} 分钟提醒',
                            ),
                          ),
                        CupertinoButton(
                          padding: const EdgeInsets.only(top: 8),
                          onPressed: _busy || _status?.active != true
                              ? null
                              : () => _run(() async {
                                  await ref.read(bridgeProvider).stop();
                                  if (mounted) {
                                    setState(
                                      () => _message = '当前提醒已结束，后续提醒仍按设置触发。',
                                    );
                                  }
                                }),
                          child: const Text('结束当前提醒'),
                        ),
                      ],
                    ),
                  ),
                  if (_busy)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: CupertinoActivityIndicator(),
                    ),
                  if (_message != null)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        _message!,
                        style: const TextStyle(fontSize: 14, height: 1.5),
                      ),
                    ),
                  if (data?.syncError != null)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: MutedText(data!.syncError!),
                    ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      children: [
        Expanded(child: Text(label, style: const TextStyle(fontSize: 14))),
        const SizedBox(width: 16),
        Flexible(child: MutedText(value)),
      ],
    ),
  );

  String _reminderTime(int millis) {
    final time = DateTime.fromMillisecondsSinceEpoch(millis);
    return '${time.month}/${time.day} ${clockText(time.hour * 60 + time.minute)}';
  }

  String _probeResult(LiveUpdateStatus status) {
    if (status.probeCancelled) return '已取消';
    if (status.probeCallbackCount == 0) {
      return DateTime.now().millisecondsSinceEpoch > status.probeDueAt! + 30000
          ? '未收到后台回调，请检查后台运行限制'
          : '等待系统闹钟，请离开 App';
    }
    if (status.probePosted == null) return '已收到回调，尚未提交测试通知';
    return status.probePosted! ? '已收到回调并提交通知，请核对桌面流体云' : '已收到回调，通知提交失败，请检查通知权限';
  }
}
