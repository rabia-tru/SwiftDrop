import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../screens/track_order_screen.dart';
import '../screens/chat_screen.dart';
import 'api_service.dart';

/// Handles notification taps: when a tracking/order notification is tapped,
/// fetch the latest order from the backend and open the live Track screen —
/// works whether the app is in memory or cold-started from a killed state.
///
/// Chat notifications carry a `chat:{orderId}` payload so the tap opens the
/// chat screen directly instead of the tracking map.
class NotificationTapHandler {
  static GlobalKey<NavigatorState>? _navigatorKey;
  static bool _initialized = false;

  /// Call once from main() — pass the MaterialApp's navigatorKey.
  static void init(GlobalKey<NavigatorState> key) {
    _navigatorKey = key;
    _initialized = true;
    _handlePendingLaunch();
  }

  static bool get isInitialized => _initialized;

  /// Main entry — called by every notification tap callback.
  /// [payload] is the orderId for tracking notifications, `chat:{orderId}`
  /// for chat notifications, or 'promo' for generic ones.
  static void handleTap(String? payload) {
    print('[NotificationTap] Tapped, payload: $payload');

    if (payload == null || payload.isEmpty || payload == 'promo') {
      // Generic notification — just bring the app forward (default behavior).
      return;
    }

    if (payload.startsWith('chat:')) {
      final orderId = payload.substring(5);
      if (orderId.isNotEmpty) _navigateToChat(orderId);
      return;
    }

    _navigateToTracking(payload);
  }

  /// Cold start: the notification itself launched the app.
  static Future<void> _handlePendingLaunch() async {
    try {
      final details =
          await FlutterLocalNotificationsPlugin().getNotificationAppLaunchDetails();
      final didLaunch = details?.didNotificationLaunchApp ?? false;
      final payload = details?.notificationResponse?.payload;
      if (didLaunch && payload != null && payload.isNotEmpty) {
        print('[NotificationTap] Cold-start from notification, payload: $payload');
        // Give the splash a moment to mount the navigator, then open tracking.
        Timer(const Duration(seconds: 2), () => handleTap(payload));
      }
    } catch (e) {
      print('[NotificationTap] Launch-details check failed: $e');
    }
  }

  /// Fetch order from backend and push TrackOrderScreen on top of everything.
  static Future<void> _navigateToTracking(String orderId) async {
    final nav = _navigatorKey?.currentState;
    if (nav == null) {
      // Navigator not ready yet (cold-start race) — retry shortly.
      Future.delayed(const Duration(milliseconds: 800),
          () => _navigateToTracking(orderId));
      return;
    }

    try {
      final order = await ApiService.getOrderById(orderId);
      if (!nav.context.mounted) return;
      nav.push(MaterialPageRoute(
        builder: (_) => TrackOrderScreen(order: Map<String, dynamic>.from(order)),
      ));
    } catch (e) {
      print('[NotificationTap] Could not load order $orderId: $e');
      // Fallback: open tracking with just the id — screen shows its loading/error state.
      final ctx = _navigatorKey?.currentContext;
      if (ctx != null && ctx.mounted) {
        Navigator.of(ctx).push(MaterialPageRoute(
          builder: (_) => TrackOrderScreen(order: {'id': orderId}),
        ));
      }
    }
  }

  /// Open the chat screen for an order. Works out of a notification tap:
  /// the order's rider/customer names are resolved from the API, with a
  /// generic fallback if the fetch fails.
  static Future<void> _navigateToChat(String orderId) async {
    final nav = _navigatorKey?.currentState;
    if (nav == null) {
      Future.delayed(const Duration(milliseconds: 800),
          () => _navigateToChat(orderId));
      return;
    }

    String otherName = 'Chat';
    String otherRole = 'rider';
    String myRole = 'customer';

    try {
      final order = await ApiService.getOrderById(orderId);
      final role = await ApiService.getLastLoginRole();
      myRole = (role == 'rider') ? 'rider' : 'customer';
      otherRole = (myRole == 'rider') ? 'customer' : 'rider';
      otherName = (myRole == 'rider')
          ? ((order['customerName'] ?? 'Customer').toString())
          : ((order['riderName'] ?? 'Rider').toString());
    } catch (_) {
      // Order fetch failed — still open chat with generic labels.
    }

    final ctx = _navigatorKey?.currentContext;
    if (ctx != null && ctx.mounted) {
      Navigator.of(ctx).push(MaterialPageRoute(
        builder: (_) => ChatScreen(
          orderId: orderId,
          otherUserName: otherName,
          otherUserRole: otherRole,
          currentUserRole: myRole,
        ),
      ));
    }
  }
}
