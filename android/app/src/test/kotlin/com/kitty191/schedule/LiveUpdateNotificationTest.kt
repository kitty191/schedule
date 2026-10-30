package com.kitty191.schedule

import android.Manifest
import android.app.Activity
import android.app.Application
import android.app.Notification
import android.app.NotificationManager
import android.content.Context
import android.os.Looper
import android.view.View
import android.view.ViewGroup
import android.widget.Chronometer
import android.widget.FrameLayout
import java.time.Duration
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config
import org.robolectric.shadows.ShadowSystem
import org.robolectric.shadows.ShadowSystemClock

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
        assertEquals("收起提醒", notification.actions.single().title)
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
        assertNull(notification.shortCriticalText)
        assertTrue(notification.extras.getBoolean(Notification.EXTRA_SHOW_WHEN))
        assertEquals(5 * 60_000L, notification.timeoutAfter)
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

    @Test @Config(sdk = [36, 37]) fun nativeTimerTicksWithoutRepostingOrOpeningTheNotification() =
        assertSystemTimerKeepsTime(sleep = false)

    @Test @Config(sdk = [36, 37]) fun nativeTimerCatchesUpAfterSleepWithoutAppRefreshOrExpansion() =
        assertSystemTimerKeepsTime(sleep = true)

    private fun assertSystemTimerKeepsTime(sleep: Boolean) {
        // Framework classes use Robolectric's virtual wall clock, unlike test JVM code.
        val postedAt = ShadowSystem.currentTimeMillis()
        val instance = CourseOccurrence(course, postedAt + 14 * 60_000, postedAt + 99 * 60_000)
        val card = CourseLiveCard.create(course, instance, postedAt, 20)
        val notification = LiveUpdateNotification.buildNotification(
            RuntimeEnvironment.getApplication(), card, instance.end, postedAt)
        assertNull(notification.shortCriticalText)
        // Render the system's ordinary collapsed notification view in a test host.
        // No app resume, scheduler refresh, notification repost or expansion is performed.
        val host = Robolectric.buildActivity(Activity::class.java).setup()
        try {
            val activity = host.get()
            val view = Notification.Builder.recoverBuilder(activity, notification)
                .createContentView().apply(activity, FrameLayout(activity))
            activity.setContentView(view)
            host.visible().windowFocusChanged(true)
            // SystemUI supplies this window event on a device; the test host has
            // no real window manager to transition its window out of GONE.
            activity.window.decorView.dispatchWindowVisibilityChanged(View.VISIBLE)
            fun findTimer(view: View): Chronometer? {
                if (view is Chronometer) return view
                if (view is ViewGroup) for (index in 0 until view.childCount) {
                    findTimer(view.getChildAt(index))?.let { return it }
                }
                return null
            }
            val timer = checkNotNull(findTimer(view)) { "System notification has no chronometer" }
            assertEquals(View.VISIBLE, timer.visibility)
            assertTrue(timer.isCountDown)
            fun seconds(): Int = timer.text.toString().trim().split(':').fold(0) { sum, part -> sum * 60 + part.toInt() }
            shadowOf(Looper.getMainLooper()).idleFor(Duration.ofSeconds(1))
            val before = seconds()
            assertTrue("Expected about fourteen minutes remaining, got $before seconds", before in 837..840)
            if (sleep) {
                activity.window.decorView.dispatchWindowVisibilityChanged(View.GONE)
                ShadowSystemClock.simulateDeepSleep(Duration.ofMinutes(6))
                activity.window.decorView.dispatchWindowVisibilityChanged(View.VISIBLE)
                shadowOf(Looper.getMainLooper()).idleFor(Duration.ofSeconds(1))
            } else shadowOf(Looper.getMainLooper()).idleFor(Duration.ofMinutes(6))
            val after = seconds()
            assertTrue("Timer did not advance by six minutes: $before -> $after", before - after in 359..361)
            assertTrue("Expected about eight minutes remaining, got $after seconds", after in 477..480)
            assertEquals(instance.start, notification.`when`)
        } finally {
            host.pause().stop().destroy()
        }
    }

    @Test fun eachPhaseKeepsTheSameAbsoluteTargetUntilTheClassStarts() {
        val start = now + 14 * 60_000
        val instance = CourseOccurrence(course, start, start + 85 * 60_000)
        for (at in listOf(now, now + 6 * 60_000, start, instance.end - 10 * 60_000)) {
            val card = CourseLiveCard.create(course, instance, at, 20)
            val notification = LiveUpdateNotification.buildNotification(
                RuntimeEnvironment.getApplication(), card, instance.end, at)
            assertNull(notification.shortCriticalText)
            assertTrue(notification.extras.getBoolean(Notification.EXTRA_SHOW_CHRONOMETER))
            assertTrue(notification.extras.getBoolean(Notification.EXTRA_CHRONOMETER_COUNT_DOWN))
            assertEquals(if (at < start) start else instance.end, notification.`when`)
            assertEquals((if (at < start) start else instance.end) - at, notification.timeoutAfter)
        }
    }

    @Test @Config(sdk = [26, 36, 37]) fun preClassExpiryMatchesTheTimerEvenWithoutAnyBoundaryCallback() {
        val start = now + 8 * 60_000
        val instance = CourseOccurrence(course, start, start + 85 * 60_000)
        // A minute refresh must keep the absolute expiry fixed at the start.
        // No scheduler callback runs at start or in the eight minutes afterwards.
        for (at in listOf(now, start - 30_000, start - 1)) {
            val card = CourseLiveCard.create(course, instance, at, 10)
            val posted = LiveUpdateNotification.buildNotification(
                RuntimeEnvironment.getApplication(), card, instance.end, at)
            assertEquals(start, at + posted.timeoutAfter)
            assertEquals(start, posted.`when`)
            assertTrue(at + posted.timeoutAfter < start + 8 * 60_000)
        }
        // Short previews still expire first, even when the class starts later.
        val card = CourseLiveCard.create(course, instance, now, 10, preview = true)
        val preview = LiveUpdateNotification.buildNotification(
            RuntimeEnvironment.getApplication(), card, now + 60_000, now, preview = true)
        assertEquals(60_000, preview.timeoutAfter)
    }

    @Test fun expiredCourseAndExpiredPreviewCannotPostAZeroTimer() {
        val application = RuntimeEnvironment.getApplication()
        shadowOf(application).grantPermissions(Manifest.permission.POST_NOTIFICATIONS)
        val expired = CourseOccurrence(course, now - 90 * 60_000, now)
        assertFalse(LiveUpdateNotification.show(application, course, expired, expired.end, now = now))
        val future = CourseOccurrence(course, now + 10 * 60_000, now + 100 * 60_000)
        assertFalse(LiveUpdateNotification.show(application, course, future, now - 1, preview = true, now = now))
        assertTrue(application.getSystemService(NotificationManager::class.java).activeNotifications.isEmpty())
    }

    @Test fun updatingAnOldPinnedReminderRemovesTheStaleChipText() {
        val application = RuntimeEnvironment.getApplication()
        shadowOf(application).grantPermissions(Manifest.permission.POST_NOTIFICATIONS)
        val postedAt = System.currentTimeMillis()
        val instance = CourseOccurrence(course, postedAt + 8 * 60_000, postedAt + 93 * 60_000)
        assertTrue(LiveUpdateNotification.show(application, course, instance, instance.end))
        val manager = application.getSystemService(NotificationManager::class.java)
        val original = manager.activeNotifications.single()
        val pinned = Notification.Builder.recoverBuilder(application, original.notification)
            .setShortCriticalText("14分上课").build()
        manager.notify(original.id, pinned)
        assertEquals("14分上课", manager.activeNotifications.single().notification.shortCriticalText)
        assertTrue(LiveUpdateNotification.show(application, course, instance, instance.end))
        val refreshed = manager.activeNotifications.single().notification
        assertNull(refreshed.shortCriticalText)
        assertEquals(instance.start, refreshed.`when`)
        assertTrue(refreshed.hasPromotableCharacteristics())
    }
}
