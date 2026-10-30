package com.kitty191.schedule

import java.util.Calendar
import java.util.TimeZone
import org.junit.Assert.*
import org.junit.Test

class CourseLiveCardTest {
    private val zone = TimeZone.getTimeZone("Asia/Shanghai")
    private fun time(day: Int, hour: Int, minute: Int): Long = Calendar.getInstance(zone).apply {
        clear(); set(2026, Calendar.OCTOBER, day, hour, minute)
    }.timeInMillis
    private val course = CourseSpec(1, "大学英语", "东校区综合楼 B402", 4, 510, 600,
        startPeriod = 3, endPeriod = 4)
    private val occurrence = CourseOccurrence(course, time(29,8,30), time(29,10,0))
    private fun card(at: Long, spec: CourseSpec = course, instance: CourseOccurrence = occurrence,
        lead: Int = 10) = CourseLiveCard.create(spec, instance, at, lead, "2026-10-26", zone = zone)

    @Test fun upcomingCardCombinesTimesCourseLocationPeriodsAndTeachingWeek() {
        val card = card(time(29,8,25))
        assertEquals("08:30 上课  ·  10:00 下课", card.headline)
        assertEquals("大学英语 · 东校区综合楼 B402", card.detail)
        assertEquals("课前 · 第 3–4 节 · 第 1 周", card.metadata)
        assertEquals("5分上课", card.critical)
        assertEquals(occurrence.start, card.countdownTo)
        assertEquals(50, card.progress)
        assertEquals(100, card.preparationEnd)
    }
    @Test fun progressIsContinuousAcrossStartAndEndingBoundary() {
        val values = (0..100).map { offset -> card(time(29,8,20) + offset * 60_000L).progress }
        assertEquals(0, values.first())
        assertEquals(1000, values.last())
        assertTrue(values.zipWithNext().all { (a,b) -> b >= a })
        val started = card(occurrence.start)
        assertEquals(started.preparationEnd, started.progress)
        assertEquals("上课中", started.critical)
        assertEquals(occurrence.end, started.countdownTo)
        val ending = card(time(29,9,50))
        assertEquals("10分下课", ending.critical)
        assertTrue(ending.metadata.startsWith("快下课"))
        assertEquals(900, ending.progress)
    }
    @Test fun fileLeadControlsPreparationSegmentAndZeroLeadRemovesIt() {
        val spec = course.copy(leadMinutes = 30)
        val longLead = card(time(29,8,15), spec, occurrence.copy(course = spec))
        assertEquals(250, longLead.preparationEnd)
        assertEquals(125, longLead.progress)
        val zero = course.copy(leadMinutes = 0)
        assertEquals(0, card(occurrence.start, zero, occurrence.copy(course = zero)).preparationEnd)
    }
    @Test fun criticalTextFitsChipForMinuteHourAndDayLongLeads() {
        for (lead in listOf(1, 59, 60, 61, 1440)) {
            val card = card(occurrence.start - lead * 60_000L, lead = lead)
            assertTrue(card.critical.length <= 6)
            assertEquals(0, card.progress)
        }
        assertEquals("1分下课", card(occurrence.end - 1).critical)
    }
    @Test fun customTimesDoNotInventPeriodsAndMissingLocationsAreReadable() {
        val spec = course.copy(startPeriod = null, endPeriod = null, location = "  ")
        val card = card(time(29,8,25), spec, occurrence.copy(course = spec))
        assertEquals("课前 · 第 1 周", card.metadata)
        assertTrue(card.detail.endsWith("未设置教室"))
    }
    @Test fun eventsUseStartAndEndLanguageWithoutClassMetadataOrEndingPhase() {
        val event = course.copy(kind = "event", location = "")
        val instance = occurrence.copy(course = event)
        val upcoming = card(time(29,8,25), event, instance)
        assertEquals("08:30 开始  ·  10:00 结束", upcoming.headline)
        assertEquals("5分开始", upcoming.critical)
        assertEquals("即将开始", upcoming.metadata)
        assertTrue(upcoming.detail.endsWith("未设置地点"))
        assertEquals("进行中", card(time(29,9,55), event, instance).metadata)
    }
    @Test fun teachingWeekUsesConfiguredFirstDayAndOmitsUnsetOrFutureSemester() {
        val sunday = time(32,8,25) // Calendar normalizes Nov 1; see separate strict date handling.
        assertEquals(2, CourseLiveCard.teachingWeek("2026-10-26", sunday, 7, zone))
        assertEquals(1, CourseLiveCard.teachingWeek("2026-10-26", sunday, 1, zone))
        assertNull(CourseLiveCard.teachingWeek(null, sunday, 1, zone))
        assertNull(CourseLiveCard.teachingWeek("2026-11-09", sunday, 1, zone))
        assertNull(CourseLiveCard.teachingWeek("2026-02-30", sunday, 1, zone))
    }
    @Test fun teachingWeeksIgnoreDaylightSavingHourChanges() {
        val berlin = TimeZone.getTimeZone("Europe/Berlin")
        val monday = Calendar.getInstance(berlin).apply { clear(); set(2026, Calendar.OCTOBER, 26, 0, 0) }
        assertEquals(2, CourseLiveCard.teachingWeek("2026-10-19", monday.timeInMillis, 1, berlin))
    }
    @Test fun importedOccurrenceClocksAndWeekComeFromActualDateRatherThanFallbackMinutes() {
        val imported = occurrence.copy(start = time(32,11,0), end = time(32,12,0))
        val card = card(time(32,10,55), instance = imported)
        assertTrue(card.headline.startsWith("11:00"))
        assertTrue(card.metadata.endsWith("第 1 周"))
        assertFalse(card.metadata.contains("节"))
        assertEquals(imported.start, card.countdownTo)
    }
    @Test fun previewHasStableSyntheticTimesAndIsClearlyLabeled() {
        val now = time(29,16,0)
        val preview = CourseLiveCard.previewOccurrence(course, now, 7, 10, false)
        val card = CourseLiveCard.create(course, preview, now, 7, preview = true, zone = zone)
        assertEquals("16:07 上课  ·  17:37 下课", card.headline)
        assertEquals("7分上课", card.critical)
        assertTrue(card.metadata.startsWith("预览 · 课前"))
        assertTrue(CourseLiveCard.create(course, preview, now + 60_000, 7).progress > card.progress)
        assertEquals(preview.start, CourseLiveCard.create(course, preview, now + 60_000, 7).countdownTo)
    }
    @Test fun endingPreviewIsNeverUpcomingEvenWhenLeadExceedsLessonDuration() {
        val now = time(29,16,0)
        for (lead in listOf(1, 10, 1440)) {
            val preview = CourseLiveCard.previewOccurrence(course, now, 7, lead, true)
            val card = CourseLiveCard.create(course, preview, now, 7, preview = true, zone = zone)
            assertTrue(card.metadata.startsWith("预览 · 快下课"))
            assertEquals(now + lead * 60_000L, card.countdownTo)
            assertTrue(card.critical.endsWith("下课"))
            if (lead == 1440) assertTrue(card.headline.contains("次日"))
        }
    }
}
