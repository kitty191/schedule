package com.kitty191.schedule

import android.Manifest
import android.app.ActivityManager
import android.os.PowerManager
import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.drawable.Icon
import android.net.Uri
import android.os.Build
import org.json.JSONArray

object LiveUpdateNotification {
    internal const val DISMISSAL_KEY = "com.kitty191.schedule.dismissalKey"
    internal const val ENDING_PHASE = "com.kitty191.schedule.endingPhase"
    internal const val PREVIEW_UNTIL = "com.kitty191.schedule.previewUntil"
    private const val CARD_STATE = "com.kitty191.schedule.cardState"
    // Keep the channel ID and package ID from the successful device test.
    private const val CHANNEL_ID = "island_test_live_updates"
    private const val NOTIFICATION_ID = 1001
    private const val IN_CLASS_NOTIFICATION_ID = 1003
    private const val ENDING_CHANNEL_ID = "course_ending_alerts_v1"
    private const val ENDING_NOTIFICATION_ID = 1002
    private const val REQUEST_PROMOTED_ONGOING = "android.requestPromotedOngoing"
    private const val PURPLE = 0xFFB69AF7.toInt()
    private const val PREPARATION_COLOR = 0xFF8D9299.toInt()

    fun ensureChannels(context: Context) {
        if (Build.VERSION.SDK_INT < 26) return
        val manager = context.getSystemService(NotificationManager::class.java)
        for (ending in listOf(false, true)) {
            manager.createNotificationChannel(NotificationChannel(
                if (ending) ENDING_CHANNEL_ID else CHANNEL_ID,
                if (ending) "下课前提示" else "课程实时提醒",
                if (ending) NotificationManager.IMPORTANCE_HIGH else NotificationManager.IMPORTANCE_DEFAULT,
            ).apply {
                description = if (ending) "到设置的下课前时间时突出显示，默认无声音和振动" else "课程时间进度、课前和下课倒计时"
                setSound(null, null)
                enableVibration(false)
                setShowBadge(false)
            })
        }
    }

