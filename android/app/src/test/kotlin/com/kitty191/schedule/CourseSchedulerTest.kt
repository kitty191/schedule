package com.kitty191.schedule

import android.Manifest
import android.app.AlarmManager
import android.app.Application
import android.app.Notification
import android.app.NotificationManager
import android.app.NotificationChannel
import android.content.Context
import android.content.Intent
import android.os.SystemClock
import android.os.Looper
import java.time.Duration
import java.util.Calendar
import java.util.TimeZone
import org.junit.Assert.*
import org.junit.Before
import org.junit.After
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config
import org.robolectric.shadows.ShadowSystem
import org.robolectric.shadows.ShadowSystemClock
import org.robolectric.shadows.ShadowAlarmManager

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [37], application = Application::class,
    instrumentedPackages = ["com.kitty191.schedule"])
class CourseSchedulerTest {
    private val context get() = RuntimeEnvironment.getApplication()
    private val notifications get() = context.getSystemService(NotificationManager::class.java)
    private val alarms get() = context.getSystemService(AlarmManager::class.java)
    private val preferences get() = context.getSharedPreferences("course_reminders", Context.MODE_PRIVATE)
    private val zone = TimeZone.getTimeZone("Asia/Shanghai")
    private fun at(hour: Int, minute: Int) = Calendar.getInstance(zone).apply {
        clear(); set(2026, Calendar.OCTOBER, 30, hour, minute)
    }.timeInMillis

    private lateinit var previousZone: TimeZone
    @Before fun setup() {
        previousZone = TimeZone.getDefault()
        TimeZone.setDefault(zone)
        shadowOf(context).grantPermissions(Manifest.permission.POST_NOTIFICATIONS)
        ShadowAlarmManager.setCanScheduleExactAlarms(true)
        ShadowAlarmManager.setAutoSchedule(false)
        SystemClock.setCurrentTimeMillis(at(7,30))
    }

    @After fun restoreZone() { TimeZone.setDefault(previousZone) }

    private fun course(fixed: Boolean = true, event: Boolean = false): Map<String, Any> = mutableMapOf<String, Any>(
        "id" to 1, "name" to "大学物理", "location" to "C6-104", "weekday" to 5,
        "startMinute" to 480, "endMinute" to 565, "kind" to if (event) "event" else "course",
    ).apply { if (fixed) put("occurrences", listOf(mapOf("start" to at(8,0), "end" to at(9,25)))) }

    private fun configure(endingLead: Int = 10, fixed: Boolean = true, event: Boolean = false) =
        CourseScheduler.configure(context, mapOf("enabled" to true, "leadMinutes" to 10,
            "endingLeadMinutes" to endingLead, "courses" to listOf(course(fixed, event))))

    private fun advanceTo(hour: Int, minute: Int) = ShadowSystemClock.advanceBy(
        Duration.ofMillis(at(hour,minute) - ShadowSystem.currentTimeMillis()))

    private fun deliverAt(hour: Int, minute: Int, wake: Boolean = true) {
        val target = at(hour,minute)
        val alarm = shadowOf(alarms).scheduledAlarms.first {
            it.triggerAtTime == target && it.type == if (wake) AlarmManager.RTC_WAKEUP else AlarmManager.RTC
        }
        advanceTo(hour,minute)
        checkNotNull(alarm.operation).send()
        shadowOf(Looper.getMainLooper()).idle()
    }

    private fun closeCurrentCloud() {
        checkNotNull(notifications.activeNotifications.single().notification.deleteIntent).send()
        shadowOf(Looper.getMainLooper()).idle()
    }

    @Test fun schedulerClockIsControlledByTheFrameworkTestClock() {
        assertEquals(at(7,30), ShadowSystem.currentTimeMillis())
        configure()
        assertTrue(notifications.activeNotifications.isEmpty())
        val endingChannel = checkNotNull(notifications.getNotificationChannel("course_ending_alerts_v1"))
        assertEquals(NotificationManager.IMPORTANCE_HIGH, endingChannel.importance)
        assertNull(endingChannel.sound)
        assertFalse(endingChannel.shouldVibrate())
        val first = shadowOf(alarms).scheduledAlarms.minBy { it.triggerAtTime }
        assertEquals(at(7,50), first.triggerAtTime)
        ShadowSystemClock.advanceBy(Duration.ofMinutes(20))
        checkNotNull(first.operation).send()
        shadowOf(Looper.getMainLooper()).idle()
        assertEquals(at(8,0), notifications.activeNotifications.single().notification.`when`)
    }

