package com.kitty191.schedule

import java.util.Calendar
import java.util.TimeZone
import org.junit.Assert.*
import org.junit.Test

class CoursePlannerTest {
    private val zone = TimeZone.getTimeZone("Asia/Shanghai")
    // 2026-10-29 is Thursday.
    private fun time(day: Int, hour: Int, minute: Int): Long = Calendar.getInstance(zone).apply {
        clear(); set(2026, Calendar.OCTOBER, day, hour, minute)
    }.timeInMillis
    private val course = CourseSpec(1, "数学", "B402", 4, 8 * 60 + 30, 10 * 60)
    private fun plan(now: Long, courses: List<CourseSpec> = listOf(course), dismissed: String? = null) =
        CoursePlanner.plan(courses, now, 10, dismissed, zone)

    @Test fun waitsUntilLeadBoundary() {
        val result = plan(time(29, 8, 19))
        assertNull(result.active)
        assertEquals(time(29, 8, 20), result.nextWake)
    }
    @Test fun startsAtLeadAndContinuesDuringClass() {
        assertNotNull(plan(time(29, 8, 20)).active)
        assertNotNull(plan(time(29, 9, 0)).active)
        assertTrue(plan(time(29, 9, 0)).nextWake!! > time(29, 9, 0))
    }
    @Test fun endsAtExactEndAndPlansNextWeek() {
        val result = plan(time(29, 10, 0))
        assertNull(result.active)
        val nextWeek = Calendar.getInstance(zone).apply { timeInMillis = time(29, 8, 20); add(Calendar.DATE, 7) }.timeInMillis
        assertEquals(nextWeek, result.nextWake)
    }
    @Test fun midnightLeadCanStartOnPreviousDay() {
        val midnight = course.copy(startMinute = 5, endMinute = 45)
        val result = plan(time(28, 23, 56), listOf(midnight))
        assertEquals(time(29, 0, 5), result.active!!.start)
    }
    @Test fun sundayToMondayRollsCorrectly() {
        val monday = course.copy(weekday = 1, startMinute = 5, endMinute = 45)
        assertNotNull(plan(time(25, 23, 56), listOf(monday)).active)
    }
    @Test fun dismissDoesNotRepostSameOccurrence() {
        val active = plan(time(29, 8, 25)).active!!
        val result = plan(time(29, 8, 26), dismissed = active.key)
        assertNull(result.active)
        assertTrue(result.nextWake!! > active.end)
    }
    @Test fun overlappingCoursesPreferEarlierAndThenSwitch() {
        val later = course.copy(id = 2, startMinute = 9 * 60, endMinute = 11 * 60)
        assertEquals(1, plan(time(29, 9, 15), listOf(later, course)).active!!.course.id)
        assertEquals(2, plan(time(29, 10, 0), listOf(later, course)).active!!.course.id)
    }
    @Test fun deletedCoursesLeaveNoFutureAlarm() {
        val result = plan(time(29, 8, 25), emptyList())
        assertNull(result.active)
        assertNull(result.nextWake)
    }
    @Test fun daylightSavingKeepsLocalClassTime() {
        val berlin = TimeZone.getTimeZone("Europe/Berlin")
        val saturday = Calendar.getInstance(berlin).apply { clear(); set(2026, Calendar.OCTOBER, 24, 12, 0) }
        val sunday = course.copy(weekday = 7)
        val result = CoursePlanner.plan(listOf(sunday), saturday.timeInMillis, 10, zone = berlin)
        val wake = Calendar.getInstance(berlin).apply { timeInMillis = result.nextWake!! }
        assertEquals(25, wake.get(Calendar.DAY_OF_MONTH))
        assertEquals(8, wake.get(Calendar.HOUR_OF_DAY))
        assertEquals(20, wake.get(Calendar.MINUTE))
    }
}
