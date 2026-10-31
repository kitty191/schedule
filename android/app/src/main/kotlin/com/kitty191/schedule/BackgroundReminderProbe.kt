package com.kitty191.schedule

import android.app.AlarmManager
import android.content.Context
import android.os.Build

/** A temporary course through the production planner/receiver, never the database. */
object BackgroundReminderProbe {
    const val COURSE_ID = -107
    private const val MINUTE = 60_000L
    private fun prefs(context: Context) = context.getSharedPreferences("background_reminder_probe", Context.MODE_PRIVATE)

    fun arm(context: Context) {
        val alarms = context.getSystemService(AlarmManager::class.java)
        check(Build.VERSION.SDK_INT < 31 || alarms.canScheduleExactAlarms()) { "请先允许准时提醒，再进行后台测试。" }
        check(LiveUpdateNotification.status(context)["notificationsEnabled"] == true) { "请先允许通知，再进行后台测试。" }
        val now = System.currentTimeMillis()
        check(CourseScheduler.canRunProbe(context, now + 4 * MINUTE)) { "接下来 4 分钟有课程提醒或预览，请稍后再测试。" }
        check(prefs(context).edit().clear()
            .putLong("start", now + 2 * MINUTE).putLong("end", now + 4 * MINUTE).commit())
        CourseScheduler.refresh(context)
    }

    fun cancel(context: Context) {
        check(prefs(context).edit().putBoolean("cancelled", true).commit())
        CourseScheduler.refresh(context)
    }

    private fun boundaries(context: Context): List<Long> {
        val preferences = prefs(context)
        val start = preferences.getLong("start", 0)
        val end = preferences.getLong("end", 0)
        if (start == 0L || preferences.getBoolean("cancelled", false)) return emptyList()
        return listOf(start - MINUTE, start, end - MINUTE, end)
    }

    fun receive(context: Context, scheduledAt: Long, now: Long) {
        if (scheduledAt !in boundaries(context)) return
        val preferences = prefs(context)
        val received = preferences.getStringSet("received", emptySet()).orEmpty() + scheduledAt.toString()
        check(preferences.edit().putStringSet("received", received)
            .putLong("lastWakeAt", now).putLong("lastScheduledAt", scheduledAt).commit())
    }

    fun plan(context: Context, now: Long): CoursePlan {
        val preferences = prefs(context)
        val start = preferences.getLong("start", 0)
        val end = preferences.getLong("end", 0)
        if (start == 0L || end <= now || preferences.getBoolean("cancelled", false)) return CoursePlan(null, null)
        val course = CourseSpec(COURSE_ID, "后台自动提醒测试", "临时测试，不保存到课表", 1, 480, 482,
            fixedOccurrences = listOf(start to end), leadMinutes = 1)
        val realPreferences = context.getSharedPreferences("course_reminders", Context.MODE_PRIVATE)
        val plan = CoursePlanner.plan(listOf(course), now, 1, endingLeadMinutes = 1,
            dismissedKeys = realPreferences.getStringSet("dismissedKeys", emptySet()).orEmpty(),
            dismissedEndingKeys = realPreferences.getStringSet("dismissedEndingKeys", emptySet()).orEmpty(),
            announcedEndingKeys = realPreferences.getStringSet("endingAnnouncedKeys", emptySet()).orEmpty())
        // UI/onResume must never generate the first test notification. Only a
        // recorded production alarm callback unlocks this temporary course.
        return if (preferences.getStringSet("received", emptySet()).orEmpty().isEmpty()) plan.copy(active = null) else plan
    }

    fun recordPost(context: Context, posted: Boolean) {
        check(prefs(context).edit().putBoolean("posted", posted).putLong("postAt", System.currentTimeMillis()).commit())
    }

    fun status(context: Context): Map<String, Any> {
        val preferences = prefs(context)
        val start = preferences.getLong("start", 0)
        if (start == 0L) return emptyMap()
        val end = preferences.getLong("end", 0)
        return mutableMapOf<String, Any>(
            "probeDueAt" to start - MINUTE,
            "probeUntil" to end,
            "probeCancelled" to preferences.getBoolean("cancelled", false),
            "probeCallbackCount" to preferences.getStringSet("received", emptySet()).orEmpty().size,
        ).apply {
            if (preferences.contains("lastWakeAt")) {
                put("probeLastWakeAt", preferences.getLong("lastWakeAt", 0))
                put("probeLastScheduledAt", preferences.getLong("lastScheduledAt", 0))
            }
            if (preferences.contains("posted")) put("probePosted", preferences.getBoolean("posted", false))
        }
    }
}
