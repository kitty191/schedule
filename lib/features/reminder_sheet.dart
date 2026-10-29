import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/app_controller.dart';
import '../data/timetable.dart';
import '../live_update_bridge.dart';
import 'components.dart';
import 'reminder_time_picker.dart';

Future<void> showReminderSheet(BuildContext context) =>
    showCupertinoModalPopup<void>(
      context: context,
      builder: (_) => const ReminderSheet(),
    );

class ReminderSheet extends ConsumerStatefulWidget {
  const ReminderSheet({super.key});
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
    return Container(
      height: MediaQuery.sizeOf(context).height * 0.86,
      decoration: const BoxDecoration(
        color: Color(0xFFF5F6FA),
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 36,
              height: 5,
              decoration: BoxDecoration(
                color: CupertinoColors.systemGrey3,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
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
                          ? '课前显示下一节课，上课后切换状态，下课前 ${preferences?.endingLeadMinutes ?? 10} 分钟以流体云显示“快下课”和倒计时，下课后自动结束。日程显示开始/结束状态。开启“沿用文件课前提醒”时，文件时间优先；修改上课前时间会自动关闭此项并统一使用新时间。提醒时长超过课程长度时，从上课开始显示下课提示。重叠时优先显示最早开始且尚未结束的一项。'
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
                              _status!.exactAllowed ? '已允许' : '系统可能延后提醒',
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
                        const MutedText(
                          '用今天下一节或已有课程发送一条预览。Android 预览最多持续 5 分钟，下课倒计时归零后结束，可返回桌面查看。',
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
                                      .preview(coursePayload(course));
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
                                        .previewEnding(coursePayload(course));
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
                                      () => _message = '当前提醒已结束。后续安排仍会继续提醒。',
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
}
