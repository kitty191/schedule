package com.kitty191.schedule

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class StopTestReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        CourseScheduler.stop(context)
    }
}
