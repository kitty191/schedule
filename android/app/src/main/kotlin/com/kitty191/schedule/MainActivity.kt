package com.kitty191.schedule

import android.Manifest
import android.content.ActivityNotFoundException
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var permissionResult: MethodChannel.Result? = null
    private var previewCourse: Map<*, *>? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.kitty191.schedule/live_updates")
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "status" -> result.success(LiveUpdateNotification.status(this))
                        "permission" -> requestNotificationPermission(result, null)
                        "configure" -> {
                            CourseScheduler.configure(this, call.arguments as Map<*, *>)
                            replyAfterUpdate(result)
                        }
                        "preview" -> requestNotificationPermission(result, call.arguments as Map<*, *>)
                        "previewEnding" -> requestNotificationPermission(result,
                            (call.arguments as Map<*, *>) + mapOf("previewEnding" to true))
                        "stop" -> { CourseScheduler.stop(this); replyAfterUpdate(result) }
                        "settings" -> { openNotificationSettings(); result.success(null) }
                        "backgroundSettings" -> {
                            openFirst(listOf(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                                Uri.parse("package:$packageName"))))
                            result.success(null)
                        }
                        "batterySettings" -> {
                            openFirst(listOf(Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS),
                                Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:$packageName"))))
                            result.success(null)
                        }
                        "exactSettings" -> {
                            if (Build.VERSION.SDK_INT >= 31) {
                                openFirst(listOf(Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM,
                                    Uri.parse("package:$packageName"))))
                            }
                            result.success(null)
                        }
                        else -> result.notImplemented()
                    }
                } catch (error: RuntimeException) {
                    result.error("notification_error", error.message ?: "系统提醒操作未完成。", null)
                }
            }
    }

    private fun requestNotificationPermission(result: MethodChannel.Result, course: Map<*, *>?) {
        if (permissionResult != null) {
            result.error("request_in_progress", "请先完成当前通知权限请求。", null)
            return
        }
        if (Build.VERSION.SDK_INT >= 33 && checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
            permissionResult = result
            previewCourse = course
            requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 1001)
        } else completePermission(result, course)
    }

    private fun completePermission(result: MethodChannel.Result, course: Map<*, *>?) {
        if (LiveUpdateNotification.status(this)["notificationsEnabled"] != true) {
            result.error("notifications_disabled", "通知已关闭，请在系统通知设置中允许。", null)
            return
        }
        if (course != null) CourseScheduler.preview(this, course)
        replyAfterUpdate(result)
    }

    private fun replyAfterUpdate(result: MethodChannel.Result) {
        Handler(Looper.getMainLooper()).postDelayed({
            try { result.success(LiveUpdateNotification.status(this)) }
            catch (error: RuntimeException) { result.error("notification_error", error.message, null) }
        }, 350)
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != 1001) return
        val result = permissionResult ?: return
        val course = previewCourse
        permissionResult = null
        previewCourse = null
        if (grantResults.firstOrNull() != PackageManager.PERMISSION_GRANTED) {
            result.error("permission_denied", "未允许通知，请在系统设置中允许后重试。", null)
            return
        }
        try { completePermission(result, course) }
        catch (error: RuntimeException) { result.error("notification_error", error.message, null) }
    }

    override fun onResume() {
        super.onResume()
        // Restore alarms after returning from exact-alarm settings, including revocation.
        CourseScheduler.refresh(this)
    }

    private fun openNotificationSettings() {
        val intents = mutableListOf<Intent>()
        if (Build.VERSION.SDK_INT >= 36 && LiveUpdateNotification.status(this)["notificationsEnabled"] == true &&
            !getSystemService(android.app.NotificationManager::class.java).canPostPromotedNotifications()) {
            intents.add(Intent("android.settings.APP_NOTIFICATION_PROMOTION_SETTINGS")
                .putExtra(Settings.EXTRA_APP_PACKAGE, packageName))
        }
        if (Build.VERSION.SDK_INT >= 26) intents.add(Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
            .putExtra(Settings.EXTRA_APP_PACKAGE, packageName))
        intents.add(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:$packageName")))
        openFirst(intents)
    }

    private fun openFirst(intents: List<Intent>) {
        for (intent in intents) {
            try { startActivity(intent); return }
            catch (_: ActivityNotFoundException) { /* Try the OEM fallback. */ }
            catch (_: SecurityException) { /* Some OEM settings are not exported. */ }
        }
        throw IllegalStateException("请在手机设置中打开本应用的通知和闹钟权限。")
    }

    override fun onDestroy() {
        permissionResult?.error("interrupted", "权限请求已中断，请重试。", null)
        permissionResult = null
        previewCourse = null
        super.onDestroy()
    }
}
