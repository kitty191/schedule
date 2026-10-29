import 'package:flutter/cupertino.dart';

bool compactLandscape(BuildContext context) {
  final size = MediaQuery.sizeOf(context);
  return size.height < 450 && size.width >= 520;
}

const courseColors = [
  Color(0xFF007AFF),
  Color(0xFFFF9500),
  Color(0xFFAF52DE),
  Color(0xFF30A46C),
  Color(0xFFFF5A78),
];

Future<void> showMessage(BuildContext context, String message) =>
    showCupertinoDialog<void>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('提示'),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('好'),
          ),
        ],
      ),
    );

class WhiteCard extends StatelessWidget {
  const WhiteCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
  });
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: CupertinoColors.white,
      borderRadius: BorderRadius.circular(22),
    ),
    child: child,
  );
}

class MutedText extends StatelessWidget {
  const MutedText(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      fontSize: 13,
      height: 1.5,
      color: CupertinoColors.secondaryLabel,
    ),
  );
}

Future<int?> pickClock(BuildContext context, String title, int initial) async {
  var selected = initial;
  return showCupertinoModalPopup<int>(
    context: context,
    builder: (context) => Container(
      height: 300 + MediaQuery.paddingOf(context).bottom,
      color: CupertinoColors.systemBackground,
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
                Expanded(
                  child: Text(
                    title,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    style: const TextStyle(fontSize: 15),
                  ),
                ),
                CupertinoButton(
                  onPressed: () => Navigator.pop(context, selected),
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
                  initial ~/ 60,
                  initial % 60,
                ),
                onDateTimeChanged: (date) =>
                    selected = date.hour * 60 + date.minute,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

Future<int?> pickNumber(
  BuildContext context,
  String title,
  int initial,
  int min,
  int max, {
  String unit = '',
}) async {
  var selected = initial.clamp(min, max);
  final controller = FixedExtentScrollController(initialItem: selected - min);
  try {
    return await showCupertinoModalPopup<int>(
      context: context,
      builder: (context) => Container(
        height: 300 + MediaQuery.paddingOf(context).bottom,
        color: CupertinoColors.systemBackground,
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
                  Expanded(
                    child: Text(
                      title,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      style: const TextStyle(fontSize: 15),
                    ),
                  ),
                  CupertinoButton(
                    onPressed: () => Navigator.pop(context, selected),
                    child: const Text('完成'),
                  ),
                ],
              ),
              Expanded(
                child: CupertinoPicker(
                  scrollController: controller,
                  itemExtent: 40,
                  onSelectedItemChanged: (index) => selected = min + index,
                  children: [
                    for (var v = min; v <= max; v++)
                      Center(child: Text('$v$unit')),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  } finally {
    controller.dispose();
  }
}
