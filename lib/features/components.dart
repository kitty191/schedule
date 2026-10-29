import 'package:flutter/cupertino.dart';

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
