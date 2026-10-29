import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'ics_importer.dart';

class CalendarFile {
  const CalendarFile(this.name, this.contents);
  final String name, contents;
}

final calendarFilePickerProvider = Provider<Future<CalendarFile?> Function()>(
  (ref) => () async {
    final file = await FilePicker.pickFile(type: FileType.any);
    if (file == null) return null;
    if (!file.name.toLowerCase().endsWith('.ics')) {
      throw const FormatException('请选择 .ics 格式的课表文件。');
    }
    if ((await file.length() ?? 0) > IcsImporter.maxBytes) {
      throw const FormatException('文件超过 2 MB，请拆分后导入。');
    }
    final bytes = await file.readAsBytes();
    if (bytes.length > IcsImporter.maxBytes) {
      throw const FormatException('文件超过 2 MB，请拆分后导入。');
    }
    try {
      return CalendarFile(file.name, utf8.decode(bytes));
    } on FormatException {
      throw const FormatException('文件不是 UTF-8 编码，请重新导出 .ics 文件。');
    }
  },
);
