package com.kitty191.schedule

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import org.json.JSONArray
import org.json.JSONObject

object CourseScheduler {
    private fun prefs(context: Context) = context.getSharedPreferences("course_reminders", Context.MODE_PRIVATE)
    private fun alarmIntent(context: Context) = PendingIntent.getBroadcast(
        context, 1010, Intent(context, CourseAlarmReceiver::class.java),
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
    )

    fun parseCourse(value: JSONObject): CourseSpec {
        val course = CourseSpec(
            value.getInt("id"), value.getString("name").trim(), value.optString("location"),
            value.getInt("weekday"), value.getInt("startMinute"), value.getInt("endMinute"),
        )
        require(course.name.isNotEmpty() && course.name.length <= 60)
        require(course.weekday in 1..7 && course.startMinute in 0..1438 &&
            course.endMinute in 1..1439 && course.endMinute > course.startMinute)
        return course
    }

    fun configure(context: Context, data: Map<*, *>) {
        val courses = JSONArray(data["courses"] as? List<*> ?: emptyList<Any>())
        for (i in 0 until courses.length()) parseCourse(courses.getJSONObject(i))
        val lead = (data["leadMinutes"] as? Number)?.toInt() ?: 10
        require(lead in listOf(5, 10, 15, 30))
        check(prefs(context).edit()
            .putString("courses", courses.toString())
            .putBoolean("enabled", data["enabled"] == true)
            .putInt("lead", lead)
            .remove("preview").remove("previewUntil")
            .commit()) { "系统提醒配置未能保存，请重试。" }
        refresh(context)
    }

    fun preview(context: Context, course: Map<*, *>) {
        val value = JSONObject(course)
        parseCourse(value)
        val until = System.currentTimeMillis() + 5 * 60_000L
        check(prefs(context).edit().putString("preview", value.toString())
            .putLong("previewUntil", until).commit())
        refresh(context)
    }

    fun stop(context: Context) {
        val occurrence = currentPlan(context).active
        check(prefs(context).edit().remove("preview").remove("previewUntil")
            .putString("dismissed", occurrence?.key).commit())
        LiveUpdateNotification.cancel(context)
        refresh(context)
    }

    private fun currentPlan(context: Context): CoursePlan {
        val preferences = prefs(context)
        if (!preferences.getBoolean("enabled", false)) return CoursePlan(null, null)
        val stored = JSONArray(preferences.getString("courses", "[]"))
        val courses = (0 until stored.length()).map { parseCourse(stored.getJSONObject(it)) }
        return CoursePlanner.plan(courses, System.currentTimeMillis(),
            preferences.getInt("lead", 10), preferences.getString("dismissed", null))
    }

    fun refresh(context: Context) {
        val preferences = prefs(context)
        val now = System.currentTimeMillis()
        val previewUntil = preferences.getLong("previewUntil", 0)
        val preview = preferences.getString("preview", null)
        val plan = currentPlan(context)
        var next = plan.nextWake
        if (preview != null && previewUntil > now) {
            LiveUpdateNotification.show(context, parseCourse(JSONObject(preview)), null, previewUntil)
            next = previewUntil
        } else {
            if (preview != null) preferences.edit().remove("preview").remove("previewUntil").apply()
            val active = plan.active
            if (active == null) LiveUpdateNotification.cancel(context)
            else LiveUpdateNotification.show(context, active.course, active, active.end)
        }
        val manager = context.getSystemService(AlarmManager::class.java)
        val pending = alarmIntent(context)
        manager.cancel(pending)
        if (next != null) {
            try {
                if (Build.VERSION.SDK_INT < 31 || manager.canScheduleExactAlarms()) {
                    manager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, next, pending)
                } else {
                    manager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, next, pending)
                }
            } catch (_: SecurityException) {
                // Permission can change between canScheduleExactAlarms and scheduling.
                manager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, next, pending)
            }
        }
    }
}

class CourseAlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        CourseScheduler.refresh(context)
    }
}

class ScheduleRestoreReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action in setOf(
                Intent.ACTION_BOOT_COMPLETED, Intent.ACTION_MY_PACKAGE_REPLACED,
                Intent.ACTION_TIME_CHANGED, Intent.ACTION_TIMEZONE_CHANGED,
                "android.app.action.SCHEDULE_EXACT_ALARM_PERMISSION_STATE_CHANGED",
            )) {
            CourseScheduler.refresh(context)
        }
    }
}
