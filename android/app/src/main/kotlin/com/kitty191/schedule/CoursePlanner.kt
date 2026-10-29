package com.kitty191.schedule

import java.util.Calendar
import java.util.TimeZone

// Pure calendar logic shared by the scheduler and JVM tests. Weekdays are ISO 1..7.
data class CourseSpec(
    val id: Int, val name: String, val location: String,
    val weekday: Int, val startMinute: Int, val endMinute: Int,
    val fixedOccurrences: List<Pair<Long, Long>>? = null,
    val leadMinutes: Int? = null, val kind: String = "course",
)

enum class CoursePhase { UPCOMING, IN_CLASS, ENDING_SOON }

data class CourseOccurrence(val course: CourseSpec, val start: Long, val end: Long) {
    val key: String get() = "${course.id}:$start"
    val endingKey: String get() = "$key:$end"
    val endingReminderAt: Long? get() = if (course.kind == "event") null else maxOf(start, end - 10 * 60_000L)
    fun phase(now: Long): CoursePhase = when {
        now < start -> CoursePhase.UPCOMING
        endingReminderAt != null && now >= endingReminderAt!! && now < end -> CoursePhase.ENDING_SOON
        else -> CoursePhase.IN_CLASS
    }
}

data class CoursePlan(val active: CourseOccurrence?, val nextWake: Long?, val nextRefresh: Long? = null)

object CoursePlanner {
    fun plan(
        courses: List<CourseSpec>, now: Long, leadMinutes: Int,
        dismissed: String? = null, zone: TimeZone = TimeZone.getDefault(),
    ): CoursePlan {
        val occurrences = mutableListOf<CourseOccurrence>()
        for (course in courses.filter { it.fixedOccurrences != null }) {
            for ((start, end) in course.fixedOccurrences!!) {
                val occurrence = CourseOccurrence(course, start, end)
                if (end > now && occurrence.key != dismissed) occurrences.add(occurrence)
            }
        }
        for (offset in -1..8) {
            val day = Calendar.getInstance(zone).apply {
                timeInMillis = now
                add(Calendar.DAY_OF_MONTH, offset)
            }
            val weekday = (day.get(Calendar.DAY_OF_WEEK) + 5) % 7 + 1
            for (course in courses.filter { it.fixedOccurrences == null && it.weekday == weekday }) {
                fun at(minute: Int): Long = (day.clone() as Calendar).apply {
                    set(Calendar.HOUR_OF_DAY, minute / 60)
                    set(Calendar.MINUTE, minute % 60)
                    set(Calendar.SECOND, 0)
                    set(Calendar.MILLISECOND, 0)
                }.timeInMillis
                val occurrence = CourseOccurrence(course, at(course.startMinute), at(course.endMinute))
                if (occurrence.end > now && occurrence.key != dismissed) occurrences.add(occurrence)
            }
        }
        occurrences.sortWith(compareBy<CourseOccurrence> { it.start }.thenBy { it.course.id })
        fun lead(occurrence: CourseOccurrence) = (occurrence.course.leadMinutes ?: leadMinutes) * 60_000L
        val active = occurrences.firstOrNull { now >= it.start - lead(it) && now < it.end }
        // Only reminder boundaries use wake-up alarms. Cosmetic minute refreshes
        // and the start-state transition must not consume allow-while-idle quota.
        val boundaries = occurrences.flatMap { listOfNotNull(it.start - lead(it), it.endingReminderAt, it.end) }
            .filter { it > now }
        val wake = boundaries.minOrNull()
        val refresh = active?.takeIf { now < it.start }?.let { minOf(now + 60_000L, it.start) }
        return CoursePlan(active, wake, refresh)
    }
}
