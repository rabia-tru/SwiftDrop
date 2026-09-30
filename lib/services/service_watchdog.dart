import 'dart:io';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Kill-survival watchdog for the background tracking service (Android).
///
/// While the unified background service is healthy it beats a heartbeat
/// into SharedPreferences every [beatInterval]. A native exact alarm
/// (WatchdogReceiver.kt) fires periodically; if it finds the heartbeat
/// stale while the tracking flags say a job should be running, it
/// restarts the plugin's foreground service — all OUTSIDE the app
/// process, so it survives the very kill it is watching for.
///
/// Nothing here runs on iOS: CLLocationManager + background URLSession
/// relaunch handle kill-survival there natively (AppDelegate.swift).
class ServiceWatchdog {
  static const _channel = MethodChannel('service_watchdog');

  /// Keep the timing constants in sync with WatchdogReceiver.kt.
  static const Duration beatInterval = Duration(seconds: 30);
  static const Duration staleAfter = Duration(seconds: 90);

  static const kHeartbeatKey = 'watchdog_heartbeat_ms';
  static const kArmedKey = 'watchdog_armed';

  /// Test seam: when non-null, arm/disarm calls are routed here instead
  /// of the real method channel.
  @visibleForTesting
  static Future<bool> Function(String method)? channelOverride;

  /// Test seam: unit tests run on desktop hosts where Platform.isAndroid
  /// is false; tests set this to exercise the arm/disarm paths.
  @visibleForTesting
  static bool? platformOverride;

  static bool get _isAndroid => platformOverride ?? Platform.isAndroid;

  static Future<bool> _invoke(String method) async {
    if (!_isAndroid) return false;
    final override = channelOverride;
    if (override != null) return override(method);
    try {
      return await _channel.invokeMethod<bool>(method) ?? false;
    } on MissingPluginException {
      return false; // unit tests / platform not ready
    } on PlatformException {
      return false;
    }
  }

  /// Start (or confirm) protection: marks the watchdog armed and
  /// schedules the first native check. Idempotent.
  static Future<void> ensureArmed() async {
    if (!_isAndroid) return;
    final prefs = await SharedPreferences.getInstance();
    final alreadyArmed = prefs.getBool(kArmedKey) ?? false;
    final ok = await _invoke('arm');
    if (ok || alreadyArmed) {
      await prefs.setBool(kArmedKey, true);
      print('[Watchdog] ✅ Armed — restart alarm chain active');
    } else {
      print('[Watchdog] ⚠️ Native side unreachable; will retry on next beat');
    }
  }

  /// Stop protection entirely (all tracking jobs ended).
  static Future<void> disarm() async {
    if (!_isAndroid) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kArmedKey, false);
    await prefs.remove(kHeartbeatKey);
    await _invoke('disarm');
    print('[Watchdog] ⏹️ Disarmed');
  }

  /// True when the watchdog considers protection active. The native
  /// receiver double-checks the job flags itself before restarting.
  static Future<bool> isArmed() async {
    if (!_isAndroid) return false;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(kArmedKey) ?? false;
  }

  /// Field-diagnostics snapshot for the tracking settings screen.
  /// Never throws — every field degrades independently so a broken
  /// piece (e.g. exact-alarm permission revoked) is visible, not fatal.
  static Future<WatchdogStatus> status() async {
    if (!_isAndroid) {
      return const WatchdogStatus(
        platformSupported: false,
        armed: false,
        canScheduleExactAlarms: true,
        lastBeatAge: null,
        lastBeatAt: null,
      );
    }
    final prefs = await SharedPreferences.getInstance();
    final beatMs = prefs.getInt(kHeartbeatKey);
    final now = DateTime.now().millisecondsSinceEpoch;
    return WatchdogStatus(
      platformSupported: true,
      armed: prefs.getBool(kArmedKey) ?? false,
      canScheduleExactAlarms: await _invoke('canScheduleExact'),
      lastBeatAge: beatMs == null ? null : now - beatMs,
      lastBeatAt: beatMs == null ? null : DateTime.fromMillisecondsSinceEpoch(beatMs),
    );
  }

  /// Write a fresh heartbeat. Called periodically from the background
  /// service's main loop; the native side compares this timestamp
  /// against its staleness window to detect a dead service.
  static Future<void> beat() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(kHeartbeatKey, DateTime.now().millisecondsSinceEpoch);
  }

  // ── Pure decision logic (unit-tested without Android) ──────────────

  /// What the native receiver should do for a given heartbeat age.
  /// Mirrors WatchdogReceiver.onReceive so tests pin the contract.
  static WatchdogDecision decide({
    required bool armed,
    required bool anyJobActive,
    required int heartbeatMs,
    required int nowMs,
    int staleMs = 90000,
  }) {
    if (!armed) return WatchdogDecision.ignore;
    if (!anyJobActive) return WatchdogDecision.selfDisarm;
    final age = nowMs - heartbeatMs;
    if (heartbeatMs <= 0 || age > staleMs) {
      return WatchdogDecision.restartService;
    }
    return WatchdogDecision.rearmOnly;
  }
}

enum WatchdogDecision { ignore, selfDisarm, restartService, rearmOnly }

/// Snapshot of watchdog health for UI display.
class WatchdogStatus {
  final bool platformSupported;
  final bool armed;

  /// Whether the OS lets us schedule the exact alarms the watchdog
  /// depends on (Android 12+ can have this revoked per-app).
  final bool canScheduleExactAlarms;

  /// Age of the last heartbeat. `null` = never beaten (service never
  /// ran since install / data cleared). Healthy service beats every 30s,
  /// so anything under ~2 min means the service was alive moments ago.
  final int? lastBeatAge;
  final DateTime? lastBeatAt;

  const WatchdogStatus({
    required this.platformSupported,
    required this.armed,
    required this.canScheduleExactAlarms,
    required this.lastBeatAge,
    required this.lastBeatAt,
  });

  /// UI verdict. Healthy requires: armed AND (alarm permission ok) AND
  /// (recent beat — service was running). [maxHealthyBeatAge] defaults
  /// to ~2 beats + slop, matching the native 90s staleness window.
  WatchdogHealth get health {
    if (!platformSupported) return WatchdogHealth.notApplicable;
    if (!canScheduleExactAlarms) return WatchdogHealth.broken;
    if (!armed) return WatchdogHealth.disarmed;
    final age = lastBeatAge;
    if (age == null) return WatchdogHealth.neverRan;
    if (age > maxHealthyBeatAgeMs) return WatchdogHealth.stale;
    return WatchdogHealth.healthy;
  }

  static const int maxHealthyBeatAgeMs = 90000;
}

enum WatchdogHealth {
  /// Android only feature — iOS/other platforms show nothing.
  notApplicable,

  /// Armed, exact alarms permitted, heartbeat fresh.
  healthy,

  /// Armed but the heartbeat is old — service likely killed recently;
  /// the watchdog should restart it within ~2 min (or already tried).
  stale,

  /// Watchdog never armed — tracking never started since install.
  neverRan,

  /// Armed flag cleared — all jobs ended (normal after going offline).
  disarmed,

  /// Exact-alarm permission revoked — watchdog CANNOT restart the
  /// service. Needs user action (Alarms & reminders special access).
  broken,
}
