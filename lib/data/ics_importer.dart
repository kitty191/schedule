import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart' show Value;
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'database.dart';
import 'timetable.dart';

class ImportedCourse {
  const ImportedCourse({
    required this.name,
    required this.location,
    required this.description,
    required this.instances,
    required this.key,
    this.reminderMinutes,
  });
  final String name, location, description, key;
  final List<CourseInstance> instances;
  final int? reminderMinutes;

  CoursesCompanion companion(int color, {bool keepReminders = true}) {
    final start = instances.first.start.toLocal();
    final end = instances.first.end.toLocal();
    return CoursesCompanion(
      name: Value(name),
      location: Value(location),
      description: Value(description),
      weekday: Value(start.weekday),
      startMinute: Value(start.hour * 60 + start.minute),
      endMinute: Value(end.hour * 60 + end.minute),
      colorIndex: Value(color),
      occurrences: Value(jsonEncode(instances.map((i) => i.toMap()).toList())),
      importKey: Value(key),
      reminderMinutes: Value(keepReminders ? reminderMinutes : null),
      kind: const Value('course'),
    );
  }
}

class ImportReport {
  const ImportReport(this.courses, this.warnings, this.totalEvents);
  final List<ImportedCourse> courses;
  final List<String> warnings;
  final int totalEvents;
  int get occurrenceCount =>
      courses.fold(0, (sum, c) => sum + c.instances.length);
  DateTime? get firstDate => courses.isEmpty
      ? null
      : courses
            .map((c) => c.instances.first.start)
            .reduce((a, b) => a.isBefore(b) ? a : b);
  DateTime? get lastDate => courses.isEmpty
      ? null
      : courses
            .map((c) => c.instances.last.end)
            .reduce((a, b) => a.isAfter(b) ? a : b);
}

class _Property {
  _Property(this.name, this.params, this.value);
  final String name, value;
  final Map<String, String> params;
}

class _CalendarTime {
  _CalendarTime(this.date, this.zone);
  final DateTime date;
  final tz.Location? zone;
  DateTime day(int offset) => zone == null
      ? DateTime(
          date.year,
          date.month,
          date.day + offset,
          date.hour,
          date.minute,
          date.second,
        )
      : tz.TZDateTime(
          zone!,
          date.year,
          date.month,
          date.day + offset,
          date.hour,
          date.minute,
          date.second,
        );
}

class IcsImporter {
  static bool _initialized = false;
  static const maxBytes = 2 * 1024 * 1024;
  static const maxOccurrences = 5000;

  ImportReport parse(String source) {
    if (utf8.encode(source).length > maxBytes) {
      throw const FormatException('文件超过 2 MB，请拆分后导入。');
    }
    if (!_initialized) {
      tzdata.initializeTimeZones();
      _initialized = true;
    }
    final unfolded = source
        .replaceFirst('\uFEFF', '')
        .replaceAll(RegExp(r'\r?\n[ \t]'), '');
    final lines = const LineSplitter().convert(unfolded);
    if (!lines.any((l) => l.trim().toUpperCase() == 'BEGIN:VCALENDAR') ||
        !lines.any((l) => l.trim().toUpperCase() == 'END:VCALENDAR')) {
      throw const FormatException('这不是完整的 iCalendar (.ics) 文件。');
    }
    final events = <List<_Property>>[];
    List<_Property>? current;
    var depth = 0;
    for (final line in lines) {
      final value = line.trim().toUpperCase();
      if (value == 'BEGIN:VEVENT') {
        if (current != null) throw const FormatException('课程文件结构不完整。');
        current = [];
        depth = 0;
      } else if (value == 'END:VEVENT') {
        if (current != null) events.add(current);
        current = null;
      } else if (current != null) {
        if (value.startsWith('BEGIN:')) depth++;
        if (value.startsWith('END:')) depth--;
        // Only retain START-related alarms, never let VALARM DESCRIPTION replace VEVENT DESCRIPTION.
        if (depth == 0 || (depth == 1 && value.startsWith('TRIGGER'))) {
          current.add(_property(line));
        }
      }
    }
    if (current != null) throw const FormatException('课程文件缺少 END:VEVENT。');
    if (events.isEmpty) throw const FormatException('文件中没有可导入的课程。');
    if (events.length > 500) throw const FormatException('单次最多导入 500 组课程。');
    final overridden = events
        .where((e) => e.any((p) => p.name == 'RECURRENCE-ID'))
        .map((e) => e.where((p) => p.name == 'UID').firstOrNull?.value)
        .toSet();
    final courses = <ImportedCourse>[];
    final warnings = <String>[];
    var occurrences = 0;
    for (var index = 0; index < events.length; index++) {
      final e = events[index];
      String? get(String name) =>
          e.where((p) => p.name == name).firstOrNull?.value;
      try {
        if (get('STATUS')?.toUpperCase() == 'CANCELLED') continue;
        if (get('RECURRENCE-ID') != null) {
          throw const FormatException('包含单次修改规则，暂不支持此组课程');
        }
        if (overridden.contains(get('UID')) && get('UID') != null) {
          throw const FormatException('包含单次修改规则，暂不支持此组课程');
        }
        final parsed = _event(e);
        final groups = _splitSameDay(parsed);
        if (courses.length + groups.length > 500) {
          throw const FormatException('导入时段超过 500 组，请拆分后导入。');
        }
        occurrences += parsed.instances.length;
        if (occurrences > maxOccurrences) {
          throw const FormatException('文件上课次数超过 5000，请拆分后导入。');
        }
        courses.addAll(groups);
      } on FormatException catch (error) {
        warnings.add('第${index + 1}组：${error.message}');
      }
    }
    return ImportReport(courses, warnings, events.length);
  }

