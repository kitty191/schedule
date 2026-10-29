import 'package:flutter/cupertino.dart';

/// Shares the sheet controller with its list: downward scrolling at the top
/// dismisses the panel, while scrolling within the list keeps the panel open.
Future<T?> showEditableSheet<T>(
  BuildContext context, {
  required ScrollableWidgetBuilder builder,
  double? topGap,
}) => Navigator.of(context, rootNavigator: true).push<T>(
  _EditableSheetRoute<T>(
    scrollableBuilder: builder,
    showDragHandle: true,
    topGap: MediaQuery.sizeOf(context).height < 450 ? 0.03 : topGap,
  ),
);

class _EditableSheetRoute<T> extends CupertinoSheetRoute<T> {
  _EditableSheetRoute({
    required super.scrollableBuilder,
    required super.showDragHandle,
    required super.topGap,
  });

  @override
  bool get barrierDismissible => true;

  @override
  Color get barrierColor => const Color(0x33000000);

  @override
  String get barrierLabel => '关闭面板';
}
