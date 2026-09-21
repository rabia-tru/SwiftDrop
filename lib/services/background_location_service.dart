import 'package:shared_preferences/shared_preferences.dart';
import 'unified_background_service.dart';

/// Rider GPS location tracking — public API kept identical to before so
/// no screen code needs to change. Internally this now just flips flags
/// read by UnifiedBackgroundService's single onStart handler, instead of
/// configuring its own competing flutter_background_service instance.
/// (See unified_background_service.dart for why that was broken.)
class BackgroundLocationService {
  /// Initialize the background service (configures the shared singleton
  /// exactly once — safe to call this and CustomerBackgroundService's
  /// initialize() in any order).
  static Future<void> initialize() async {
    await UnifiedBackgroundService.ensureConfigured();
    print('[BG-Location] ✅ Ready (shared background service)');
  }

  /// Start rider GPS tracking for the given order (or general "online"
  /// tracking if orderId is null).
  static Future<void> start({String? orderId}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(UnifiedBackgroundService.kRiderActive, true);
    await prefs.setString(UnifiedBackgroundService.kRiderOrderId, orderId ?? '');

    await UnifiedBackgroundService.ensureRunning();
    print('[BG-Location] ✅ Rider GPS tracking started for order: $orderId');
  }

  /// Stop rider GPS tracking.
  static Future<void> stop() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(UnifiedBackgroundService.kRiderActive, false);
    await prefs.remove(UnifiedBackgroundService.kRiderOrderId);

    await UnifiedBackgroundService.stopIfNothingActive();
    print('[BG-Location] ⏹️ Rider GPS tracking stopped');
  }

  /// Whether the shared background process is currently running (true if
  /// EITHER rider GPS tracking or customer ETA tracking is active).
  static Future<bool> isRunning() => UnifiedBackgroundService.isRunning();

  /// Restore rider GPS tracking state after an app restart.
  static Future<void> restoreTrackingState() async {
    final prefs = await SharedPreferences.getInstance();
    final isActive = prefs.getBool(UnifiedBackgroundService.kRiderActive) ?? false;
    final orderId = prefs.getString(UnifiedBackgroundService.kRiderOrderId);

    if (isActive) {
      await start(orderId: (orderId != null && orderId.isNotEmpty) ? orderId : null);
      print('[BG-Location] 🔄 Restored rider tracking state');
    }
  }

  /// Update which order the rider is currently delivering, without
  /// restarting the whole service.
  static Future<void> setCurrentOrder(String? orderId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(UnifiedBackgroundService.kRiderOrderId, orderId ?? '');
    await UnifiedBackgroundService.ensureRunning();
    print('[BG-Location] Current order set: $orderId');
  }
}
