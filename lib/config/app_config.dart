// Change this to your deployed backend URL before building a release APK.
// For local testing on a physical Android device, use your PC's LAN IP
// (not localhost/127.0.0.1 — the phone can't reach your PC's localhost).
// PC LAN IPs seen so far: 192.168.100.2 (old), 192.168.54.240 (current).
// If login shows "No internet connection", run `ipconfig` and update below.
// For Android emulator talking to a backend on your dev machine, use:
// 'http://10.0.2.2:3000/api'
class AppConfig {
  // Multi-phone testing: both phones connect to the PC over WiFi.
  // PC LAN IP: 192.168.100.2 / 192.168.54.240 (run `ipconfig` to check if it changes)
  // USB single-phone testing: use 'http://127.0.0.1:3000/api' + adb reverse
  static const String apiBaseUrl = 'http://192.168.54.240:3000/api';

  /// WebSocket URL is derived from apiBaseUrl by stripping '/api'
  /// e.g. http://192.168.100.121:3000/api → http://192.168.100.121:3000
  static String get wsBaseUrl {
    final apiIndex = apiBaseUrl.lastIndexOf('/api');
    return apiIndex > 0 ? apiBaseUrl.substring(0, apiIndex) : apiBaseUrl;
  }

  // How often the background service takes a location reading and
  // attempts to sync it, in seconds.
  static const int locationSyncIntervalSeconds = 30;
}
