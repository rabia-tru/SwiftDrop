import 'dart:async';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../config/app_config.dart';

/// WebSocket Service — Real-time connection to backend via Socket.IO
/// Handles order tracking, rider location updates, and status changes
class WebSocketService {
  static WebSocketService? _instance;
  static WebSocketService get instance => _instance ??= WebSocketService._();
  WebSocketService._();

  IO.Socket? _socket;
  bool _isConnected = false;
  String? _currentOrderId;
  String? _currentRiderId;
  // The token the current socket's handshake headers were built with.
  // Needed because Socket.IO can't change a live connection's headers —
  // a token change means the socket itself has to be rebuilt.
  String? _connectedToken;

  // ─── Streams for real-time data ──────────────────────────────
  final _orderStatusController = StreamController<Map<String, dynamic>>.broadcast();
  final _riderLocationController = StreamController<Map<String, dynamic>>.broadcast();
  final _riderAssignedController = StreamController<Map<String, dynamic>>.broadcast();
  final _connectionController = StreamController<bool>.broadcast();
  final _newOrderController = StreamController<Map<String, dynamic>>.broadcast();
  final _chatMessageController = StreamController<Map<String, dynamic>>.broadcast();
  final _chatTypingController = StreamController<Map<String, dynamic>>.broadcast();
  final _businessOrderController = StreamController<Map<String, dynamic>>.broadcast();
  final _menuUpdatedController = StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get orderStatusStream => _orderStatusController.stream;
  Stream<Map<String, dynamic>> get riderLocationStream => _riderLocationController.stream;
  Stream<Map<String, dynamic>> get riderAssignedStream => _riderAssignedController.stream;
  Stream<bool> get connectionStream => _connectionController.stream;
  Stream<Map<String, dynamic>> get newOrderStream => _newOrderController.stream;
  Stream<Map<String, dynamic>> get chatMessageStream => _chatMessageController.stream;
  Stream<Map<String, dynamic>> get chatTypingStream => _chatTypingController.stream;
  Stream<Map<String, dynamic>> get businessOrderStream => _businessOrderController.stream;
  /// Fires whenever ANY business's menu changes (item added/updated/deleted/
  /// toggled) — carries {businessId, updatedAt}. Screens filter by businessId.
  Stream<Map<String, dynamic>> get menuUpdatedStream => _menuUpdatedController.stream;
  String? _currentBusinessId;
  String? _currentCustomerId;

  bool get isConnected => _isConnected;

  // ─── Connect to WebSocket server ─────────────────────────────

  void connect({String? token}) {
    if (_socket != null && _isConnected && token == _connectedToken) return;

    // The app connects once at startup with no token (before login), then
    // again after login with the real JWT. Socket.IO can't swap the
    // Authorization header on a live/cached socket, so if the token has
    // changed since this socket was built, tear it down and rebuild it —
    // otherwise every request after login would still go out unauthenticated.
    if (_socket != null && token != _connectedToken) {
      _socket!.clearListeners();
      _socket!.disconnect();
      _socket!.dispose();
      _socket = null;
      _isConnected = false;
    } else if (_socket != null) {
      // Do not replace a reconnecting socket: subscriptions created while it
      // was connecting are retained and replayed on connect.
      _socket!.connect();
      return;
    }

    _connectedToken = token;

    // Derive WebSocket URL from API base URL
    // http://192.168.100.121:3000/api → http://192.168.100.121:3000
    final baseUrl = AppConfig.apiBaseUrl;
    final apiIndex = baseUrl.lastIndexOf('/api');
    final wsUrl = apiIndex > 0 ? baseUrl.substring(0, apiIndex) : baseUrl;

    print('[WebSocket] Connecting to $wsUrl/tracking');

    _socket = IO.io(
      '$wsUrl/tracking',
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .enableAutoConnect()
          .enableReconnection()
          .setReconnectionDelay(2000)
          .setReconnectionDelayMax(10000)
          .setExtraHeaders(token != null ? {'Authorization': 'Bearer $token'} : {})
          .build(),
    );

    _socket!.onConnect((_) {
      print('[WebSocket] Connected!');
      _isConnected = true;
      _connectionController.add(true);

      // Re-subscribe to tracked order/rider if we had one
      if (_currentOrderId != null) {
        watchOrder(_currentOrderId!);
      }
      if (_currentRiderId != null) {
        watchRider(_currentRiderId!);
      }
      if (_currentBusinessId != null) {
        watchBusiness(_currentBusinessId!);
      }
      if (_currentCustomerId != null) {
        watchCustomerOrders(_currentCustomerId!);
      }
    });

    _socket!.onDisconnect((_) {
      print('[WebSocket] Disconnected');
      _isConnected = false;
      _connectionController.add(false);
    });

    _socket!.onReconnect((_) {
      print('[WebSocket] Reconnected');
      _isConnected = true;
      _connectionController.add(true);
    });

    _socket!.onConnectError((error) {
      print('[WebSocket] Connection error: $error');
      _isConnected = false;
      _connectionController.add(false);
    });

    // ─── Listen for events from server ───────────────────────────

    // Order status changed
    _socket!.on('order:status', (data) {
      print('[WebSocket] Order status: $data');
      _orderStatusController.add(Map<String, dynamic>.from(data));
    });

    // Rider location update
    _socket!.on('order:location', (data) {
      print('[WebSocket] Rider location: $data');
      _riderLocationController.add(Map<String, dynamic>.from(data));
    });

    // Also listen to global rider:location for dashboard
    _socket!.on('rider:location', (data) {
      _riderLocationController.add(Map<String, dynamic>.from(data));
    });

    // Rider assigned to order — also push into orderStatus stream so
    // TrackOrderScreen picks up riderName immediately when assignment happens
    _socket!.on('order:riderAssigned', (data) {
      print('[WebSocket] Rider assigned: $data');
      final d = Map<String, dynamic>.from(data);
      _riderAssignedController.add(d);
      // Merge into order-status stream (adds orderId if present so screens can match)
      final merged = Map<String, dynamic>.from(d);
      _orderStatusController.add(merged);
    });

    // Global order update
    _socket!.on('order:update', (data) {
      _orderStatusController.add(Map<String, dynamic>.from(data));
    });

    // New order available for riders
    _socket!.on('order:newAvailable', (data) {
      print('[WebSocket] New order available: $data');
      _newOrderController.add(Map<String, dynamic>.from(data));
    });

    // New order assigned to this rider
    _socket!.on('order:newAssigned', (data) {
      print('[WebSocket] New order assigned: $data');
      _newOrderController.add(Map<String, dynamic>.from(data));
    });

    // Chat message received
    _socket!.on('chat:message', (data) {
      print('[WebSocket] Chat message: $data');
      _chatMessageController.add(Map<String, dynamic>.from(data));
    });
    _socket!.on('chat:typing', (data) {
      _chatTypingController.add(Map<String, dynamic>.from(data));
    });

    // Business room: new order / any update for THIS business
    _socket!.on('business:newOrder', (data) {
      print('[WebSocket] Business order update: $data');
      _businessOrderController.add(Map<String, dynamic>.from(data));
    });

    // Customer room: live updates for my orders
    _socket!.on('customer:orderUpdate', (data) {
      print('[WebSocket] Customer order update: $data');
      _orderStatusController.add(Map<String, dynamic>.from(data));
    });

    // A business's menu changed — lets browsing customers auto-refresh
    // instead of only picking up new items on next manual pull-to-refresh.
    _socket!.on('business:menuUpdated', (data) {
      print('[WebSocket] Menu updated: $data');
      _menuUpdatedController.add(Map<String, dynamic>.from(data));
    });

    _socket!.onError((error) {
      print('[WebSocket] Error: $error');
    });
  }

