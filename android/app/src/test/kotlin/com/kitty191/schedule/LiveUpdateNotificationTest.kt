package com.kitty191.schedule

import android.app.Application
import android.app.Notification
import android.content.Context
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [37], application = Application::class)
class LiveUpdateNotificationTest {
    private val course = CourseSpec(1, "大学英语", "B402", 4, 510, 600)
    private val now = 1_800_000_000_000L
    private fun notification(lead: Int = 10, alert: Boolean = false): Notification {
        val occurrence = CourseOccurrence(course, now + 5 * 60_000, now + 95 * 60_000)
        val card = CourseLiveCard.create(course, occurrence, now, lead)
        return LiveUpdateNotification.buildNotification(RuntimeEnvironment.getApplication(), card, occurrence.end, now, alert)
    }

    @Test fun richProgressTemplateRetainsPlatformPromotionEligibility() {
        val notification = notification()
        assertTrue(notification.hasPromotableCharacteristics())
        assertEquals("android.app.Notification\$ProgressStyle", notification.extras.getString(Notification.EXTRA_TEMPLATE))
        assertTrue(notification.extras.getBoolean("android.requestPromotedOngoing"))
        assertTrue(notification.flags and Notification.FLAG_ONGOING_EVENT != 0)
        assertFalse(notification.extras.getBoolean(Notification.EXTRA_COLORIZED))
        assertNull(notification.contentView)
        assertNull(notification.bigContentView)
        assertNotNull(notification.deleteIntent)
        assertNotNull(notification.contentIntent)
        assertEquals("结束提醒", notification.actions.single().title)
    }
    @Test fun segmentsMilestoneTrackerAndCountdownSurviveBuildingNotification() {
        val notification = notification()
        val builder = Notification.Builder.recoverBuilder(RuntimeEnvironment.getApplication(), notification)
        val style = builder.style as Notification.ProgressStyle
        assertEquals(1000, style.progressMax)
        assertEquals(50, style.progress)
        assertEquals(listOf(100, 900), style.progressSegments.map { it.length })
        assertEquals(listOf(100), style.progressPoints.map { it.position })
        assertNotNull(style.progressTrackerIcon)
        assertFalse(style.isStyledByProgress)
        assertEquals(now + 5 * 60_000, notification.`when`)
        assertTrue(notification.extras.getBoolean(Notification.EXTRA_SHOW_CHRONOMETER))
        assertTrue(notification.extras.getBoolean(Notification.EXTRA_CHRONOMETER_COUNT_DOWN))
        assertEquals("5分上课", notification.shortCriticalText)
        assertEquals(95 * 60_000L, notification.timeoutAfter)
        assertTrue(notification.extras.getCharSequence(Notification.EXTRA_TEXT).toString().contains("大学英语 · B402"))
    }
    @Test fun cosmeticsStaySilentAndOnlyTheEndingTransitionCanAlertAgain() {
        assertTrue(notification().flags and Notification.FLAG_ONLY_ALERT_ONCE != 0)
        assertEquals(0, notification(alert = true).flags and Notification.FLAG_ONLY_ALERT_ONCE)
    }
    @Test @Config(sdk = [36]) fun firstAndroid16ReleaseUsesItsLegacyEligibilityRequirement() {
        val notification = notification()
        assertTrue(notification.hasPromotableCharacteristics())
        assertTrue(notification.extras.getBoolean(Notification.EXTRA_COLORIZED))
        assertTrue(notification.extras.getBoolean("android.requestPromotedOngoing"))
        assertEquals("island_test_live_updates", notification.channelId)
        assertEquals("android.app.Notification\$ProgressStyle", notification.extras.getString(Notification.EXTRA_TEMPLATE))
    }
    @Test @Config(sdk = [24]) fun oldestSupportedAndroidUsesReadableBigTextAndOrdinaryProgress() {
        val notification = notification()
        assertEquals("android.app.Notification\$BigTextStyle", notification.extras.getString(Notification.EXTRA_TEMPLATE))
        assertTrue(notification.extras.getCharSequence(Notification.EXTRA_BIG_TEXT).toString().contains("大学英语"))
        assertEquals(1000, notification.extras.getInt(Notification.EXTRA_PROGRESS_MAX))
        assertFalse(notification.extras.getBoolean("android.requestPromotedOngoing"))
    }

    @Test fun calendarConfigurationIsPersistedAndClearingSemesterRemovesOldValue() {
        val context = RuntimeEnvironment.getApplication()
        val preferences = context.getSharedPreferences("course_reminders", Context.MODE_PRIVATE)
        CourseScheduler.configure(context, mapOf("courses" to emptyList<Any>(), "weekStart" to 7,
            "semesterStart" to "2026-10-26"))
        assertEquals(7, preferences.getInt("weekStart", 0))
        assertEquals("2026-10-26", preferences.getString("semesterStart", null))
        CourseScheduler.configure(context, mapOf("courses" to emptyList<Any>(), "weekStart" to 1))
        assertFalse(preferences.contains("semesterStart"))
    }

    @Test fun oldPreviewSurvivingUpgradeGetsStableTimesAndCanBeStopped() {
        val context = RuntimeEnvironment.getApplication()
        val preferences = context.getSharedPreferences("course_reminders", Context.MODE_PRIVATE)
        val before = System.currentTimeMillis()
        preferences.edit().putString("preview",
            """{"id":1,"name":"大学英语","location":"B402","weekday":4,"startMinute":510,"endMinute":600}""")
            .putLong("previewUntil", before + 5 * 60_000).putLong("previewEndAt", 0).commit()
        CourseScheduler.refresh(context)
        val start = preferences.getLong("previewStartAt", 0)
        val end = preferences.getLong("previewEndAt", 0)
        assertTrue(start >= before + 10 * 60_000)
        assertEquals(90 * 60_000L, end - start)
        CourseScheduler.refresh(context)
        assertEquals(start, preferences.getLong("previewStartAt", 0))
        assertEquals(end, preferences.getLong("previewEndAt", 0))
        CourseScheduler.stop(context)
        assertFalse(preferences.contains("preview"))
        assertFalse(preferences.contains("previewStartAt"))
    }
}
