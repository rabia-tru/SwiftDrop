import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';
import '../theme/app_colors.dart';
import 'api_service.dart';
import 'location_queue_db.dart';
import 'foodpanda_notifications.dart';
import '../utils/safe_parse.dart';

/// ─────────────────────────────────────────────────────────────────────
/// THE SINGLE background-service entry point for the whole app.
///
/// `flutter_background_service` wraps exactly ONE Android foreground
/// service / ONE `onStart` callback per app. Previously
/// `BackgroundLocationService` (rider GPS tracking) and
/// `CustomerBackgroundService` (customer ETA polling) each called
/// `FlutterBackgroundService().configure(...)` independently. Since
/// there is only one underlying service, whichever `.configure()` ran
/// LAST silently replaced the other's `onStart` — meaning only one of
/// the two jobs ever actually executed inside the background isolate,
/// no matter which one's `.start()` was called.
///
/// Fix: configure the service exactly ONCE, here, with a single
/// `onStart` that does BOTH jobs, switched on/off independently via
/// flags in SharedPreferences. `BackgroundLocationService` and
/// `CustomerBackgroundService` keep their original public APIs (so no
/// screen code needs to change) but now just flip these flags and make
/// sure this one service is running.
/// ─────────────────────────────────────────────────────────────────────
class UnifiedBackgroundService {
  static bool _configured = false;

  // Rider GPS tracking flags (read by BackgroundLocationService)
  static const kRiderActive = 'bg_tracking_active';
  static const kRiderOrderId = 'bg_tracking_order_id';

  // Customer ETA-polling flags (read by CustomerBackgroundService)
  static const kCustomerActive = 'is_tracking_order';
  static const kCustomerOrderId = 'tracked_order_id';

  // Rider order-status notification flags (read by RiderBackgroundService).
  // Separate from kRiderActive/kRiderOrderId above: that pair is about
  // *GPS* tracking, this pair is about polling the order's status to show
  // "Order Picked Up" / "Delivered" style notifications to the rider —
  // previously done with an in-app Timer that died the moment the app
  // process was killed.
  static const kRiderOrderActive = 'is_rider_tracking';
  static const kRiderOrderTrackedId = 'rider_tracked_order_id';

  // Chat notification flags — one job per side. Both can run at once
  // (customer + rider accounts on the same device after role switching).
  static const kChatCustomerOrder = 'chat_watch_order_customer';
  static const kChatRiderOrder = 'chat_watch_order_rider';
  static const kChatLastSeenCount = 'chat_last_seen_count';
  static const kChatLastSeenCountRider = 'chat_last_seen_count_rider';

