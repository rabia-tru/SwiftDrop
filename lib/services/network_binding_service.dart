import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Keeps the app's sockets bound to the WiFi network on Android.
///
/// Why this exists: when the phone has BOTH mobile data and WiFi on, Android
/// often routes the app through cellular (the default network). The backend
/// runs on a PC's LAN IP (192.168.x.x) which is only reachable over WiFi —
/// so with mobile data on, every API call failed ("no internet" while the
/// browser worked fine, since browsers use per-network connections).
///
/// Fix: MainActivity.kt binds the whole process to WiFi via
/// ConnectivityManager.bindProcessToNetwork() whenever a WiFi network is
/// available. This service complements it by re-asserting the binding when
/// the app RESUMES (some OEMs reset process bindings when the app is
/// backgrounded/killed to save memory).
class NetworkBindingService with WidgetsBindingObserver {
  NetworkBindingService._();
  static final NetworkBindingService instance = NetworkBindingService._();

  static const _channel = MethodChannel('network_binding');
  bool _wired = false;

  /// Call once from main() after runApp.
  void init() {
    if (_wired) return;
    _wired = true;
    WidgetsBinding.instance.addObserver(this);
    rebind();
  }

  /// Called on every app lifecycle change — re-assert the WiFi binding on
  /// resume (cheap no-op when already bound).
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      rebind();
    }
  }

  /// Ask the Android side to re-bind to WiFi. Returns true when bound to
  /// WiFi, false otherwise (no WiFi / API < 23 / platform not Android).
  Future<bool> rebind() async {
    if (defaultTargetPlatform != TargetPlatform.android) return false;
    try {
      final bound = await _channel.invokeMethod<bool>('rebind');
      return bound ?? false;
    } on MissingPluginException {
      return false; // hot-reload / non-Android runtime
    } on PlatformException {
      return false;
    }
  }
}
