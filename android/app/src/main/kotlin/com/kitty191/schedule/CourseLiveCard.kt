package com.kitty191.schedule

import java.util.Calendar
import java.util.Locale
import java.util.TimeZone
import kotlin.math.ceil

/** All times/progress derive from the same occurrence, including the two preview modes. */
data class CourseLiveCard(
    val headline: String,
    val detail: String,
    val metadata: String,
    val critical: String,
    val expandedText: String,
    val countdownTo: Long,
    val progress: Int,
    val preparationEnd: Int,
) {
    companion object {
        const val PROGRESS_MAX = 1000

        fun previewOccurrence(course: CourseSpec, now: Long, leadMinutes: Int, endingLeadMinutes: Int,
            ending: Boolean): CourseOccurrence {
            val duration = (course.endMinute - course.startMinute) * 60_000L
            if (ending) {
                val remaining = endingLeadMinutes * 60_000L
                val end = now + remaining
                return CourseOccurrence(course, end - maxOf(duration, remaining), end, endingLeadMinutes)
            }
            val start = now + (course.leadMinutes ?: leadMinutes) * 60_000L
            return CourseOccurrence(course, start, start + duration, endingLeadMinutes)
        }

        fun create(
            course: CourseSpec,
            occurrence: CourseOccurrence,
            now: Long,
            leadMinutes: Int,
            semesterStart: String? = null,
            weekStart: Int = 1,
            preview: Boolean = false,
            zone: TimeZone = TimeZone.getDefault(),
        ): CourseLiveCard {
            val event = course.kind == "event"
            val upcoming = now < occurrence.start
            val ending = occurrence.phase(now) == CoursePhase.ENDING_SOON
            val startVerb = if (event) "开始" else "上课"
            val endVerb = if (event) "结束" else "下课"
            val target = if (upcoming) occurrence.start else occurrence.end
            val minutes = ceil((target - now) / 60_000.0).toInt().coerceAtLeast(1)
            val phase = when {
                upcoming -> if (event) "即将开始" else "课前"
                ending -> "快下课"
                event -> "进行中"
                else -> "上课中"
            }
            val critical = if (upcoming || ending) {
                // Keep well within the system chip's small text budget, even for 24 h leads.
                val remaining = if (minutes < 60) "${minutes}分" else "${ceil(minutes / 60.0).toInt()}时"
                "$remaining${if (upcoming) startVerb else endVerb}"
            } else phase
            fun date(at: Long) = Calendar.getInstance(zone).apply { timeInMillis = at }
            fun minute(at: Long): Int = date(at).let { it.get(Calendar.HOUR_OF_DAY) * 60 + it.get(Calendar.MINUTE) }
            fun clock(at: Long): String = String.format(Locale.ROOT, "%02d:%02d", minute(at) / 60, minute(at) % 60)
            val nextDay = date(occurrence.start).let { start ->
                val end = date(occurrence.end)
                start.get(Calendar.YEAR) != end.get(Calendar.YEAR) || start.get(Calendar.DAY_OF_YEAR) != end.get(Calendar.DAY_OF_YEAR)
            }
            val headline = "${clock(occurrence.start)} $startVerb  ·  ${if (nextDay) "次日 " else ""}${clock(occurrence.end)} $endVerb"
            val location = course.location.trim().ifEmpty { if (event) "未设置地点" else "未设置教室" }
            val first = course.startPeriod
            val last = course.endPeriod
            val matchingLocalTimes = preview || (minute(occurrence.start) == course.startMinute && minute(occurrence.end) == course.endMinute)
            val period = if (!event && matchingLocalTimes && first != null && last != null && first in 1..24 && last in first..24) {
                if (first == last) "第 $first 节" else "第 $first–$last 节"
            } else null
            val week = if (event) null else teachingWeek(semesterStart, occurrence.start, weekStart, zone)
            val metadata = listOfNotNull(if (preview) "预览" else null, phase, period, week?.let { "第 $it 周" }).joinToString(" · ")
            val preparation = (course.leadMinutes ?: leadMinutes).coerceIn(0, 1440) * 60_000L
            val journeyStart = occurrence.start - preparation
            val duration = (occurrence.end - journeyStart).coerceAtLeast(1)
            val progress = ((now - journeyStart).coerceIn(0, duration) * PROGRESS_MAX / duration).toInt()
            val preparationEnd = if (preparation == 0L) 0 else
                (preparation * PROGRESS_MAX / duration).toInt().coerceIn(1, PROGRESS_MAX - 1)
            val countdown = "${minutes}分钟后${if (upcoming) startVerb else endVerb}"
            return CourseLiveCard(
                headline, "${course.name} · $location", metadata, critical,
                "${course.name}\n$headline\n$location\n$metadata\n$countdown", target,
                progress, preparationEnd,
            )
        }

        /** Calendar dates rather than 24 h intervals keep teaching weeks stable across DST. */
        internal fun teachingWeek(start: String?, at: Long, weekStart: Int, zone: TimeZone): Int? {
            if (start == null || weekStart !in 1..7 || !Regex("\\d{4}-\\d{2}-\\d{2}").matches(start)) return null
            val parts = start.split('-').map(String::toInt)
            val utc = TimeZone.getTimeZone("UTC")
            val first = Calendar.getInstance(utc).apply {
                clear(); isLenient = false
                set(parts[0], parts[1] - 1, parts[2])
            }
            try { first.timeInMillis } catch (_: IllegalArgumentException) { return null }
            val weekday = (first.get(Calendar.DAY_OF_WEEK) + 5) % 7 + 1
            first.add(Calendar.DAY_OF_MONTH, -(weekday - weekStart + 7) % 7)
            val local = Calendar.getInstance(zone).apply { timeInMillis = at }
            val day = Calendar.getInstance(utc).apply {
                clear()
                set(local.get(Calendar.YEAR), local.get(Calendar.MONTH), local.get(Calendar.DAY_OF_MONTH))
            }
            val days = (day.timeInMillis - first.timeInMillis) / 86_400_000L
            return if (days < 0) null else (days / 7 + 1).toInt()
        }
    }
}
