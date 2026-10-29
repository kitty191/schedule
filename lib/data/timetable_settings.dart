import 'dart:convert';

class ClassPeriod {
  const ClassPeriod(this.start, this.end);
  final int start, end;
  Map<String, int> toMap() => {'start': start, 'end': end};
  ClassPeriod copyWith({int? start, int? end}) =>
      ClassPeriod(start ?? this.start, end ?? this.end);
}

class TimetableSettings {
  const TimetableSettings({
    required this.periods,
    this.weekStart = 1,
    this.visibleDays = 7,
    this.periodView = true,
    this.heightPercent = 100,
    this.firstStart = 480,
    this.lessonMinutes = 40,
    this.breakMinutes = 5,
    this.lunchAfter = 5,
    this.lunchMinutes = 100,
    this.eveningAfter = 10,
    this.eveningMinutes = 70,
  });
  final List<ClassPeriod> periods;
  final int weekStart, visibleDays, firstStart, lessonMinutes, breakMinutes;
  final int lunchAfter, lunchMinutes, eveningAfter, eveningMinutes;
  final bool periodView;
  final int heightPercent;

  static TimetableSettings defaults() {
    const draft = TimetableSettings(periods: []);
    return draft.generate(12);
  }

  factory TimetableSettings.decode(String? encoded) {
    if (encoded == null) return defaults();
    final v = jsonDecode(encoded) as Map<String, dynamic>;
    final value = TimetableSettings(
      periods: (v['periods'] as List)
          .map((p) => ClassPeriod(p['start'] as int, p['end'] as int))
          .toList(),
      weekStart: v['weekStart'] as int,
      visibleDays: v['visibleDays'] as int,
      periodView: v['periodView'] as bool,
      heightPercent: v['heightPercent'] as int? ?? 100,
      firstStart: v['firstStart'] as int,
      lessonMinutes: v['lessonMinutes'] as int,
      breakMinutes: v['breakMinutes'] as int,
      lunchAfter: v['lunchAfter'] as int,
      lunchMinutes: v['lunchMinutes'] as int,
      eveningAfter: v['eveningAfter'] as int,
      eveningMinutes: v['eveningMinutes'] as int,
    );
    final error = value.validationError;
    if (error != null) throw FormatException(error);
    return value;
  }

  String encode() => jsonEncode({
    'periods': periods.map((p) => p.toMap()).toList(),
    'weekStart': weekStart,
    'visibleDays': visibleDays,
    'periodView': periodView,
    'heightPercent': heightPercent,
    'firstStart': firstStart,
    'lessonMinutes': lessonMinutes,
    'breakMinutes': breakMinutes,
    'lunchAfter': lunchAfter,
    'lunchMinutes': lunchMinutes,
    'eveningAfter': eveningAfter,
    'eveningMinutes': eveningMinutes,
  });

  String? get validationError {
    if (heightPercent < 60 || heightPercent > 160) {
      return '课表高度需要在 60% 至 160% 之间。';
    }
    if (weekStart < 1 || weekStart > 7 || ![5, 7].contains(visibleDays)) {
      return '请选择有效的每周起始日和显示天数。';
    }
    if (periods.isEmpty || periods.length > 24) return '每天需要设置 1 至 24 节课。';
    if (firstStart < 0 ||
        firstStart > 1438 ||
        lessonMinutes < 5 ||
        lessonMinutes > 180 ||
        breakMinutes < 0 ||
        breakMinutes > 120 ||
        lunchAfter < 0 ||
        lunchAfter > 24 ||
        eveningAfter < 0 ||
        eveningAfter > 24 ||
        lunchMinutes < 0 ||
        lunchMinutes > 240 ||
        eveningMinutes < 0 ||
        eveningMinutes > 240) {
      return '排课模板中的时长或节次无效。';
    }
    if (lunchAfter > 0 &&
        lunchAfter == eveningAfter &&
        lunchAfter < periods.length) {
      return '午休和晚休不能安排在同一节课后，请调整节次。';
    }
    for (var i = 0; i < periods.length; i++) {
      final p = periods[i];
      if (p.start < 0 || p.end > 1439 || p.end <= p.start) {
        return '第 ${i + 1} 节的下课时间需晚于上课时间，且不能跨午夜。';
      }
      if (i > 0 && p.start < periods[i - 1].end) {
        return '第 $i 节与第 ${i + 1} 节时间重叠，请调整起止时间。';
      }
    }
    return null;
  }