    @Test @Config(sdk = [36,37]) fun endingBoundaryPostsAFreshVisibleReminderWithoutOpeningTheApp() {
        configure()
        deliverAt(7,50)
        val before = notifications.activeNotifications.single()
        deliverAt(9,15)
        val ending = notifications.activeNotifications.single()
        assertNotEquals("Ending reminder reused the ongoing notification", before.id, ending.id)
        assertTrue(ending.notification.extras.getCharSequence(Notification.EXTRA_TITLE).toString().contains("快下课"))
        assertTrue(notifications.getNotificationChannel(ending.notification.channelId).importance >= NotificationManager.IMPORTANCE_HIGH)
        assertEquals(at(9,25), ending.notification.`when`)
        assertEquals(0, ending.notification.flags and Notification.FLAG_ONLY_ALERT_ONCE)
        assertNull(ending.notification.shortCriticalText)
    }

    @Test @Config(sdk = [36,37]) fun dismissingThePreClassCloudStillDeliversTheScheduledEndingReminder() {
        configure()
        deliverAt(7,50)
        closeCurrentCloud()
        assertTrue(notifications.activeNotifications.isEmpty())
        assertEquals(at(9,15), CourseScheduler.endingStatus(context)["nextEndingAt"])
        deliverAt(9,15)
        assertTrue(notifications.activeNotifications.single().notification.extras
            .getCharSequence(Notification.EXTRA_TITLE).toString().contains("快下课"))
        assertEquals(at(9,15), CourseScheduler.endingStatus(context)["lastEndingAt"])
        assertEquals(true, CourseScheduler.endingStatus(context)["lastEndingPosted"])
    }

    @Test fun anEndingReminderAlertsOnceSurvivesRestoreAndDoesNotReturnAfterDismissal() {
        configure()
        deliverAt(7,50)
        closeCurrentCloud()
        deliverAt(9,15)
        val first = notifications.activeNotifications.single()
        deliverAt(9,16,wake=false)
        assertEquals(first.id, notifications.activeNotifications.single().id)
        assertTrue(notifications.activeNotifications.single().notification.flags and Notification.FLAG_ONLY_ALERT_ONCE != 0)
        assertEquals(at(9,15), CourseScheduler.endingStatus(context)["lastEndingAt"])
        ScheduleRestoreReceiver().onReceive(context, Intent(Intent.ACTION_BOOT_COMPLETED))
        assertTrue(notifications.activeNotifications.single().notification.flags and Notification.FLAG_ONLY_ALERT_ONCE != 0)
        closeCurrentCloud()
        CourseAlarmReceiver().onReceive(context, Intent())
        assertTrue(notifications.activeNotifications.isEmpty())
        assertTrue(shadowOf(alarms).scheduledAlarms.isEmpty())
    }

    @Test fun minuteRefreshCannotQuietlyOverwriteTheEndingBoundaryAlert() {
        configure()
        deliverAt(7,50)
        advanceTo(9,14)
        CourseAlarmReceiver().onReceive(context, Intent())
        val atBoundary = shadowOf(alarms).scheduledAlarms.filter { it.triggerAtTime == at(9,15) }
        assertEquals(1, atBoundary.size)
        assertEquals(AlarmManager.RTC_WAKEUP, atBoundary.single().type)
        deliverAt(9,15)
        assertEquals(0, notifications.activeNotifications.single().notification.flags and Notification.FLAG_ONLY_ALERT_ONCE)
    }

    @Test fun manualWeeklyCoursesUseTheSameIndependentEndingAlarm() {
        configure(fixed=false)
        deliverAt(7,50)
        closeCurrentCloud()
        deliverAt(9,15)
        assertEquals(at(9,25), notifications.activeNotifications.single().notification.`when`)
    }

