import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

Future<int?> pickReminderMinutes(
  BuildContext context, {
  required String title,
  required int current,
}) async {
  final selected = await showCupertinoModalPopup<int>(
    context: context,
    builder: (context) => CupertinoActionSheet(
      title: Text(title),
      actions: [
        for (final minutes in [5, 10, 15, 20, 30, 60])
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(context, minutes),
            child: Text('$minutes 分钟'),
          ),
        CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context, -1),
          child: const Text('自定义分钟'),
        ),
      ],
      cancelButton: CupertinoActionSheetAction(
        onPressed: () => Navigator.pop(context),
        child: const Text('取消'),
      ),
    ),
  );
  if (selected != -1 || !context.mounted) return selected;
  return showCupertinoDialog<int>(
    context: context,
    builder: (_) => _CustomMinutesDialog(title: title, current: current),
  );
}

class _CustomMinutesDialog extends StatefulWidget {
  const _CustomMinutesDialog({required this.title, required this.current});
  final String title;
  final int current;

  @override
  State<_CustomMinutesDialog> createState() => _CustomMinutesDialogState();
}

class _CustomMinutesDialogState extends State<_CustomMinutesDialog> {
  late final _controller = TextEditingController(text: '${widget.current}');
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    final value = int.tryParse(_controller.text);
    if (value == null || value < 1 || value > 1440) {
      setState(() => _error = '请输入 1–1440 之间的整数');
      return;
    }
    Navigator.pop(context, value);
  }

  @override
  Widget build(BuildContext context) => CupertinoAlertDialog(
    title: Text(widget.title),
    content: Column(
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Text('提前 1–1440 分钟提醒'),
        ),
        CupertinoTextField(
          key: const Key('custom-reminder-minutes'),
          controller: _controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          maxLength: 4,
          suffix: const Padding(
            padding: EdgeInsets.only(right: 8),
            child: Text('分钟'),
          ),
          onSubmitted: (_) => _save(),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              _error!,
              style: const TextStyle(color: CupertinoColors.systemRed),
            ),
          ),
      ],
    ),
    actions: [
      CupertinoDialogAction(
        onPressed: () => Navigator.pop(context),
        child: const Text('取消'),
      ),
      CupertinoDialogAction(
        key: const Key('save-custom-reminder'),
        onPressed: _save,
        child: const Text('确定'),
      ),
    ],
  );
}
