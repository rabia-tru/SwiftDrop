import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_service.dart';
import 'foodpanda_notifications.dart';
import 'websocket_service.dart';

/// Tracks unread chat messages per order so the Orders screen and the
/// Orders nav tab can show a live badge (like WhatsApp/Foodpanda).
///
/// Rules:
///  • Only messages from the OTHER side count (own echoes never do).
///  • Messages for the currently-open chat don't count — the chat screen
///    marks itself read.
///  • Counts persist in SharedPreferences so the badge survives app
///    restarts.
class ChatUnreadService extends ChangeNotifier {
  ChatUnreadService._();
  static final ChatUnreadService instance = ChatUnreadService._();

  static const _prefsKey = 'chat_unread_counts';

  final Map<String, int> _counts = {};
  StreamSubscription<Map<String, dynamic>>? _sub;
  bool _initialized = false;

  /// Order whose chat screen is currently open — messages for it are
  /// seen immediately, so they never count as unread.
  String? _activeOrderId;

  /// My side of the conversation ('rider' | 'customer') — used to ignore
  /// my own message echoes. Loaded from the saved login role.
  String _myRole = 'customer';

  /// Fires whenever any unread count changes (for badge widgets).
  final _changeController = StreamController<int>.broadcast();
  Stream<int> get changeStream => _changeController.stream;

  /// Total unread messages across all orders (nav-bar badge).
  int get totalUnreads =>
      _counts.values.fold(0, (sum, n) => sum + n);

  /// Unread count for one order (order-card badge). 0 = no badge.
  int unreadsFor(String orderId) => _counts[orderId] ?? 0;

  /// Call once at app startup (after WebSocketService is available).
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    // Restore persisted counts
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        _counts
          ..clear()
          ..addEntries(decoded.entries.map(
            (e) => MapEntry(e.key, (e.value as num?)?.toInt() ?? 0),
          ));
      }
    } catch (_) {
      _counts.clear();
    }

    // My role so own echoes are never counted as unread
    final role = await ApiService.getLastLoginRole();
    if (role == 'rider' || role == 'business') _myRole = 'rider';

    // Live counting from the shared socket
    final ws = WebSocketService.instance;
    _sub?.cancel();
    _sub = ws.chatMessageStream.listen(_onMessage);
  }

  void _onMessage(Map<String, dynamic> data) {
    final orderId = (data['orderId'] ?? '').toString();
    if (orderId.isEmpty) return;

    final senderRole = (data['senderRole'] ?? '').toString();
    if (senderRole == _myRole) return; // my own echo
    if (orderId == _activeOrderId) return; // chat is open — already seen

    _counts[orderId] = (_counts[orderId] ?? 0) + 1;
    _persist();
    notifyListeners();
    _changeController.add(totalUnreads);

    // App is running but the chat screen is closed → heads-up notification
    // (app-kill case is handled by the background service's chat poller).
    final name = (data['senderName'] ?? '').toString();
    final text = (data['message'] ?? '').toString();
    FoodPandaNotifications.chatMessage(
      orderId,
      name.isNotEmpty ? name : (_myRole == 'rider' ? 'Customer' : 'Rider'),
      text,
    );
  }

  /// Chat screen opened (or returned to) → everything there is read.
  Future<void> markOrderRead(String orderId) async {
    if (orderId.isEmpty) return;
    if (_counts[orderId] == null || _counts[orderId] == 0) return;
    _counts[orderId] = 0;
    await _persist();
    notifyListeners();
    _changeController.add(totalUnreads);
  }

  /// Order finished/cancelled → its badge is no longer relevant.
  Future<void> clearOrder(String orderId) async {
    if (_counts.remove(orderId) != null) {
      await _persist();
      notifyListeners();
      _changeController.add(totalUnreads);
    }
  }

  /// Chat screen lifecycle hooks.
  void setActiveOrder(String? orderId) => _activeOrderId = orderId;

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, jsonEncode(_counts));
    } catch (_) {/* best-effort */}
  }

  @override
  void dispose() {
    _sub?.cancel();
    _changeController.close();
    super.dispose();
  }
}