  /// Configure the service exactly once. Safe to call from both
  /// BackgroundLocationService.initialize() and
  /// CustomerBackgroundService.initialize() — the second call is a no-op.
  static Future<void> ensureConfigured() async {
    if (_configured) return;
    _configured = true;

    final service = FlutterBackgroundService();
    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: _onStart,
        autoStart: false,
        isForegroundMode: true,
        foregroundServiceNotificationId: 9001,
        initialNotificationTitle: 'SwiftDrop is tracking your delivery',
        initialNotificationContent: 'Location sharing active — tap to open',
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: _onStart,
        onBackground: _onIosBackground,
      ),
    );

    print('[UnifiedBG] ✅ Configured — one onStart handles GPS + ETA jobs');
  }

  @pragma('vm:entry-point')
  static bool _onIosBackground(ServiceInstance service) => true;

  /// Runs in a separate isolate. Statics here are NOT shared with the
  /// main isolate, so all state is re-read from SharedPreferences.
  @pragma('vm:entry-point')
  static void _onStart(ServiceInstance service) async {
    DartPluginRegistrant.ensureInitialized();

    final notifications = FlutterLocalNotificationsPlugin();
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    await notifications.initialize(const InitializationSettings(android: androidSettings));

    String? riderOrderId;
    String? customerOrderId;
    String? riderOrderTrackedId;
    String? lastRiderOrderStatus;
    String? lastCustomerStatus;
    bool notifiedNearby = false;
    bool notifiedVeryClose = false;
    DateTime? lastImmediateSync;
    bool gpsStreamStarted = false;
    String? chatOrderCustomer; // customer side: watch this order's chat
    String? chatOrderRider;    // rider side: watch this order's chat
    int lastCustomerChatCount = -1; // -1 = unknown (first poll just observes)
    int lastRiderChatCount = -1;

    Future<void> refreshFlags() async {
      final prefs = await SharedPreferences.getInstance();
      final riderActive = prefs.getBool(kRiderActive) ?? false;
      final newRiderOrderId = riderActive ? prefs.getString(kRiderOrderId) : null;
      // Order changed (e.g. rider picked a different delivery) — reset nothing,
      // GPS stream itself doesn't care which order a fix belongs to.
      riderOrderId = (newRiderOrderId != null && newRiderOrderId.isNotEmpty) ? newRiderOrderId : null;

      final customerActive = prefs.getBool(kCustomerActive) ?? false;
      final newCustomerOrderId = customerActive ? prefs.getString(kCustomerOrderId) : null;
      if (newCustomerOrderId != customerOrderId) {
        // Switched to tracking a different order — reset milestone flags.
        lastCustomerStatus = null;
        notifiedNearby = false;
        notifiedVeryClose = false;
      }
      customerOrderId = (newCustomerOrderId != null && newCustomerOrderId.isNotEmpty) ? newCustomerOrderId : null;

      final riderOrderActive = prefs.getBool(kRiderOrderActive) ?? false;
      final newRiderOrderTrackedId = riderOrderActive ? prefs.getString(kRiderOrderTrackedId) : null;
      if (newRiderOrderTrackedId != riderOrderTrackedId) {
        lastRiderOrderStatus = null;
      }
      riderOrderTrackedId = (newRiderOrderTrackedId != null && newRiderOrderTrackedId.isNotEmpty) ? newRiderOrderTrackedId : null;

      // Chat-watch flags (either side)
      chatOrderCustomer = (prefs.getString(kChatCustomerOrder) ?? '').isNotEmpty
          ? prefs.getString(kChatCustomerOrder)
          : null;
      chatOrderRider = (prefs.getString(kChatRiderOrder) ?? '').isNotEmpty
          ? prefs.getString(kChatRiderOrder)
          : null;
    }

    await refreshFlags();

    if (service is AndroidServiceInstance) {
      service.setAsForegroundService();
      service.on('stopService').listen((_) => service.stopSelf());
      // Main isolate calls this (via invoke) whenever it changes a flag,
      // so we don't have to wait up to 5s for the next poll tick.
      service.on('refresh').listen((_) async => refreshFlags());
    }

    Future<void> updateForegroundNotification() async {
      if (service is! AndroidServiceInstance) return;
      final parts = <String>[];
      if (riderOrderId != null) parts.add('📍 Location tracking ON');
      if (riderOrderTrackedId != null) parts.add('🛵 Delivery status ON');
      if (customerOrderId != null) parts.add('📦 Tracking your order');
      service.setForegroundNotificationInfo(
        title: '🟢 SwiftDrop',
        content: parts.isEmpty ? 'Idle' : parts.join(' • '),
      );
    }

    Future<void> syncLocationToServer() async {
      try {
        final pending = await LocationQueueDb.getPendingBatch(limit: 100);
        if (pending.isEmpty) return;
        final payload = pending
            .map((row) => {
                  'latitude': row['latitude'],
                  'longitude': row['longitude'],
                  'speed': row['speed'],
                  'accuracy': row['accuracy'],
                  'orderId': row['orderId'],
                  'recordedAt': row['recordedAt'],
                })
            .toList();
        final saved = await ApiService.syncLocationBatch(payload);
        final ids = pending.map((row) => row['id'] as int).toList();
        await LocationQueueDb.markSynced(ids);
        print('[UnifiedBG] ✅ Synced $saved location pings');
      } catch (e) {
        print('[UnifiedBG] ❌ Location sync error: $e');
      }
    }

    Future<void> startGpsStreamIfNeeded() async {
      if (gpsStreamStarted) return;

      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        print('[UnifiedBG] ❌ Location services disabled');
        return;
      }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        print('[UnifiedBG] ❌ Location permission denied');
        return;
      }

      gpsStreamStarted = true;
      Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10,
        ),
      ).listen(
        (position) async {
          // Rider tracking might have been switched off since the stream
          // started — drop fixes instead of tearing the stream down/up.
          if (riderOrderId == null) return;

          await LocationQueueDb.enqueue(
            latitude: position.latitude,
            longitude: position.longitude,
            speed: position.speed,
            accuracy: position.accuracy,
            orderId: riderOrderId,
            recordedAt: DateTime.now(),
          );

          final now = DateTime.now();
          if (lastImmediateSync == null || now.difference(lastImmediateSync!) > const Duration(seconds: 5)) {
            lastImmediateSync = now;
            unawaited(syncLocationToServer());
          }
        },
        onError: (e) => print('[UnifiedBG] ❌ Position error: $e'),
      );
      print('[UnifiedBG] ✅ GPS position stream started');
    }

    double calcDistanceMeters(double lat1, double lon1, double lat2, double lon2) {
      const R = 6371000.0;
      final dLat = (lat2 - lat1) * pi / 180;
      final dLon = (lon2 - lon1) * pi / 180;
      final a = (dLat / 2) * (dLat / 2) +
          cos(lat1 * pi / 180) * cos(lat2 * pi / 180) * (dLon / 2) * (dLon / 2);
      return R * 2 * asin(sqrt(a));
    }

    Future<void> showCustomerEtaNotification(
      Map<String, dynamic> order,
      String status,
      int etaMinutes,
      double distanceKm,
    ) async {
      String statusEmoji;
      String statusText;
      switch (status) {
        case 'assigned':
          statusEmoji = '🛵';
          statusText = 'Rider assigned';
          break;
        case 'accepted':
          statusEmoji = '📍';
          statusText = 'Rider heading to pickup';
          break;
        case 'picked_up':
          statusEmoji = '📦';
          statusText = 'Order picked up';
          break;
        case 'in_transit':
          statusEmoji = '🏃';
          statusText = 'On the way to you';
          break;
        case 'delivered':
          statusEmoji = '✅';
          statusText = 'Delivered!';
          break;
        default:
          statusEmoji = '📋';
          statusText = 'Processing Order';
      }

      final title = '$statusEmoji $statusText';
      final distanceText = distanceKm > 0 ? '${distanceKm.toStringAsFixed(1)} km' : '';
      final body = etaMinutes > 0
          ? '⏱ $etaMinutes min away • $distanceText • Tap to track live'
          : '📦 Your order is being processed!';

      const androidDetails = AndroidNotificationDetails(
        'order_tracking',
        'Order Tracking',
        channelDescription: 'Real-time order tracking with ETA',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        color: AppColors.orange,
        ongoing: true,
        autoCancel: false,
      );
      await notifications.show(
        9003,
        title,
        body,
        const NotificationDetails(android: androidDetails),
        payload: customerOrderId, // tap → open live tracking
      );
    }

    Future<void> sendCustomerStatusChangeNotification(String status) async {
      String title;
      String body;
      switch (status) {
        case 'assigned':
          title = '🛵 Rider Assigned!';
          body = 'A rider is heading to pickup your order';
          break;
        case 'accepted':
          title = '✅ Order Accepted!';
          body = 'Rider is on the way to pickup';
          break;
        case 'picked_up':
          title = '📦 Order Picked Up!';
          body = 'Your order is on its way to you';
          break;
        case 'in_transit':
          title = '🏃 Out for Delivery!';
          body = 'Your order is arriving soon!';
          break;
        case 'delivered':
          title = '🎉 Delivered!';
          body = 'Your order has been delivered. Enjoy!';
          break;
        case 'cancelled':
          title = '❌ Order Cancelled';
          body = 'Your order has been cancelled';
          break;
        default:
          title = '📋 Order Update';
          body = 'Status: $status';
      }
      const androidDetails = AndroidNotificationDetails(
        'order_tracking',
        'Order Tracking',
        channelDescription: 'Real-time order status updates',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        color: AppColors.orange,
      );
      await notifications.show(
        DateTime.now().millisecondsSinceEpoch.remainder(100000),
        title,
        body,
        const NotificationDetails(android: androidDetails),
        payload: customerOrderId,
      );
    }

    Future<void> checkCustomerOrder() async {
      if (customerOrderId == null) return;
      try {
        final order = await ApiService.getOrderById(customerOrderId!);
        final currentStatus = order['status'] as String;

        int etaMinutes = 15;
        double distanceKm = 0;
        try {
          final riderId = order['riderId'];
          double? riderLat, riderLng;
          if (riderId != null) {
            riderLat = SafeParse.toDouble(order['riderLat'] ?? order['lastKnownLat']);
            riderLng = SafeParse.toDouble(order['riderLng'] ?? order['lastKnownLng']);
          }

          final pickupLat = SafeParse.toDouble(order['pickupLat'], 31.5204);
          final pickupLng = SafeParse.toDouble(order['pickupLng'], 74.3587);
          final dropLat = SafeParse.toDouble(order['dropLat'], 31.47);
          final dropLng = SafeParse.toDouble(order['dropLng'], 74.42);

          if (currentStatus == 'assigned' || currentStatus == 'accepted') {
            distanceKm = (riderLat != null && riderLng != null)
                ? calcDistanceMeters(riderLat, riderLng, pickupLat, pickupLng) / 1000
                : 3.0;
          } else if (currentStatus == 'picked_up' || currentStatus == 'in_transit') {
            distanceKm = calcDistanceMeters(pickupLat, pickupLng, dropLat, dropLng) / 1000;
          }

          etaMinutes = (distanceKm / 20 * 60).round();
          if (etaMinutes < 3) etaMinutes = 3;
          if (etaMinutes > 60) etaMinutes = 60;
        } catch (_) {}

        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt('last_eta_seconds', etaMinutes * 60);
        await prefs.setString('last_order_status', currentStatus);

        await showCustomerEtaNotification(order, currentStatus, etaMinutes, distanceKm);

        if (lastCustomerStatus != null && lastCustomerStatus != currentStatus) {
          await sendCustomerStatusChangeNotification(currentStatus);
        }

        if (etaMinutes <= 5 && !notifiedNearby && (currentStatus == 'picked_up' || currentStatus == 'in_transit')) {
          notifiedNearby = true;
          await FoodPandaNotifications.riderNearby(customerOrderId!, '$etaMinutes min');
        }
        if (etaMinutes <= 1 && !notifiedVeryClose && (currentStatus == 'picked_up' || currentStatus == 'in_transit')) {
          notifiedVeryClose = true;
          await FoodPandaNotifications.riderVeryClose(customerOrderId!);
        }
        if (currentStatus == 'accepted' && lastCustomerStatus != 'accepted') {
          await FoodPandaNotifications.riderAtPickup(customerOrderId!);
        }
        if (currentStatus == 'assigned' && lastCustomerStatus != 'assigned') {
          await FoodPandaNotifications.orderPreparing(customerOrderId!);
        }
        if (currentStatus == 'delivered' && lastCustomerStatus != 'delivered') {
          await FoodPandaNotifications.rateOrder(customerOrderId!);
        }

        lastCustomerStatus = currentStatus;

        if (currentStatus == 'delivered' || currentStatus == 'cancelled') {
          // Turn customer tracking off; leave rider GPS tracking (if any)
          // untouched since it's an independent flag.
          final p = await SharedPreferences.getInstance();
          await p.setBool(kCustomerActive, false);
          await p.remove(kCustomerOrderId);
          customerOrderId = null;
          await notifications.cancel(9003);
        }
      } catch (e) {
        print('[UnifiedBG] ❌ Customer order check error: $e');
      }
    }

    Future<void> updateRiderOrderNotification(
      String status,
      String pickup,
      String drop,
      dynamic fare,
      int etaMinutes,
    ) async {
      String statusEmoji;
      String statusText;
      String detailText;
      switch (status) {
        case 'assigned':
          statusEmoji = '📋';
          statusText = 'Order Assigned';
          detailText = 'Tap to accept • Rs.$fare';
          break;
        case 'accepted':
          statusEmoji = '🛵';
          statusText = 'Heading to Pickup';
          detailText = '$pickup • ${etaMinutes}min away';
          break;
        case 'picked_up':
          statusEmoji = '📦';
          statusText = 'Order Picked Up';
          detailText = '$drop • ${etaMinutes}min to deliver';
          break;
        case 'in_transit':
          statusEmoji = '🏃';
          statusText = 'Delivering Now';
          detailText = '$drop • ${etaMinutes}min remaining';
          break;
        case 'delivered':
          statusEmoji = '✅';
          statusText = 'Delivered!';
          detailText = 'Order completed';
          break;
        default:
          statusEmoji = '🛵';
          statusText = 'Active Order';
          detailText = 'Status: $status';
      }

      const androidDetails = AndroidNotificationDetails(
        'rider_order_tracking',
        'Rider Order Tracking',
        channelDescription: 'Persistent notification while delivering orders',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        color: AppColors.orange,
        ongoing: true,
        autoCancel: false,
      );
      await notifications.show(
        9002,
        '$statusEmoji $statusText',
        'Rs.$fare • $detailText',
        const NotificationDetails(android: androidDetails),
        payload: riderOrderTrackedId, // tap → open the active order
      );
    }

    Future<void> sendRiderOrderStatusChangeNotification(String status) async {
      String title;
      String body;
      switch (status) {
        case 'accepted':
          title = '✅ Order Accepted!';
          body = 'Navigate to pickup location';
          break;
        case 'picked_up':
          title = '📦 Order Picked Up!';
          body = 'Navigate to customer location';
          break;
        case 'in_transit':
          title = '🏃 Out for Delivery!';
          body = 'Customer is waiting for delivery';
          break;
        case 'delivered':
          title = '🎉 Delivery Complete!';
          body = 'Great job! Payment credited to your account';
          break;
        case 'cancelled':
          title = '❌ Order Cancelled';
          body = 'This order has been cancelled';
          break;
        default:
          title = '📋 Order Update';
          body = 'Status: $status';
      }
      const androidDetails = AndroidNotificationDetails(
        'rider_order_tracking',
        'Rider Order Tracking',
        channelDescription: 'Order status change notifications',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        color: AppColors.orange,
      );
      await notifications.show(
        DateTime.now().millisecondsSinceEpoch.remainder(100000),
        title,
        body,
        const NotificationDetails(android: androidDetails),
        payload: riderOrderTrackedId,
      );
    }

    Future<void> checkRiderOrder() async {
      if (riderOrderTrackedId == null) return;
      try {
        final order = await ApiService.getOrderById(riderOrderTrackedId!);
        final status = order['status'] as String;
        final pickup = order['pickupAddress'] ?? 'Pickup';
        final drop = order['dropAddress'] ?? 'Drop';
        final fare = order['fare'] ?? 0;

        int etaMinutes = 10;
        try {
          final pickupLat = SafeParse.toDouble(order['pickupLat'], 31.5204);
          final pickupLng = SafeParse.toDouble(order['pickupLng'], 74.3587);
          final dropLat = SafeParse.toDouble(order['dropLat'], 31.4700);
          final dropLng = SafeParse.toDouble(order['dropLng'], 74.4200);
          final distance = calcDistanceMeters(pickupLat, pickupLng, dropLat, dropLng) / 1000;
          etaMinutes = (distance / 20 * 60).round();
          if (etaMinutes < 3) etaMinutes = 3;
          if (etaMinutes > 60) etaMinutes = 60;
        } catch (_) {}

        await updateRiderOrderNotification(status, pickup, drop, fare, etaMinutes);

        if (lastRiderOrderStatus != null && lastRiderOrderStatus != status) {
          await sendRiderOrderStatusChangeNotification(status);
        }
        lastRiderOrderStatus = status;

        if (status == 'delivered' || status == 'cancelled') {
          final p = await SharedPreferences.getInstance();
          await p.setBool(kRiderOrderActive, false);
          await p.remove(kRiderOrderTrackedId);
          riderOrderTrackedId = null;
          await notifications.cancel(9002);
        }
      } catch (e) {
        print('[UnifiedBG] ❌ Rider order check error: $e');
      }
    }

    // Chat-message notification — shown when a message arrives while the
    // chat screen is closed. Tapping it opens the chat directly.
    Future<void> showChatNotification(String orderId, String senderName, String message, bool fromRider) async {
      final body = message.trim().isEmpty
          ? '📷 Photo bheji hai' // image-only message
          : (message.length > 80 ? '${message.substring(0, 80)}…' : message);

      final androidDetails = AndroidNotificationDetails(
        'chat_messages',
        'Chat Messages',
        channelDescription: 'New chat messages about your order',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        color: AppColors.orange,
        category: AndroidNotificationCategory.message,
      );
      await notifications.show(
        // Stable id per order so consecutive messages update the same
        // notification instead of spamming new ones.
        9100 + (orderId.hashCode.abs() % 900),
        '💬 $senderName',
        body,
        NotificationDetails(android: androidDetails),
        payload: 'chat:$orderId', // tap → open chat (NotificationTapHandler)
      );
      print('[UnifiedBG] 💬 Chat notification: $senderName → order ${orderId.substring(0, 8)}');
    }

    /// Poll the chat history of the watched order(s) and notify about
    /// messages that arrived since the last seen count. Works while the
    /// app is closed — this runs inside the foreground service.
    Future<void> checkChatMessages() async {
      // ── Customer side ──
      if (chatOrderCustomer != null) {
        try {
          final history = await ApiService.getChatHistory(chatOrderCustomer!);
          final count = history.length;
          if (lastCustomerChatCount >= 0 && count > lastCustomerChatCount) {
            // New message(s) — announce the latest one
            final last = history.last;
            final senderRole = (last['senderRole'] ?? '').toString();
            if (senderRole != 'customer') {
              // Only notify when the OTHER side sent it (rider → customer)
              await showChatNotification(
                chatOrderCustomer!,
                (last['senderName'] ?? 'Rider').toString(),
                (last['message'] ?? '').toString(),
                true,
              );
            }
          }
          lastCustomerChatCount = count;
        } catch (e) {
          print('[UnifiedBG] ❌ Chat poll (customer) error: $e');
        }
      } else {
        lastCustomerChatCount = -1;
      }

      // ── Rider side ──
      if (chatOrderRider != null) {
        try {
          final history = await ApiService.getChatHistory(chatOrderRider!);
          final count = history.length;
          if (lastRiderChatCount >= 0 && count > lastRiderChatCount) {
            final last = history.last;
            final senderRole = (last['senderRole'] ?? '').toString();
            if (senderRole != 'rider') {
              // Customer → rider
              await showChatNotification(
                chatOrderRider!,
                (last['senderName'] ?? 'Customer').toString(),
                (last['message'] ?? '').toString(),
                false,
              );
            }
          }
          lastRiderChatCount = count;
        } catch (e) {
          print('[UnifiedBG] ❌ Chat poll (rider) error: $e');
        }
      } else {
        lastRiderChatCount = -1;
      }
    }

    // Fast tick: pick up flag changes, keep the GPS stream alive, refresh
    // the single foreground notification.
    Timer.periodic(const Duration(seconds: 5), (_) async {
      await refreshFlags();
      if (riderOrderId != null) await startGpsStreamIfNeeded();
      await updateForegroundNotification();
    });

    // Rider GPS batch sync — matches AppConfig.locationSyncIntervalSeconds.
    Timer.periodic(Duration(seconds: AppConfig.locationSyncIntervalSeconds), (_) async {
      if (riderOrderId != null) await syncLocationToServer();
    });

    // Customer ETA polling.
    Timer.periodic(const Duration(seconds: 15), (_) async {
      await checkCustomerOrder();
    });

    // Rider order-status polling — matches the old RiderBackgroundService's
    // 20s interval, but now inside the real foreground service so it
    // survives the app process being killed.
    Timer.periodic(const Duration(seconds: 20), (_) async {
      await checkRiderOrder();
    });

    // Chat polling — every 10s so replies feel near-instant even with
    // the app closed. Runs only while a chat-watch flag is set.
    Timer.periodic(const Duration(seconds: 10), (_) async {
      await checkChatMessages();
    });

    // Run both immediately instead of waiting for the first tick.
    if (riderOrderId != null) {
      await startGpsStreamIfNeeded();
      await syncLocationToServer();
    }
    await checkCustomerOrder();
    await checkRiderOrder();
    await checkChatMessages(); // first poll just records the baseline count
    await updateForegroundNotification();
  }

  /// Make sure the (single) background process is running and has picked
  /// up the latest flags. Call after writing kRiderActive/kCustomerActive.
  static Future<void> ensureRunning() async {
    await ensureConfigured();
    final service = FlutterBackgroundService();
    final running = await service.isRunning();
    if (!running) {
      await service.startService();
    } else {
      service.invoke('refresh');
    }
  }

  /// Stop the whole background process only if NONE of the jobs needs it
  /// anymore; otherwise just tell it to re-read flags.
  static Future<void> stopIfNothingActive() async {
    final prefs = await SharedPreferences.getInstance();
    final riderActive = prefs.getBool(kRiderActive) ?? false;
    final customerActive = prefs.getBool(kCustomerActive) ?? false;
    final riderOrderActive = prefs.getBool(kRiderOrderActive) ?? false;
    final chatWatching = (prefs.getString(kChatCustomerOrder) ?? '').isNotEmpty ||
        (prefs.getString(kChatRiderOrder) ?? '').isNotEmpty;
    final service = FlutterBackgroundService();
    if (!await service.isRunning()) return;

    if (!riderActive && !customerActive && !riderOrderActive && !chatWatching) {
      service.invoke('stopService');
    } else {
      service.invoke('refresh');
    }
  }

  static Future<bool> isRunning() => FlutterBackgroundService().isRunning();
}