  // One row represents one meeting per date. RDATE may add a second meeting
  // that day: split by clock time so both meetings appear and remain editable.
  List<ImportedCourse> _splitSameDay(ImportedCourse course) {
    final dates = course.instances
        .map((i) => dayKey(i.start.toLocal()))
        .toSet();
    if (dates.length == course.instances.length) return [course];
    final groups = <String, List<CourseInstance>>{};
    for (final instance in course.instances) {
      final start = instance.start.toLocal(), end = instance.end.toLocal();
      final key =
          '${start.hour}:${start.minute}:${start.second}-${end.hour}:${end.minute}:${end.second}';
      (groups[key] ??= []).add(instance);
    }
    return groups.values
        .map(
          (instances) => ImportedCourse(
            name: course.name,
            location: course.location,
            description: course.description,
            reminderMinutes: course.reminderMinutes,
            instances: instances,
            key: sha256
                .convert(
                  utf8.encode(
                    jsonEncode([
                      course.name,
                      course.location,
                      instances.map((i) => i.toMap()).toList(),
                    ]),
                  ),
                )
                .toString(),
          ),
        )
        .toList();
  }

  _Property _property(String line) {
    final colon = line.indexOf(':');
    if (colon < 0) return _Property('', {}, '');
    final parts = line.substring(0, colon).split(';');
    final params = <String, String>{};
    for (final part in parts.skip(1)) {
      final equals = part.indexOf('=');
      if (equals > 0) {
        params[part.substring(0, equals).toUpperCase()] = part
            .substring(equals + 1)
            .replaceAll('"', '');
      }
    }
    return _Property(
      parts.first.toUpperCase(),
      params,
      line.substring(colon + 1),
    );
  }

  String _unescape(String value) => value.replaceAllMapped(
    RegExp(r'\\([nN,;\\])'),
    (m) => m[1]!.toLowerCase() == 'n' ? '\n' : m[1]!,
  );

  _CalendarTime _time(_Property property) {
    final raw = property.value;
    final match = RegExp(r'^(\d{4})(\d{2})(\d{2})T(\d{2})(\d{2})(\d{2})?(Z)?$')
        .firstMatch(raw);
    if (match == null) throw const FormatException('仅支持带具体时间的课程，全天或日期格式暂不支持');
    final v = List.generate(6, (i) => int.parse(match[i + 1] ?? '0'));
    tz.Location? zone;
    if (match[7] != null) {
      zone = tz.UTC;
    } else if (property.params['TZID'] case final id?) {
      try {
        zone = tz.getLocation(
          id == 'China Standard Time' ? 'Asia/Shanghai' : id,
        );
      } catch (_) {
        throw FormatException('无法识别时区 $id');
      }
    }
    final date = zone == null
        ? DateTime(v[0], v[1], v[2], v[3], v[4], v[5])
        : tz.TZDateTime(zone, v[0], v[1], v[2], v[3], v[4], v[5]);
    if (date.year != v[0] ||
        date.month != v[1] ||
        date.day != v[2] ||
        date.hour != v[3] ||
        date.minute != v[4] ||
        date.second != v[5]) {
      throw const FormatException('课程日期或时间无效');
    }
    return _CalendarTime(date, zone);
  }

