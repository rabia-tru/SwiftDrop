import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../theme/app_colors.dart';
import 'notification_tap_handler.dart';

/// Push Notification Service — Handles all app notifications
class PushNotificationService {
  static final FlutterLocalNotificationsPlugin _notifications = 
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  /// Initialize notification service
  static Future<void> initialize() async {
    if (_initialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);
    
    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Create notification channels
    await _createNotificationChannels();
    
    _initialized = true;
  }

  /// Create Android notification channels
  static Future<void> _createNotificationChannels() async {
    const orderChannel = AndroidNotificationChannel(
      'order_updates',
      'Order Updates',
      description: 'Notifications for order status changes',
      importance: Importance.high,
      enableVibration: true,
      playSound: true,
    );

    const locationChannel = AndroidNotificationChannel(
      'location_tracking',
      'Location Tracking',
      description: 'Background location tracking notification',
      importance: Importance.low,
      enableVibration: false,
      playSound: false,
    );

    const riderTrackingChannel = AndroidNotificationChannel(
      'rider_order_tracking',
      'Rider Order Tracking',
      description: 'Persistent notification while delivering orders',
      importance: Importance.high,
      enableVibration: true,
      playSound: true,
    );

    // Channel used by flutter_background_service
    const backgroundTrackingChannel = AndroidNotificationChannel(
      'rider_tracking',
      'Rider Location Tracking',
      description: 'Background location tracking for deliveries',
      importance: Importance.low,
      enableVibration: false,
      playSound: false,
    );

    final androidPlugin = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    
    await androidPlugin?.createNotificationChannel(orderChannel);
    await androidPlugin?.createNotificationChannel(locationChannel);
    await androidPlugin?.createNotificationChannel(riderTrackingChannel);
    await androidPlugin?.createNotificationChannel(backgroundTrackingChannel);
  }

  /// Handle notification tap — opens the live tracking screen for order
  /// notifications (payload = orderId); generic notifications just open the app.
  static void _onNotificationTapped(NotificationResponse response) {
    print('[PushNotification] Notification tapped: ${response.payload}');
    NotificationTapHandler.handleTap(response.payload);
  }

  /// Show order status notification
  static Future<void> showOrderNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'order_updates',
      'Order Updates',
      channelDescription: 'Notifications for order status changes',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      color: AppColors.orange,
      enableVibration: true,
      playSound: true,
    );
    const details = NotificationDetails(android: androidDetails);
    
    await _notifications.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title,
      body,
      details,
      payload: payload,
    );
  }

  /// Show location tracking notification
  static Future<void> showLocationTrackingNotification({
    required String title,
    String? body,
    String? content,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'rider_tracking',
      'Rider Location Tracking',
      channelDescription: 'Background location tracking notification',
      importance: Importance.low,
      priority: Priority.low,
      icon: '@mipmap/ic_launcher',
      color: AppColors.orange,
      enableVibration: false,
      playSound: false,
      ongoing: true, // Cannot be swiped away
    );
    const details = NotificationDetails(android: androidDetails);
    
    await _notifications.show(
      9001, // Fixed ID for persistent notification
      title,
      content ?? body ?? '',
      details,
    );
  }

  /// Cancel all notifications
  static Future<void> cancelAll() async {
    await _notifications.cancelAll();
  }

  /// Cancel specific notification
  static Future<void> cancel(int id) async {
    await _notifications.cancel(id);
  }
}
