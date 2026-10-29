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

    @Test fun importedOccurrencesNeverRepeatOutsideFileDates() {
        val finite = course.copy(fixedOccurrences = listOf(Pair(time(29, 8, 30), time(29, 10, 0))))
        assertNotNull(plan(time(29, 8, 25), listOf(finite)).active)
        val result = plan(time(29, 10, 0), listOf(finite))
        assertNull(result.active)
        assertNull(result.nextWake)
    }
    @Test fun fileReminderOverridesGlobalLead() {
        val imported = course.copy(leadMinutes = 20,
            fixedOccurrences = listOf(Pair(time(29, 8, 30), time(29, 10, 0))))
        assertNotNull(plan(time(29, 8, 10), listOf(imported)).active)
        assertNull(plan(time(29, 8, 9), listOf(imported)).active)
    }
    @Test fun finiteImportMayBeMonthsAheadAndDoesNotUseWeekdayFallback() {
        val future = course.copy(fixedOccurrences = listOf(Pair(time(29, 8, 30), time(29, 10, 0))))
        val result = plan(time(1, 8, 25), listOf(future))
        assertNull(result.active)
        assertEquals(time(29, 8, 20), result.nextWake)
        assertNull(plan(time(29, 9, 0),listOf(course.copy(fixedOccurrences = emptyList()))).active)
    }
    @Test fun oneOffEventCanBeDismissedWithoutWeeklyRepost() {
        val event = course.copy(kind = "event", fixedOccurrences = listOf(Pair(time(29,8,30),time(29,10,0))))
        val key = plan(time(29,8,25),listOf(event)).active!!.key
        val stopped = plan(time(29,8,26),listOf(event),key)
        assertNull(stopped.active)
        assertNull(stopped.nextWake)
    }

    @Test fun tenMinuteBoundarySwitchesIntoEndingPhaseAndEndsOnTime() {
        val before = plan(time(29, 9, 49))
        assertEquals(CoursePhase.IN_CLASS, before.active!!.phase(time(29,9,49)))
        assertEquals(time(29,9,50), before.nextWake)
        assertNull(before.nextRefresh)
        val ending = plan(time(29,9,50))
        assertEquals(CoursePhase.ENDING_SOON, ending.active!!.phase(time(29,9,50)))
        assertEquals(CoursePhase.ENDING_SOON, ending.active!!.phase(time(29,9,59)))
        assertEquals(time(29,10,0), ending.nextWake)
        assertNull(plan(time(29,10,0)).active)
    }
    @Test fun cosmeticRefreshDoesNotConsumeReminderWakeBoundary() {
        val before = plan(time(29,8,25))
        assertEquals(time(29,8,26), before.nextRefresh)
        assertEquals(time(29,9,50), before.nextWake)
        val started = plan(time(29,8,30))
        assertNull(started.nextRefresh)
        assertEquals(time(29,9,50), started.nextWake)
    }
    @Test fun shortClassesStartEndingReminderAtStartInsteadOfBeforeClass() {
        val short = course.copy(endMinute = 8*60+38)
        val upcoming = plan(time(29,8,29), listOf(short)).active!!
        assertEquals(CoursePhase.UPCOMING, upcoming.phase(time(29,8,29)))
        assertEquals(time(29,8,30), upcoming.endingReminderAt)
        assertEquals(CoursePhase.ENDING_SOON, plan(time(29,8,30),listOf(short)).active!!.phase(time(29,8,30)))
        assertNull(plan(time(29,8,38),listOf(short)).active)
    }
    @Test fun importedClassHasTheSameEndingBoundaryAndDismissalIsRespected() {
        val finite = course.copy(fixedOccurrences = listOf(Pair(time(29,8,30),time(29,10,0))))
        val ending = plan(time(29,9,50),listOf(finite)).active!!
        assertEquals(CoursePhase.ENDING_SOON, ending.phase(time(29,9,50)))
        val stopped = plan(time(29,9,51),listOf(finite),ending.key)
        assertNull(stopped.active); assertNull(stopped.nextWake)
    }
    @Test fun ordinaryEventsHaveNoClassEndingReminder() {
        val event = course.copy(kind = "event")
        val active = plan(time(29,9,55),listOf(event)).active!!
        assertNull(active.endingReminderAt)
        assertEquals(CoursePhase.IN_CLASS, active.phase(time(29,9,55)))
    }
    @Test fun rescheduledEndGetsANewEndingAnnouncementKey() {
        val old = CourseOccurrence(course,time(29,8,30),time(29,10,0))
        val changed = old.copy(end = time(29,10,30))
        assertNotEquals(old.endingKey, changed.endingKey)
        assertEquals(time(29,10,20), changed.endingReminderAt)
    }
}
