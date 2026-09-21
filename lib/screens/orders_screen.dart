import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../services/chat_unread_service.dart';
import '../services/api_service.dart';
import '../services/background_location_service.dart';
import '../services/rider_background_service.dart';
import '../widgets/confetti_celebration.dart';
import '../widgets/premium_dialogs.dart';
import 'chat_screen.dart';

/// SwiftDrop Orders Screen — Modern & Attractive Design
class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  List<dynamic> _orders = [];
  bool _loading = true;
  String? _error;
  String _selectedFilter = 'All';

  static const Map<String, String> _nextStatus = {
    'assigned': 'accepted',
    'accepted': 'picked_up',
    'picked_up': 'in_transit',
    'in_transit': 'delivered',
  };

  static const Map<String, String> _nextStatusLabel = {
    'assigned': 'Accept',
    'accepted': 'Pick Up',
    'picked_up': 'Deliver',
    'in_transit': 'Done',
  };

  static const Map<String, IconData> _statusIcons = {
    'assigned': Icons.person_add_rounded,
    'accepted': Icons.check_circle_outline,
    'picked_up': Icons.shopping_bag_rounded,
    'in_transit': Icons.local_shipping_rounded,
    'delivered': Icons.task_alt_rounded,
    'cancelled': Icons.cancel_rounded,
  };

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    setState(() { _loading = true; _error = null; });
    try {
      final orders = await ApiService.getMyOrders();
      setState(() { _orders = orders; _loading = false; });
    } catch (e) {
      setState(() { _error = e.toString().replaceAll('Exception: ', ''); _loading = false; });
    }
  }

  List<dynamic> get _filteredOrders {
    if (_selectedFilter == 'All') return _orders;
    return _orders.where((o) => o['status'] == _selectedFilter.toLowerCase()).toList();
  }

  Map<String, int> get _statusCounts {
    final counts = <String, int>{'All': _orders.length};
    for (final order in _orders) {
      final status = order['status'] ?? 'unknown';
      counts[status] = (counts[status] ?? 0) + 1;
    }
    return counts;
  }

  Future<void> _advanceStatus(dynamic order, String nextStatus) async {
    // Accepting an order is a commitment — confirm first and show the
    // route + fare so the rider knows exactly what they're taking on.
    if (nextStatus == 'accepted') {
      final confirmed = await PremiumDialogs.showConfirm(
        context,
        title: 'Accept Order?',
        message:
            'Pickup: ${order['pickupAddress'] ?? 'Restaurant'}\nDrop: ${order['dropAddress'] ?? 'Customer'}\nFare: Rs.${order['fare'] ?? 0}',
        confirmText: 'Accept',
        icon: Icons.local_shipping_rounded,
      );
      if (!confirmed) return;
      if (!mounted) return;
    }
    final orderId = (order['id'] ?? '').toString();
    try {
      await ApiService.updateOrderStatus(orderId, nextStatus);
      
      if (nextStatus == 'accepted' || nextStatus == 'picked_up') {
        await RiderBackgroundService.startTracking(orderId: orderId);
        // Link GPS pings to this order so customers see live location
        await BackgroundLocationService.setCurrentOrder(orderId);
      }
      
      if (nextStatus == 'delivered' || nextStatus == 'cancelled') {
        await RiderBackgroundService.stopTracking();
        // Unlink order from GPS pings
        await BackgroundLocationService.setCurrentOrder(null);
      }
      
      _loadOrders();
      if (mounted) {
        if (nextStatus == 'delivered') {
          // Show confetti celebration for delivery
          showDialog(
            context: context,
            barrierDismissible: true,
            builder: (context) => DeliveryCelebrationDialog(
              orderId: orderId,
              onContinue: () => Navigator.of(context).pop(),
              onRateNow: () => Navigator.of(context).pop(),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(Icons.check_circle, color: Colors.white, size: 16),
                  ),
                  const SizedBox(width: 10),
                  Text('Order status updated!', style: const TextStyle(fontWeight: FontWeight.w600)),
                ],
              ),
              backgroundColor: AppColors.orange,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              margin: const EdgeInsets.all(16),
            ),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white, size: 18),
              const SizedBox(width: 10),
              Expanded(child: Text(e.toString(), style: const TextStyle(fontSize: 13))),
            ],
          ),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0A0A0A) : AppColors.offWhite;
    final cardColor = isDark ? const Color(0xFF1A1A1A) : Colors.white;
    final textColor = isDark ? Colors.white : AppColors.black;
    final subTextColor = isDark ? const Color(0xFFB0B0B0) : AppColors.darkGray;

    AppColors.setLightStatusBar();
    // ListenableBuilder: card badges rebuild live as new chat messages arrive
    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        top: false,
        child: ListenableBuilder(
          listenable: ChatUnreadService.instance,
          builder: (context, _) => Column(
          children: [
            // Header
            _buildHeader(textColor, subTextColor),
            
            // Filter chips
            if (!_loading && _orders.isNotEmpty)
              _buildFilterChips(isDark),
            
            // Content
            Expanded(child: _buildContent(cardColor, textColor, subTextColor)),
          ],
        ),
        ),
      ),
    );
  }

  Widget _buildHeader(Color textColor, Color subTextColor) {
    final statusBarHeight = MediaQuery.of(context).padding.top;
    return Container(
      margin: EdgeInsets.fromLTRB(16, statusBarHeight + 12, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.orange.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          // Icon container
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.receipt_long_rounded, color: Colors.white, size: 26),
          ),
          const SizedBox(width: 14),
          // Title & subtitle
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'My Orders',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${_orders.length} total orders',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
          // Refresh button
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 22),
              onPressed: _loadOrders,
              padding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips(bool isDark) {
    final counts = _statusCounts;
    final filters = ['All', 'assigned', 'accepted', 'picked_up', 'in_transit', 'delivered'];
    
    return Container(
      height: 52,
      margin: const EdgeInsets.only(top: 12),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final filter = filters[index];
          final count = counts[filter] ?? 0;
          final isSelected = _selectedFilter == filter;
          
          if (filter != 'All' && count == 0) return const SizedBox.shrink();
          
          return GestureDetector(
            onTap: () => setState(() => _selectedFilter = filter),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.orange : (isDark ? const Color(0xFF1A1A1A) : Colors.white),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? AppColors.orange : AppColors.gray,
                  width: 1,
                ),
                boxShadow: isSelected
                    ? [BoxShadow(color: AppColors.orange.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 3))]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (filter != 'All')
                    Icon(_statusIcons[filter] ?? Icons.circle, size: 14, color: isSelected ? Colors.white : AppColors.orange),
                  if (filter != 'All') const SizedBox(width: 6),
                  Text(
                    filter == 'All' ? 'All' : _getStatusLabel(filter),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.white : AppColors.darkGray,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.white.withValues(alpha: 0.2) : AppColors.orangePale,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$count',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: isSelected ? Colors.white : AppColors.orange,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'assigned': return 'New';
      case 'accepted': return 'Accepted';
      case 'picked_up': return 'Picked Up';
      case 'in_transit': return 'In Transit';
      case 'delivered': return 'Delivered';
      default: return status;
    }
  }

  Widget _buildContent(Color cardColor, Color textColor, Color subTextColor) {
    if (_loading) {
      return _buildLoadingState(subTextColor);
    }

    if (_error != null) {
      return _buildErrorState(textColor, subTextColor);
    }

    if (_orders.isEmpty) {
      return _buildEmptyState(textColor, subTextColor);
    }

    if (_filteredOrders.isEmpty) {
      return _buildNoFilterResults(textColor, subTextColor);
    }

    return RefreshIndicator(
      onRefresh: _loadOrders,
      color: AppColors.orange,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        itemCount: _filteredOrders.length,
        itemBuilder: (context, index) {
          final order = _filteredOrders[index];
          final status = order['status'] as String;
          final next = _nextStatus[status];
          return _buildOrderCard(order, status, next, cardColor, textColor, subTextColor);
        },
      ),
    );
  }

  Widget _buildLoadingState(Color subTextColor) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              shape: BoxShape.circle,
            ),
            child: const Padding(
              padding: EdgeInsets.all(14),
              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
            ),
          ),
          const SizedBox(height: 20),
          Text('Loading orders...', style: TextStyle(fontSize: 14, color: subTextColor, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildErrorState(Color textColor, Color subTextColor) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.error_outline_rounded, size: 48, color: Colors.red),
            ),
            const SizedBox(height: 20),
            Text('Oops!', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: textColor)),
            const SizedBox(height: 8),
            Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: subTextColor, fontSize: 14)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadOrders,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.orange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(Color textColor, Color subTextColor) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: AppColors.orangePale,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.receipt_long_rounded, size: 56, color: AppColors.orange.withValues(alpha: 0.7)),
          ),
          const SizedBox(height: 24),
          Text('No Orders Yet', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: textColor)),
          const SizedBox(height: 8),
          Text('Your assigned orders will appear here', style: TextStyle(color: subTextColor, fontSize: 14)),
          const SizedBox(height: 8),
          Text('Go online to start receiving orders', style: TextStyle(color: AppColors.orange, fontSize: 13, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildNoFilterResults(Color textColor, Color subTextColor) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.filter_list_off_rounded, size: 48, color: AppColors.orange.withValues(alpha: 0.5)),
          const SizedBox(height: 16),
          Text('No orders with this status', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: textColor)),
          const SizedBox(height: 8),
          Text('Try a different filter', style: TextStyle(color: subTextColor, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildOrderCard(dynamic order, String status, String? next, Color cardColor, Color textColor, Color subTextColor) {
    final hasAction = next != null;
    final orderId = (order['id'] ?? '').toString();
    final shortId = orderId.length > 8 ? orderId.substring(0, 8) : orderId;
    final unreadChats = ChatUnreadService.instance.unreadsFor(orderId);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Order header with status
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _getStatusColor(status).withValues(alpha: 0.08),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _getStatusColor(status).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    _statusIcons[status] ?? Icons.circle,
                    size: 18,
                    color: _getStatusColor(status),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order['customerName'] ?? 'Customer',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: textColor),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Order #$shortId',
                        style: TextStyle(fontSize: 12, color: subTextColor),
                      ),
                    ],
                  ),
                ),
                // Unread chat count chip
                if (unreadChats > 0)
                  Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.orange,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.chat_bubble_rounded, size: 12, color: Colors.white),
                        const SizedBox(width: 4),
                        Text(
                          '$unreadChats new',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                _buildStatusChip(status),
              ],
            ),
          ),
          
          // Order details
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                // Route info
                Row(
                  children: [
                    _buildRouteDot(AppColors.statusDelivered),
                    Expanded(
                      child: Text(
                        order['pickupAddress'] ?? 'Pickup location',
                        style: TextStyle(fontSize: 13, color: textColor),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                Container(
                  margin: const EdgeInsets.only(left: 5),
                  width: 2,
                  height: 16,
                  color: AppColors.gray,
                ),
                Row(
                  children: [
                    _buildRouteDot(AppColors.orange),
                    Expanded(
                      child: Text(
                        order['dropAddress'] ?? 'Drop location',
                        style: TextStyle(fontSize: 13, color: textColor),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 12),
                
                // Bottom row: fare + action
                Row(
                  children: [
                    // Fare
                    if (order['fare'] != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.orange.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.payments_rounded, size: 16, color: AppColors.orange),
                            const SizedBox(width: 6),
                            Text(
                              'Rs.${order['fare']}',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: AppColors.orange,
                              ),
                            ),
                          ],
                        ),
                      ),
                    
                    const Spacer(),
                    
                    // Chat button — only after the rider has accepted the
                    // order; before that there's no confirmed relationship
                    // with the customer to chat about.
                    if (_hasAcceptedOrder(status))
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ChatScreen(
                                orderId: order['id']?.toString() ?? '',
                                otherUserName: order['customerName'] ?? 'Customer',
                                otherUserRole: 'customer',
                                currentUserRole: 'rider',
                              ),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.orangePale,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.chat_bubble_outline, color: AppColors.orange, size: 18),
                        ),
                      ),
                    
                    if (_hasAcceptedOrder(status)) const SizedBox(width: 8),
                    
                    // Action button
                    if (hasAction)
                      ElevatedButton(
                        onPressed: () => _advanceStatus(order, next),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.orange,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          elevation: 0,
                          shadowColor: Colors.transparent,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(_statusIcons[next] ?? Icons.arrow_forward, size: 16),
                            const SizedBox(width: 6),
                            Text(
                              _nextStatusLabel[status] ?? next,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ),
                    
                    if (!hasAction && status == 'delivered')
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_circle, size: 16, color: Colors.green),
                            SizedBox(width: 6),
                            Text('Completed', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.green)),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Chat/support actions unlock only once the rider has ACCEPTED the
  /// order — assigned (not yet accepted) orders have no actionable chat.
  bool _hasAcceptedOrder(String status) {
    return status == 'accepted' || status == 'picked_up' || status == 'in_transit';
  }

  Widget _buildRouteDot(Color color) {
    return Container(
      margin: const EdgeInsets.only(right: 10),
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'assigned': return AppColors.darkGray;
      case 'accepted': return Colors.blue;
      case 'picked_up': return Colors.purple;
      case 'in_transit': return AppColors.orange;
      case 'delivered': return Colors.green;
      case 'cancelled': return Colors.red;
      default: return AppColors.gray;
    }
  }

  Widget _buildStatusChip(String status) {
    final color = _getStatusColor(status);
    final label = _getStatusLabel(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_statusIcons[status] ?? Icons.circle, size: 12, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
