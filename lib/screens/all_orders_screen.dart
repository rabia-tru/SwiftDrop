import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../services/api_service.dart';
import '../services/error_helper.dart';
import '../services/chat_unread_service.dart';
import '../utils/order_time.dart';
import 'track_order_screen.dart';

/// SwiftDrop All Orders — Search, filter, reorder (Real API data)
class AllOrdersScreen extends StatefulWidget {
  const AllOrdersScreen({super.key});

  @override
  State<AllOrdersScreen> createState() => _AllOrdersScreenState();
}

class _AllOrdersScreenState extends State<AllOrdersScreen> {
  final _searchController = TextEditingController();
  String _selectedFilter = 'All';
  List<dynamic> _orders = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadOrders() async {
    setState(() { _loading = true; _error = null; });
    try {
      final orders = await ApiService.getMyOrders();
      if (mounted) setState(() { _orders = orders; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = ErrorHelper.getMessage(e); _loading = false; });
    }
  }

  List<dynamic> get _filteredOrders {
    var filtered = _orders;
    if (_selectedFilter != 'All') {
      final statusMap = {
        'Delivered': 'delivered',
        'In Progress': ['assigned', 'accepted', 'picked_up', 'in_transit'],
        'Cancelled': 'cancelled',
      };
      final status = statusMap[_selectedFilter];
      if (status is String) {
        filtered = filtered.where((o) => o['status'] == status).toList();
      } else if (status is List) {
        filtered = filtered.where((o) => status.contains(o['status'])).toList();
      }
    }
    if (_searchController.text.isNotEmpty) {
      final q = _searchController.text.toLowerCase();
      filtered = filtered.where((o) =>
        (o['customerName'] ?? '').toLowerCase().contains(q) ||
        (o['pickupAddress'] ?? '').toLowerCase().contains(q) ||
        (o['dropAddress'] ?? '').toLowerCase().contains(q)
      ).toList();
    }
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0A0A0A) : AppColors.offWhite;
    final cardColor = isDark ? const Color(0xFF1A1A1A) : Colors.white;
    final textColor = isDark ? Colors.white : AppColors.black;
    final subTextColor = isDark ? const Color(0xFFB0B0B0) : AppColors.darkGray;
    final headerBg = isDark ? const Color(0xFF121212) : Colors.white;

