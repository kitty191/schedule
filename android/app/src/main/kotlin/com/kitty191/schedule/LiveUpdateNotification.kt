package com.kitty191.schedule

import android.Manifest
import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import kotlin.math.ceil

object LiveUpdateNotification {
    // Keep the channel ID and package ID from the successful device test.
    private const val CHANNEL_ID = "island_test_live_updates"
    private const val NOTIFICATION_ID = 1001
    private const val REQUEST_PROMOTED_ONGOING = "android.requestPromotedOngoing"

    fun show(context: Context, course: CourseSpec, occurrence: CourseOccurrence?, expires: Long,
        alert: Boolean = false, previewEndAt: Long? = null): Boolean {
        val manager = context.getSystemService(NotificationManager::class.java)
        if (Build.VERSION.SDK_INT >= 33 && context.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) !=
            PackageManager.PERMISSION_GRANTED) return false
        if (!manager.areNotificationsEnabled()) return false
        if (Build.VERSION.SDK_INT >= 26) {
            manager.createNotificationChannel(NotificationChannel(
                CHANNEL_ID, "课程实时提醒", NotificationManager.IMPORTANCE_DEFAULT,
            ).apply {
                description = "课前倒计时和上课状态"
                setSound(null, null)
                enableVibration(false)
                setShowBadge(false)
            })
        }
        val open = PendingIntent.getActivity(context, 0, Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
        }, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val stop = PendingIntent.getBroadcast(context, 1, Intent(context, StopTestReceiver::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val now = System.currentTimeMillis()
        val phase = occurrence?.phase(now)
        val inClass = occurrence != null && now >= occurrence.start
        val ending = phase == CoursePhase.ENDING_SOON || previewEndAt != null
        val minutes = occurrence?.let { ceil(((if (inClass) it.end else it.start) - now) / 60_000.0).toInt().coerceAtLeast(1) }
        val event = course.kind == "event"
        val critical = if (ending) "快下课" else if (occurrence == null) "提醒预览" else if (inClass) {
            if (event) "进行中" else "上课中"
        } else "${minutes}分${if (event) "开始" else "上课"}"
        fun clock(minute: Int) = "%02d:%02d".format(minute / 60, minute % 60)
        val clockFormat = java.text.SimpleDateFormat("HH:mm", java.util.Locale.getDefault())
        val time = if (occurrence == null) "${clock(course.startMinute)} — ${clock(course.endMinute)}" else
            "${clockFormat.format(java.util.Date(occurrence.start))} — ${clockFormat.format(java.util.Date(occurrence.end))}"
        val location = course.location.ifBlank { "未设置教室" }
        val endClock = occurrence?.let { clockFormat.format(java.util.Date(it.end)) }
        val description = when {
            previewEndAt != null -> "下课前10分钟提醒预览 · 5分钟后自动结束"
            occurrence == null -> "课程预览 · 5分钟后自动结束"
            ending -> "下课倒计时 · $endClock 下课"
            inClass -> "${if (event) "进行中" else "正在上课"} · $endClock ${if (event) "结束" else "下课"}"
            else -> "${minutes}分钟后${if (event) "开始" else "上课"}"
        }
        @Suppress("DEPRECATION")
        val builder = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(context, CHANNEL_ID) else Notification.Builder(context)
        builder.setSmallIcon(R.drawable.ic_live_test)
            .setContentTitle(if (previewEndAt != null) "${course.name} · 预览" else course.name)
            .setContentText("$critical · $location")
            .setStyle(Notification.BigTextStyle().bigText("$description\n$time\n$location"))
            .setContentIntent(open)
            .setCategory(Notification.CATEGORY_EVENT)
            .setOngoing(true).setOnlyAlertOnce(!alert)
            .setVisibility(Notification.VISIBILITY_PUBLIC)
            .addAction(Notification.Action.Builder(null, "结束提醒", stop).build())
        if (Build.VERSION.SDK_INT >= 26) builder.setTimeoutAfter((expires - now).coerceAtLeast(1))
        val countdownTo = previewEndAt ?: occurrence?.let { if (inClass) it.end else it.start }
        if (countdownTo != null) {
            builder.setWhen(countdownTo).setUsesChronometer(true).setChronometerCountDown(true)
        } else builder.setShowWhen(false)
        if (Build.VERSION.SDK_INT >= 36) {
            // API 36 uses the documented AndroidX-compatible extra. No private APIs.
            builder.setShortCriticalText(critical)
            builder.extras.putBoolean(REQUEST_PROMOTED_ONGOING, true)
        }
        if (Build.VERSION.SDK_INT >= 26 && manager.getNotificationChannel(CHANNEL_ID)?.importance == NotificationManager.IMPORTANCE_NONE) return false
        manager.notify(NOTIFICATION_ID, builder.build())
        return true
    }

    fun cancel(context: Context) = context.getSystemService(NotificationManager::class.java).cancel(NOTIFICATION_ID)

    fun status(context: Context): Map<String, Any> {
        val manager = context.getSystemService(NotificationManager::class.java)
        val supported = Build.VERSION.SDK_INT >= 36
        val permission = Build.VERSION.SDK_INT < 33 || context.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED
        val active = manager.activeNotifications.firstOrNull { it.id == NOTIFICATION_ID }
        val channelEnabled = Build.VERSION.SDK_INT < 26 || manager.getNotificationChannel(CHANNEL_ID)?.importance != NotificationManager.IMPORTANCE_NONE
        return mapOf(
            "supported" to supported,
            "notificationsEnabled" to (permission && manager.areNotificationsEnabled() && channelEnabled),
            "promotionAllowed" to (supported && manager.canPostPromotedNotifications()),
            "active" to (active != null),
            "promoted" to (supported && active != null && (active.notification.flags and Notification.FLAG_PROMOTED_ONGOING) != 0),
            "exactAllowed" to (Build.VERSION.SDK_INT < 31 || context.getSystemService(AlarmManager::class.java).canScheduleExactAlarms()),
        )
    }
}
