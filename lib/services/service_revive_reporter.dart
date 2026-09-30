import 'package:shared_preferences/shared_preferences.dart';

import 'api_service.dart';

/// Client-side companion to the backend's location-gap revive channel.
///
/// The backend can only *detect* a gap (no pings for N minutes); it cannot
/// tell "killed once" from "killed every 60 seconds" (OEM deep-kill loop).
/// This reporter gives the backend that ground truth: the watchdog records
/// how many times it had to restart the service, and once the count passes
/// [kReportThreshold] within one tracking session, the app tells the
/// backend. The backend can then log/flag the device (and, once FCM is
/// added to this project, escalate to a real silent push).
///
/// All persistence uses plain SharedPreferences counters so it survives
/// the very kills it reports.
class ServiceReviveReporter {
  static const kKillCountKey = 'watchdog_kill_count';
  static const kSessionIdKey = 'watchdog_session_id';
  static const kReportedCountKey = 'watchdog_last_reported_count';

  /// Number of watchdog restarts within one tracking session after which
  /// the app reports "repeated kills" to the backend.
  static const int kReportThreshold = 2;

  /// Called by UnifiedBackgroundService on startup. Increments the kill
  /// counter if the previous session was interrupted abnormally (tracking
  /// flags still active but service was gone — i.e. the watchdog or boot
  /// receiver restarted us), and reports when the threshold is crossed.
  static Future<void> recordStartup({required bool revivedAfterKill}) async {
    if (!revivedAfterKill) {
      // Normal (user-initiated or boot-resume) start: reset the streak.
      await _reset();
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final count = (prefs.getInt(kKillCountKey) ?? 0) + 1;
    await prefs.setInt(kKillCountKey, count);

    if (count >= kReportThreshold) {
      final alreadyReported = prefs.getInt(kReportedCountKey) ?? 0;
      if (count > alreadyReported) {
        await prefs.setInt(kReportedCountKey, count);
        try {
          await ApiService.reportServiceKills(
            killCount: count,
            windowMinutes: 30,
          );
        } catch (_) {
          // Reporting is best-effort; the counter persists for the next
          // successful sync if the request failed.
          await prefs.setInt(kReportedCountKey, alreadyReported);
        }
      }
    }
  }

  static Future<void> _reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(kKillCountKey, 0);
    await prefs.setInt(kReportedCountKey, 0);
  }
}
