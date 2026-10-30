package com.kitty191.schedule

import android.app.AlarmManager
import android.app.PendingIntent
import android.app.NotificationManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.net.Uri
import org.json.JSONArray
import org.json.JSONObject

object CourseScheduler {
    private fun prefs(context: Context) = context.getSharedPreferences("course_reminders", Context.MODE_PRIVATE)
    private fun recentKeys(keys: Set<String>, now: Long) = keys.filter {
        (it.substringAfter(':').substringBefore(':').toLongOrNull() ?: 0) > now - 24 * 60 * 60_000L
    }.toMutableSet()
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
            if (value.has("startPeriod")) value.getInt("startPeriod") else null,
            if (value.has("endPeriod")) value.getInt("endPeriod") else null,
        )
        require(course.name.isNotEmpty() && course.name.length <= 60)
        require(course.weekday in 1..7 && course.startMinute in 0..1438 &&
            course.endMinute in 1..1439 && course.endMinute > course.startMinute)
        require((course.startPeriod == null && course.endPeriod == null) ||
            (course.startPeriod != null && course.endPeriod != null &&
                course.startPeriod in 1..24 && course.endPeriod in course.startPeriod..24))
        return course
    }

    fun configure(context: Context, data: Map<*, *>) {
        val courses = JSONArray(data["courses"] as? List<*> ?: emptyList<Any>())
        for (i in 0 until courses.length()) parseCourse(courses.getJSONObject(i))
        val lead = (data["leadMinutes"] as? Number)?.toInt() ?: 10
        val endingLead = (data["endingLeadMinutes"] as? Number)?.toInt() ?: 10
        val weekStart = (data["weekStart"] as? Number)?.toInt() ?: 1
        require(lead in 1..1440 && endingLead in 1..1440 && weekStart in 1..7)
        check(prefs(context).edit()
            .putString("courses", courses.toString())
            .putBoolean("enabled", data["enabled"] == true)
            .putInt("lead", lead)
            .putInt("endingLead", endingLead)
            .putInt("weekStart", weekStart)
            .putString("semesterStart", data["semesterStart"] as? String)
            .remove("preview").remove("previewUntil").remove("previewStartAt").remove("previewEndAt").remove("previewAnnounced")
            .commit()) { "系统提醒配置未能保存，请重试。" }
        // Create the ending category before its first alert so users can inspect
        // and allow its banner in system settings in advance.
        LiveUpdateNotification.ensureChannels(context)
        refresh(context)
    }

    fun preview(context: Context, course: Map<*, *>) {
        val value = JSONObject(course)
        val spec = parseCourse(value)
        val now = System.currentTimeMillis()
        val preferences = prefs(context)
        val occurrence = CourseLiveCard.previewOccurrence(spec, now, preferences.getInt("lead", 10),
            preferences.getInt("endingLead", 10), course["previewEnding"] == true)
        val until = minOf(now + 5 * 60_000L, occurrence.end)
        check(prefs(context).edit().putString("preview", value.toString())
            .putLong("previewUntil", until)
            .putLong("previewStartAt", occurrence.start)
            .putLong("previewEndAt", occurrence.end)
            .putBoolean("previewAnnounced", false)
            .commit())
        refresh(context)
    }

    fun stop(context: Context, targetKey: String? = null, targetEnding: Boolean? = null,
        targetPreviewUntil: Long? = null) {
        val preferences = prefs(context)
        val now = System.currentTimeMillis()
        val visible = context.getSystemService(NotificationManager::class.java).activeNotifications
            .firstOrNull { it.notification.extras.containsKey(LiveUpdateNotification.DISMISSAL_KEY) }?.notification?.extras
        val visibleKey = visible?.getString(LiveUpdateNotification.DISMISSAL_KEY)
        if (targetKey == null && visibleKey != null) {
            // The displayed card can differ from a newly calculated priority at
            // a boundary or when several classes overlap. Close the visible one.
            stop(context, visibleKey, visible.getBoolean(LiveUpdateNotification.ENDING_PHASE),
                if (visible.containsKey(LiveUpdateNotification.PREVIEW_UNTIL)) visible.getLong(LiveUpdateNotification.PREVIEW_UNTIL) else null)
            return
        }
        val isPreview = preferences.getLong("previewUntil", 0) > now
        if (targetPreviewUntil != null && preferences.getLong("previewUntil", 0) != targetPreviewUntil) return
        val occurrence = currentPlan(context, now).active
        val closingPreview = targetPreviewUntil != null || (targetKey == null && isPreview)
        val edit = preferences.edit()
        if (closingPreview) edit.remove("preview").remove("previewUntil").remove("previewStartAt").remove("previewEndAt").remove("previewAnnounced")
        else {
            val ending = targetEnding ?: (occurrence?.phase(now) == CoursePhase.ENDING_SOON)
            val key = targetKey ?: occurrence?.let { if (ending) it.endingKey else it.key }
            val field = if (ending) "dismissedEndingKeys" else "dismissedKeys"
            val dismissed = recentKeys(preferences.getStringSet(field, emptySet()).orEmpty(), now)
            if (!ending) preferences.getString("dismissed", null)?.let { dismissed.add(it) }
            if (key != null) dismissed.add(key)
            edit.putStringSet(field, dismissed)
            if (!ending) edit.remove("dismissed")
            val currentKey = visibleKey ?: occurrence?.let { if (it.phase(now) == CoursePhase.ENDING_SOON) it.endingKey else it.key }
            if (targetKey != null && (isPreview || currentKey != targetKey)) {
                // A delayed click/dismissal from the old card must not close or
                // quietly overwrite a newer ending notification.
                check(edit.commit())
                return
            }
        }
        check(edit.commit())
        LiveUpdateNotification.cancel(context)
        refresh(context)
    }

    private fun currentPlan(context: Context, now: Long = System.currentTimeMillis()): CoursePlan {
        val preferences = prefs(context)
        if (!preferences.getBoolean("enabled", false)) return CoursePlan(null, null)
        val stored = JSONArray(preferences.getString("courses", "[]"))
        val courses = (0 until stored.length()).map { parseCourse(stored.getJSONObject(it)) }
        return CoursePlanner.plan(courses, now,
            preferences.getInt("lead", 10), preferences.getString("dismissed", null),
            endingLeadMinutes = preferences.getInt("endingLead", 10),
            dismissedKeys = preferences.getStringSet("dismissedKeys", emptySet()).orEmpty(),
            dismissedEndingKeys = preferences.getStringSet("dismissedEndingKeys", emptySet()).orEmpty(),
            announcedEndingKeys = preferences.getStringSet("endingAnnouncedKeys", emptySet()).orEmpty() +
                listOfNotNull(preferences.getString("endingAnnounced", null)))
    }

    fun endingStatus(context: Context): Map<String, Any> {
        val preferences = prefs(context)
        return mutableMapOf<String, Any>().apply {
            currentPlan(context).nextEndingAt?.let { put("nextEndingAt", it) }
            if (preferences.contains("lastEndingAt")) {
                put("lastEndingAt", preferences.getLong("lastEndingAt", 0))
                put("lastEndingCourse", preferences.getString("lastEndingCourse", "").orEmpty())
                put("lastEndingPosted", preferences.getBoolean("lastEndingPosted", false))
            }
        }
    }

    private const val BOUNDARY_ACTION = "com.kitty191.schedule.COURSE_BOUNDARY"
    private fun boundaryIntent(context: Context, at: Long) = PendingIntent.getBroadcast(
        context, 1012, Intent(context, CourseAlarmReceiver::class.java).apply {
            action = BOUNDARY_ACTION
            data = Uri.parse("schedule://boundary/$at")
            putExtra("scheduledAt", at)
        }, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
    )

    private fun scheduleBoundaries(context: Context, times: List<Long>) {
        val preferences = prefs(context)
        val old = preferences.getStringSet("wakeTimes", emptySet()).orEmpty()
        val desired = times.map { it.toString() }.toSet()
        // Save identities before registering, so a killed process cannot leave
        // untracked alarms behind. Re-register all desired alarms on restore:
        // persisted identities alone do not prove the OS still has the alarms.
        check(preferences.edit().putStringSet("wakeTimes", old + desired).commit())
        val manager = context.getSystemService(AlarmManager::class.java)
        for (at in times) {
            val pending = boundaryIntent(context, at)
            try {
                if (Build.VERSION.SDK_INT < 31 || manager.canScheduleExactAlarms()) {
                    manager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, pending)
                } else manager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, pending)
            } catch (_: SecurityException) {
                manager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, pending)
            }
        }
        // Add replacements before removing stale ones. Editing/deleting courses,
        // changing times, and disabling reminders cannot leave old wakeups alive.
        for (value in old - desired) value.toLongOrNull()?.let {
            val pending = boundaryIntent(context, it)
            manager.cancel(pending)
            pending.cancel()
        }
        check(preferences.edit().putStringSet("wakeTimes", desired).commit())
    }

    fun receiveAlarm(context: Context, intent: Intent) {
        if (intent.action == BOUNDARY_ACTION) {
            // Persist a receipt separately from UI/onResume refreshes. Opening
            // the app must never make a missed background alarm look delivered.
            check(prefs(context).edit()
                .putLong("lastBackgroundWakeAt", System.currentTimeMillis())
                .putLong("lastBackgroundScheduledAt", intent.getLongExtra("scheduledAt", 0))
                .commit())
        }
        refresh(context)
    }

    fun backgroundStatus(context: Context): Map<String, Any> {
        val preferences = prefs(context)
        return mutableMapOf<String, Any>().apply {
            val times = preferences.getStringSet("wakeTimes", emptySet()).orEmpty()
                .mapNotNull { it.toLongOrNull() }.filter { it > System.currentTimeMillis() }
            // These are registrations, not proof of future delivery by ColorOS.
            put("scheduledBoundaryCount", times.size)
            times.minOrNull()?.let { put("nextBackgroundAt", it) }
            if (preferences.contains("lastBackgroundWakeAt")) {
                put("lastBackgroundWakeAt", preferences.getLong("lastBackgroundWakeAt", 0))
                put("lastBackgroundScheduledAt", preferences.getLong("lastBackgroundScheduledAt", 0))
            }
        }
    }

    fun refresh(context: Context) {
        val preferences = prefs(context)
        val now = System.currentTimeMillis()
        val previewUntil = preferences.getLong("previewUntil", 0)
        val preview = preferences.getString("preview", null)
        val plan = currentPlan(context, now)
        val announced = preferences.getStringSet("endingAnnouncedKeys", emptySet()).orEmpty().toMutableSet()
        preferences.getString("endingAnnounced", null)?.let { announced.add(it) }
        val newEnding = plan.active?.let { it.phase(now) == CoursePhase.ENDING_SOON && it.endingKey !in announced } == true
        var wakeTimes = plan.wakeTimes
        var nextRefresh = plan.nextRefresh
        if (preview != null && previewUntil > now && !newEnding) {
            val value = JSONObject(preview)
            val spec = parseCourse(value)
            // A still-active preview can survive an app update from the old format.
            val occurrence = if (preferences.contains("previewStartAt")) {
                CourseOccurrence(spec, preferences.getLong("previewStartAt", now),
                    preferences.getLong("previewEndAt", previewUntil), preferences.getInt("endingLead", 10))
            } else {
                CourseLiveCard.previewOccurrence(spec, now, preferences.getInt("lead", 10),
                    preferences.getInt("endingLead", 10), value.optBoolean("previewEnding", false)).also {
                    preferences.edit().putLong("previewStartAt", it.start).putLong("previewEndAt", it.end).apply()
                }
            }
            val posted = LiveUpdateNotification.show(context, spec, occurrence, previewUntil,
                alert = !preferences.getBoolean("previewAnnounced", false),
                leadMinutes = preferences.getInt("lead", 10), semesterStart = preferences.getString("semesterStart", null),
                weekStart = preferences.getInt("weekStart", 1), preview = true, now = now)
            if (posted) preferences.edit().putBoolean("previewAnnounced", true).apply()
            // A test preview must not remove a real class's pending ending alarm.
            wakeTimes = (wakeTimes + previewUntil).distinct().sorted().take(64)
            nextRefresh = minOf(now + 60_000L, if (now < occurrence.start) occurrence.start else previewUntil)
        } else {
            if (preview != null) preferences.edit().remove("preview").remove("previewUntil").remove("previewStartAt").remove("previewEndAt").remove("previewAnnounced").apply()
            val active = plan.active
            if (active == null) LiveUpdateNotification.cancel(context)
            else {
                val posted = LiveUpdateNotification.show(context, active.course, active, active.end, alert = newEnding,
                    leadMinutes = preferences.getInt("lead", 10), semesterStart = preferences.getString("semesterStart", null),
                    weekStart = preferences.getInt("weekStart", 1), now = now)
                if (newEnding) {
                    val edit = preferences.edit().putLong("lastEndingAt", now)
                        .putString("lastEndingCourse", active.course.name).putBoolean("lastEndingPosted", posted)
                    if (posted) {
                        announced.add(active.endingKey)
                        edit.putStringSet("endingAnnouncedKeys", recentKeys(announced, now)).remove("endingAnnounced")
                    }
                    edit.apply()
                }
            }
        }
        val manager = context.getSystemService(AlarmManager::class.java)
        // Migrate the old single, chained alarm. Every upcoming boundary now
        // has its own system PendingIntent and is registered before leaving UI.
        manager.cancel(alarmIntent(context))
        val cosmetic = alarmIntent(context, refresh = true)
        manager.cancel(cosmetic)
        scheduleBoundaries(context, wakeTimes)
        val next = wakeTimes.firstOrNull()
        // A minute refresh at the same instant as a reminder boundary can overwrite
        // its fresh alert with a quiet update before SystemUI has displayed it.
        val cosmeticAt = nextRefresh?.takeIf { refresh -> next?.let { refresh < it } ?: true }
        if (cosmeticAt != null) {
            // RTC never wakes a sleeping phone. Live countdowns are rendered by
            // the system chronometer; these refreshes only update the awake UI.
            try {
                if (Build.VERSION.SDK_INT < 31 || manager.canScheduleExactAlarms()) {
                    manager.setExact(AlarmManager.RTC, cosmeticAt, cosmetic)
                } else manager.set(AlarmManager.RTC, cosmeticAt, cosmetic)
            } catch (_: SecurityException) {
                manager.set(AlarmManager.RTC, cosmeticAt, cosmetic)
            }
        }

    }
}

class CourseAlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        CourseScheduler.receiveAlarm(context, intent)
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
