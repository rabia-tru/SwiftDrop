package com.example.rider_app

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log

/**
 * Kill-survival watchdog for the background tracking service.
 *
 * `flutter_background_service` runs the tracking work in a foreground
 * service, which Android rarely kills — but OEM task managers (Xiaomi,
 * Oppo, Vivo, Huawei...) and aggressive battery savers do kill it anyway,
 * mid-delivery. When that happens nothing restarts it: the rider appears
 * frozen on the customer's map with no notification and no error.
 *
 * Design (works entirely OUTSIDE the app process, so it survives the
 * same kill it is watching for):
 *
 *   Dart (unified_background_service.dart) writes a heartbeat to
 *   SharedPreferences every 30s while the service is healthy, and arms
 *   an exact alarm through [arm] (called over the `service_watchdog`
 *   method channel from MainActivity).
 *
 *   The alarm fires → [WatchdogReceiver.onReceive] runs in a fresh,
 *   empty process → it compares "now" against the heartbeat timestamp:
 *
 *     • heartbeat fresh (≤ [STALE_MS])  → service alive → re-arm only
 *     • heartbeat stale / missing flags → service dead → START it again
 *       by firing the same service intent the plugin itself uses
 *     • tracking flags all off          → disarmed → do nothing
 *
 * Re-arming from inside the receiver keeps the watchdog chain alive for
 * as long as the heartbeat keeps being refreshed, and the chain stops
 * by itself when tracking ends. This uses the SCHEDULE_EXACT_ALARM
 * permission the manifest already declared (previously unused).
 */
class WatchdogReceiver : BroadcastReceiver() {

    companion object {
        const val TAG = "Watchdog"

        const val ACTION = "com.example.rider_app.WATCHDOG_TICK"

        // SharedPreferences — MUST match the keys used by the Dart side.
        const val PREFS = "FlutterSharedPreferences"
        const val KEY_HEARTBEAT = "flutter.watchdog_heartbeat_ms"
        const val KEY_ARMED = "flutter.watchdog_armed"
        const val KEY_RIDER_ACTIVE = "flutter.bg_tracking_active"
        const val KEY_CUSTOMER_ACTIVE = "flutter.is_tracking_order"
        const val KEY_RIDER_ORDER_ACTIVE = "flutter.is_rider_tracking"
        const val KEY_CHAT_WATCH = "flutter.chat_watch_order_customer"
        const val KEY_CHAT_WATCH_RIDER = "flutter.chat_watch_order_rider"

        /// How stale the heartbeat may get before we consider the service
        /// dead. Dart beats every 30s; two missed beats + scheduling slop.
        const val STALE_MS: Long = 90_000L

        /// Watchdog check cadence. Slightly longer than STALE_MS so a
        /// single tick never sees a healthy-but-just-slowed heartbeat.
        const val TICK_MS: Long = 120_000L

        fun pendingIntent(context: Context, flags: Int): PendingIntent {
            val intent = Intent(context, WatchdogReceiver::class.java).setAction(ACTION)
            var piFlags = flags
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                piFlags = piFlags or PendingIntent.FLAG_IMMUTABLE
            }
            return PendingIntent.getBroadcast(context, 1001, intent, piFlags)
        }

        /** (Re)schedule the next watchdog tick, replacing any previous one. */
        fun scheduleNext(context: Context, delayMs: Long = TICK_MS) {
            val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val triggerAt = System.currentTimeMillis() + delayMs
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && !am.canScheduleExactAlarms()) {
                    // Android 12+ fallback: inexact still delivers within
                    // ~15 min in Doze — degraded but functional.
                    am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAt, pendingIntent(context, 0))
                    Log.w(TAG, "Exact alarms not permitted — using inexact watchdog tick")
                } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAt, pendingIntent(context, 0))
                } else {
                    am.setExact(AlarmManager.RTC_WAKEUP, triggerAt, pendingIntent(context, 0))
                }
            } catch (e: Exception) {
                // SecurityException on OEM builds that block even allowed
                // exact alarms — degrade to inexact rather than crash.
                Log.w(TAG, "Exact alarm scheduling failed (${e.message}) — inexact fallback")
                am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAt, pendingIntent(context, 0))
            }
        }

        fun cancel(context: Context) {
            val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            am.cancel(pendingIntent(context, 0))
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != ACTION) return

        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val armed = prefs.getBoolean(KEY_ARMED, false)

        if (!armed) {
            Log.i(TAG, "Disarmed — chain ends")
            return
        }

        val anyJobActive = prefs.getBoolean(KEY_RIDER_ACTIVE, false) ||
                prefs.getBoolean(KEY_CUSTOMER_ACTIVE, false) ||
                prefs.getBoolean(KEY_RIDER_ORDER_ACTIVE, false) ||
                prefs.getString(KEY_CHAT_WATCH, "")!!.isNotEmpty() ||
                prefs.getString(KEY_CHAT_WATCH_RIDER, "")!!.isNotEmpty()

        if (!anyJobActive) {
            // Everything finished while we slept — stop the chain quietly.
            prefs.edit().putBoolean(KEY_ARMED, false).apply()
            Log.i(TAG, "No active jobs — disarming")
            return
        }

        val heartbeat = prefs.getLong(KEY_HEARTBEAT, 0L)
        val age = System.currentTimeMillis() - heartbeat
        if (heartbeat == 0L || age > STALE_MS) {
            Log.w(TAG, "Service dead (heartbeat age ${age}ms) — restarting")
            restartService(context)
        } else {
            Log.i(TAG, "Service healthy (heartbeat age ${age}ms)")
        }

        // Keep the chain alive regardless of what we found; it self-stops
        // via the armed/anyJobActive checks once tracking ends.
        scheduleNext(context)
    }

    /**
     * Restart the plugin's foreground service. The plugin reads its
     * "should I run?" state from the shared flags (same ones the app's
     * Dart code writes), so a cold start picks up exactly where the kill
     * left off — no duplicate configuration needed.
     */
    private fun restartService(context: Context) {
        try {
            val intent = Intent().setClassName(context, "id.flutter.flutter_background_service.BackgroundService")
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Restart failed: ${e.message}")
        }
    }
}
