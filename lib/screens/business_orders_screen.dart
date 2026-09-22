import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../services/api_service.dart';
import '../services/error_helper.dart';
import '../services/websocket_service.dart';
import '../widgets/shimmer_loading.dart';
import '../utils/order_time.dart';

/// SwiftDrop Business Orders — FoodPanda-partner style
class BusinessOrdersScreen extends StatefulWidget {
  const BusinessOrdersScreen({super.key});

  @override
  State<BusinessOrdersScreen> createState() => _BusinessOrdersScreenState();
}

class _BusinessOrdersScreenState extends State<BusinessOrdersScreen>
    with SingleTickerProviderStateMixin {
  List<dynamic> _orders = [];
  bool _loading = true;
  String? _error;
  String _filter = 'All';
  StreamSubscription<Map<String, dynamic>>? _wsSub;

  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;

  final List<_OrderFilter> _filters = const [
    _OrderFilter('All', Icons.list_rounded),
    _OrderFilter('pending', Icons.schedule_rounded),
    _OrderFilter('accepted', Icons.check_circle_outline_rounded),
    _OrderFilter('picked_up', Icons.shopping_bag_outlined),
    _OrderFilter('in_transit', Icons.local_shipping_outlined),
    _OrderFilter('delivered', Icons.task_alt_rounded),
    _OrderFilter('cancelled', Icons.cancel_outlined),
  ];

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _loadOrders();
    _listenLive();
  }

  /// Live updates: any new order / status change for THIS business arrives instantly.
  void _listenLive() async {
    WebSocketService.instance.connect();
    // Join this business's room — 'business:newOrder' is sent server-side
    // to room `business:<id>` only, so without joining it, the listener
    // below never actually receives anything.
    try {
      final biz = await ApiService.businessGetMe();
      final businessId = biz['id']?.toString();
      if (businessId != null) {
        WebSocketService.instance.watchBusiness(businessId);
      }
    } catch (_) {}
    _wsSub = WebSocketService.instance.businessOrderStream.listen((update) {
      if (!mounted) return;
      final orderId = update['orderId']?.toString();
      if (orderId == null) return;
      final idx = _orders.indexWhere((o) => o['id']?.toString() == orderId);
      if (idx >= 0 && update['status'] != null) {
        setState(() => _orders[idx]['status'] = update['status']);
      } else if (idx < 0) {
        _loadOrders(); // new order → refetch to get full details
      }
    });
  }

  @override
  void dispose() {
    _wsSub?.cancel();
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _loadOrders() async {
    setState(() { _loading = true; _error = null; });
    try {
      // Only THIS business's orders (FoodPanda-partner style)
      final orders = await ApiService.businessGetMyOrders();
      if (mounted) {
        setState(() { _orders = orders; _loading = false; });
        _fadeController.forward();
      }
    } catch (e) {
      if (mounted) {
        setState(() { _error = ErrorHelper.getMessage(e); _loading = false; });
      }
    }
  }

  List<dynamic> get _filteredOrders {
    if (_filter == 'All') return _orders;
    return _orders.where((o) => (o['status'] ?? 'pending') == _filter).toList();
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'pending': return AppColors.orangeDark;
      case 'accepted': return AppColors.orange;
      case 'picked_up': return AppColors.orangeDark;
      case 'in_transit': return AppColors.orange;
      case 'delivered': return AppColors.statusDelivered;
      case 'cancelled': return AppColors.darkGray;
      default: return AppColors.darkGray;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'pending': return 'New Order';
      case 'assigned': return 'Assigned';
      case 'accepted': return 'Accepted';
      case 'picked_up': return 'Picked Up';
      case 'in_transit': return 'On the Way';
      case 'delivered': return 'Delivered';
      case 'cancelled': return 'Cancelled';
      default: return status;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'pending': return Icons.notifications_active_rounded;
      case 'accepted': return Icons.restaurant_rounded;
      case 'picked_up': return Icons.shopping_bag_rounded;
      case 'in_transit': return Icons.motorcycle_rounded;
      case 'delivered': return Icons.check_circle_rounded;
      case 'cancelled': return Icons.cancel_rounded;
      default: return Icons.receipt_long_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0A0A0A) : const Color(0xFFF6F6F6);
    final textColor = isDark ? Colors.white : AppColors.black;

    return Scaffold(
      backgroundColor: bgColor,
      body: Column(
        children: [
          _buildHeader(isDark, textColor),
          _buildFilterTabs(isDark),
          Expanded(child: _buildBody(isDark, textColor)),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isDark, Color textColor) {
    final statusBarHeight = MediaQuery.of(context).padding.top;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(20, statusBarHeight + 14, 20, 18),
      decoration: const BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
        boxShadow: [
          BoxShadow(color: AppColors.orange, blurRadius: 16, offset: Offset(0, 6), spreadRadius: -6),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Orders', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: textColor == Colors.white ? Colors.white : Colors.white)),
                const SizedBox(height: 2),
                Text('${_orders.where((o) => (o['status'] ?? '') == 'pending').length} new • ${_orders.length} total',
                    style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.85))),
              ],
            ),
          ),
          GestureDetector(
            onTap: _loadOrders,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.refresh_rounded, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterTabs(bool isDark) {
    return SizedBox(
      height: 62,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
        itemCount: _filters.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final f = _filters[i];
          final isSelected = _filter == f.label;
          final count = f.label == 'All'
              ? _orders.length
              : _orders.where((o) => (o['status'] ?? '') == f.label).length;
          return GestureDetector(
            onTap: () => setState(() => _filter = f.label),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                gradient: isSelected ? AppColors.primaryGradient : null,
                color: isSelected ? null : (isDark ? const Color(0xFF1A1A1A) : Colors.white),
                borderRadius: BorderRadius.circular(20),
                border: isSelected ? null : Border.all(color: AppColors.gray.withValues(alpha: 0.4)),
                boxShadow: isSelected
                    ? [BoxShadow(color: AppColors.orange.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 3))]
                    : [],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(f.icon, size: 15, color: isSelected ? Colors.white : AppColors.darkGray),
                  const SizedBox(width: 5),
                  Text(
                    f.label == 'All' ? 'All' : _statusLabel(f.label),
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? Colors.white : AppColors.darkGray,
                    ),
                  ),
                  if (count > 0) ...[
                    const SizedBox(width: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.white.withValues(alpha: 0.25) : AppColors.orange.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text('$count', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: isSelected ? Colors.white : AppColors.orange)),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBody(bool isDark, Color textColor) {
    if (_loading) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        children: const [
          OrderCardSkeleton(),
          SizedBox(height: 12),
          OrderCardSkeleton(),
          SizedBox(height: 12),
          OrderCardSkeleton(),
        ],
      );
    }
    if (_error != null) {
      return _buildErrorState(isDark);
    }
    final orders = _filteredOrders;
    if (orders.isEmpty) {
      return _buildEmptyState(isDark);
    }
    return FadeTransition(
      opacity: _fadeAnimation,
      child: RefreshIndicator(
        onRefresh: _loadOrders,
        color: AppColors.orange,
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
          itemCount: orders.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, i) => _buildOrderCard(orders[i], isDark),
        ),
      ),
    );
  }

  Widget _buildErrorState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(color: AppColors.orangePale.withValues(alpha: 0.5), shape: BoxShape.circle),
              child: const Icon(Icons.wifi_off_rounded, size: 44, color: AppColors.orange),
            ),
            const SizedBox(height: 18),
            Text(_error!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, color: AppColors.darkGray, height: 1.5)),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _loadOrders,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.orange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Retry', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: AppColors.orangePale.withValues(alpha: 0.5), shape: BoxShape.circle),
              child: const Icon(Icons.receipt_long_rounded, size: 52, color: AppColors.orange),
            ),
            const SizedBox(height: 18),
            Text('No ${_filter == 'All' ? '' : '${_statusLabel(_filter).toLowerCase()} '}orders yet',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: isDark ? Colors.white : AppColors.black)),
            const SizedBox(height: 6),
            const Text('New orders will appear here in real time', style: TextStyle(fontSize: 13, color: AppColors.darkGray)),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderCard(dynamic order, bool isDark) {
    final status = (order['status'] ?? 'pending').toString();
    final businessConfirmed = order['businessConfirmed'] == true;
    final statusColor = _statusColor(status);
    final textColor = isDark ? Colors.white : AppColors.black;
    final customer = (order['customerName'] ?? 'Customer').toString();
    final phone = (order['customerPhone'] ?? '').toString();
    final pickup = (order['pickupAddress'] ?? '').toString();
    final drop = (order['dropAddress'] ?? '').toString();
    final fareRaw = order['fare'];
    final fare = fareRaw != null ? double.tryParse(fareRaw.toString()) ?? 0.0 : 0.0;
    // UTC → local conversion via shared helper (raw .hour showed UTC clock,
    // 5 hours behind Pakistan time).
    final timeStr = formatOrderDayTime(order['createdAt']);
    final cardColor = isDark ? const Color(0xFF1A1A1A) : Colors.white;

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Column(
        children: [
          // Top row: id + status chip
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(_statusIcon(status), size: 18, color: statusColor),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('#${(order['id'] ?? '').toString().substring(0, 8).toUpperCase()}',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: textColor, letterSpacing: 0.3)),
                      Text(timeStr, style: const TextStyle(fontSize: 11, color: AppColors.darkGray)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: (status == 'pending' && businessConfirmed ? AppColors.statusDelivered : statusColor).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                      // Accepted-by-business orders stay status 'pending'
                      // (that flag is separate from the rider flow) — show
                      // them as 'Preparing' so the owner SEES the accept
                      // worked instead of the order looking untouched.
                      status == 'pending' && businessConfirmed ? 'Preparing 🔥' : _statusLabel(status),
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: status == 'pending' && businessConfirmed ? AppColors.statusDelivered : statusColor)),
                ),
              ],
            ),
          ),
          // Customer + addresses
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: AppColors.orange.withValues(alpha: 0.12),
                  child: Text(customer.isNotEmpty ? customer[0].toUpperCase() : 'C',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.orange)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(customer, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: textColor)),
                      if (phone.isNotEmpty) Text(phone, style: const TextStyle(fontSize: 11.5, color: AppColors.darkGray)),
                    ],
                  ),
                ),
                Text('Rs.${fare.toStringAsFixed(0)}',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.orange)),
              ],
            ),
          ),
          // Route
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppColors.orange, shape: BoxShape.circle)),
                    Container(width: 1.5, height: 26, color: AppColors.gray),
                    const Icon(Icons.location_on_rounded, size: 12, color: AppColors.darkGray),
                  ],
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(pickup.isEmpty ? 'Pickup' : pickup,
                          style: TextStyle(fontSize: 12, color: textColor.withValues(alpha: 0.8)),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 12),
                      Text(drop.isEmpty ? 'Drop-off' : drop,
                          style: TextStyle(fontSize: 12, color: textColor.withValues(alpha: 0.8)),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Accept / Reject actions for NEW orders (business confirms it
          // can prepare this order). Reject archives it as cancelled.
          // Gated on businessConfirmed, not on rider `status` — this used
          // to call updateOrderStatus(id, 'accepted'), which is the RIDER's
          // accept step. That collided with the rider's own Accept button
          // (whoever tapped first silently overwrote the other's step) and
          // outright failed while status was still 'pending' (pending can
          // only move to assigned/cancelled, not accepted).
          if (!businessConfirmed && status != 'delivered' && status != 'cancelled')
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _rejectOrder(order),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red.shade600,
                        side: BorderSide(color: Colors.red.shade300),
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.close_rounded, size: 17),
                      label: const Text('Reject', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _acceptOrder(order),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.orange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.check_rounded, size: 17),
                      label: const Text('Accept Order', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800)),
                    ),
                  ),
                ],
              ),
            ),
          // Food is PREPARED — tell the assigned rider to come pick it up.
          // This is the "rider ko kaise pata chale" step: the backend pings
          // the rider's private socket room and their app notifies them.
          if (businessConfirmed &&
              (order['readyNotifiedAt'] ?? '') == '' &&
              status != 'delivered' &&
              status != 'cancelled' &&
              status != 'in_transit')
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _markReady(order),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.statusDelivered,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  icon: const Icon(Icons.room_service_rounded, size: 17),
                  label: const Text('Order Ready — Call Rider', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800)),
                ),
              ),
            ),
          if ((order['readyNotifiedAt'] ?? '').toString().isNotEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Row(
                children: [
                  Icon(Icons.notifications_active_rounded, size: 14, color: AppColors.statusDelivered),
                  SizedBox(width: 6),
                  Text('Rider notified — food is ready for pickup', style: TextStyle(fontSize: 12, color: AppColors.statusDelivered, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// Food prepared → ping the rider. Backend emits a notification into
  /// the rider's socket room; the rider's app shows it as a system
  /// notification + live card update.
  Future<void> _markReady(dynamic order) async {
    final id = (order['id'] ?? '').toString();
    if (id.isEmpty) return;
    try {
      await ApiService.markOrderReady(id);
      if (!mounted) return;
      setState(() {
        final idx = _orders.indexWhere((o) => o['id'].toString() == id);
        if (idx != -1) {
          _orders[idx]['readyNotifiedAt'] = DateTime.now().toIso8601String();
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(children: [
            Icon(Icons.notifications_active_rounded, color: Colors.white, size: 18),
            SizedBox(width: 10),
            Text('Rider notified — food is ready!', style: TextStyle(fontWeight: FontWeight.w600)),
          ]),
          backgroundColor: AppColors.statusDelivered,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not notify rider: $e', style: const TextStyle(fontSize: 13)),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  Future<void> _acceptOrder(dynamic order) async {
    final id = (order['id'] ?? '').toString();
    if (id.isEmpty) return;
    try {
      await ApiService.businessAcceptOrder(id);
      if (!mounted) return;
      setState(() {
        final idx = _orders.indexWhere((o) => o['id'].toString() == id);
        if (idx != -1) _orders[idx]['businessConfirmed'] = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(children: [
            Icon(Icons.check_circle, color: Colors.white, size: 18),
            SizedBox(width: 10),
            Text('Order accepted — start preparing!', style: TextStyle(fontWeight: FontWeight.w600)),
          ]),
          backgroundColor: AppColors.orange,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not accept order: $e', style: const TextStyle(fontSize: 13)),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  Future<void> _rejectOrder(dynamic order) async {
    final id = (order['id'] ?? '').toString();
    if (id.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject this order?'),
        content: const Text('The customer will be notified that the order cannot be fulfilled.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep order')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Reject', style: TextStyle(color: Colors.red.shade600, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ApiService.updateOrderStatus(id, 'cancelled');
      if (!mounted) return;
      setState(() {
        final idx = _orders.indexWhere((o) => o['id'].toString() == id);
        if (idx != -1) _orders[idx]['status'] = 'cancelled';
      });
    } catch (_) {}
  }
}

class _OrderFilter {
  final String label;
  final IconData icon;
  const _OrderFilter(this.label, this.icon);
}