    fun show(context: Context, course: CourseSpec, occurrence: CourseOccurrence, expires: Long,
        alert: Boolean = false, leadMinutes: Int = 10, semesterStart: String? = null,
        weekStart: Int = 1, preview: Boolean = false, now: Long = System.currentTimeMillis()): Boolean {
        val manager = context.getSystemService(NotificationManager::class.java)
        if (Build.VERSION.SDK_INT >= 33 && context.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) !=
            PackageManager.PERMISSION_GRANTED) return false
        if (!manager.areNotificationsEnabled()) return false
        val card = CourseLiveCard.create(course, occurrence, now, leadMinutes, semesterStart, weekStart, preview)
        val validUntil = minOf(expires, card.countdownTo)
        if (validUntil <= now) return false
        val channelId = if (card.endingSoon) ENDING_CHANNEL_ID else CHANNEL_ID
        val notificationId = when {
            card.endingSoon -> ENDING_NOTIFICATION_ID
            now < occurrence.start -> NOTIFICATION_ID
            else -> IN_CLASS_NOTIFICATION_ID
        }
        ensureChannels(context)
        if (Build.VERSION.SDK_INT >= 26 && manager.getNotificationChannel(channelId)?.importance == NotificationManager.IMPORTANCE_NONE) return false
        val state = JSONArray(listOf(card.headline, card.detail, card.metadata, card.expandedText,
            card.countdownTo, card.progress, card.preparationEnd, card.endingSoon,
            occurrence.key, validUntil, preview)).toString()
        // Several overdue alarms may arrive in one batch after background delay.
        // Do not overwrite an identical fresh alert with a quiet notification.
        if (!alert && manager.activeNotifications.any {
                it.id == notificationId && it.notification.extras.getString(CARD_STATE) == state &&
                    (Build.VERSION.SDK_INT < 36 || it.notification.shortCriticalText == null)
            }) return true
        // The ending boundary is a new attention event, not a quiet edit of a
        // notification that may already have been dismissed or demoted by the OEM.
        if (card.endingSoon && alert) manager.cancel(ENDING_NOTIFICATION_ID)
        try {
            val notification = buildNotification(context, card, expires, now, alert, occurrence, preview)
            notification.extras.putString(CARD_STATE, state)
            manager.notify(notificationId, notification)
        } catch (_: SecurityException) { return false }
        for (id in listOf(NOTIFICATION_ID, IN_CLASS_NOTIFICATION_ID, ENDING_NOTIFICATION_ID)) {
            if (id != notificationId) manager.cancel(id)
        }
        return true
    }

    internal fun buildNotification(context: Context, card: CourseLiveCard, expires: Long, now: Long,
        alert: Boolean = false, occurrence: CourseOccurrence? = null, preview: Boolean = false): Notification {
        val open = PendingIntent.getActivity(context, 0, Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
        }, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val stopIntent = Intent(context, StopTestReceiver::class.java).apply {
            if (occurrence != null) {
                val key = if (card.endingSoon) occurrence.endingKey else occurrence.key
                val identity = if (preview) "preview:$expires" else key
                data = Uri.parse("schedule://reminder/${Uri.encode(identity)}")
                putExtra("dismissalKey", key).putExtra("ending", card.endingSoon)
                if (preview) putExtra("previewUntil", expires)
            }
        }
        val stop = PendingIntent.getBroadcast(context, 1, stopIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        @Suppress("DEPRECATION")
        val builder = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(context,
            if (card.endingSoon) ENDING_CHANNEL_ID else CHANNEL_ID) else Notification.Builder(context)
        if (occurrence != null) {
            builder.extras.putString(DISMISSAL_KEY, if (card.endingSoon) occurrence.endingKey else occurrence.key)
            builder.extras.putBoolean(ENDING_PHASE, card.endingSoon)
            if (preview) builder.extras.putLong(PREVIEW_UNTIL, expires)
        }
        builder.setSmallIcon(if (card.endingSoon) R.drawable.ic_live_ending else R.drawable.ic_live_test)
            .setContentTitle(card.headline)
            .setContentText(card.detail)
            .setSubText(card.metadata)
            .setColor(PURPLE)
            .setContentIntent(open)
            .setDeleteIntent(stop)
            .setCategory(Notification.CATEGORY_EVENT)
            .setPriority(if (card.endingSoon) Notification.PRIORITY_HIGH else Notification.PRIORITY_DEFAULT)
            .setOngoing(true).setOnlyAlertOnce(!alert)
            .setVisibility(Notification.VISIBILITY_PUBLIC)
            .addAction(Notification.Action.Builder(null, if (card.endingSoon) "结束下课提醒" else "收起提醒", stop).build())
        // A system chronometer does not advance the course state at zero. Give
        // the system the current timer's deadline, not the whole course's end.
        // If the boundary receiver is delayed, the stale pre-class card expires
        // without needing the app process. The in-class card has a separate ID
        // so an old timeout cannot withdraw the replacement countdown.
        if (Build.VERSION.SDK_INT >= 26) builder.setTimeoutAfter((minOf(expires, card.countdownTo) - now).coerceAtLeast(1))
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

    fun cancel(context: Context) {
        val manager = context.getSystemService(NotificationManager::class.java)
        manager.cancel(NOTIFICATION_ID)
        manager.cancel(IN_CLASS_NOTIFICATION_ID)
        manager.cancel(ENDING_NOTIFICATION_ID)
    }

    fun status(context: Context): Map<String, Any> {
        val manager = context.getSystemService(NotificationManager::class.java)
        val supported = Build.VERSION.SDK_INT >= 36
        val permission = Build.VERSION.SDK_INT < 33 || context.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED
        val active = manager.activeNotifications.firstOrNull { it.id == ENDING_NOTIFICATION_ID }
            ?: manager.activeNotifications.firstOrNull { it.id == IN_CLASS_NOTIFICATION_ID }
            ?: manager.activeNotifications.firstOrNull { it.id == NOTIFICATION_ID }
        val channelEnabled = Build.VERSION.SDK_INT < 26 || manager.getNotificationChannel(CHANNEL_ID)?.importance != NotificationManager.IMPORTANCE_NONE
        val endingChannelEnabled = Build.VERSION.SDK_INT < 26 || manager.getNotificationChannel(ENDING_CHANNEL_ID)?.importance != NotificationManager.IMPORTANCE_NONE
        return mapOf(
            "batteryOptimizationIgnored" to context.getSystemService(PowerManager::class.java).isIgnoringBatteryOptimizations(context.packageName),
            "backgroundRestricted" to (Build.VERSION.SDK_INT >= 28 && context.getSystemService(ActivityManager::class.java).isBackgroundRestricted),
            "supported" to supported,
            "notificationsEnabled" to (permission && manager.areNotificationsEnabled() && channelEnabled),
            "promotionAllowed" to (supported && manager.canPostPromotedNotifications()),
            "active" to (active != null),
            "promoted" to (supported && active != null && (active.notification.flags and Notification.FLAG_PROMOTED_ONGOING) != 0),
            "exactAllowed" to (Build.VERSION.SDK_INT < 31 || context.getSystemService(AlarmManager::class.java).canScheduleExactAlarms()),
            "endingNotificationsEnabled" to (permission && manager.areNotificationsEnabled() && endingChannelEnabled),
            "endingBannerEnabled" to (Build.VERSION.SDK_INT < 26 ||
                (manager.getNotificationChannel(ENDING_CHANNEL_ID)?.importance ?: NotificationManager.IMPORTANCE_HIGH) >= NotificationManager.IMPORTANCE_HIGH),
        ) + CourseScheduler.endingStatus(context) + CourseScheduler.backgroundStatus(context) + BackgroundReminderProbe.status(context)
    }
}
