import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'unified_background_service.dart';

/// Rider order-status tracking (shows "Order Picked Up" / "Delivered"
/// style notifications while a rider is on a delivery).
///
/// Public API kept identical to before so no screen code needs to change.
/// Previously this ran on an in-app `Timer.periodic`, which meant it died
/// the instant the app process was killed — exactly when a rider is most
/// likely to have the app swiped away mid-delivery. It's now handled by
/// UnifiedBackgroundService's single real foreground-service `onStart`,
/// so it survives the app being killed the same way GPS tracking does.
class RiderBackgroundService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  /// Initialize notifications (configures the shared singleton service
  /// exactly once — safe to call alongside the other services' initialize()).
  static Future<void> initialize() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);
    await _notifications.initialize(initSettings);

    await UnifiedBackgroundService.ensureConfigured();
    print('[RiderBackgroundService] ✅ Ready (shared background service)');
  }

  /// Start tracking the current order's status for the rider.
  static Future<void> startTracking({String? orderId}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(UnifiedBackgroundService.kRiderOrderTrackedId, orderId ?? '');
    await prefs.setBool(UnifiedBackgroundService.kRiderOrderActive, orderId != null);

    if (orderId != null) {
      await UnifiedBackgroundService.ensureRunning();
    } else {
      await UnifiedBackgroundService.stopIfNothingActive();
    }
    print('[RiderBackgroundService] Started tracking order: $orderId');
  }

  /// Stop tracking.
  static Future<void> stopTracking() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(UnifiedBackgroundService.kRiderOrderTrackedId);
    await prefs.setBool(UnifiedBackgroundService.kRiderOrderActive, false);

    await UnifiedBackgroundService.stopIfNothingActive();
    await _notifications.cancel(9002);
    print('[RiderBackgroundService] Stopped tracking');
  }

  /// Restore tracking state on app start.
  static Future<void> restoreTrackingState() async {
    final prefs = await SharedPreferences.getInstance();
    final isTracking = prefs.getBool(UnifiedBackgroundService.kRiderOrderActive) ?? false;
    final orderId = prefs.getString(UnifiedBackgroundService.kRiderOrderTrackedId);

    if (isTracking && orderId != null && orderId.isNotEmpty) {
      await startTracking(orderId: orderId);
    }
  }
}
