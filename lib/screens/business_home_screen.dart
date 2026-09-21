import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';
import '../services/api_service.dart';
import '../services/websocket_service.dart';
import '../services/push_notification_service.dart';
import '../widgets/floating_nav_bar.dart';
import '../widgets/premium_dialogs.dart';
import '../widgets/shimmer_loading.dart';
import 'business_menu_screen.dart';
import 'business_orders_screen.dart';
import 'business_profile_screen.dart';
import '../widgets/exit_confirm_dialog.dart';

/// SwiftDrop Business Home — FoodPanda-partner style shell
/// Tabs: Home (dashboard) • Menu • Orders • Profile
class BusinessHomeScreen extends StatefulWidget {
  const BusinessHomeScreen({super.key});

  /// Allows child screens (e.g. profile) to switch tabs on the shell.
  static _BusinessHomeScreenState? of(BuildContext context) =>
      context.findAncestorStateOfType<_BusinessHomeScreenState>();

  @override
  State<BusinessHomeScreen> createState() => _BusinessHomeScreenState();
}

class _BusinessHomeScreenState extends State<BusinessHomeScreen>
    with TickerProviderStateMixin {
  Map<String, dynamic>? _business;
  Map<String, dynamic>? _stats;
  List<dynamic> _menuItems = [];
  List<dynamic> _orders = [];
  bool _loading = true;
  int _currentTab = 0;
  bool _isOpen = true;

  late AnimationController _fadeController;
  late AnimationController _floatController;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(duration: const Duration(milliseconds: 600), vsync: this);
    _floatController = AnimationController(duration: const Duration(milliseconds: 3000), vsync: this);
    _pulseController = AnimationController(duration: const Duration(milliseconds: 1100), vsync: this);
    _fadeController.forward();
    _floatController.repeat(reverse: true);
    _pulseController.repeat(reverse: true);
    _loadData();
    _listenLiveOrders();
  }

  StreamSubscription<Map<String, dynamic>>? _wsSub;

  /// Public API for child screens to switch tabs (e.g. profile → orders).
  void goToTab(int index) {
    if (!mounted) return;
    setState(() => _currentTab = index.clamp(0, 3));
  }

  /// Live: new customer orders pop up instantly (notification + refresh).
  void _listenLiveOrders() {
    WebSocketService.instance.connect();
    _wsSub = WebSocketService.instance.businessOrderStream.listen((update) async {
      if (!mounted) return;
      final isNew = (update['status'] ?? '') == 'pending';
      final count = (update['items'] as List?)?.length ?? 0;
      await PushNotificationService.showOrderNotification(
        title: isNew ? '🔔 New Order Received!' : '📋 Order Update',
        body: isNew
            ? '${update['customerName'] ?? 'A customer'} placed an order${count > 0 ? ' ($count items)' : ''} — Rs.${update['fare'] ?? ''}'
            : 'Order #${(update['orderId'] ?? '').toString().substring(0, 8)} is now ${update['status']}',
        payload: update['orderId']?.toString(),
      );
      _loadData(); // refresh stats + lists
    });
  }

  @override
  void dispose() {
    _wsSub?.cancel();
    _fadeController.dispose();
    _floatController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final biz = await ApiService.businessGetMe();
      final stats = await ApiService.businessGetStats();
      final menu = await ApiService.businessGetMenu();
      List<dynamic> orders = [];
      try {
        orders = await ApiService.businessGetMyOrders();
      } catch (_) {/* orders optional */}
      if (mounted) {
        setState(() {
          _business = Map<String, dynamic>.from(biz);
          _stats = Map<String, dynamic>.from(stats);
          _menuItems = List<dynamic>.from(menu);
          _orders = orders;
          _isOpen = (_business?['isOpen'] ?? true) as bool;
          _loading = false;
        });
        // Join this business's private WebSocket room. Without this,
        // 'business:newOrder' events the backend sends to room
        // `business:<id>` never reach this screen — same class of bug as
        // the rider home screen not calling watchRider().
        final businessId = _business?['id']?.toString();
        if (businessId != null) {
          WebSocketService.instance.watchBusiness(businessId);
        }
        _fadeController.forward(from: 0);
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Orders still waiting for THIS business to accept — status is pending
  /// AND the business hasn't confirmed yet (accepted ones stay 'pending'
  /// but carry businessConfirmed=true).
  int get _pendingOrders => _orders
      .where((o) => (o['status'] ?? '') == 'pending' && o['businessConfirmed'] != true)
      .length;
  int get _todayOrders => _orders.length;

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ));

    return PopScope(
      // Non-Home tab → BACK pehle Home tab pe; Home tab par do baar BACK
      // = exit-confirmation. Role Selection pe kabhi wapas nahi jata.
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (_currentTab != 0) {
          setState(() => _currentTab = 0);
          return;
        }
        await ExitConfirmDialog.show(context, isDark: false);
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF6F6F6),
        body: _loading
            ? _buildLoadingState()
            : _buildCurrentTab(),
        // Nav bar har tab pe visible hai — Menu tab pe bhi (pehle wahan
        // hide hota tha, jis se Menu screen orphan lagti thi).
        floatingActionButton: _buildSharedNav(),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      ),
    );
  }

  Widget _buildLoadingState() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
      children: const [
        ShimmerLoading(width: double.infinity, height: 120, borderRadius: BorderRadius.all(Radius.circular(24))),
        SizedBox(height: 20),
        Row(children: [
          Expanded(child: ShimmerLoading(height: 100, borderRadius: BorderRadius.all(Radius.circular(18)))),
          SizedBox(width: 12),
          Expanded(child: ShimmerLoading(height: 100, borderRadius: BorderRadius.all(Radius.circular(18)))),
          SizedBox(width: 12),
          Expanded(child: ShimmerLoading(height: 100, borderRadius: BorderRadius.all(Radius.circular(18)))),
        ]),
        SizedBox(height: 20),
        ShimmerLoading(width: double.infinity, height: 180, borderRadius: BorderRadius.all(Radius.circular(20))),
      ],
    );
  }

  Widget _buildCurrentTab() {
    switch (_currentTab) {
      case 1:
        return BusinessMenuScreen(
          onDataChanged: _loadData,
          onBack: () => setState(() => _currentTab = 0),
        );
      case 2:
        return const BusinessOrdersScreen();
      case 3:
        return const BusinessProfileScreen();
      default:
        return _buildHomeTab();
    }
  }

  // ═══════════════════════════════════════════════════════════
  // HOME TAB — Premium partner dashboard
  // ═══════════════════════════════════════════════════════════
  Widget _buildHomeTab() {
    return FadeTransition(
      opacity: _fadeController,
      child: RefreshIndicator(
        onRefresh: _loadData,
        color: AppColors.orange,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(0, 0, 0, 110),
          children: [
            _buildDashboardHeader(),
            // Stats cards float over the header's curved bottom edge
            Transform.translate(
              offset: const Offset(0, -28),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _buildStatsRow(),
              ),
            ),
            const SizedBox(height: 8),
            if (!_isOpen)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
                child: _buildClosedBanner(),
              ),
            if (_pendingOrders > 0)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: _buildNewOrdersAlert(),
              ),
            const SizedBox(height: 22),
            _buildMenuPreview(),
            const SizedBox(height: 22),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _buildRecentOrders(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardHeader() {
    final statusBarHeight = MediaQuery.of(context).padding.top;
    return AnimatedBuilder(
      animation: _floatController,
      builder: (context, _) {
        return Container(
          width: double.infinity,
          padding: EdgeInsets.fromLTRB(20, statusBarHeight + 12, 20, 44),
          decoration: const BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(32),
              bottomRight: Radius.circular(32),
            ),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  // Floating app icon on a solid white puck — the orange
                  // bike artwork stays visible on the orange header.
                  Transform.translate(
                    offset: Offset(0, sin(_floatController.value * pi) * 3),
                    child: Container(
                      width: 52, height: 52,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withValues(alpha: 0.6), width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(6),
                      child: Image.asset('assets/icon/app_icon.png', fit: BoxFit.contain),
                    ),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Hi, ${(_business?['name'] ?? 'Business').toString().split(' ').first} 👋',
                            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: Colors.white)),
                        const SizedBox(height: 2),
                        Text(_isOpen ? 'Store is open — taking orders' : 'Store is closed',
                            style: TextStyle(fontSize: 12.5, color: Colors.white.withValues(alpha: 0.85))),
                      ],
                    ),
                  ),
                  // Open/Closed pill toggle
                  GestureDetector(
                    onTap: () => _toggleStore(),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: _isOpen ? 0.28 : 0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            width: 8, height: 8,
                            decoration: BoxDecoration(
                              color: _isOpen ? Colors.greenAccent : Colors.white.withValues(alpha: 0.6),
                              shape: BoxShape.circle,
                              boxShadow: _isOpen ? [BoxShadow(color: Colors.greenAccent.withValues(alpha: 0.8), blurRadius: 6)] : [],
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(_isOpen ? 'Open' : 'Closed',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Revenue strip — glass style
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 18),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text('Total Revenue', style: TextStyle(fontSize: 13, color: Colors.white, fontWeight: FontWeight.w600)),
                    ),
                    Text('Rs.${_stats?['totalRevenue']?.toString() ?? '0'}',
                        style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: Colors.white)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _toggleStore() async {
    final newValue = !_isOpen;
    setState(() => _isOpen = newValue);
    try {
      await ApiService.businessUpdateMe({'isOpen': newValue});
      if (mounted) {
        PremiumDialogs.showSuccess(context, newValue ? 'Store is now Open 🎉' : 'Store is now Closed');
      }
    } catch (e) {
      if (mounted) setState(() => _isOpen = !newValue);
    }
  }

  Widget _buildStatsRow() {
    return Row(
      children: [
        _buildStatCard('Orders', '$_todayOrders', Icons.receipt_long_rounded),
        const SizedBox(width: 12),
        _buildStatCard('Pending', '$_pendingOrders', Icons.schedule_rounded, highlight: _pendingOrders > 0),
        const SizedBox(width: 12),
        _buildStatCard('Menu', '${_stats?['menuItems'] ?? 0}', Icons.restaurant_menu_rounded),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, {bool highlight = false}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: highlight ? Border.all(color: AppColors.orange.withValues(alpha: 0.35), width: 1.5) : null,
          boxShadow: [
            BoxShadow(
              color: highlight ? AppColors.orange.withValues(alpha: 0.18) : Colors.black.withValues(alpha: 0.06),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          children: [
            Text(value, style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900, color: highlight ? AppColors.orange : AppColors.black, height: 1)),
            const SizedBox(height: 5),
            Text(label, style: const TextStyle(fontSize: 11, color: AppColors.darkGray, fontWeight: FontWeight.w700, letterSpacing: 0.2)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.orange.withValues(alpha: highlight ? 0.14 : 0.07),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: AppColors.orange, size: 15),
            ),
          ],
        ),
      ),
    );
  }

  /// Amber warning banner shown when the store is closed.
  Widget _buildClosedBanner() {
    return GestureDetector(
      onTap: _toggleStore,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.orangePale.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.orange.withValues(alpha: 0.35)),
        ),
        child: Row(
          children: [
            const Icon(Icons.storefront_rounded, color: AppColors.orange, size: 22),
            const SizedBox(width: 12),
            const Expanded(
              child: Text('Your store is closed — customers can\'t order right now',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.black)),
            ),
            GestureDetector(
              onTap: _toggleStore,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text('Open', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNewOrdersAlert() {
    return GestureDetector(
      onTap: () => setState(() => _currentTab = 2),
      child: AnimatedBuilder(
        animation: _pulseController,
        builder: (context, child) => Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppColors.orange.withValues(alpha: 0.25 + _pulseController.value * 0.2),
                blurRadius: 14 + _pulseController.value * 10,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: child,
        ),
        child: Row(
          children: [
            const Badge(
              backgroundColor: Colors.white,
              label: Text('!', style: TextStyle(color: AppColors.orange, fontWeight: FontWeight.w900)),
              child: Icon(Icons.notifications_active_rounded, color: Colors.white, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$_pendingOrders new order${_pendingOrders > 1 ? 's' : ''} waiting!',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white)),
                  const SizedBox(height: 2),
                  Text('Tap to view incoming orders', style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.85))),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 16),
          ],
        ),
      ),
    );
  }

  // Quick Actions removed — the floating nav bar already covers these
  // (Add Item/Menu → Menu tab, Orders → Orders tab, Profile → Profile tab).

  /// Compact square action tile in the FoodPanda-partner style.
  Widget _buildActionTile(String label, IconData icon, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, 4))],
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(13),
                  boxShadow: [BoxShadow(color: AppColors.orange.withValues(alpha: 0.28), blurRadius: 8, offset: const Offset(0, 3))],
                ),
                child: Icon(icon, color: Colors.white, size: 20),
              ),
              const SizedBox(height: 9),
              Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800), maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuPreview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Your Menu', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              GestureDetector(
                onTap: () => setState(() => _currentTab = 1),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.orange.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text('Manage', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.orange)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (_menuItems.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 12, offset: const Offset(0, 4))],
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: AppColors.orangePale.withValues(alpha: 0.5), shape: BoxShape.circle),
                    child: const Icon(Icons.restaurant_menu_rounded, size: 36, color: AppColors.orange),
                  ),
                  const SizedBox(height: 12),
                  const Text('No menu items yet', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  const Text('Add items so customers can order', style: TextStyle(fontSize: 12, color: AppColors.darkGray)),
                ],
              ),
            ),
          )
        else
          SizedBox(
            height: 168,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: _menuItems.take(8).length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, i) => _buildMenuItemCard(_menuItems[i]),
            ),
          ),
      ],
    );
  }

  /// Horizontal scrolling menu card with food photo, price chip and availability dot.
  Widget _buildMenuItemCard(dynamic item) {
    final isAvailable = item['isAvailable'] ?? true;
    final hasImage = item['imageUrl'] != null && item['imageUrl'].toString().isNotEmpty;
    return GestureDetector(
      onTap: () => setState(() => _currentTab = 1),
      child: Container(
        width: 128,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            Expanded(
              child: Stack(
                children: [
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: hasImage ? null : AppColors.primaryGradient,
                      color: hasImage ? AppColors.orangePale : null,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                    ),
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                      child: hasImage
                          ? Image.network(item['imageUrl'], fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Icon(Icons.restaurant_rounded, color: Colors.white, size: 30))
                          : const Icon(Icons.restaurant_rounded, color: Colors.white, size: 30),
                    ),
                  ),
                  if (!isAvailable)
                    Positioned(
                      top: 8, left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.65),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text('Hidden', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: Colors.white)),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item['name'] ?? '', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, height: 1.1), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Text('Rs.${item['price']}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: AppColors.orange)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentOrders() {
    if (_orders.isEmpty) return const SizedBox.shrink();
    final recent = _orders.take(3).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Recent Orders', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            GestureDetector(
              onTap: () => setState(() => _currentTab = 2),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.orange.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text('View All', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.orange)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...recent.map((order) => _buildOrderRow(order)),
      ],
    );
  }

  Widget _buildOrderRow(dynamic order) {
    final status = (order['status'] ?? 'pending').toString();
    final customer = (order['customerName'] ?? 'Customer').toString();
    final fareRaw = order['fare'];
    final fare = fareRaw != null ? double.tryParse(fareRaw.toString()) ?? 0.0 : 0.0;
    final statusColor = status == 'delivered'
        ? AppColors.statusDelivered
        : status == 'cancelled'
            ? AppColors.darkGray
            : AppColors.orange;
    final statusLabel = status == 'pending'
        ? 'New'
        : status == 'delivered'
            ? 'Delivered'
            : status == 'cancelled'
                ? 'Cancelled'
                : status == 'in_transit'
                    ? 'On the way'
                    : status;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.orange.withValues(alpha: 0.12),
            child: Text(customer.isNotEmpty ? customer[0].toUpperCase() : 'C',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.orange)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(customer, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text('#${(order['id'] ?? '').toString().substring(0, 8).toUpperCase()}',
                    style: const TextStyle(fontSize: 11, color: AppColors.darkGray, letterSpacing: 0.3)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('Rs.${fare.toStringAsFixed(0)}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: AppColors.orange)),
              const SizedBox(height: 3),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
                child: Text(statusLabel, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: statusColor)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // SHARED NAV BAR — same design as customer & rider
  // ═══════════════════════════════════════════════════════════
  Widget _buildSharedNav() {
    return FloatingNavBar(
      currentIndex: _currentTab,
      onTap: (i) {
        setState(() => _currentTab = i);
        if (i == 1 || i == 2) _loadData();
      },
      isBusiness: true,
      notificationCount: _pendingOrders,
    );
  }
}