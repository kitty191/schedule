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
import android.graphics.drawable.Icon
import android.os.Build

object LiveUpdateNotification {
    // Keep the channel ID and package ID from the successful device test.
    private const val CHANNEL_ID = "island_test_live_updates"
    private const val NOTIFICATION_ID = 1001
    private const val REQUEST_PROMOTED_ONGOING = "android.requestPromotedOngoing"
    private const val PURPLE = 0xFFB69AF7.toInt()
    private const val PREPARATION_COLOR = 0xFF8D9299.toInt()

    fun show(context: Context, course: CourseSpec, occurrence: CourseOccurrence, expires: Long,
        alert: Boolean = false, leadMinutes: Int = 10, semesterStart: String? = null,
        weekStart: Int = 1, preview: Boolean = false): Boolean {
        val manager = context.getSystemService(NotificationManager::class.java)
        if (Build.VERSION.SDK_INT >= 33 && context.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) !=
            PackageManager.PERMISSION_GRANTED) return false
        if (!manager.areNotificationsEnabled()) return false
        if (Build.VERSION.SDK_INT >= 26) {
            manager.createNotificationChannel(NotificationChannel(
                CHANNEL_ID, "课程实时提醒", NotificationManager.IMPORTANCE_DEFAULT,
            ).apply {
                description = "课程时间进度、课前和下课倒计时"
                setSound(null, null)
                enableVibration(false)
                setShowBadge(false)
            })
        }
        val now = System.currentTimeMillis()
        val card = CourseLiveCard.create(course, occurrence, now, leadMinutes, semesterStart, weekStart, preview)
        if (Build.VERSION.SDK_INT >= 26 && manager.getNotificationChannel(CHANNEL_ID)?.importance == NotificationManager.IMPORTANCE_NONE) return false
        manager.notify(NOTIFICATION_ID, buildNotification(context, card, expires, now, alert))
        return true
    }

    internal fun buildNotification(context: Context, card: CourseLiveCard, expires: Long, now: Long,
        alert: Boolean = false): Notification {
        val open = PendingIntent.getActivity(context, 0, Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
        }, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val stop = PendingIntent.getBroadcast(context, 1, Intent(context, StopTestReceiver::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        @Suppress("DEPRECATION")
        val builder = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(context, CHANNEL_ID) else Notification.Builder(context)
        builder.setSmallIcon(R.drawable.ic_live_test)
            .setContentTitle(card.headline)
            .setContentText(card.detail)
            .setSubText(card.metadata)
            .setColor(PURPLE)
            .setContentIntent(open)
            .setDeleteIntent(stop)
            .setCategory(Notification.CATEGORY_EVENT)
            .setOngoing(true).setOnlyAlertOnce(!alert)
            .setVisibility(Notification.VISIBILITY_PUBLIC)
            .addAction(Notification.Action.Builder(null, "结束提醒", stop).build())
        if (Build.VERSION.SDK_INT >= 26) builder.setTimeoutAfter((expires - now).coerceAtLeast(1))
        // The same system-owned timer feeds the collapsed chip and expanded card.
        // A shortCriticalText such as "14分上课" is a snapshot, not a live timer;
        // it takes precedence over the chip's chronometer and can stay stale if
        // background cosmetic refreshes are delayed while the phone is idle.
        builder.setWhen(card.countdownTo).setShowWhen(true)
            .setUsesChronometer(true).setChronometerCountDown(true)
        if (Build.VERSION.SDK_INT >= 36) {
            // A system template preserves promotion eligibility. Never use custom RemoteViews.
            val segments = mutableListOf<Notification.ProgressStyle.Segment>()
            if (card.preparationEnd > 0) segments.add(
                Notification.ProgressStyle.Segment(card.preparationEnd).setColor(PREPARATION_COLOR))
            segments.add(Notification.ProgressStyle.Segment(CourseLiveCard.PROGRESS_MAX - card.preparationEnd).setColor(PURPLE))
            val style = Notification.ProgressStyle().setStyledByProgress(false)
                .setProgressSegments(segments).setProgress(card.progress)
                .setProgressTrackerIcon(Icon.createWithResource(context, R.drawable.ic_course_tracker))
            if (card.preparationEnd > 0) style.addProgressPoint(
                Notification.ProgressStyle.Point(card.preparationEnd).setColor(PURPLE))
            // System text colors keep times readable in both light and dark/OEM cards.
            builder.setStyle(style)
            builder.extras.putBoolean(REQUEST_PROMOTED_ONGOING, true)
        } else {
            builder.setStyle(Notification.BigTextStyle().bigText(card.expandedText))
                .setProgress(CourseLiveCard.PROGRESS_MAX, card.progress, false)
        }
        val notification = builder.build()
        if (Build.VERSION.SDK_INT >= 36 && !notification.hasPromotableCharacteristics()) {
            val original = notification.clone()
            // Android 16's first implementation required colorized=true; newer
            // implementations require the opposite. Ask the public capability API
            // instead of guessing from the Android/OEM version or using private extras.
            val legacy = builder.setColorized(true).build()
            if (legacy.hasPromotableCharacteristics()) return legacy
            return original
        }
        return notification
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
