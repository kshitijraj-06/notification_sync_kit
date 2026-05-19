package com.example.notification_test

import android.app.AppOpsManager
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.os.Process
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    companion object {
        // Must match InteractionDetector.defaultChannelName in the Dart package.
        private const val CHANNEL = "notification_sync_kit/usage_stats"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {

                // Returns true if the user has granted Usage Access permission.
                "hasUsageStatsPermission" -> {
                    result.success(hasUsageStatsPermission())
                }

                // Opens the system Usage Access settings screen so the user can grant permission.
                "requestUsageStatsPermission" -> {
                    startActivity(Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS))
                    result.success(null)
                }

                // Returns true if [packageName] moved to the foreground within the last [withinMs]
                // milliseconds. Used to detect whether the driver tapped and opened a notification.
                //
                // Arguments:
                //   packageName (String) — the app to check
                //   withinMs    (Int)    — look-back window in milliseconds (default 3000)
                "wasAppOpenedRecently" -> {
                    val packageName = call.argument<String>("packageName") ?: ""
                    val withinMs = (call.argument<Int>("withinMs") ?: 3000).toLong()
                    result.success(wasAppOpenedRecently(packageName, withinMs))
                }

                else -> result.notImplemented()
            }
        }
    }

    // ── Helpers ───────────────────────────────────────────────────────────────

    private fun hasUsageStatsPermission(): Boolean {
        val appOps = getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        val mode = appOps.checkOpNoThrow(
            AppOpsManager.OPSTR_GET_USAGE_STATS,
            Process.myUid(),
            packageName,
        )
        return mode == AppOpsManager.MODE_ALLOWED
    }

    /**
     * Queries UsageStatsManager for MOVE_TO_FOREGROUND events from [packageName]
     * within the last [withinMs] milliseconds.
     *
     * Returns false if Usage Access permission has not been granted.
     */
    private fun wasAppOpenedRecently(packageName: String, withinMs: Long): Boolean {
        if (!hasUsageStatsPermission()) return false

        val usm = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val now = System.currentTimeMillis()
        val events = usm.queryEvents(now - withinMs, now)
        val event = UsageEvents.Event()

        while (events.hasNextEvent()) {
            events.getNextEvent(event)
            if (event.packageName == packageName &&
                event.eventType == UsageEvents.Event.MOVE_TO_FOREGROUND
            ) {
                return true
            }
        }
        return false
    }
}
