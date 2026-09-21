import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:provider/provider.dart';
import '../theme/app_colors.dart';
import '../widgets/status_badge.dart';
import '../widgets/shimmer_loading.dart';
import '../services/api_service.dart';
import '../services/background_location_service.dart';
import '../services/rider_background_service.dart';
import '../services/location_permission_helper.dart';
import '../services/location_queue_db.dart';
import '../services/realtime_order_tracker.dart';
import '../services/push_notification_service.dart';
import '../services/websocket_service.dart';
import '../widgets/premium_dialogs.dart';
import '../services/battery_optimization_helper.dart';
import '../services/error_helper.dart';
import 'all_orders_screen.dart';
import 'earnings_screen.dart';
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
  List<dynamic> _pendingOrders = [];
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
    _loadPendingOrders();
    _refreshPendingCount();
    _initTracking();
    _listenForNewOrders();
  }

  Future<void> _initTracking() async {
    await PushNotificationService.initialize();
  }

  void _listenForNewOrders() {
    WebSocketService.instance.connect();
    _newOrderSub = WebSocketService.instance.newOrderStream.listen((order) {
      _showNewOrderNotification(order);
      _loadPendingOrders();
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
            onPressed: () => _loadPendingOrders(),
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    _newOrderSub?.cancel();
    _animController.dispose();
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

  Future<void> _loadPendingOrders() async {
    try {
      final orders = await ApiService.getMyOrders();
      final pending = orders.where((o) =>
        o['status'] == 'assigned' || o['status'] == 'accepted'
      ).toList();
      if (mounted) setState(() => _pendingOrders = pending);
    } catch (_) {}
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
          onRefresh: _loadRider,
          color: AppColors.orange,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: statusBarHeight + 16),
                _buildHeader(textColor, subTextColor, statusBarHeight),
                const SizedBox(height: 20),
                _buildStatusCard(cardColor, textColor, subTextColor),
                const SizedBox(height: 16),
                _buildProgressStepper(cardColor, textColor, subTextColor),
                const SizedBox(height: 16),
                _buildActiveOrders(cardColor, textColor, subTextColor),
                if (_pendingOrders.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _buildPendingOrdersSection(cardColor, textColor, subTextColor),
                ],
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
  }

  Widget _buildProgressStepper(Color cardColor, Color textColor, Color subTextColor) {
    final steps = [
      {'label': 'Offline', 'icon': Icons.power_settings_new, 'active': !_isOnline},
      {'label': 'Tracking', 'icon': Icons.gps_fixed, 'active': _isOnline},
      {'label': 'Delivering', 'icon': Icons.local_shipping, 'active': _rider?['status'] == 'on_delivery'},
    ];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(cardColor),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Quick Status', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: textColor)),
          const SizedBox(height: 20),
          Row(
            children: List.generate(steps.length * 2 - 1, (index) {
              if (index.isOdd) {
                final isActive = steps[index ~/ 2]['active'] as bool;
                return Expanded(child: Container(height: 2, color: isActive ? AppColors.orange : AppColors.gray));
              }
              final step = steps[index ~/ 2];
              final isActive = step['active'] as bool;
              return Column(
                children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: isActive ? AppColors.orange : AppColors.lightGray,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(step['icon'] as IconData, size: 20, color: isActive ? Colors.white : AppColors.darkGray),
                  ),
                  const SizedBox(height: 8),
                  Text(step['label'] as String, style: TextStyle(fontSize: 10, fontWeight: isActive ? FontWeight.w700 : FontWeight.w500, color: isActive ? textColor : subTextColor)),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveOrders(Color cardColor, Color textColor, Color subTextColor) {
    return Consumer<RealtimeOrderTracker>(
      builder: (context, tracker, child) {
        if (!tracker.isTracking || tracker.order == null) return const SizedBox.shrink();
        final order = tracker.order!;
        final status = order['status'] ?? 'pending';

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: AppColors.orange.withValues(alpha: 0.3), blurRadius: 15, offset: const Offset(0, 8))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.local_shipping, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(child: Text('Active Delivery', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700))),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12)),
                    child: Text(status.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: tracker.statusProgress,
                  backgroundColor: Colors.white.withValues(alpha: 0.3),
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                  minHeight: 6,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Order #${(order['id'] ?? '').toString().substring(0, 8)}', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                  Text('${order['dropAddress'] ?? 'Delivery'}', style: const TextStyle(color: Colors.white70, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPendingOrdersSection(Color cardColor, Color textColor, Color subTextColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(cardColor),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: AppColors.orangePale, borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.pending_actions, color: AppColors.orange, size: 18),
              ),
              const SizedBox(width: 10),
              Text('Pending Orders (${_pendingOrders.length})', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: textColor)),
            ],
          ),
          const SizedBox(height: 12),
          ..._pendingOrders.take(5).map((order) => _buildPendingOrderItem(order, textColor, subTextColor)),
        ],
      ),
    );
  }

  Widget _buildPendingOrderItem(dynamic order, Color textColor, Color subTextColor) {
    final status = order['status'] ?? 'assigned';
    final customerName = order['customerName'] ?? 'Customer';
    final pickup = order['pickupAddress'] ?? 'Pickup';
    final drop = order['dropAddress'] ?? 'Drop';
    final fare = double.tryParse((order['fare'] ?? '0').toString()) ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.orangePale.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(child: Text(customerName, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textColor))),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: status == 'assigned' ? AppColors.lightGray : AppColors.orange,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(status.toUpperCase(), style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: status == 'assigned' ? AppColors.darkGray : Colors.white)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text('$pickup → $drop', style: TextStyle(fontSize: 12, color: subTextColor), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text('Rs.${fare.toStringAsFixed(0)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.orange)),
              ],
            ),
          ),
          if (status == 'assigned')
            ElevatedButton(
              onPressed: () async {
                // Accepting is a commitment — confirm first and show the
                // route + fare so the rider knows what they're taking on.
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
                try {
                  await ApiService.updateOrderStatus(order['id'], 'accepted');
                  // Link GPS pings to this order so customers see live location
                  await BackgroundLocationService.setCurrentOrder(order['id']?.toString());
                  // Start background order tracking (status notifications even
                  // when the app is killed) — same as the Orders screen does.
                  await RiderBackgroundService.startTracking(orderId: order['id']?.toString());
                  _loadPendingOrders();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Row(children: [Icon(Icons.check_circle, color: Colors.white, size: 18), SizedBox(width: 12), Text('Order accepted!')]),
                        backgroundColor: AppColors.orange,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        margin: const EdgeInsets.all(16),
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) PremiumDialogs.showError(context, ErrorHelper.getMessage(e));
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.orange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                minimumSize: Size.zero,
              ),
              child: const Text('Accept', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
            ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(Color cardColor, Color textColor, Color subTextColor) {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AllOrdersScreen())),
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
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const EarningsScreen())),
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
