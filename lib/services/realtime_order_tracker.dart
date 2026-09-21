import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/push_notification_service.dart';
import '../services/websocket_service.dart';

/// Real-time Order Tracker — Uses WebSocket for live updates
/// Falls back to polling if WebSocket is unavailable
class RealtimeOrderTracker extends ChangeNotifier {
  Timer? _pollTimer;
  Map<String, dynamic>? _order;
  bool _isTracking = false;
  String? _orderId;
  String? _lastStatus;

  // Rider location from WebSocket
  double? _riderLatitude;
  double? _riderLongitude;
  String? _riderId;

  StreamSubscription? _orderStatusSub;
  StreamSubscription? _riderLocationSub;
  StreamSubscription? _riderAssignedSub;
  StreamSubscription? _connectionSub;

  /// Get current order data
  Map<String, dynamic>? get order => _order;
  bool get isTracking => _isTracking;
  String? get currentStatus => _order?['status'];
  double? get riderLatitude => _riderLatitude;
  double? get riderLongitude => _riderLongitude;
  String? get riderId => _riderId;

  /// Start tracking an order
  void startTracking(String orderId) {
    _orderId = orderId;
    _isTracking = true;
    _lastStatus = null;
    _riderLatitude = null;
    _riderLongitude = null;
    _riderId = null;

    // Initial fetch to get current state
    _fetchOrderStatus();

    // Subscribe to WebSocket events
    _setupWebSocketListeners();

    // Also start polling as fallback (every 10s instead of 5s since WebSocket handles real-time)
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 10), (_) => _fetchOrderStatus());

    // Subscribe to connection changes to re-setup listeners on reconnect
    _connectionSub?.cancel();
    _connectionSub = WebSocketService.instance.connectionStream.listen((connected) {
      if (connected && _isTracking) {
        _setupWebSocketListeners();
      }
    });

    notifyListeners();
  }

  /// Set up WebSocket listeners for real-time updates
  void _setupWebSocketListeners() {
    final ws = WebSocketService.instance;

    // Ensure we're connected
    if (!ws.isConnected) {
      ws.connect();
    }

    // Watch this order for status updates
    ws.watchOrder(_orderId!);

    // If the order has a rider, watch their location too
    if (_order != null && _order!['riderId'] != null) {
      _riderId = _order!['riderId'].toString();
      ws.watchRider(_riderId!);
    }

    // Listen for order status changes.
    // NOTE: always compare ids via .toString() — the server may send them
    // as a non-String (e.g. a number), and a strict `==` would then
    // silently drop every matching event, making tracking look broken.
    _orderStatusSub?.cancel();
    _orderStatusSub = ws.orderStatusStream.listen((data) {
      if (data['orderId']?.toString() == _orderId) {
        _handleStatusUpdate(data);
      }
    });

    // Listen for rider location updates
    _riderLocationSub?.cancel();
    _riderLocationSub = ws.riderLocationStream.listen((data) {
      if (data['orderId']?.toString() == _orderId || data['riderId']?.toString() == _riderId) {
        _handleRiderLocation(data);
      }
    });

    // Listen for rider assignment
    _riderAssignedSub?.cancel();
    _riderAssignedSub = ws.riderAssignedStream.listen((data) {
      if (data['orderId']?.toString() == _orderId) {
        _handleRiderAssigned(data);
      }
    });
  }

  /// Handle real-time status update from WebSocket
  void _handleStatusUpdate(Map<String, dynamic> data) {
    final newStatus = data['status'] as String?;

    if (newStatus != null && newStatus != _lastStatus) {
      _lastStatus = newStatus;

      // Update the order data
      if (_order != null) {
        _order!['status'] = newStatus;
      }

      // If rider was assigned, start watching their location
      if (newStatus == 'assigned' && data['riderId'] != null) {
        _riderId = data['riderId'].toString();
        _order?['riderId'] = _riderId;
        _order?['riderName'] = data['riderName'];
        WebSocketService.instance.watchRider(_riderId!);
      }

      // Show notification for status change
      _showStatusNotification(newStatus, data);

      // Auto-stop on terminal states
      if (newStatus == 'delivered' || newStatus == 'cancelled') {
        stopTracking();
      }

      notifyListeners();
    }
  }

  /// Handle real-time rider location from WebSocket
  void _handleRiderLocation(Map<String, dynamic> data) {
    final lat = data['latitude'] as num?;
    final lng = data['longitude'] as num?;

    if (lat != null && lng != null) {
      _riderLatitude = lat.toDouble();
      _riderLongitude = lng.toDouble();
      notifyListeners();
    }
  }

  /// Handle rider assignment from WebSocket
  void _handleRiderAssigned(Map<String, dynamic> data) {
    _riderId = data['riderId']?.toString();
    _order?['riderId'] = _riderId;
    _order?['riderName'] = data['riderName'];
    _order?['riderPhone'] = data['riderPhone'];
    _order?['vehicleType'] = data['vehicleType'];
    _order?['status'] = 'assigned';
    _lastStatus = 'assigned';

    // Start watching the assigned rider's location
    WebSocketService.instance.watchRider(_riderId!);

    // Show notification
    PushNotificationService.showOrderNotification(
      title: '🚚 Rider Assigned!',
      body: '${data['riderName'] ?? 'A rider'} is heading to pickup',
      payload: _orderId,
    );

    notifyListeners();
  }

  /// Show notification for status changes
  void _showStatusNotification(String newStatus, Map<String, dynamic> data) {
    String title;
    String body;

    switch (newStatus) {
      case 'assigned':
        title = '🚚 Rider Assigned';
        body = 'A rider has been assigned to your order';
        break;
      case 'accepted':
        title = '✅ Order Accepted';
        body = 'Rider is heading to pickup location';
        break;
      case 'picked_up':
        title = '📦 Order Picked Up';
        body = 'Your order is on its way to you';
        break;
      case 'in_transit':
        title = '🏃 Out for Delivery';
        body = 'Your order is arriving soon!';
        break;
      case 'delivered':
        title = '🎉 Delivered!';
        body = 'Your order has been delivered';
        break;
      case 'cancelled':
        title = '❌ Order Cancelled';
        body = 'Your order has been cancelled';
        break;
      default:
        title = '📋 Status Update';
        body = 'Order status: $newStatus';
    }

    PushNotificationService.showOrderNotification(
      title: title,
      body: body,
      payload: _orderId,
    );
  }

  /// Stop tracking
  void stopTracking() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _isTracking = false;

    // Unsubscribe from WebSocket events
    if (_orderId != null) {
      WebSocketService.instance.unwatchOrder(_orderId!);
    }

    _orderStatusSub?.cancel();
    _riderLocationSub?.cancel();
    _riderAssignedSub?.cancel();
    _connectionSub?.cancel();

    _orderId = null;
    _lastStatus = null;
    _order = null;
    _riderLatitude = null;
    _riderLongitude = null;
    _riderId = null;
    notifyListeners();
  }

  /// Fetch order status from API (fallback / initial load)
  Future<void> _fetchOrderStatus() async {
    if (_orderId == null) return;

    try {
      final order = await ApiService.getOrderById(_orderId!);
      final newStatus = order['status'] as String;

      // Check if status changed (polling fallback)
      if (_lastStatus != null && _lastStatus != newStatus) {
        _handleStatusUpdate({
          'orderId': _orderId,
          'status': newStatus,
          'riderId': order['riderId'],
          'riderName': order['rider']?['name'],
          'updatedAt': DateTime.now().toIso8601String(),
        });
      }

      _order = order;
      _lastStatus = newStatus;

      // If we have rider info, start watching their location
      if (order['riderId'] != null && _riderId == null) {
        _riderId = order['riderId'].toString();
        WebSocketService.instance.watchRider(_riderId!);
      }

      notifyListeners();
    } catch (e) {
      print('[RealtimeOrderTracker] Error: $e');
    }
  }

  /// Get status progress (0.0 to 1.0)
  double get statusProgress {
    if (_order == null) return 0.0;

    final status = _order!['status'] as String;
    switch (status) {
      case 'pending': return 0.0;
      case 'assigned': return 0.2;
      case 'accepted': return 0.4;
      case 'picked_up': return 0.6;
      case 'in_transit': return 0.8;
      case 'delivered': return 1.0;
      default: return 0.0;
    }
  }

  /// Get status step index (for stepper)
  int get statusStepIndex {
    if (_order == null) return 0;

    final status = _order!['status'] as String;
    switch (status) {
      case 'pending': return 0;
      case 'assigned': return 1;
      case 'accepted': return 2;
      case 'picked_up': return 3;
      case 'in_transit': return 4;
      case 'delivered': return 5;
      default: return 0;
    }
  }

  @override
  void dispose() {
    stopTracking();
    super.dispose();
  }
}