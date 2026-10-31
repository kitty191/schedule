package com.kitty191.schedule

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class StopTestReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        CourseScheduler.stop(context, intent.getStringExtra("dismissalKey"),
            if (intent.hasExtra("ending")) intent.getBooleanExtra("ending", false) else null,
            if (intent.hasExtra("previewUntil")) intent.getLongExtra("previewUntil", 0) else null)
    }
}
