import 'dart:async';

import 'package:flutter/material.dart';

import 'push_notification_service.dart';
import 'websocket_service.dart';

/// Global rider notification service.
///
/// Listens to the rider's WebSocket streams for the WHOLE app lifetime
/// (started once from main()) and converts live events into:
///   • Android system notifications (works app-in-foreground on any screen)
///   • in-app snackbars on the current screen
///
/// Before this existed, order events only notified when the rider Home
/// screen was open — switching tabs or navigating anywhere silenced them.
class RiderNotificationService {
  RiderNotificationService._();
  static final RiderNotificationService instance = RiderNotificationService._();

  static bool _started = false;
  StreamSubscription? _newOrderSub;
  StreamSubscription? _riderOrderSub;
  StreamSubscription? _statusSub;

  /// Events already surfaced in this session (dedupe socket replays).
  final Set<String> _seen = {};

  void start() {
    if (_started) return;
    _started = true;

    final ws = WebSocketService.instance;
    ws.connect();

    // 1. Brand-new assignment / ready-for-pickup pings.
    _newOrderSub = ws.newOrderStream.listen(_onNewOrderEvent);

    // 2. Status changes on MY orders (business confirmed, etc).
    _riderOrderSub = ws.riderOrderStream.listen(_onStatusEvent);
    _statusSub = ws.orderStatusStream.listen(_onStatusEvent);
  }

  void stop() {
    _newOrderSub?.cancel();
    _riderOrderSub?.cancel();
    _statusSub?.cancel();
    _started = false;
  }

  void _onNewOrderEvent(Map<String, dynamic> data) {
    final orderId = (data['orderId'] ?? data['id'] ?? '').toString();
    final fare = data['fare'] ?? 0;
    final pickup = (data['pickupAddress'] ?? 'Pickup').toString();
    final drop = (data['dropAddress'] ?? 'Drop').toString();

    // 'order:newAssigned' vs 'order:newAvailable' vs 'ready' — pick copy.
    final isReady = data['ready'] == true ||
        data['readyForPickup'] == true ||
        data['note']?.toString().contains('ready') == true;
    final title = isReady
        ? '🍲 Order Ready for Pickup!'
        : '🛵 New Order Assigned!';
    final body = isReady
        ? 'The restaurant has prepared the order. Head to $pickup.'
        : 'Rs.$fare • $pickup → $drop';

    _announce(key: 'new:$orderId', title: title, body: body, payload: orderId);
  }

  void _onStatusEvent(Map<String, dynamic> data) {
    final status = (data['status'] ?? '').toString();
    if (status.isEmpty) return;
    final orderId = (data['orderId'] ?? data['id'] ?? '').toString();

    // Business confirmed → "restaurant is preparing your order".
    if (data['businessConfirmed'] == true) {
      _announce(
        key: 'confirmed:$orderId',
        title: '🍳 Restaurant Accepted the Order',
        body: 'The restaurant is preparing order #${_shortId(orderId)}.',
        payload: orderId,
      );
      return;
    }
    // Order marked ready by the business → GO PICK IT UP.
    if (data['readyForPickup'] == true) {
      _announce(
        key: 'ready:$orderId',
        title: '🍲 Food is Ready for Pickup!',
        body: 'Order #${_shortId(orderId)} is prepared — head to the restaurant.',
        payload: orderId,
      );
    }
  }

  String _shortId(String id) => id.length > 8 ? id.substring(0, 8) : id;

  void _announce({
    required String key,
    required String title,
    required String body,
    String? payload,
  }) {
    if (!_seen.add(key)) return; // duplicate event, ignore

    // System notification — visible even over other apps / any screen.
    PushNotificationService.showOrderNotification(
      title: title,
      body: body,
      payload: payload,
    );

    // In-app snackbar on whatever screen is currently open.
    final context = NavigationService.currentContext;
    if (context != null && context.mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.notifications_active_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.white)),
                    const SizedBox(height: 2),
                    Text(body, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF2E7D32),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }
}

/// Tiny navigator-key context holder so background services can show
/// snackbars on whatever screen is currently open.
class NavigationService {
  NavigationService._();
  static GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  static BuildContext? get currentContext => navigatorKey.currentContext;
}