    @Test fun customEndingLeadUsesTheConfiguredWakeBoundaryAndEndsAtClassEnd() {
        configure(endingLead=7)
        deliverAt(7,50)
        closeCurrentCloud()
        deliverAt(9,18)
        assertEquals(at(9,18), CourseScheduler.endingStatus(context)["lastEndingAt"])
        deliverAt(9,25)
        assertTrue(notifications.activeNotifications.isEmpty())
        assertTrue(shadowOf(alarms).scheduledAlarms.isEmpty())
    }

    @Test fun longerThanClassEndingLeadStartsAtClassStartInsteadOfBeforeIt() {
        configure(endingLead=1440)
        deliverAt(7,50)
        assertFalse(notifications.activeNotifications.single().notification.extras
            .getCharSequence(Notification.EXTRA_TITLE).toString().contains("快下课"))
        deliverAt(8,0)
        assertTrue(notifications.activeNotifications.single().notification.extras
            .getCharSequence(Notification.EXTRA_TITLE).toString().contains("快下课"))
    }

    @Test fun deniedNotificationsRecordAFailureAndDoNotConsumeTheEndingAnnouncement() {
        configure()
        deliverAt(7,50)
        closeCurrentCloud()
        shadowOf(context).denyPermissions(Manifest.permission.POST_NOTIFICATIONS)
        deliverAt(9,15)
        assertTrue(notifications.activeNotifications.isEmpty())
        assertEquals(false, CourseScheduler.endingStatus(context)["lastEndingPosted"])
        assertTrue(preferences.getStringSet("endingAnnouncedKeys", emptySet()).orEmpty().isEmpty())
        shadowOf(context).grantPermissions(Manifest.permission.POST_NOTIFICATIONS)
        deliverAt(9,16,wake=false)
        assertEquals(true, CourseScheduler.endingStatus(context)["lastEndingPosted"])
        assertEquals(0, notifications.activeNotifications.single().notification.flags and Notification.FLAG_ONLY_ALERT_ONCE)
    }

    @Test fun blockedEndingChannelIsReportedAndItsUserSettingIsNotOverwritten() {
        notifications.createNotificationChannel(NotificationChannel("course_ending_alerts_v1", "下课前提示", NotificationManager.IMPORTANCE_NONE))
        configure()
        deliverAt(7,50)
        closeCurrentCloud()
        deliverAt(9,15)
        assertTrue(notifications.activeNotifications.isEmpty())
        assertEquals(false, LiveUpdateNotification.status(context)["endingNotificationsEnabled"])
        assertEquals(false, CourseScheduler.endingStatus(context)["lastEndingPosted"])
        assertEquals(NotificationManager.IMPORTANCE_NONE, notifications.getNotificationChannel("course_ending_alerts_v1").importance)
    }

    @Test fun eventsHaveNoEndingReminderAndDisablingCancelsAllCloudsAndAlarms() {
        configure(event=true)
        assertNull(CourseScheduler.endingStatus(context)["nextEndingAt"])
        deliverAt(7,50)
        CourseScheduler.configure(context, mapOf("enabled" to false,"courses" to emptyList<Any>()))
        assertTrue(notifications.activeNotifications.isEmpty())
        assertTrue(shadowOf(alarms).scheduledAlarms.isEmpty())
    }

    @Test fun missingExactPermissionStillSchedulesAWakeupAndReportsTheLimitation() {
        ShadowAlarmManager.setCanScheduleExactAlarms(false)
        configure()
        val first = shadowOf(alarms).scheduledAlarms.single()
        assertEquals(AlarmManager.RTC_WAKEUP, first.type)
        assertNotEquals(ShadowAlarmManager.WINDOW_EXACT, first.windowLengthMs)
        assertEquals(false, LiveUpdateNotification.status(context)["exactAllowed"])
    }

    @Test fun aStaleCloseActionFromTheRegularCloudCannotDismissTheNewEndingAlert() {
        configure()
        deliverAt(7,50)
        val staleClose = checkNotNull(notifications.activeNotifications.single().notification.deleteIntent)
        deliverAt(9,15)
        staleClose.send()
        shadowOf(Looper.getMainLooper()).idle()
        val ending = notifications.activeNotifications.single().notification
        assertTrue(ending.extras.getCharSequence(Notification.EXTRA_TITLE).toString().contains("快下课"))
        assertEquals(0, ending.flags and Notification.FLAG_ONLY_ALERT_ONCE)
        assertTrue(preferences.getStringSet("dismissedEndingKeys",emptySet()).orEmpty().isEmpty())
    }

