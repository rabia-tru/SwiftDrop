import 'package:shared_preferences/shared_preferences.dart';
import 'unified_background_service.dart';

/// Bridges the chat UI and the unified background service.
///
/// When a chat screen is open for an order, the background chat-watcher is
/// paused for that order (the UI shows messages live via WebSocket). When
/// the chat closes — or the app is killed — the watcher keeps polling and
/// posts a system notification for every new message from the other side.
class ChatNotificationService {
  /// Start watching an order's chat. Call when a chat screen opens —
  /// the background poller suppresses notifications for watched orders
  /// whose chat is currently open on screen.
  static Future<void> startWatch(String orderId, String myRole) async {
    if (orderId.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    if (myRole == 'rider') {
      await prefs.setString(UnifiedBackgroundService.kChatRiderOrder, orderId);
    } else {
      await prefs.setString(UnifiedBackgroundService.kChatCustomerOrder, orderId);
    }
    await UnifiedBackgroundService.ensureRunning();
  }

  /// Stop watching (chat closed or order finished). The watch flag is
  /// removed; if the app is still alive the in-app stream handles badges.
  static Future<void> stopWatch(String orderId, String myRole) async {
    final prefs = await SharedPreferences.getInstance();
    final key = (myRole == 'rider')
        ? UnifiedBackgroundService.kChatRiderOrder
        : UnifiedBackgroundService.kChatCustomerOrder;
    if (prefs.getString(key) == orderId) {
      await prefs.remove(key);
      await UnifiedBackgroundService.stopIfNothingActive();
    }
  }

  /// Called by ChatScreen when the user sends a message — the background
  /// poller's baseline count updates on next tick, so our own message
  /// never triggers a notification.
  static Future<void> notifyOwnMessageSent(String orderId) async {
    // Nothing needed: the poller compares counts and only announces the
    // latest message when its senderRole is the other side. Our own sends
    // are filtered by senderRole check inside the background isolate.
  }
}
