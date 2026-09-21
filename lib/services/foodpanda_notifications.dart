import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../theme/app_colors.dart';
import 'notification_tap_handler.dart';

/// FoodPanda-style Notifications — Extra UX notifications
class FoodPandaNotifications {
  static final FlutterLocalNotificationsPlugin _notifications = 
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  /// Must be called once before showing notifications — wires the tap
  /// handler so tapping an order notification opens live tracking.
  static Future<void> ensureInitialized() async {
    if (_initialized) return;
    _initialized = true;
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _notifications.initialize(
      const InitializationSettings(android: androidSettings),
      onDidReceiveNotificationResponse: (response) {
        print('[FoodPandaNotif] tapped: ${response.payload}');
        NotificationTapHandler.handleTap(response.payload);
      },
    );
  }

  /// 1. Order Confirmation (immediately after placing)
  static Future<void> orderConfirmed(String orderId) async {
    await _show(
      id: 10,
      title: '✅ Order Confirmed!',
      body: 'Your order #$orderId has been placed successfully',
      payload: orderId,
    );
  }

  /// 2. Rider is X minutes away
  static Future<void> riderNearby(String orderId, String minutes) async {
    await _show(
      id: 11,
      title: '🏍️ Rider is $minutes away!',
      body: 'Your order #$orderId is almost there',
      payload: orderId,
    );
  }

  /// 3. Rider is at pickup location
  static Future<void> riderAtPickup(String orderId) async {
    await _show(
      id: 12,
      title: '📍 Rider at pickup location',
      body: 'Rider has arrived to collect your order #$orderId',
      payload: orderId,
    );
  }

  /// 4. Order is being prepared
  static Future<void> orderPreparing(String orderId) async {
    await _show(
      id: 13,
      title: '👨‍🍳 Preparing your order',
      body: 'Your order #$orderId is being prepared',
      payload: orderId,
    );
  }

  /// 5. Rate your order (after delivery)
  static Future<void> rateOrder(String orderId) async {
    await Future.delayed(const Duration(minutes: 5)); // Delay 5 min
    await _show(
      id: 14,
      title: '⭐ Rate your order',
      body: 'How was your experience with order #$orderId?',
      payload: orderId,
    );
  }

  /// 6. Order cancelled by rider
  static Future<void> riderCancelled(String orderId, String reason) async {
    await _show(
      id: 15,
      title: '❌ Rider cancelled',
      body: 'Reason: $reason. Finding new rider for #$orderId...',
      payload: orderId,
    );
  }

  /// 7. Payment successful
  static Future<void> paymentSuccess(String orderId, String amount) async {
    await _show(
      id: 16,
      title: '💰 Payment Successful',
      body: 'Rs.$amount paid for order #$orderId',
      payload: orderId,
    );
  }

  /// 8. Promo/Discount available
  static Future<void> promoAvailable(String code, String discount) async {
    await _show(
      id: 17,
      title: '🎉 Special Offer!',
      body: 'Use code $code for $discount off your next order',
      payload: 'promo',
    );
  }

  /// 9. Rider is very close (500m)
  static Future<void> riderVeryClose(String orderId) async {
    await _show(
      id: 18,
      title: '🏠 Rider is very close!',
      body: 'Your order #$orderId will be delivered in 1-2 minutes',
      payload: orderId,
    );
  }

  /// 10. Delivery attempted but failed
  static Future<void> deliveryFailed(String orderId, String reason) async {
    await _show(
      id: 19,
      title: '⚠️ Delivery attempt failed',
      body: '$reason. Rider will try again for order #$orderId',
      payload: orderId,
    );
  }

  /// Base notification show method
  static Future<void> _show({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    await ensureInitialized();
    const androidDetails = AndroidNotificationDetails(
      'foodpanda_extras',
      'FoodPanda Extras',
      channelDescription: 'Extra notifications for better UX',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      color: AppColors.orange,
      enableVibration: true,
      playSound: true,
    );
    const details = NotificationDetails(android: androidDetails);
    
    await _notifications.show(id, title, body, details, payload: payload);
  }

  /// In-app heads-up chat notification — fires when a chat message arrives
  /// over WebSocket while this app is running but the chat screen is NOT
  /// open (app-kill case is handled by the background service instead).
  /// Tapping opens the chat via NotificationTapHandler's chat: payload.
  static Future<void> chatMessage(
    String orderId,
    String senderName,
    String message,
  ) async {
    final body = message.trim().isEmpty
        ? '📷 sent a photo'
        : (message.length > 80 ? '${message.substring(0, 80)}…' : message);

    await ensureInitialized();
    const androidDetails = AndroidNotificationDetails(
      'chat_messages',
      'Chat Messages',
      channelDescription: 'New chat messages about your order',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      color: AppColors.orange,
      enableVibration: true,
      playSound: true,
      category: AndroidNotificationCategory.message,
    );

    // Stable id per order: consecutive messages refresh one heads-up
    // instead of stacking duplicates.
    await _notifications.show(
      9100 + (orderId.hashCode.abs() % 900),
      '💬 $senderName',
      body,
      const NotificationDetails(android: androidDetails),
      payload: 'chat:$orderId',
    );
  }
}
