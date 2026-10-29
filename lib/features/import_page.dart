import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/app_controller.dart';
import '../data/calendar_file.dart';
import '../data/ics_importer.dart';
import '../data/timetable.dart';
import 'components.dart';

class ImportPage extends ConsumerStatefulWidget {
  const ImportPage({super.key});
  @override
  ConsumerState<ImportPage> createState() => _ImportPageState();
}

class _ImportPageState extends ConsumerState<ImportPage> {
  ImportReport? _report;
  String? _filename, _error, _result;
  bool _busy = false, _keepReminders = true;

  Future<void> _pick() async {
    setState(() {
      _busy = true;
      _error = null;
      _result = null;
    });
    try {
      final file = await ref.read(calendarFilePickerProvider)();
      if (file == null || !mounted) return;
      final report = IcsImporter().parse(file.contents);
      setState(() {
        _report = report;
        _filename = file.name;
      });
    } on FormatException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _report = null;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _error = '暂时无法读取文件，请先将它下载到手机后重试。');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _import() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final report = _report!;
      final count = await ref
          .read(appProvider.notifier)
          .importCalendar(report, keepReminders: _keepReminders);
      if (!mounted) return;
      setState(
        () => _result =
            '已导入 $count 组课程，跳过 ${report.courses.length - count} 组已有课程。',
      );
      setState(() => _busy = false);
      await showMessage(context, '$_result\n可以回到课表查看对应周的课程。');
    } catch (_) {
      if (mounted) setState(() => _error = '导入未完成，原有课程会保留，请重试。');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final report = _report;
    final names = report?.courses.map((c) => c.name).toSet().length ?? 0;
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(middle: Text('导入课表')),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 20),
            const Icon(
              CupertinoIcons.calendar_badge_plus,
              size: 58,
              color: CupertinoColors.activeBlue,
            ),
            const SizedBox(height: 22),
            const Text(
              '把课表带过来',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 27, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            const Text(
              '从 WakeUp 等应用导出 .ics 文件，\n选择后先预览，再确认导入。',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                height: 1.6,
                color: CupertinoColors.secondaryLabel,
              ),
            ),
            const SizedBox(height: 24),
            CupertinoButton.filled(
              key: const Key('pick-calendar'),
              onPressed: _busy ? null : _pick,
              child: Text(report == null ? '选择 .ics 文件' : '重新选择文件'),
            ),
            const SizedBox(height: 24),
            if (report != null) ...[
              WhiteCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _filename!,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '$names 门课程 · ${report.courses.length} 组时段 · ${report.occurrenceCount} 次上课',
                      style: const TextStyle(fontSize: 16, height: 1.6),
                    ),
                    if (report.firstDate != null)
                      MutedText(
                        '${dateText(report.firstDate!.toLocal())} — ${dateText(report.lastDate!.toLocal())}',
                      ),
                    const SizedBox(height: 12),
                    const MutedText(
                      '按文件的实际日期导入，保留教学周、教室变化和时区。不覆盖已有课程，相同内容再次导入会自动跳过。',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              WhiteCard(
                padding: const EdgeInsets.all(8),
                child: CupertinoListTile(
                  title: const Text('沿用文件中的提醒'),
                  subtitle: const Text('保留文件时间；是否启用可在“提醒设置”切换'),
                  trailing: CupertinoSwitch(
                    value: _keepReminders,
                    onChanged: _busy
                        ? null
                        : (value) => setState(() => _keepReminders = value),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ...report.courses
                  .take(5)
                  .map(
                    (c) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          const Icon(
                            CupertinoIcons.book,
                            color: CupertinoColors.activeBlue,
                            size: 18,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              c.name,
                              style: const TextStyle(fontSize: 15),
                            ),
                          ),
                          MutedText('${c.instances.length} 次'),
                        ],
                      ),
                    ),
                  ),
              if (report.courses.length > 5) const MutedText('以及其他课程…'),
              if (report.warnings.isNotEmpty) ...[
                const SizedBox(height: 20),
                WhiteCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${report.warnings.length} 组未导入，请核对',
                        style: const TextStyle(
                          color: CupertinoColors.systemOrange,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 10),
                      ...report.warnings.take(10).map((w) => MutedText(w)),
                      if (report.warnings.length > 10)
                        const MutedText('还有其他不支持的条目。'),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),
              CupertinoButton.filled(
                key: const Key('confirm-import'),
                onPressed: _busy || report.courses.isEmpty || _result != null
                    ? null
                    : _import,
                child: const Text('确认导入'),
              ),
            ],
            if (_busy)
              const Padding(
                padding: EdgeInsets.all(20),
                child: CupertinoActivityIndicator(),
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(
                  _error!,
                  style: const TextStyle(
                    color: CupertinoColors.destructiveRed,
                    height: 1.5,
                  ),
                ),
              ),
            if (_result != null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(_result!, style: const TextStyle(height: 1.5)),
              ),
            const SizedBox(height: 24),
            const MutedText(
              '支持有结束日期/次数的每日、每周规则及排除日期。全天、跨午夜、单次改期等不支持的条目会列出说明，不会静默改成每周重复。导入后可在“我的 → 提醒设置”开启系统提醒。',
            ),
          ],
        ),
      ),
    );
  }
}