  ImportedCourse _event(List<_Property> properties) {
    _Property? get(String name) =>
        properties.where((p) => p.name == name).firstOrNull;
    final name = _unescape(get('SUMMARY')?.value ?? '').trim();
    final location = _unescape(get('LOCATION')?.value ?? '').trim();
    if (name.isEmpty || name.length > 60 || location.length > 100) {
      throw const FormatException('课程名称为空或名称/地点过长');
    }
    if (get('DTSTART') == null || get('DTEND') == null) {
      throw const FormatException('缺少上课或下课时间');
    }
    final start = _time(get('DTSTART')!);
    final end = _time(get('DTEND')!);
    final duration = end.date.difference(start.date);
    if (duration <= Duration.zero || duration > const Duration(hours: 23)) {
      throw const FormatException('课程时长无效');
    }
    final starts = <int, DateTime>{
      start.date.millisecondsSinceEpoch: start.date,
    };
    if (get('RRULE') case final rule?) {
      final values = <String, String>{};
      for (final part in rule.value.toUpperCase().split(';')) {
        final pair = part.split('=');
        if (pair.length != 2 || values.containsKey(pair[0])) {
          throw const FormatException('重复规则无效');
        }
        values[pair[0]] = pair[1];
      }
      if (values.keys.any(
            (key) => ![
              'FREQ',
              'INTERVAL',
              'UNTIL',
              'COUNT',
              'BYDAY',
              'WKST',
            ].contains(key),
          ) ||
          !['WEEKLY', 'DAILY'].contains(values['FREQ'])) {
        throw const FormatException('暂不支持该重复规则');
      }
      if (values['COUNT'] != null && values['UNTIL'] != null) {
        throw const FormatException('重复规则不能同时包含 COUNT 和 UNTIL');
      }
      final interval = int.tryParse(values['INTERVAL'] ?? '1') ?? 0;
      final count = values['COUNT'] == null
          ? null
          : int.tryParse(values['COUNT']!);
      if (interval < 1 ||
          interval > 366 ||
          (values['COUNT'] != null &&
              (count == null || count < 1 || count > 5000))) {
        throw const FormatException('重复次数或间隔无效');
      }
      if (count == null && values['UNTIL'] == null) {
        throw const FormatException('重复课程需要结束日期或次数');
      }
      DateTime? until;
      if (values['UNTIL'] case final raw?) {
        final full = raw.length == 8 ? '${raw}T235959' : raw;
        until = _time(
          _Property(
            'UNTIL',
            full.endsWith('Z') ? {} : get('DTSTART')!.params,
            full,
          ),
        ).date;
        if (until.isBefore(start.date)) {
          throw const FormatException('结束日期早于首次上课日期');
        }
      }
      final byDays =
          values['BYDAY']?.split(',') ??
          [
            const [
              'MO',
              'TU',
              'WE',
              'TH',
              'FR',
              'SA',
              'SU',
            ][start.date.weekday - 1],
          ];
      const days = ['MO', 'TU', 'WE', 'TH', 'FR', 'SA', 'SU'];
      if (byDays.any((d) => !days.contains(d))) {
        throw const FormatException('暂不支持此类 BYDAY 规则');
      }
      final wkst = values['WKST'] ?? 'MO';
      if (!days.contains(wkst)) throw const FormatException('周起始日期无效');
      final anchorOffset =
          (start.date.weekday - (days.indexOf(wkst) + 1) + 7) % 7;
      var total = 1;
      var finished = count == 1;
      for (var offset = 1; offset <= 366 * 5 && !finished; offset++) {
        final candidate = start.day(offset);
        if (until != null && candidate.isAfter(until)) {
          finished = true;
          break;
        }
        final eligible = values['FREQ'] == 'DAILY'
            ? offset % interval == 0 &&
                  (values['BYDAY'] == null ||
                      byDays.contains(days[candidate.weekday - 1]))
            : ((offset + anchorOffset) ~/ 7) % interval == 0 &&
                  byDays.contains(days[candidate.weekday - 1]);
        if (!eligible) continue;
        starts[candidate.millisecondsSinceEpoch] = candidate;
        total++;
        if (total > 5000) throw const FormatException('课程重复次数过多');
        if (count != null && total >= count) finished = true;
      }
      if (!finished) throw const FormatException('课程重复范围超过 5 年，请拆分后导入');
    }
    for (final property in properties.where(
      (p) => p.name == 'RDATE' || p.name == 'EXDATE',
    )) {
      for (final raw in property.value.split(',')) {
        final time = _time(_Property(property.name, property.params, raw)).date;
        if (property.name == 'RDATE') {
          starts[time.millisecondsSinceEpoch] = time;
        } else {
          starts.remove(time.millisecondsSinceEpoch);
        }
      }
    }
    if (starts.isEmpty) throw const FormatException('没有剩余的上课日期');
    final ordered = starts.values.toList()..sort();
    final instances = ordered.map((time) {
      final finish = time.add(duration);
      if (!sameDay(time.toLocal(), finish.toLocal())) {
        throw const FormatException('跨午夜课程暂不支持，请拆分后导入');
      }
      final a = time.toLocal(), b = finish.toLocal();
      if (a.hour * 60 + a.minute >= b.hour * 60 + b.minute) {
        throw const FormatException('起止时间在同一分钟内，无法按分钟显示，请调整后导入');
      }
      return CourseInstance(time.toUtc(), finish.toUtc());
    }).toList();
    final signature = jsonEncode([
      name,
      location,
      instances.map((i) => i.toMap()).toList(),
    ]);
    final alarm = properties
        .where(
          (p) =>
              p.name == 'TRIGGER' &&
              (p.params['RELATED'] ?? 'START') == 'START',
        )
        .firstOrNull;
    final alarmMatch = alarm == null
        ? null
        : RegExp(r'^-PT(?:(\d+)H)?(?:(\d+)M)?$').firstMatch(alarm.value);
    final alarmMinutes = alarmMatch == null
        ? null
        : int.parse(alarmMatch[1] ?? '0') * 60 +
              int.parse(alarmMatch[2] ?? '0');
    return ImportedCourse(
      name: name,
      location: location,
      description: _unescape(get('DESCRIPTION')?.value ?? ''),
      instances: instances,
      key: sha256.convert(utf8.encode(signature)).toString(),
      reminderMinutes: alarmMinutes != null && alarmMinutes <= 1440
          ? alarmMinutes
          : null,
    );
  }
}
