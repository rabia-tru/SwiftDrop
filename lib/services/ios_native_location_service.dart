import 'dart:io';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';

/// Dart bridge to the NATIVE iOS background location tracker implemented
/// in ios/Runner/AppDelegate.swift.
///
/// Why this exists: `flutter_background_service` cannot keep a Dart isolate
/// running once iOS suspends the app, so on iOS the actual GPS + upload
/// work is done natively (CLLocationManager + background URLSession) and
/// this class is just the remote control.
///
/// On Android this whole service is a no-op — Android keeps using the
/// unified foreground service (see unified_background_service.dart).
class IosNativeLocationService {
  static const _channel = MethodChannel('app/native_location');

  /// SharedPreferences key holding the auth token — the native side reads
  /// the same key to build the Authorization header for uploads.
  static const _flutterTokenKey = 'flutter.auth_token';

  /// True when running on iOS and the native tracker answered at least one
  /// call (defends against the channel not being set up yet).
  static bool _available = false;

  static bool get isSupportedPlatform => Platform.isIOS;

  /// Fire-and-forget availability probe. Safe to call on any platform.
  static Future<void> warmUp() async {
    if (!isSupportedPlatform) return;
    try {
      await _channel.invokeMethod('pendingCount');
      _available = true;
    } on MissingPluginException {
      _available = false;
    } catch (_) {
      // Channel exists but native side not ready — assume available anyway
      // once the app is fully launched.
      _available = true;
    }
  }

  static Future<bool> _invokeBool(String method, [Map<String, dynamic>? args]) async {
    if (!isSupportedPlatform || !_available) return false;
    try {
      return await _channel.invokeMethod<bool>(method, args) ?? false;
    } on MissingPluginException {
      _available = false;
      return false;
    } on PlatformException {
      return false;
    }
  }

  /// Start native background GPS tracking for [orderId]. Also writes the
  /// auth token + API base so native uploads can reach the backend.
  static Future<bool> startTracking(String? orderId) async {
    if (!isSupportedPlatform) return false;
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    if (token != null) {
      // Native side reads 'flutter.auth_token' from UserDefaults — the
      // shared_preferences plugin prefixes keys with 'flutter.'.
      await prefs.setString(_flutterTokenKey, token);
    }
    return _invokeBool('startTracking', {
      'orderId': orderId ?? '',
      'apiBaseUrl': AppConfig.apiBaseUrl,
    });
  }

  /// Stop native tracking and flush whatever is still queued.
  static Future<void> stopTracking() async {
    await _invokeBool('stopTracking');
  }

  /// Whether the native tracker believes it is currently tracking.
  static Future<bool> isTracking() => _invokeBool('isTracking');

  /// Number of pings sitting in the native queue awaiting upload.
  static Future<int> pendingCount() async {
    if (!isSupportedPlatform || !_available) return 0;
    try {
      return await _channel.invokeMethod<int>('pendingCount') ?? 0;
    } catch (_) {
      return 0;
    }
  }

  /// Force an upload attempt of the native queue.
  static Future<void> flushQueue() async {
    await _invokeBool('flushQueue');
  }

  /// Result of asking iOS for location authorization:
  /// always / whenInUse / denied / restricted / notDetermined / unknown.
  static Future<String> requestPermissions() async {
    if (!isSupportedPlatform || !_available) return 'unknown';
    try {
      return await _channel.invokeMethod<String>('requestPermissions') ?? 'unknown';
    } catch (_) {
      return 'unknown';
    }
  }

  /// Install the native→Dart callback for when background authorization is
  /// revoked (user flips it off in Settings). [onPermissionLost] runs on
  /// the main isolate.
  static void setPermissionLostHandler(void Function() onPermissionLost) {
    if (!isSupportedPlatform) return;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onPermissionLost') {
        onPermissionLost();
      }
    });
  }
}
