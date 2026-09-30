import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

import 'ios_native_location_service.dart';
import 'unified_background_service.dart';

/// Rider GPS location tracking — public API kept identical so no screen
/// code needs to change.
///
/// Platform split:
/// - **Android** — flips flags read by UnifiedBackgroundService's single
///   foreground-service handler (the only way GPS survives app closure).
/// - **iOS** — delegates to IosNativeLocationService, which talks over a
///   method channel to the CLLocationManager + background-URLSession
///   tracker in AppDelegate.swift. The Dart isolate cannot keep running
///   once iOS suspends the app, so the flags/SQLite-queue path is skipped
///   entirely on this platform.
class BackgroundLocationService {
  /// Initialize the background service. On iOS this also probes the native
  /// side and installs the permission-lost callback (restarts tracking
  /// whenever the user re-grants access from Settings).
  static Future<void> initialize() async {
    if (Platform.isIOS) {
      await IosNativeLocationService.warmUp();
      IosNativeLocationService.setPermissionLostHandler(() {
        // fired when authorization drops to denied/restricted while
        // tracking — native stops updates itself; nothing to do here
        // beyond logging (UI can query isTracking()/requestPermissions()).
        print('[BG-Location] ⚠️ iOS location permission lost');
      });
      print('[BG-Location] ✅ Ready (native CLLocationManager tracker)');
      return;
    }

    await UnifiedBackgroundService.ensureConfigured();
    print('[BG-Location] ✅ Ready (shared background service)');
  }

  /// Start rider GPS tracking for the given order (or general "online"
  /// tracking if orderId is null).
  static Future<void> start({String? orderId}) async {
    if (Platform.isIOS) {
      await IosNativeLocationService.startTracking(orderId);
      print('[BG-Location] ✅ Rider GPS tracking started (native iOS) for order: $orderId');
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(UnifiedBackgroundService.kRiderActive, true);
    await prefs.setString(UnifiedBackgroundService.kRiderOrderId, orderId ?? '');

    await UnifiedBackgroundService.ensureRunning();
    print('[BG-Location] ✅ Rider GPS tracking started for order: $orderId');
  }

  /// Stop rider GPS tracking.
  static Future<void> stop() async {
    if (Platform.isIOS) {
      await IosNativeLocationService.stopTracking();
      print('[BG-Location] ⏹️ Rider GPS tracking stopped (native iOS)');
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(UnifiedBackgroundService.kRiderActive, false);
    await prefs.remove(UnifiedBackgroundService.kRiderOrderId);

    await UnifiedBackgroundService.stopIfNothingActive();
    print('[BG-Location] ⏹️ Rider GPS tracking stopped');
  }

  /// Whether rider tracking is currently active. On iOS this reflects the
  /// native tracker's own persisted state (survives process relaunches).
  static Future<bool> isRunning() async {
    if (Platform.isIOS) return IosNativeLocationService.isTracking();
    return UnifiedBackgroundService.isRunning();
  }

  /// Restore rider GPS tracking state after an app restart.
  static Future<void> restoreTrackingState() async {
    if (Platform.isIOS) {
      // The native side re-arms itself from UserDefaults at launch, but
      // it needs a fresh token + apiBaseUrl for uploads, so re-issue them.
      final prefs = await SharedPreferences.getInstance();
      final isActive = prefs.getBool(UnifiedBackgroundService.kRiderActive) ?? false;
      final orderId = prefs.getString(UnifiedBackgroundService.kRiderOrderId);
      if (isActive) {
        await IosNativeLocationService.startTracking(
          (orderId != null && orderId.isNotEmpty) ? orderId : null,
        );
        print('[BG-Location] 🔄 Restored native iOS tracking state');
      }
      return;
    }

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
    if (Platform.isIOS) {
      await IosNativeLocationService.startTracking(orderId); // updates orderId in place
      print('[BG-Location] Current order set (native iOS): $orderId');
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(UnifiedBackgroundService.kRiderOrderId, orderId ?? '');
    await UnifiedBackgroundService.ensureRunning();
    print('[BG-Location] Current order set: $orderId');
  }

  /// Force-upload whatever location pings are still queued locally
  /// (iOS native queue; Android is handled by the unified service's
  /// periodic sync).
  static Future<void> flushQueue() async {
    if (Platform.isIOS) {
      await IosNativeLocationService.flushQueue();
    }
  }
}
