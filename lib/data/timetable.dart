import 'database.dart';

const weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];

String clockText(int minute) =>
    '${(minute ~/ 60).toString().padLeft(2, '0')}:${(minute % 60).toString().padLeft(2, '0')}';

DateTime courseTime(Course course, DateTime day, {bool end = false}) {
  final minute = end ? course.endMinute : course.startMinute;
  return DateTime(day.year, day.month, day.day, minute ~/ 60, minute % 60);
}

List<Course> coursesOn(List<Course> courses, DateTime day) =>
    courses.where((c) => c.weekday == day.weekday).toList()
      ..sort((a, b) => a.startMinute.compareTo(b.startMinute));

Course? upcomingToday(List<Course> courses, DateTime now) {
  final remaining = coursesOn(
    courses,
    now,
  ).where((c) => courseTime(c, now, end: true).isAfter(now));
  return remaining.firstOrNull;
}

int? semesterWeek(DateTime? start, DateTime now) {
  if (start == null) return null;
  // UTC date-only arithmetic avoids daylight-saving shifts in calendar weeks.
  final monday = DateTime.utc(
    start.year,
    start.month,
    start.day,
  ).subtract(Duration(days: start.weekday - 1));
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
};
