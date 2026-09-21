import 'dart:io';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';

/// Battery Optimization Helper — Requests exemption on Android
/// Prevents OEM battery managers from killing background tracking
class BatteryOptimizationHelper {
  static const MethodChannel _channel = MethodChannel('battery_optimization');

  /// Check if battery optimization is disabled for this app
  static Future<bool> isIgnoringBatteryOptimizations() async {
    if (!Platform.isAndroid) return true; // iOS doesn't have this
    try {
      final result = await _channel.invokeMethod('isIgnoringBatteryOptimizations');
      return result == true;
    } catch (e) {
      // Fallback: assume not ignoring if we can't check
      return false;
    }
  }

  /// Request to ignore battery optimizations for this app
  /// This will show a system dialog asking the user to allow it
  static Future<bool> requestIgnoreBatteryOptimizations() async {
    if (!Platform.isAndroid) return true;
    try {
      final result = await _channel.invokeMethod('requestIgnoreBatteryOptimizations');
      return result == true;
    } catch (e) {
      // Fallback: try using geolocator's method
      try {
        await Geolocator.openLocationSettings();
        return false;
      } catch (_) {
        return false;
      }
    }
  }

  /// Is Android battery-saver (power saving) mode currently ON?
  /// While ON, Android throttles background GPS aggressively.
  static Future<bool> isPowerSaveModeOn() async {
    if (!Platform.isAndroid) return false;
    try {
      final result = await _channel.invokeMethod('isPowerSaveMode');
      return result == true;
    } catch (_) {
      return false;
    }
  }

  /// Open the system Battery Saver settings page so the user can turn it off.
  static Future<void> openBatterySaverSettings() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('openBatterySaverSettings');
    } catch (_) {
      try {
        await Geolocator.openLocationSettings();
      } catch (_) {}
    }
  }

  /// Open battery optimization settings for this app
  /// So user can manually disable it
  static Future<void> openBatteryOptimizationSettings() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('openBatterySettings');
    } catch (e) {
      // Fallback: open app settings
      try {
        await Geolocator.openAppSettings();
      } catch (_) {}
    }
  }

  /// Get manufacturer-specific instructions
  static String getManufacturerInstructions() {
    final manufacturer = Platform.operatingSystemVersion;
    if (manufacturer.toLowerCase().contains('xiaomi')) {
      return 'Xiaomi: Settings → Apps → Manage Apps → SwiftDrop → Battery Saver → No restrictions';
    } else if (manufacturer.toLowerCase().contains('oppo') || manufacturer.toLowerCase().contains('realme')) {
      return 'OPPO/Realme: Settings → Battery → SwiftDrop → Allow background activity';
    } else if (manufacturer.toLowerCase().contains('vivo')) {
      return 'Vivo: Settings → More Settings → Applications → SwiftDrop → Background management → Allow';
    } else if (manufacturer.toLowerCase().contains('samsung')) {
      return 'Samsung: Settings → Device Care → Battery → SwiftDrop → Allow background activity';
    } else if (manufacturer.toLowerCase().contains('huawei')) {
      return 'Huawei: Settings → Battery → App Launch → SwiftDrop → Manage Manually → Auto-launch + Run in background';
    }
    return 'Settings → Apps → SwiftDrop → Battery → Select "Unrestricted" or "Allow background activity"';
  }
}
