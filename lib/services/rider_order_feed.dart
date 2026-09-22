import 'dart:async';

import 'package:flutter/foundation.dart';

import 'api_service.dart';
import 'websocket_service.dart';

/// Shared live feed of the signed-in rider's orders.
///
/// Rider screens (Home, Orders, Earnings) all need the same list, and all
/// of them need to update LIVE as statuses change (business confirms, rider
/// advances a delivery from another tab, new assignment arrives). Instead of
/// each screen keeping its own copy and its own listeners, they all watch
/// this singleton:
///
///   • fetches once on first [refresh] and shares the result,
///   • re-fetches (debounced) whenever ANY rider-relevant WebSocket event
///     fires (`rider:orderUpdate`, `order:update`, new assignment, connection
///     restored), so every screen stays in sync with a single API call,
///   • exposes [ChangeNotifier]-style listeners plus derived getters
///     (active orders, today/weekly earnings) so screens stay dumb.
class RiderOrderFeed extends ChangeNotifier {
  RiderOrderFeed._();
  static final RiderOrderFeed instance = RiderOrderFeed._();

  List<dynamic> _orders = const [];
  bool _loading = false;
  bool _loadedOnce = false;
  String? _error;
  Timer? _debounce;

  /// Order ids currently being updated (button spinners key off this).
  final Set<String> _updating = {};

  List<dynamic> get orders => _orders;
  bool get loading => _loading;
  bool get loadedOnce => _loadedOnce;
  String? get error => _error;
  bool isUpdating(String orderId) => _updating.contains(orderId);

  /// Orders the rider is actively handling (accepted → in transit).
  List<dynamic> get activeOrders => _orders
      .where((o) =>
          o['status'] == 'accepted' ||
          o['status'] == 'picked_up' ||
          o['status'] == 'in_transit')
      .toList();

  /// Orders waiting for the rider's action (assigned, not yet accepted).
  List<dynamic> get assignedOrders =>
      _orders.where((o) => o['status'] == 'assigned').toList();

  /// Delivered orders only (for the earnings tab).
  List<dynamic> get deliveredOrders =>
      _orders.where((o) => o['status'] == 'delivered').toList();

  static double _fareOf(dynamic o) =>
      double.tryParse((o['fare'] ?? '0').toString()) ?? 0;

  static DateTime? _createdOf(dynamic o) {
    final raw = o['createdAt'];
    if (raw is DateTime) return raw.toLocal();
    final s = raw?.toString() ?? '';
    return s.isEmpty ? null : DateTime.tryParse(s)?.toLocal();
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  double get todayEarnings {
    final now = DateTime.now();
    return deliveredOrders
        .where((o) {
          final t = _createdOf(o);
          return t != null && _sameDay(t, now);
        })
        .fold(0.0, (sum, o) => sum + _fareOf(o));
  }

  int get todayDeliveries => deliveredOrders.where((o) {
        final t = _createdOf(o);
        final now = DateTime.now();
        return t != null && _sameDay(t, now);
      }).length;

  double get weeklyEarnings {
    final weekAgo = DateTime.now().subtract(const Duration(days: 7));
    return deliveredOrders
        .where((o) => (_createdOf(o) ?? DateTime(2000)).isAfter(weekAgo))
        .fold(0.0, (sum, o) => sum + _fareOf(o));
  }

  double get totalEarnings =>
      deliveredOrders.fold(0.0, (sum, o) => sum + _fareOf(o));

  /// Deliveries per day for the last 7 days, oldest first (Mon-Sun chart).
  List<int> deliveriesByDay() {
    final now = DateTime.now();
    final counts = List<int>.filled(7, 0);
    for (final o in deliveredOrders) {
      final t = _createdOf(o);
      if (t == null) continue;
      final daysAgo = now.difference(t).inDays;
      // An order created 3 days ago but 1h earlier in the day counts as 3.
      // Clamp edge cases where clock drift makes diff slightly negative.
      if (daysAgo >= 0 && daysAgo < 7) counts[6 - daysAgo] += 1;
    }
    return counts;
  }

  double earningsByDay(List<int> counts) {
    // Kept as a helper so callers don't recompute fares twice if they want
    // both counts and amounts per day.
    return counts.fold(0, (a, b) => a + b).toDouble();
  }

  Future<void> refresh({bool force = false}) async {
    if (_loading && !force) return;
    _loading = true;
    if (!_loadedOnce) notifyListeners();
    try {
      final orders = await ApiService.getMyOrders();
      _orders = orders;
      _error = null;
      _loadedOnce = true;
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Debounced live refresh — collapses bursts of WS events into one fetch.
  void scheduleRefresh() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      refresh(force: true);
    });
  }

  /// Mark an order locally as being updated (optimistic button state).
  void markUpdating(String orderId, bool value) {
    value ? _updating.add(orderId) : _updating.remove(orderId);
    notifyListeners();
  }

  /// Optimistically apply a status change locally so all screens move
  /// instantly, then confirm with the server via [scheduleRefresh].
  void applyLocalStatus(String orderId, String status) {
    for (final o in _orders) {
      if ((o['id'] ?? '').toString() == orderId) {
        o['status'] = status;
        break;
      }
    }
    notifyListeners();
  }

  /// Subscribe to the WS room updates relevant to this rider and keep the
  /// feed fresh. Call once from a screen that is always alive (rider Home).
  void startListening() {
    final ws = WebSocketService.instance;
    ws.connect();
    ws.riderOrderStream.listen((_) => scheduleRefresh());
    ws.orderStatusStream.listen((_) => scheduleRefresh());
    ws.connectionStream.listen((connected) {
      if (connected) {
        scheduleRefresh();
        awaitRiderId(); // re-join the private room after reconnects
      }
    });
    awaitRiderId();
  }

  /// Join the rider's private room (`rider:<id>`) so backend pushes
  /// status updates even for orders we never watched directly. The id
  /// only becomes known once /riders/me resolves; the connection listener
  /// retries after every reconnect.
  Future<void> awaitRiderId() async {
    try {
      final me = await ApiService.getMe();
      final id = me['id']?.toString();
      if (id != null && id.isNotEmpty) {
        WebSocketService.instance.watchRider(id);
      }
    } catch (_) {
      // Unauthenticated or offline — the next reconnect retries.
    }
  }
}
