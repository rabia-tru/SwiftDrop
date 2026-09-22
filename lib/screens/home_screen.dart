import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../theme/app_colors.dart';
import '../utils/order_time.dart';
import '../services/chat_unread_service.dart';
import '../services/rider_order_feed.dart';
import '../widgets/status_badge.dart';
import '../widgets/shimmer_loading.dart';
import '../services/api_service.dart';
import '../services/background_location_service.dart';
import '../services/rider_background_service.dart';
import '../services/location_permission_helper.dart';
import '../services/location_queue_db.dart';
import '../services/push_notification_service.dart';
import '../services/websocket_service.dart';
import '../widgets/premium_dialogs.dart';
import '../widgets/confetti_celebration.dart';
import '../services/battery_optimization_helper.dart';
import '../services/error_helper.dart';
import 'all_orders_screen.dart';
import 'earnings_screen.dart';
import 'main_navigation.dart';
import '../widgets/exit_confirm_dialog.dart';

/// SwiftDrop Rider Home — Premium Dashboard
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  Map<String, dynamic>? _rider;
  bool _loading = true;
  bool _toggling = false;
  int _pendingSyncCount = 0;
  final RiderOrderFeed _feed = RiderOrderFeed.instance;
  late AnimationController _animController;

  StreamSubscription? _newOrderSub;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _loadRider();
    // One shared live feed drives Home, Orders AND Earnings: a single
    // fetch + WebSocket listeners, debounced so bursts of events collapse
    // into one reload.
    _feed.startListening();
    _feed.addListener(_onFeedChanged);
    _feed.refresh();
    _refreshPendingCount();
    _initTracking();
    _listenForNewOrders();
  }

  void _onFeedChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _initTracking() async {
    await PushNotificationService.initialize();
  }

  void _listenForNewOrders() {
    WebSocketService.instance.connect();
    _newOrderSub = WebSocketService.instance.newOrderStream.listen((order) {
      _showNewOrderNotification(order);
      _feed.scheduleRefresh();
    });
    RiderBackgroundService.restoreTrackingState();
  }

  void _showNewOrderNotification(Map<String, dynamic> order) {
    final fare = order['fare'] ?? 0;
    final pickup = order['pickupAddress'] ?? 'Pickup';
    final drop = order['dropAddress'] ?? 'Drop';

    PushNotificationService.showOrderNotification(
      title: '🛵 New Order Available!',
      body: 'Rs.$fare • $pickup → $drop',
      payload: order['orderId'],
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.delivery_dining, color: Colors.white, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('New Order Available!', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white)),
                    const SizedBox(height: 2),
                    Text('Rs.$fare • $pickup → $drop', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
          backgroundColor: AppColors.orange,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'VIEW',
            textColor: Colors.white,
            onPressed: () => _feed.scheduleRefresh(),
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    _newOrderSub?.cancel();
    _animController.dispose();
    _feed.removeListener(_onFeedChanged);
    super.dispose();
  }

  Future<void> _loadRider() async {
    try {
      final rider = await ApiService.getMe();
      if (mounted) setState(() { _rider = rider; _loading = false; });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _refreshPendingCount() async {
    final count = await LocationQueueDb.pendingCount();
    if (mounted) setState(() => _pendingSyncCount = count);
    Future.delayed(const Duration(seconds: 10), () {
      if (mounted) _refreshPendingCount();
    });
  }

  bool get _isOnline => _rider != null && (_rider!['status'] == 'online' || _rider!['status'] == 'on_delivery');

  Future<void> _toggleOnline(bool goOnline) async {
    setState(() => _toggling = true);
    if (goOnline) {
      final permission = await LocationPermissionHelper.requestFullAccess();
      if (!permission.granted) {
        _showSnackBar(permission.message, isError: true);
        setState(() => _toggling = false);
        return;
      }
      await _requestNotificationPermission();
      if (mounted) await _checkBatterySaverMode();
      if (mounted) await _requestBatteryOptimization();
    }
    try {
      await ApiService.updateStatus(goOnline ? 'online' : 'offline');
      if (goOnline) {
        await BackgroundLocationService.start();
        _showSnackBar('You are now online!', isError: false);
      } else {
        await BackgroundLocationService.stop();
        _showSnackBar('You are now offline', isError: false);
      }
      await _loadRider();
    } catch (e) {
      _showSnackBar(e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _toggling = false);
    }
  }

  Future<void> _requestNotificationPermission() async {
    try {
      final androidPlugin = FlutterLocalNotificationsPlugin()
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        final granted = await androidPlugin.requestNotificationsPermission();
        if (granted == false && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: const [
                  Icon(Icons.notifications_off, color: Colors.white, size: 18),
                  SizedBox(width: 12),
                  Expanded(child: Text('Notifications disabled. You won\'t receive order alerts.')),
                ],
              ),
              backgroundColor: AppColors.darkGray,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              margin: const EdgeInsets.all(16),
            ),
          );
        }
      }
    } catch (_) {}
  }

  Future<void> _requestBatteryOptimization() async {
    final batteryOk = await BatteryOptimizationHelper.isIgnoringBatteryOptimizations();
    if (batteryOk) return;

    final confirmed = await PremiumDialogs.showConfirm(
      context,
      title: 'Battery Optimization',
      message: 'To keep tracking your location in the background (even when the app is closed), please disable battery optimization for SwiftDrop.',
      confirmText: 'Allow',
      cancelText: 'Skip',
      icon: Icons.battery_saver_rounded,
    );

    if (confirmed == true && mounted) {
      final result = await BatteryOptimizationHelper.requestIgnoreBatteryOptimizations();
      if (mounted) {        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(result ? Icons.check_circle : Icons.info, color: Colors.white, size: 18),
                const SizedBox(width: 12),
                Expanded(child: Text(result ? 'Battery optimization disabled!' : 'You can enable this later in Tracking Settings', maxLines: 2, overflow: TextOverflow.ellipsis)),
              ],
            ),
            backgroundColor: result ? AppColors.orange : AppColors.darkGray,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    }
  }

  /// Battery Saver mode check — if ON, background GPS gets throttled by
  /// Android and tracking will stutter. Ask the rider to turn it off first.
  Future<void> _checkBatterySaverMode() async {
    try {
      final powerSaveOn = await BatteryOptimizationHelper.isPowerSaveModeOn();
      if (!powerSaveOn || !mounted) return;

      final turnOff = await PremiumDialogs.showConfirm(
        context,
        title: 'Battery Saver is ON',
        message: 'Battery Saver mode blocks background location updates, so your live tracking will stop working while it is on. Turn it off for reliable tracking?',
        confirmText: 'Turn Off',
        cancelText: 'Continue Anyway',
        icon: Icons.battery_alert_rounded,
      );

      if (turnOff == true) {
        await BatteryOptimizationHelper.openBatterySaverSettings();
      }
    } catch (_) {
      // Non-fatal — tracking can still work with saver on, just degraded.
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    if (isError) {
      PremiumDialogs.showError(context, message);
    } else {
      PremiumDialogs.showSuccess(context, message);
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
    return PopScope(
      // Rider home root screen hai — BACK dabane par pehle exit-confirmation
      // aata hai; app kabhi silently exit nahi hota aur Role Selection pe
      // wapas bhi nahi jata.
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await ExitConfirmDialog.show(context, isDark: isDark);
      },
      child: _buildBody(isDark, bgColor, cardColor, textColor, subTextColor),
    );
  }

  Widget _buildBody(bool isDark, Color bgColor, Color cardColor, Color textColor, Color subTextColor) {
    if (_loading) {
      return Scaffold(
        backgroundColor: bgColor,
        body: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          children: [
            const SizedBox(height: 16),
            // Shimmer header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: const [
                  ShimmerLoading(width: 50, height: 50, borderRadius: BorderRadius.all(Radius.circular(25))),
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ShimmerLoading(width: 140, height: 18, borderRadius: BorderRadius.all(Radius.circular(9))),
                        SizedBox(height: 8),
                        ShimmerLoading(width: 70, height: 14, borderRadius: BorderRadius.all(Radius.circular(7))),
                      ],
                    ),
                  ),
                  ShimmerLoading(width: 42, height: 42, borderRadius: BorderRadius.all(Radius.circular(14))),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Shimmer status card
            ShimmerLoading(width: double.infinity, height: 160, borderRadius: BorderRadius.circular(16)),
            const SizedBox(height: 16),
            // Shimmer stepper
            ShimmerLoading(width: double.infinity, height: 100, borderRadius: BorderRadius.circular(16)),
            const SizedBox(height: 16),
            // Shimmer quick actions
            Row(
              children: const [
                Expanded(child: ShimmerLoading(height: 100, borderRadius: BorderRadius.all(Radius.circular(16)))),
                SizedBox(width: 12),
                Expanded(child: ShimmerLoading(height: 100, borderRadius: BorderRadius.all(Radius.circular(16)))),
              ],
            ),
          ],
        ),
      );
    }

    final statusBarHeight = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          onRefresh: () async {
            await _loadRider();
            await _feed.refresh(force: true);
          },
          color: AppColors.orange,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: statusBarHeight + 16),
                _buildHeader(textColor, subTextColor, statusBarHeight),
                const SizedBox(height: 16),
                _buildTodayStrip(cardColor, textColor, subTextColor),
                const SizedBox(height: 16),
                _buildStatusCard(cardColor, textColor, subTextColor),
                const SizedBox(height: 16),
                _buildOrderFeedSection(cardColor, textColor, subTextColor),
                const SizedBox(height: 16),
                _buildQuickActions(cardColor, textColor, subTextColor),
                if (_pendingSyncCount > 0) ...[
                  const SizedBox(height: 16),
                  _buildPendingSyncCard(cardColor, textColor),
                ],
                const SizedBox(height: 16),
                _buildInfoSection(cardColor, textColor, subTextColor),
                const SizedBox(height: 100),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(Color textColor, Color subTextColor, double statusBarHeight) {
    final name = _rider?['name']?.split(' ').first ?? 'Rider';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: AppColors.orange.withValues(alpha: 0.08), blurRadius: 16, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          // Avatar with gradient border
          Container(
            width: 50, height: 50,
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              shape: BoxShape.circle,
            ),
            child: Container(
              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
              child: const Icon(Icons.person_rounded, color: AppColors.orange, size: 24),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Hello, $name!', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: textColor)),
                const SizedBox(height: 4),
                StatusBadge(status: _isOnline ? 'online' : 'offline'),
              ],
            ),
          ),
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
              color: AppColors.orangePale.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                const Icon(Icons.notifications_none_rounded, color: AppColors.orange, size: 22),
                if (_pendingSyncCount > 0)
                  Positioned(
                    top: 6, right: 6,
                    child: Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFFE53935), shape: BoxShape.circle)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard(Color cardColor, Color textColor, Color subTextColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: _cardDecoration(cardColor),
      child: Column(
        children: [
          Text('RIDER STATUS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: subTextColor, letterSpacing: 1)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: _isOnline ? AppColors.orange : AppColors.lightGray,
              borderRadius: BorderRadius.circular(9999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(_isOnline ? Icons.check_circle : Icons.power_settings_new, size: 16, color: _isOnline ? Colors.white : AppColors.darkGray),
                const SizedBox(width: 8),
                Text(_isOnline ? 'Online & Tracking' : 'Offline', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _isOnline ? Colors.white : AppColors.darkGray)),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 48, width: double.infinity,
            child: ElevatedButton(
              onPressed: _toggling ? null : () => _toggleOnline(!_isOnline),
              style: ElevatedButton.styleFrom(
                backgroundColor: _isOnline ? AppColors.orangeDark : AppColors.orange,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: _toggling
                  ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2.5, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))
                  : Text(_isOnline ? 'Go Offline' : 'Go Online', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }  /// Compact today strip: earnings + deliveries, sourced from the shared
  /// live feed — same numbers the Earnings tab shows.
  Widget _buildTodayStrip(Color cardColor, Color textColor, Color subTextColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: AppColors.orange.withValues(alpha: 0.25), blurRadius: 12, offset: const Offset(0, 6))],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('TODAY', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white.withValues(alpha: 0.8), letterSpacing: 1.2)),
                const SizedBox(height: 4),
                Text('Rs.${_feed.todayEarnings.toStringAsFixed(0)}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white)),
                Text('${_feed.todayDeliveries} delivered today', style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.8))),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => _switchToTab(2, const EarningsScreen()),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12)),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 18),
                  SizedBox(width: 6),
                  Text('Earnings', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Live order feed: assigned (needs action) + active (accepted → in
  /// transit) deliveries, driven by the shared RiderOrderFeed. Updates
  /// arrive over WebSocket without leaving this screen.
  Widget _buildOrderFeedSection(Color cardColor, Color textColor, Color subTextColor) {
    final assigned = _feed.assignedOrders;
    final active = _feed.activeOrders;

    if (_feed.loading && !_feed.loadedOnce) {
      return _cardShell(
        cardColor,
        const Column(children: [OrderCardSkeleton(), SizedBox(height: 12), OrderCardSkeleton()]),
      );
    }
    if (_feed.error != null && _feed.orders.isEmpty) {
      return _cardShell(cardColor, _buildFeedError(subTextColor));
    }
    if (assigned.isEmpty && active.isEmpty) {
      return _cardShell(cardColor, _buildFeedEmpty(textColor, subTextColor));
    }

    return ListenableBuilder(
      listenable: ChatUnreadService.instance,
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: AppColors.orangePale, borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.local_shipping_rounded, color: AppColors.orange, size: 18),
              ),
              const SizedBox(width: 10),
              Text('Orders (${assigned.length + active.length})', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: textColor)),
              const Spacer(),
              GestureDetector(
                onTap: () => _switchToTab(1, const AllOrdersScreen()),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('View all', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.orange)),
                    SizedBox(width: 2),
                    Icon(Icons.chevron_right_rounded, size: 16, color: AppColors.orange),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...assigned.map((o) => _buildLiveOrderCard(o, cardColor, textColor, subTextColor)),
          ...active.map((o) => _buildLiveOrderCard(o, cardColor, textColor, subTextColor)),
        ],
      ),
    );
  }

  Widget _cardShell(Color cardColor, Widget child) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(cardColor),
      child: child,
    );
  }

  Widget _buildFeedEmpty(Color textColor, Color subTextColor) {
    return Column(
      children: [
        Container(
          width: 64, height: 64,
          decoration: const BoxDecoration(color: AppColors.orangePale, shape: BoxShape.circle),
          child: const Icon(Icons.delivery_dining_rounded, size: 32, color: AppColors.orange),
        ),
        const SizedBox(height: 12),
        Text('No orders yet', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: textColor)),
        const SizedBox(height: 4),
        Text('New deliveries assigned to you appear here live', style: TextStyle(fontSize: 12, color: subTextColor), textAlign: TextAlign.center),
      ],
    );
  }

  Widget _buildFeedError(Color subTextColor) {
    return Column(
      children: [
        const Icon(Icons.wifi_off_rounded, size: 36, color: AppColors.orange),
        const SizedBox(height: 10),
        Text(_feed.error ?? 'Something went wrong', style: TextStyle(fontSize: 13, color: subTextColor), textAlign: TextAlign.center),
        const SizedBox(height: 10),
        TextButton.icon(
          onPressed: () => _feed.refresh(force: true),
          icon: const Icon(Icons.refresh_rounded, size: 16),
          label: const Text('Retry'),
          style: TextButton.styleFrom(foregroundColor: AppColors.orange),
        ),
      ],
    );
  }

  double _fareOf(dynamic o) => double.tryParse((o['fare'] ?? '0').toString()) ?? 0;

  static const Map<String, String> _nextStatus = {
    'assigned': 'accepted',
    'accepted': 'picked_up',
    'picked_up': 'in_transit',
    'in_transit': 'delivered',
  };

  static const Map<String, String> _nextActionLabel = {
    'assigned': 'Accept Order',
    'accepted': 'Mark Picked Up',
    'picked_up': 'Start Delivery',
    'in_transit': 'Mark Delivered',
  };

  static const Map<String, IconData> _nextActionIcon = {
    'assigned': Icons.check_circle_outline,
    'accepted': Icons.shopping_bag_outlined,
    'picked_up': Icons.local_shipping_rounded,
    'in_transit': Icons.task_alt_rounded,
  };

  /// A real order card: business, items, addresses, progress stepper and
  /// the single next action for its status.
  Widget _buildLiveOrderCard(dynamic order, Color cardColor, Color textColor, Color subTextColor) {
    final orderId = (order['id'] ?? '').toString();
    final status = (order['status'] ?? 'assigned').toString();
    final businessName = (order['businessName'] ?? 'Order').toString();
    final items = (order['items'] as List?) ?? const [];
    final unreadChats = ChatUnreadService.instance.unreadsFor(orderId);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration(cardColor),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: business + order id + unread chats + status badge
          Row(
            children: [
              Container(
                width: 42, height: 42,
                decoration: BoxDecoration(gradient: AppColors.primaryGradient, borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.storefront_rounded, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(businessName, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: textColor)),
                    const SizedBox(height: 2),
                    Text(
                      'Order #${orderId.length > 8 ? orderId.substring(0, 8) : orderId}'
                      '${formatOrderTimeAgo(order['createdAt']).isNotEmpty ? '  •  ${formatOrderTimeAgo(order['createdAt'])}' : ''}',
                      style: TextStyle(fontSize: 11, color: subTextColor),
                    ),
                  ],
                ),
              ),
              if (unreadChats > 0)
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: AppColors.orange, borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.chat_bubble_rounded, size: 12, color: Colors.white),
                      const SizedBox(width: 4),
                      Text('$unreadChats', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
                    ],
                  ),
                ),
              StatusBadge(status: status),
            ],
          ),
          // Row 2: item summary from the order snapshot
          if (items.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              '${items.map((i) => '${(i['name'] ?? 'Item')} × ${i['quantity'] ?? 1}').take(3).join(', ')}'
              '${items.length > 3 ? '  +${items.length - 3} more' : ''}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: subTextColor),
            ),
          ],
          // Row 3: pickup → drop
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: AppColors.orangePale.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(10)),
            child: Column(
              children: [
                Row(children: [
                  Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppColors.orange, shape: BoxShape.circle)),
                  const SizedBox(width: 8),
                  Expanded(child: Text((order['pickupAddress'] ?? 'Pickup').toString(), style: TextStyle(fontSize: 13, color: textColor), maxLines: 1, overflow: TextOverflow.ellipsis)),
                ]),
                const SizedBox(height: 6),
                Row(children: [
                  Container(width: 8, height: 8, decoration: BoxDecoration(color: AppColors.orangeDark, borderRadius: BorderRadius.circular(2))),
                  const SizedBox(width: 8),
                  Expanded(child: Text((order['dropAddress'] ?? 'Drop').toString(), style: TextStyle(fontSize: 13, color: textColor), maxLines: 1, overflow: TextOverflow.ellipsis)),
                ]),
              ],
            ),
          ),
          // Row 4: progress dots
          const SizedBox(height: 12),
          _buildStatusStepper(status),
          const SizedBox(height: 12),
          Row(
            children: [
              Text('Fare', style: TextStyle(fontSize: 12, color: subTextColor)),
              const Spacer(),
              Text('Rs.${_fareOf(order).toStringAsFixed(0)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.orange)),
            ],
          ),
          // Row 5: the single next action for this status
          const SizedBox(height: 10),
          _buildNextAction(order, status, _feed.isUpdating(orderId)),
        ],
      ),
    );
  }

  /// 4-step progress: Accepted → Picked Up → In Transit → Delivered.
  Widget _buildStatusStepper(String status) {
    final stepIndex = switch (status) {
      'accepted' => 1,
      'picked_up' => 2,
      'in_transit' => 3,
      'delivered' => 4,
      _ => 0, // assigned & anything else
    };
    return Row(
      children: List.generate(4 * 2 - 1, (i) {
        if (i.isOdd) {
          return Expanded(child: Container(height: 2, color: (i ~/ 2) < stepIndex ? AppColors.orange : AppColors.gray));
        }
        final s = i ~/ 2;
        final done = s < stepIndex;
        final current = s == stepIndex;
        return Container(
          width: 22, height: 22,
          decoration: BoxDecoration(
            color: done || current ? AppColors.orange : AppColors.lightGray,
            shape: BoxShape.circle,
          ),
          child: done
              ? const Icon(Icons.check, size: 14, color: Colors.white)
              : Center(
                  child: Text('${s + 1}', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: current ? Colors.white : AppColors.darkGray)),
                ),
        );
      }),
    );
  }

  Widget _buildNextAction(dynamic order, String status, bool isUpdating) {
    final next = _nextStatus[status];
    if (next == null) return const SizedBox.shrink();
    return SizedBox(
      width: double.infinity,
      height: 44,
      child: ElevatedButton.icon(
        onPressed: isUpdating ? null : () => _advanceOrder(order, next),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.orange,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.orange.withValues(alpha: 0.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
        ),
        icon: isUpdating
            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
            : Icon(_nextActionIcon[status] ?? Icons.arrow_forward_rounded, size: 18),
        label: Text(_nextActionLabel[status] ?? next, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
      ),
    );
  }

  /// Single handler for advancing a delivery from the Home cards: confirms
  /// commitments, calls the API, starts/stops GPS tracking, moves the card
  /// optimistically and lets the shared feed confirm from the server.
  Future<void> _advanceOrder(dynamic order, String nextStatus) async {
    final orderId = (order['id'] ?? '').toString();
    if (nextStatus == 'accepted') {
      final confirmed = await PremiumDialogs.showConfirm(
        context,
        title: 'Accept Order?',
        message: 'Pickup: ${order['pickupAddress'] ?? 'Restaurant'}\nDrop: ${order['dropAddress'] ?? 'Customer'}\nFare: Rs.${order['fare'] ?? 0}',
        confirmText: 'Accept',
        icon: Icons.local_shipping_rounded,
      );
      if (!confirmed || !mounted) return;
    }
    if (nextStatus == 'delivered') {
      final confirmed = await PremiumDialogs.showConfirm(
        context,
        title: 'Mark as Delivered?',
        message: 'Confirm the customer received their order.\nFare earned: Rs.${order['fare'] ?? 0}',
        confirmText: 'Delivered',
        icon: Icons.task_alt_rounded,
      );
      if (!confirmed || !mounted) return;
    }
    _feed.markUpdating(orderId, true);
    try {
      await ApiService.updateOrderStatus(orderId, nextStatus);
      _feed.applyLocalStatus(orderId, nextStatus);

      if (nextStatus == 'accepted' || nextStatus == 'picked_up') {
        await RiderBackgroundService.startTracking(orderId: orderId);
        await BackgroundLocationService.setCurrentOrder(orderId);
      }
      if (nextStatus == 'delivered' || nextStatus == 'cancelled') {
        await RiderBackgroundService.stopTracking();
        await BackgroundLocationService.setCurrentOrder(null);
      }
      if (nextStatus == 'delivered') {
        await PushNotificationService.showOrderNotification(
          title: '🎉 Delivery Complete!',
          body: 'Rs.${order['fare'] ?? 0} added to your earnings. Great job!',
          payload: orderId,
        );
      }
      if (mounted) {
        if (nextStatus == 'delivered') {
          showDialog(
            context: context,
            barrierDismissible: true,
            builder: (dialogContext) => DeliveryCelebrationDialog(
              orderId: orderId,
              onContinue: () => Navigator.of(dialogContext).pop(),
              onRateNow: () => Navigator.of(dialogContext).pop(),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(nextStatus == 'accepted' ? 'Order accepted!' : 'Status updated!'),
              backgroundColor: AppColors.orange,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              margin: const EdgeInsets.all(16),
            ),
          );
        }
      }
      _feed.scheduleRefresh();
    } catch (e) {
      if (mounted) PremiumDialogs.showError(context, ErrorHelper.getMessage(e));
    } finally {
      _feed.markUpdating(orderId, false);
    }
  }

  /// Switches the rider bottom-nav to a tab via MainNavigation's global key.
  /// Falls back to pushing the screen directly when Home is opened outside
  /// the shell (e.g. deep-links).
  void _switchToTab(int index, Widget fallback) {
    final navState = MainNavigation.navKey.currentState;
    if (navState != null && navState.mounted) {
      navState.switchToTab(index);
      return;
    }
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => fallback));
  }

  Widget _buildQuickActions(Color cardColor, Color textColor, Color subTextColor) {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () => _switchToTab(1, const AllOrdersScreen()),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: _cardDecoration(cardColor),
              child: Column(
                children: [
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft, end: Alignment.bottomRight,
                        colors: [AppColors.orange.withValues(alpha: 0.15), AppColors.orangePale.withValues(alpha: 0.4)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.receipt_long, color: AppColors.orange, size: 24),
                  ),
                  const SizedBox(height: 10),
                  Text('All Orders', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textColor)),
                  const SizedBox(height: 2),
                  Text('Search & filter', style: TextStyle(fontSize: 11, color: subTextColor)),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: GestureDetector(
            onTap: () => _switchToTab(2, const EarningsScreen()),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: _cardDecoration(cardColor),
              child: Column(
                children: [
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft, end: Alignment.bottomRight,
                        colors: [AppColors.orange.withValues(alpha: 0.15), AppColors.orangePale.withValues(alpha: 0.4)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.account_balance_wallet, color: AppColors.orange, size: 24),
                  ),
                  const SizedBox(height: 10),
                  Text('Earnings', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textColor)),
                  const SizedBox(height: 2),
                  Text('View payments', style: TextStyle(fontSize: 11, color: subTextColor)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPendingSyncCard(Color cardColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.orangePale, borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          const Icon(Icons.cloud_queue, color: AppColors.orange, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$_pendingSyncCount location(s) queued', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textColor)),
                const SizedBox(height: 2),
                const Text('Will upload automatically', style: TextStyle(fontSize: 12, color: AppColors.darkGray)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection(Color cardColor, Color textColor, Color subTextColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(cardColor),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline, color: AppColors.orange, size: 18),
              const SizedBox(width: 8),
              Text('How Tracking Works', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: textColor)),
            ],
          ),
          const SizedBox(height: 16),
          _buildInfoItem(icon: Icons.check_circle_outline, text: 'Go online to start GPS tracking', subTextColor: subTextColor),
          const SizedBox(height: 10),
          _buildInfoItem(icon: Icons.sync, text: 'Location syncs every 30 seconds', subTextColor: subTextColor),
          const SizedBox(height: 10),
          _buildInfoItem(icon: Icons.phone_android, text: 'Works even when app is closed', subTextColor: subTextColor),
          const SizedBox(height: 10),
          _buildInfoItem(icon: Icons.cloud_queue, text: 'Offline data syncs automatically', subTextColor: subTextColor),
        ],
      ),
    );
  }

  Widget _buildInfoItem({required IconData icon, required String text, required Color subTextColor}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.orange, size: 16),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: TextStyle(fontSize: 14, color: subTextColor))),
      ],
    );
  }

  BoxDecoration _cardDecoration(Color cardColor) {
    return BoxDecoration(
      color: cardColor,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(color: AppColors.orange.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, 4)),
      ],
    );
  }
}
