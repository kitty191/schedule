import 'dart:convert';

import 'database.dart';

const weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];

String clockText(int minute) =>
    '${(minute ~/ 60).toString().padLeft(2, '0')}:${(minute % 60).toString().padLeft(2, '0')}';
String dateText(DateTime day) => '${day.year}/${day.month}/${day.day}';
String dayKey(DateTime day) =>
    '${day.year.toString().padLeft(4, '0')}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
DateTime dateOnly(DateTime day) => DateTime(day.year, day.month, day.day);
DateTime mondayOf(DateTime day) =>
    DateTime(day.year, day.month, day.day - day.weekday + 1);
bool sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
bool isEvent(Course c) => c.kind == 'event';

class CourseInstance {
  const CourseInstance(this.start, this.end);
  final DateTime start;
  final DateTime end;
  Map<String, int> toMap() => {
    'start': start.millisecondsSinceEpoch,
    'end': end.millisecondsSinceEpoch,
  };
}

// Cached by immutable encoded value; entries are invalidated naturally on edits.
final _instanceCache = <String, List<CourseInstance>>{};
List<CourseInstance> instancesOf(Course course) {
  final encoded = course.occurrences;
  if (encoded == null) return const [];
  if (_instanceCache.length > 500) _instanceCache.clear();
  return _instanceCache.putIfAbsent(
    encoded,
    () => (jsonDecode(encoded) as List)
        .map(
          (e) => CourseInstance(
            DateTime.fromMillisecondsSinceEpoch(e['start'] as int),
            DateTime.fromMillisecondsSinceEpoch(e['end'] as int),
          ),
        )
        .toList(),
  );
}

DateTime courseTime(Course course, DateTime day, {bool end = false}) {
  if (course.occurrences != null) {
    final instance = instancesOf(course)
        .where((i) => sameDay(i.start, day))
        .firstOrNull;
    if (instance != null) return end ? instance.end : instance.start;
  }
  final minute = end ? course.endMinute : course.startMinute;
  return DateTime(day.year, day.month, day.day, minute ~/ 60, minute % 60);
}

int minuteOn(Course course, DateTime day, {bool end = false}) {
  final time = courseTime(course, day, end: end);
  return time.hour * 60 + time.minute;
}

List<Course> coursesOn(List<Course> courses, DateTime day) =>
    courses
        .where(
          (c) => c.occurrences == null
              ? c.weekday == day.weekday
              : instancesOf(c).any((i) => sameDay(i.start, day)),
        )
        .toList()
      ..sort((a, b) => courseTime(a, day).compareTo(courseTime(b, day)));

Course? upcomingToday(List<Course> courses, DateTime now) => coursesOn(
  courses,
  now,
).where((c) => courseTime(c, now, end: true).isAfter(now)).firstOrNull;

int? semesterWeek(DateTime? start, DateTime now, {int weekStart = 1}) {
  if (start == null) return null;
  final monday = DateTime.utc(
    start.year,
    start.month,
    start.day,
  ).subtract(Duration(days: (start.weekday - weekStart + 7) % 7));
  final today = DateTime.utc(now.year, now.month, now.day);
  if (today.isBefore(monday)) return null;
  return today.difference(monday).inDays ~/ 7 + 1;
}

Map<String, Object> coursePayload(Course c) => {
  'id': c.id,
  'name': c.name,
  'location': c.location,
  'weekday': c.weekday,
  'startMinute': c.startMinute,
  'endMinute': c.endMinute,
  'kind': c.kind ?? 'course',
  if (c.reminderMinutes != null) 'leadMinutes': c.reminderMinutes!,
  if (c.occurrences != null)
    'occurrences': instancesOf(c).map((i) => i.toMap()).toList(),
};
