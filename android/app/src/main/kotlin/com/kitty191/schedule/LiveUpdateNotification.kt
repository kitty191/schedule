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

    fun show(context: Context, course: CourseSpec, occurrence: CourseOccurrence?, expires: Long) {
        val manager = context.getSystemService(NotificationManager::class.java)
        if (Build.VERSION.SDK_INT >= 33 && context.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) !=
            PackageManager.PERMISSION_GRANTED) return
        if (!manager.areNotificationsEnabled()) return
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
        val inClass = occurrence != null && now >= occurrence.start
        val minutes = occurrence?.let { ceil(((if (inClass) it.end else it.start) - now) / 60_000.0).toInt().coerceAtLeast(1) }
        val critical = if (occurrence == null) "课程预览" else if (inClass) "上课中" else "${minutes}分上课"
        fun clock(minute: Int) = "%02d:%02d".format(minute / 60, minute % 60)
        val time = "${clock(course.startMinute)} — ${clock(course.endMinute)}"
        val location = course.location.ifBlank { "未设置教室" }
        val description = if (occurrence == null) "课程预览 · $time" else
            if (inClass) "正在上课 · ${minutes}分钟后下课" else "${minutes}分钟后上课 · $time"
        @Suppress("DEPRECATION")
        val builder = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(context, CHANNEL_ID) else Notification.Builder(context)
        builder.setSmallIcon(R.drawable.ic_live_test)
            .setContentTitle(course.name)
            .setContentText("$critical · $location")
            .setStyle(Notification.BigTextStyle().bigText("$description\n$location"))
            .setContentIntent(open)
            .setCategory(Notification.CATEGORY_EVENT)
            .setOngoing(true).setOnlyAlertOnce(true)
            .setVisibility(Notification.VISIBILITY_PUBLIC)
            .addAction(Notification.Action.Builder(null, "结束提醒", stop).build())
        if (Build.VERSION.SDK_INT >= 26) builder.setTimeoutAfter((expires - now).coerceAtLeast(1))
        if (occurrence != null) {
            builder.setWhen(if (inClass) occurrence.end else occurrence.start)
                .setUsesChronometer(true).setChronometerCountDown(true)
        } else builder.setShowWhen(false)
        if (Build.VERSION.SDK_INT >= 36) {
            // API 36 uses the documented AndroidX-compatible extra. No private APIs.
            builder.setShortCriticalText(critical)
            builder.extras.putBoolean(REQUEST_PROMOTED_ONGOING, true)
        }
        manager.notify(NOTIFICATION_ID, builder.build())
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