    AppColors.setLightStatusBar();
    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            _buildHeader(headerBg, textColor),
            _buildSearchBar(cardColor, textColor, subTextColor),
            _buildFilterChips(),
            Expanded(child: _loading 
                ? _buildLoading(subTextColor)
                : _error != null 
                    ? _buildError(textColor, subTextColor)
                    : _buildOrderList(cardColor, textColor, subTextColor)),
          ],
        ),
      ),
    );
  }

  Widget _buildLoading(Color subTextColor) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 48, height: 48,
            decoration: const BoxDecoration(color: AppColors.orange, shape: BoxShape.circle),
            child: const Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3)),
          ),
          const SizedBox(height: 20),
          Text('Loading orders...', style: TextStyle(fontSize: 14, color: subTextColor)),
        ],
      ),
    );
  }

  Widget _buildError(Color textColor, Color subTextColor) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(color: AppColors.orangePale, shape: BoxShape.circle),
              child: const Icon(Icons.warning, size: 48, color: AppColors.orange),
            ),
            const SizedBox(height: 20),
            Text('Oops!', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: textColor)),
            const SizedBox(height: 8),
            Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: subTextColor, fontSize: 14)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadOrders,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.orange, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(Color headerBg, Color textColor) {
    final statusBarHeight = MediaQuery.of(context).padding.top;
    return Container(
      padding: EdgeInsets.fromLTRB(20, statusBarHeight + 14, 20, 14),
      decoration: BoxDecoration(
        color: headerBg,
        boxShadow: [BoxShadow(color: AppColors.orange.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: const Icon(Icons.arrow_back_ios, color: AppColors.orange, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(child: Text('All Orders', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: textColor))),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.orange, size: 22),
            onPressed: _loadOrders,
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(Color cardColor, Color textColor, Color subTextColor) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.orange.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            const Icon(Icons.search, color: AppColors.orange, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                style: TextStyle(fontSize: 15, color: textColor),
                decoration: InputDecoration(
                  hintText: 'Search orders...',
                  hintStyle: TextStyle(color: subTextColor, fontSize: 15),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    final filters = [
      {'label': 'All', 'icon': null},
      {'label': 'Delivered', 'icon': Icons.check_circle_outline},
      {'label': 'In Progress', 'icon': Icons.access_time},
      {'label': 'Cancelled', 'icon': Icons.cancel_outlined},
    ];

    return SizedBox(
      height: 52,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: filters.length,
        itemBuilder: (context, index) {
          final f = filters[index];
          final isSelected = _selectedFilter == f['label'];
          return Padding(
            padding: const EdgeInsets.only(right: 10),
            child: FilterChip(
              selected: isSelected,
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (f['icon'] != null) ...[
                    Icon(f['icon'] as IconData, size: 14, color: isSelected ? Colors.white : AppColors.orange),
                    const SizedBox(width: 4),
                  ],
                  Text(f['label'] as String, style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? Colors.white : AppColors.orange,
                  )),
                ],
              ),
              selectedColor: AppColors.orange,
              backgroundColor: Colors.white,
              side: BorderSide(color: isSelected ? AppColors.orange : AppColors.orange.withValues(alpha: 0.3)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              onSelected: (selected) => setState(() => _selectedFilter = f['label'] as String),
              checkmarkColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 4),
            ),
          );
        },
      ),
    );
  }

  Widget _buildOrderList(Color cardColor, Color textColor, Color subTextColor) {
    final orders = _filteredOrders;
    if (orders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(color: AppColors.orangePale, shape: BoxShape.circle),
              child: const Icon(Icons.inbox, size: 48, color: AppColors.orange),
            ),
            const SizedBox(height: 16),
            Text('No orders found', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: textColor)),
            const SizedBox(height: 8),
            Text('Try a different search or filter', style: TextStyle(fontSize: 14, color: subTextColor)),
          ],
        ),
      );
    }

    // Rebuild cards live when unread chat counts change
    return ListenableBuilder(
      listenable: ChatUnreadService.instance,
      child: RefreshIndicator(
        onRefresh: _loadOrders,
        color: AppColors.orange,
        child: ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          itemCount: orders.length,
          itemBuilder: (context, index) => _buildOrderCard(orders[index], cardColor, textColor, subTextColor),
        ),
      ),
      builder: (context, child) => child!,
    );
  }

  Widget _buildOrderCard(dynamic order, Color cardColor, Color textColor, Color subTextColor) {
    final status = order['status'] ?? 'pending';
    final customerName = order['customerName'] ?? 'Customer';
    final pickup = order['pickupAddress'] ?? 'Pickup';
    final drop = order['dropAddress'] ?? 'Drop';
    final fare = double.tryParse((order['fare'] ?? '0').toString()) ?? 0;
    final orderId = order['id'] ?? '';
    final unreadChats = ChatUnreadService.instance.unreadsFor(orderId.toString());

    // "21 Sep, 11:32 AM" — local time (was date-only and in UTC before).
    final dateStr = formatOrderDayTime(order['createdAt']);

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => TrackOrderScreen(order: Map<String, dynamic>.from(order)),
        ));
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: AppColors.orange.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(customerName, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: textColor)),
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
                        const Icon(Icons.chat_bubble, size: 12, color: Colors.white),
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
                _buildStatusBadge(status),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.location_on, color: AppColors.orange, size: 14),
                const SizedBox(width: 6),
                Expanded(child: Text('$pickup → $drop', style: TextStyle(fontSize: 13, color: subTextColor), maxLines: 1, overflow: TextOverflow.ellipsis)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text('Rs.${fare.toStringAsFixed(0)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.orange)),
                const SizedBox(width: 12),
                Text(dateStr, style: TextStyle(fontSize: 12, color: subTextColor)),
                const Spacer(),
                Text('#${orderId.toString().substring(0, 8)}', style: TextStyle(fontSize: 12, color: subTextColor)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bgColor;
    Color textColor;
    String label;
    IconData icon;

    switch (status) {
      case 'delivered':
        bgColor = AppColors.orange;
        textColor = Colors.white;
        label = 'Delivered';
        icon = Icons.check_circle;
        break;
      case 'in_transit':
      case 'picked_up':
      case 'accepted':
      case 'assigned':
        bgColor = AppColors.orangeLight;
        textColor = Colors.white;
        label = status.replaceAll('_', ' ');
        label = label[0].toUpperCase() + label.substring(1);
        icon = Icons.access_time;
        break;
      case 'cancelled':
        bgColor = AppColors.lightGray;
        textColor = AppColors.darkGray;
        label = 'Cancelled';
        icon = Icons.cancel;
        break;
      default:
        bgColor = AppColors.lightGray;
        textColor = AppColors.darkGray;
        label = status;
        icon = Icons.help;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(9999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: textColor),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: textColor)),
        ],
      ),
    );
  }
}