  TimetableSettings generate(int count) {
    if (count < 1 || count > 24) {
      throw const FormatException('每天需要设置 1 至 24 节课。');
    }
    final result = <ClassPeriod>[];
    var start = firstStart;
    for (var i = 1; i <= count; i++) {
      final end = start + lessonMinutes;
      result.add(ClassPeriod(start, end));
      final pause = i == lunchAfter
          ? lunchMinutes
          : i == eveningAfter
          ? eveningMinutes
          : breakMinutes;
      start = end + pause;
    }
    final settings = copyWith(periods: result);
    final error = settings.validationError;
    if (error != null) throw FormatException(error);
    return settings;
  }

  TimetableSettings copyWith({
    List<ClassPeriod>? periods,
    int? weekStart,
    int? visibleDays,
    bool? periodView,
    int? heightPercent,
    int? firstStart,
    int? lessonMinutes,
    int? breakMinutes,
    int? lunchAfter,
    int? lunchMinutes,
    int? eveningAfter,
    int? eveningMinutes,
  }) => TimetableSettings(
    periods: periods ?? this.periods,
    weekStart: weekStart ?? this.weekStart,
    visibleDays: visibleDays ?? this.visibleDays,
    periodView: periodView ?? this.periodView,
    heightPercent: heightPercent ?? this.heightPercent,
    firstStart: firstStart ?? this.firstStart,
    lessonMinutes: lessonMinutes ?? this.lessonMinutes,
    breakMinutes: breakMinutes ?? this.breakMinutes,
    lunchAfter: lunchAfter ?? this.lunchAfter,
    lunchMinutes: lunchMinutes ?? this.lunchMinutes,
    eveningAfter: eveningAfter ?? this.eveningAfter,
    eveningMinutes: eveningMinutes ?? this.eveningMinutes,
  );
}

DateTime startOfWeek(DateTime day, int weekStart) =>
    DateTime(day.year, day.month, day.day - (day.weekday - weekStart + 7) % 7);

class _AxisSegment {
  const _AxisSegment(this.start, this.end, this.top, this.height);
  final int start, end;
  final double top, height;
}

/// Monotonic real-time mapping: class rows have equal height and breaks stay visible.
/// Imported courses outside the configured school day extend the axis.
class TimetableAxis {
  TimetableAxis(
    TimetableSettings settings, {
    required int earliest,
    required int latest,
    double minimumPeriodHeight = 0,
  }) {
    final scale = settings.heightPercent / 100;
    final first = settings.periods.first.start;
    final last = settings.periods.last.end;
    if (!settings.periodView) {
      final start = (earliest < first ? earliest : first) ~/ 60 * 60;
      final end = ((latest > last ? latest : last) / 60).ceil() * 60;
      _add(start, end, (end - start) * 1.2 * scale);
      return;
    }
    final rowHeight = (76 * scale).clamp(minimumPeriodHeight, double.infinity);
    // Extend using the adjacent period density, including accessibility height.
    // A late class must not collapse simply because it is outside the template.
    if (earliest < first) {
      final period = settings.periods.first;
      _add(
        earliest,
        first,
        (first - earliest) * rowHeight / (period.end - period.start),
      );
    }
    for (var i = 0; i < settings.periods.length; i++) {
      final p = settings.periods[i];
      if (i > 0) {
        final previous = settings.periods[i - 1];
        if (p.start > previous.end) {
          _add(
            previous.end,
            p.start,
            (p.start - previous.end >= 60 ? 32 : 12) * scale,
          );
        }
      }
      _add(p.start, p.end, rowHeight);
    }
    if (latest > last) {
      final period = settings.periods.last;
      _add(
        last,
        latest,
        (latest - last) * rowHeight / (period.end - period.start),
      );
    }
  }
  final _segments = <_AxisSegment>[];
  double height = 0;
  void _add(int start, int end, double size) {
    _segments.add(_AxisSegment(start, end, height, size));
    height += size;
  }

  double at(int minute) {
    if (minute <= _segments.first.start) return 0;
    for (final segment in _segments) {
      if (minute <= segment.end) {
        return segment.top +
            (minute - segment.start) /
                (segment.end - segment.start) *
                segment.height;
      }
    }
    return height;
  }

  int minuteAt(double y) {
    if (y <= 0) return _segments.first.start;
    for (final segment in _segments) {
      if (y <= segment.top + segment.height) {
        return segment.start +
            ((y - segment.top) / segment.height * (segment.end - segment.start))
                .round();
      }
    }
    return _segments.last.end;
  }

  int periodAt(double y, List<ClassPeriod> periods) {
    final minute = minuteAt(y);
    for (var i = 0; i < periods.length; i++) {
      if (minute < periods[i].end) return i + 1;
    }
    return periods.length;
  }
}