    @Test fun anUnrelatedLongClassCannotOccupyTheEndingReminderSlot() {
        val long = course().toMutableMap().apply {
            put("id",2); put("name","较早开始的长课"); put("startMinute",470); put("endMinute",600)
            put("occurrences",listOf(mapOf("start" to at(7,50),"end" to at(10,0))))
        }
        CourseScheduler.configure(context,mapOf("enabled" to true,"courses" to listOf(long,course())))
        deliverAt(7,40)
        deliverAt(7,50)
        deliverAt(9,15)
        assertEquals("快下课 · 大学物理", notifications.activeNotifications.single().notification.extras
            .getCharSequence(Notification.EXTRA_TITLE).toString())
    }

    @Test fun aRealEndingBoundaryPreemptsAnUnrelatedPreview() {
        configure()
        deliverAt(7,50)
        advanceTo(9,14)
        CourseScheduler.preview(context,course().toMutableMap().apply { put("name","正在测试的课程") })
        val stalePreview = checkNotNull(notifications.activeNotifications.single().notification.deleteIntent)
        deliverAt(9,15)
        assertFalse(preferences.contains("preview"))
        stalePreview.send()
        shadowOf(Looper.getMainLooper()).idle()
        assertEquals("快下课 · 大学物理", notifications.activeNotifications.single().notification.extras
            .getCharSequence(Notification.EXTRA_TITLE).toString())
    }

    @Test @Config(sdk = [24]) fun endingReminderFallsBackToOrdinaryHighPriorityNotificationOnOldAndroid() {
        configure()
        deliverAt(7,50)
        closeCurrentCloud()
        deliverAt(9,15)
        val ending = notifications.activeNotifications.single().notification
        assertEquals(Notification.PRIORITY_HIGH, ending.priority)
        assertTrue(ending.extras.getCharSequence(Notification.EXTRA_BIG_TEXT).toString().contains("快下课"))
        deliverAt(9,25)
        assertTrue(notifications.activeNotifications.isEmpty())
    }

    @Test fun anAlreadyShownEndingCloudCannotSuppressAnotherCoursesNewEndingBoundary() {
        val second = course().toMutableMap().apply {
            put("id",2); put("name","另一门课"); put("startMinute",510); put("endMinute",570)
            put("occurrences",listOf(mapOf("start" to at(8,30),"end" to at(9,30))))
        }
        CourseScheduler.configure(context,mapOf("enabled" to true,"courses" to listOf(course(),second)))
        deliverAt(7,50)
        deliverAt(8,20)
        deliverAt(9,15)
        deliverAt(9,20)
        assertEquals("快下课 · 另一门课", notifications.activeNotifications.single().notification.extras
            .getCharSequence(Notification.EXTRA_TITLE).toString())
        assertEquals(0, notifications.activeNotifications.single().notification.flags and Notification.FLAG_ONLY_ALERT_ONCE)
        assertEquals(2, preferences.getStringSet("endingAnnouncedKeys",emptySet()).orEmpty().size)
        checkNotNull(notifications.activeNotifications.single().notification.actions.single().actionIntent).send()
        shadowOf(Looper.getMainLooper()).idle()
        assertEquals("快下课 · 大学物理", notifications.activeNotifications.single().notification.extras
            .getCharSequence(Notification.EXTRA_TITLE).toString())
        assertEquals(1, preferences.getStringSet("dismissedEndingKeys",emptySet()).orEmpty().size)
    }

    @Test fun closingTheVisibleRegularCloudAtTheBoundaryDoesNotCancelTheNotYetPostedEndingAlert() {
        configure()
        deliverAt(7,50)
        advanceTo(9,15)
        CourseScheduler.stop(context)
        assertEquals("快下课 · 大学物理", notifications.activeNotifications.single().notification.extras
            .getCharSequence(Notification.EXTRA_TITLE).toString())
        assertTrue(preferences.getStringSet("dismissedEndingKeys",emptySet()).orEmpty().isEmpty())
    }
}
