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
    private fun alarmIntent(context: Context, refresh: Boolean = false) = PendingIntent.getBroadcast(
        context, if (refresh) 1011 else 1010, Intent(context, CourseAlarmReceiver::class.java),
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
    )

    fun parseCourse(value: JSONObject): CourseSpec {
        val stored = value.optJSONArray("occurrences")
        require(stored == null || stored.length() <= 5000)
        val fixed = stored?.let { entries -> (0 until entries.length()).map {
            val item = entries.getJSONObject(it)
            val start = item.getLong("start")
            val end = item.getLong("end")
            require(end > start && end - start <= 24 * 60 * 60_000L)
            Pair(start, end)
        } }
        val lead = if (value.has("leadMinutes")) value.getInt("leadMinutes") else null
        require(lead == null || lead in 0..1440)
        val course = CourseSpec(
            value.getInt("id"), value.getString("name").trim(), value.optString("location"),
            value.getInt("weekday"), value.getInt("startMinute"), value.getInt("endMinute"),
            fixed, lead, value.optString("kind", "course"),
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
        val endingLead = (data["endingLeadMinutes"] as? Number)?.toInt() ?: 10
        require(lead in 1..1440 && endingLead in 1..1440)
        check(prefs(context).edit()
            .putString("courses", courses.toString())
            .putBoolean("enabled", data["enabled"] == true)
            .putInt("lead", lead)
            .putInt("endingLead", endingLead)
            .remove("preview").remove("previewUntil").remove("previewEndAt")
            .commit()) { "系统提醒配置未能保存，请重试。" }
        refresh(context)
    }

    fun preview(context: Context, course: Map<*, *>) {
        val value = JSONObject(course)
        parseCourse(value)
        val now = System.currentTimeMillis()
        val previewEndAt = if (course["previewEnding"] == true) now + prefs(context).getInt("endingLead", 10) * 60_000L else 0
        val until = if (previewEndAt > 0) minOf(now + 5 * 60_000L, previewEndAt) else now + 5 * 60_000L
        check(prefs(context).edit().putString("preview", value.toString())
            .putLong("previewUntil", until)
            .putLong("previewEndAt", previewEndAt)
            .commit())
        refresh(context)
    }

    fun stop(context: Context) {
        val preferences = prefs(context)
        val isPreview = preferences.getLong("previewUntil", 0) > System.currentTimeMillis()
        val occurrence = currentPlan(context).active
        val edit = preferences.edit().remove("preview").remove("previewUntil").remove("previewEndAt")
        if (!isPreview) edit.putString("dismissed", occurrence?.key)
        check(edit.commit())
        LiveUpdateNotification.cancel(context)
        refresh(context)
    }

    private fun currentPlan(context: Context): CoursePlan {
        val preferences = prefs(context)
        if (!preferences.getBoolean("enabled", false)) return CoursePlan(null, null)
        val stored = JSONArray(preferences.getString("courses", "[]"))
        val courses = (0 until stored.length()).map { parseCourse(stored.getJSONObject(it)) }
        return CoursePlanner.plan(courses, System.currentTimeMillis(),
            preferences.getInt("lead", 10), preferences.getString("dismissed", null),
            endingLeadMinutes = preferences.getInt("endingLead", 10))
    }

    fun refresh(context: Context) {
        val preferences = prefs(context)
        val now = System.currentTimeMillis()
        val previewUntil = preferences.getLong("previewUntil", 0)
        val preview = preferences.getString("preview", null)
        val plan = currentPlan(context)
        var next = plan.nextWake
        var nextRefresh = plan.nextRefresh
        if (preview != null && previewUntil > now) {
            LiveUpdateNotification.show(context, parseCourse(JSONObject(preview)), null, previewUntil,
                previewEndAt = preferences.getLong("previewEndAt", 0).takeIf { it > now },
                previewLeadMinutes = preferences.getInt("endingLead", 10))
            next = previewUntil
            nextRefresh = null
        } else {
            if (preview != null) preferences.edit().remove("preview").remove("previewUntil").remove("previewEndAt").apply()
            val active = plan.active
            if (active == null) LiveUpdateNotification.cancel(context)
            else {
                val newEnding = active.phase(now) == CoursePhase.ENDING_SOON &&
                    preferences.getString("endingAnnounced", null) != active.endingKey
                val posted = LiveUpdateNotification.show(context, active.course, active, active.end, alert = newEnding)
                if (posted && newEnding) preferences.edit().putString("endingAnnounced", active.endingKey).apply()
            }
        }
        val manager = context.getSystemService(AlarmManager::class.java)
        val pending = alarmIntent(context)
        manager.cancel(pending)
        val cosmetic = alarmIntent(context, refresh = true)
        manager.cancel(cosmetic)
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
        if (nextRefresh != null) {
            // RTC never wakes a sleeping phone. Live countdowns are rendered by
            // the system chronometer; these refreshes only update the awake UI.
            try {
                if (Build.VERSION.SDK_INT < 31 || manager.canScheduleExactAlarms()) {
                    manager.setExact(AlarmManager.RTC, nextRefresh, cosmetic)
                } else manager.set(AlarmManager.RTC, nextRefresh, cosmetic)
            } catch (_: SecurityException) {
                manager.set(AlarmManager.RTC, nextRefresh, cosmetic)
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
