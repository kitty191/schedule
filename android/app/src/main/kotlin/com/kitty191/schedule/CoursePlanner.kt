package com.kitty191.schedule

import java.util.Calendar
import java.util.TimeZone

// Pure calendar logic shared by the scheduler and JVM tests. Weekdays are ISO 1..7.
data class CourseSpec(
    val id: Int, val name: String, val location: String,
    val weekday: Int, val startMinute: Int, val endMinute: Int,
)

data class CourseOccurrence(val course: CourseSpec, val start: Long, val end: Long) {
    val key: String get() = "${course.id}:$start"
}

data class CoursePlan(val active: CourseOccurrence?, val nextWake: Long?)

object CoursePlanner {
    fun plan(
        courses: List<CourseSpec>, now: Long, leadMinutes: Int,
        dismissed: String? = null, zone: TimeZone = TimeZone.getDefault(),
    ): CoursePlan {
        val occurrences = mutableListOf<CourseOccurrence>()
        for (offset in -1..8) {
            val day = Calendar.getInstance(zone).apply {
                timeInMillis = now
                add(Calendar.DAY_OF_MONTH, offset)
            }
            val weekday = (day.get(Calendar.DAY_OF_WEEK) + 5) % 7 + 1
            for (course in courses.filter { it.weekday == weekday }) {
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
        val lead = leadMinutes * 60_000L
        val active = occurrences.firstOrNull { now >= it.start - lead && now < it.end }
        val boundaries = occurrences.flatMap { listOf(it.start - lead, it.start, it.end) }
            .filter { it > now }
        val wake = (boundaries + listOfNotNull(active?.let { now + 60_000L })).minOrNull()
        return CoursePlan(active, wake)
    }
}