  // ─── Subscribe to events ─────────────────────────────────────

  void watchOrder(String orderId) {
    _currentOrderId = orderId;
    _socket?.emit('watchOrder', {'orderId': orderId});
    print('[WebSocket] Watching order: $orderId');
  }

  void unwatchOrder(String orderId) {
    _socket?.emit('unwatchOrder', {'orderId': orderId});
    if (_currentOrderId == orderId) _currentOrderId = null;
    print('[WebSocket] Unwatched order: $orderId');
  }

  void watchRider(String riderId) {
    _currentRiderId = riderId;
    _socket?.emit('watchRider', {'riderId': riderId});
    print('[WebSocket] Watching rider: $riderId');
  }

  void watchCustomerOrders(String customerId) {
    _currentCustomerId = customerId;
    _socket?.emit('watchCustomerOrders', {'customerId': customerId});
    print('[WebSocket] Watching customer orders: $customerId');
  }

  void watchBusiness(String businessId) {
    _currentBusinessId = businessId;
    _socket?.emit('watchBusiness', {'businessId': businessId});
    print('[WebSocket] Watching business: $businessId');
  }

  // ─── Send chat message ───────────────────────────────────────

  void sendChatMessage({
    required String orderId,
    required String message,
    required String senderRole,
    String? senderName,
    String? imageUrl,
  }) {
    _socket?.emit('chat:send', {
      'orderId': orderId,
      'message': message,
      'senderRole': senderRole,
      if (senderName != null && senderName.isNotEmpty) 'senderName': senderName,
      if (imageUrl != null && imageUrl.isNotEmpty) 'imageUrl': imageUrl,
      'timestamp': DateTime.now().toIso8601String(),
    });
    print('[WebSocket] Sent chat message: ${imageUrl != null ? '[image] $message' : message}');
  }

  /// Fire-and-forget typing indicator to the other chat participant.
  void sendChatTyping({
    required String orderId,
    required String senderRole,
    required bool isTyping,
  }) {
    _socket?.emit('chat:typing', {
      'orderId': orderId,
      'senderRole': senderRole,
      'isTyping': isTyping,
    });
  }

  // ─── Disconnect ──────────────────────────────────────────────

  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _isConnected = false;
    _currentOrderId = null;
    _currentRiderId = null;
    _currentBusinessId = null;
    _currentCustomerId = null;
    print('[WebSocket] Disconnected manually');
  }

  void dispose() {
    disconnect();
    _orderStatusController.close();
    _riderLocationController.close();
    _riderAssignedController.close();
    _connectionController.close();
    _newOrderController.close();
    _chatMessageController.close();
    _chatTypingController.close();
    _businessOrderController.close();
    _menuUpdatedController.close();
  }
}