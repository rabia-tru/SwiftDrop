package com.example.rider_app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log

/**
 * Resumes background tracking after a device reboot.
 *
 * The kill-survival watchdog (WatchdogReceiver.kt) covers "Android killed
 * the process mid-session" — but a reboot is a different failure mode:
 * alarms are cleared, the process is gone, and nothing would ever restart
 * tracking for a rider who shut their phone off at lunch and booted it on
 * the road. This receiver closes that gap.
 *
 * It runs at boot OUTSIDE the app process, reads the same persisted job
 * flags the rest of the pipeline uses, and — only if a job was active —
 * cold-starts the plugin's foreground service, which picks up its state
 * (order id, GPS, chat watches) from SharedPreferences exactly like the
 * watchdog restart does.
 *
 * Registered in AndroidManifest.xml with:
 *   - BOOT_COMPLETED            → normal boot (on FBE devices this fires
 *                                 AFTER unlock, when credential-encrypted
 *                                 storage — incl. our SharedPreferences —
 *                                 becomes readable)
 *   - MY_PACKAGE_REPLACED       → app updated over Play/adb while
 *                                 tracking was on (same "everything
 *                                 died" situation as a reboot)
 *
 * Note: the plugin ALSO ships its own BootReceiver, but it no-ops for us
 * because we configure the service with autoStart:false (we only want a
 * boot resume when a job flag is actually set, not on every launch).
 */
class BootReceiver : BroadcastReceiver() {

    companion object {
        const val TAG = "BootReceiver"

        // SharedPreferences — MUST match the keys used by the Dart side.
        const val PREFS = "FlutterSharedPreferences"
        const val KEY_RIDER_ACTIVE = "flutter.bg_tracking_active"
        const val KEY_CUSTOMER_ACTIVE = "flutter.is_tracking_order"
        const val KEY_RIDER_ORDER_ACTIVE = "flutter.is_rider_tracking"
        const val KEY_CHAT_WATCH = "flutter.chat_watch_order_customer"
        const val KEY_CHAT_WATCH_RIDER = "flutter.chat_watch_order_rider"
        const val KEY_WATCHDOG_ARMED = "flutter.watchdog_armed"

        /** Mirrors the receiver-side decision logic, unit-tested in Dart
         *  (test/boot_resume_policy_test.dart) to pin the contract. */
        fun shouldResume(
            riderActive: Boolean,
            customerActive: Boolean,
            riderOrderActive: Boolean,
            chatCustomer: String?,
            chatRider: String?,
        ): Boolean = riderActive || customerActive || riderOrderActive ||
                !chatCustomer.isNullOrEmpty() || !chatRider.isNullOrEmpty()
    }

    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action ?: return
        when (action) {
            Intent.ACTION_BOOT_COMPLETED, Intent.ACTION_MY_PACKAGE_REPLACED -> {}
            // LOCKED_BOOT_COMPLETED fires before credential-encrypted
            // storage is unlocked; our prefs aren't readable yet. The
            // plain BOOT_COMPLETED broadcast follows once the user
            // unlocks, so the actual resume happens there.
            Intent.ACTION_LOCKED_BOOT_COMPLETED -> {
                Log.i(TAG, "Locked boot — deferring resume until BOOT_COMPLETED")
                return
            }
            else -> return
        }

        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val resume = shouldResume(
            riderActive = prefs.getBoolean(KEY_RIDER_ACTIVE, false),
            customerActive = prefs.getBoolean(KEY_CUSTOMER_ACTIVE, false),
            riderOrderActive = prefs.getBoolean(KEY_RIDER_ORDER_ACTIVE, false),
            chatCustomer = prefs.getString(KEY_CHAT_WATCH, null),
            chatRider = prefs.getString(KEY_CHAT_WATCH_RIDER, null),
        )

        if (!resume) {
            Log.i(TAG, "Boot: no active tracking jobs — not resuming")
            return
        }

        Log.i(TAG, "Boot: tracking was active — resuming service")

        // Re-arm the watchdog as part of the resume so the kill-survival
        // alarm chain is rebuilt for the new process lifetime.
        try {
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                .edit().putBoolean(KEY_WATCHDOG_ARMED, true).apply()
            WatchdogReceiver.scheduleNext(context)
        } catch (e: Exception) {
            Log.w(TAG, "Watchdog re-arm failed: ${e.message}")
        }

        // Cold-start the plugin's foreground service. It reads the same
        // flags to decide what jobs to run; if the app itself is launched
        // later, main.dart's restore path is a no-op because flags match.
        try {
            val service = Intent().setClassName(
                context,
                "id.flutter.flutter_background_service.BackgroundService",
            )
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(service)
            } else {
                context.startService(service)
            }
        } catch (e: Exception) {
            // Android 12+ can require the app to have shown a notification
            // recently; if that fails here, the foreground service cannot
            // start from the background. Flag it loudly — the rider can
            // recover by simply opening the app once.
            Log.e(TAG, "Service start from boot failed: ${e.message}")
        }
    }
}
