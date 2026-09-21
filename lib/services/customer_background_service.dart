import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'unified_background_service.dart';

/// Customer order/ETA tracking — public API kept identical to before so
/// no screen code needs to change. Internally this now just flips flags
/// read by UnifiedBackgroundService's single onStart handler, instead of
/// configuring its own competing flutter_background_service instance.
/// (See unified_background_service.dart for why that was broken.)
class CustomerBackgroundService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  /// Initialize (configures the shared singleton exactly once — safe to
  /// call this and BackgroundLocationService's initialize() in any order).
  static Future<void> initialize() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);
    await _notifications.initialize(initSettings);

    await UnifiedBackgroundService.ensureConfigured();
    print('[CustomerBG] ✅ Ready (shared background service)');
  }

  /// Start tracking an order's ETA/status for the customer.
  static Future<void> trackOrder(String orderId) async {
    await _saveTrackingState(orderId);
    await UnifiedBackgroundService.ensureRunning();
    print('[CustomerBG] ✅ Started tracking order: $orderId');
  }

  /// Stop tracking.
  static Future<void> stopTracking() async {
    await _clearTrackingState();
    await UnifiedBackgroundService.stopIfNothingActive();

    await _notifications.cancel(9001);
    await _notifications.cancel(9003);
    print('[CustomerBG] ⏹️ Stopped tracking');
  }

  static Future<void> _saveTrackingState(String orderId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(UnifiedBackgroundService.kCustomerOrderId, orderId);
    await prefs.setBool(UnifiedBackgroundService.kCustomerActive, true);
    await prefs.setString('tracking_started_at', DateTime.now().toIso8601String());
  }

  static Future<void> _clearTrackingState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(UnifiedBackgroundService.kCustomerOrderId);
    await prefs.setBool(UnifiedBackgroundService.kCustomerActive, false);
    await prefs.remove('tracking_started_at');
    await prefs.remove('last_eta_seconds');
    await prefs.remove('last_order_status');
  }

  /// Restore tracking state on app start.
  static Future<void> restoreTrackingState() async {
    final prefs = await SharedPreferences.getInstance();
    final isTracking = prefs.getBool(UnifiedBackgroundService.kCustomerActive) ?? false;
    final orderId = prefs.getString(UnifiedBackgroundService.kCustomerOrderId);

    if (isTracking && orderId != null && orderId.isNotEmpty) {
      await trackOrder(orderId);
    }
  }

  /// Get remaining ETA seconds from saved state.
  static Future<int?> getRemainingEta() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('last_eta_seconds');
  }

  /// Get tracked order ID.
  static Future<String?> getTrackedOrderId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(UnifiedBackgroundService.kCustomerOrderId);
  }
}
