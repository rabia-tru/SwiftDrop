import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';
import '../utils/safe_parse.dart';
import '../services/api_service.dart';
import '../services/error_helper.dart';
import '../services/eta_calculator.dart';
import '../services/websocket_service.dart';
import '../services/customer_background_service.dart';
import '../widgets/confetti_celebration.dart';
import 'map_screen.dart';
import 'order_rating_screen.dart';
import 'chat_screen.dart';

/// SwiftDrop Track Order — Real-time tracking with backend data
class TrackOrderScreen extends StatefulWidget {
  final Map<String, dynamic> order;

  const TrackOrderScreen({super.key, required this.order});

  @override
  State<TrackOrderScreen> createState() => _TrackOrderScreenState();
}

class _TrackOrderScreenState extends State<TrackOrderScreen> {
  int _currentIndex = 0;
  late Map<String, dynamic> _order;
  StreamSubscription? _orderStatusSub;

  @override
  void initState() {
    super.initState();
    _order = Map<String, dynamic>.from(widget.order);
    _flattenRiderData();
    _setupWebSocket();
  }

  @override
  void dispose() {
    _orderStatusSub?.cancel();
    super.dispose();
  }

  void _setupWebSocket() {
    final ws = WebSocketService.instance;
    final orderId = _order['id']?.toString();
    if (orderId != null) {
      // This screen can be opened before another customer screen has
      // initialized the shared socket connection.
      ws.connect();
      ws.watchOrder(orderId);
      _orderStatusSub = ws.orderStatusStream.listen((data) {
        if (!mounted) return;
        if (data['orderId']?.toString() == orderId || data['id']?.toString() == orderId) {
          setState(() {
            if (data['status'] != null) _order['status'] = data['status'];
            if (data['riderLat'] != null) _order['riderLat'] = data['riderLat'];
            if (data['riderLng'] != null) _order['riderLng'] = data['riderLng'];
            if (data['riderName'] != null) _order['riderName'] = data['riderName'];
          });
        }
      });
    }
  }

  /// Flattens the backend's nested `rider: {...}` object into the flat
  /// riderName/riderLat/riderLng fields this screen reads.
  void _flattenRiderData() {
    final rider = _order['rider'];
    if (rider is Map) {
      _order['riderName'] ??= rider['name'];
      _order['riderPhone'] ??= rider['phone'];
      _order['riderLat'] ??= rider['lastKnownLat'];
      _order['riderLng'] ??= rider['lastKnownLng'];
    }
  }

  // Same visual language as FloatingNavBar (the main Home/Orders/.../Profile
  // nav) — white pill, orange-gradient pill on the active tab, label only
  // shown when selected — so this in-screen tab bar doesn't look like a
  // different app from the rest of SwiftDrop.
  Widget _buildNavItem(int index, IconData outlineIcon, IconData filledIcon, String label, Color navIconColor) {
    final isSelected = _currentIndex == index;
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() => _currentIndex = index);
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOutCubic,
        padding: EdgeInsets.symmetric(horizontal: isSelected ? 14 : 8, vertical: 10),
        decoration: BoxDecoration(
          gradient: isSelected ? AppColors.primaryGradient : null,
          borderRadius: BorderRadius.circular(16),
          boxShadow: isSelected
              ? [BoxShadow(color: AppColors.orange.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 3))]
              : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(isSelected ? filledIcon : outlineIcon, size: 22, color: isSelected ? Colors.white : navIconColor),
            if (isSelected) ...[
              const SizedBox(width: 8),
              Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final navBg = isDark ? const Color(0xFF121212) : Colors.white;
    final navIconColor = isDark ? const Color(0xFFB0B0B0) : AppColors.darkGray;
    AppColors.setLightStatusBar();

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0A0A) : AppColors.offWhite,
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios, color: AppColors.orange, size: 20), onPressed: () => Navigator.of(context).pop()),
        title: const Text('Track Order', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.orange)),
        centerTitle: true,
        backgroundColor: navBg,
        elevation: 0,
        actions: [
          // Chat button - only show if rider is assigned
          if (_order['riderName'] != null && _order['status'] != 'delivered' && _order['status'] != 'cancelled')
            IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.orangePale,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.chat_bubble_outline, color: AppColors.orange, size: 20),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChatScreen(
                      orderId: _order['id']?.toString() ?? '',
                      otherUserName: _order['riderName'] ?? 'Rider',
                      otherUserRole: 'rider',
                      currentUserRole: 'customer',
                    ),
                  ),
                );
              },
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _OrderStatusTab(order: _order),
          _OrderMapTab(order: _order),
          _OrderDetailsTab(order: _order),
          _OrderHistoryTab(order: _order),
        ],
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: Container(
          height: 70,
          decoration: BoxDecoration(
            color: navBg,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 24, offset: const Offset(0, 8)),
              BoxShadow(color: AppColors.orange.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, 2)),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildNavItem(0, Icons.speed_outlined, Icons.speed, 'Status', navIconColor),
              _buildNavItem(1, Icons.map_outlined, Icons.map, 'Map', navIconColor),
              _buildNavItem(2, Icons.receipt_long_outlined, Icons.receipt_long, 'Details', navIconColor),
              _buildNavItem(3, Icons.history_outlined, Icons.history, 'History', navIconColor),
            ],
          ),
        ),
      ),
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// TAB 1: STATUS — Live ETA Countdown
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
class _OrderStatusTab extends StatefulWidget {
  final Map<String, dynamic> order;
  const _OrderStatusTab({required this.order});
  @override
  State<_OrderStatusTab> createState() => _OrderStatusTabState();
}

class _OrderStatusTabState extends State<_OrderStatusTab> {
  Timer? _countdownTimer;
  int _remainingSeconds = 300;
  double? _riderLat;
  double? _riderLng;
  StreamSubscription? _riderLocationSub;

  @override
  void initState() {
    super.initState();
    _startCountdown();
    _setupRiderTracking();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _riderLocationSub?.cancel();
    super.dispose();
  }

  void _startCountdown() async {
    final savedEta = await CustomerBackgroundService.getRemainingEta();
    if (savedEta != null && savedEta > 0) {
      _remainingSeconds = savedEta;
    } else {
      final riderLat = SafeParse.toDouble(widget.order['riderLat']);
      final riderLng = SafeParse.toDouble(widget.order['riderLng']);
      final dropLat = SafeParse.toDouble(widget.order['dropLat'], 31.47);
      final dropLng = SafeParse.toDouble(widget.order['dropLng'], 74.42);

      if (riderLat != null && riderLng != null) {
        final eta = EtaCalculator.getEtaInfo(riderLat: riderLat, riderLng: riderLng, destinationLat: dropLat, destinationLng: dropLng);
        _remainingSeconds = eta.etaMinutes * 60;
        _riderLat = riderLat;
        _riderLng = riderLng;
      }
    }
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted && _remainingSeconds > 0) setState(() => _remainingSeconds--);
    });
  }

  void _setupRiderTracking() {
    final ws = WebSocketService.instance;
    _riderLocationSub = ws.riderLocationStream.listen((data) {
      if (!mounted) return;
      if (data['orderId'] != null && data['orderId'].toString() != widget.order['id']?.toString()) return;

      final lat = data['latitude'] as num?;
      final lng = data['longitude'] as num?;
      if (lat != null && lng != null) {
        final dropLat = SafeParse.toDouble(widget.order['dropLat'], 31.47);
        final dropLng = SafeParse.toDouble(widget.order['dropLng'], 74.42);
        final eta = EtaCalculator.getEtaInfo(riderLat: lat.toDouble(), riderLng: lng.toDouble(), destinationLat: dropLat, destinationLng: dropLng);

        setState(() {
          _riderLat = lat.toDouble();
          _riderLng = lng.toDouble();
          _remainingSeconds = eta.etaMinutes * 60;
        });
      }
    });
  }

  String get _formattedTime {
    final minutes = _remainingSeconds ~/ 60;
    final seconds = _remainingSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String get _statusLabel {
    switch (widget.order['status'] ?? 'pending') {
      case 'pending': return 'Waiting for rider...';
      case 'assigned': return 'Rider assigned — heading to pickup';
      case 'accepted': return 'Rider heading to restaurant';
      case 'picked_up': return 'Order picked up — on the way!';
      case 'in_transit': return 'Arriving soon!';
      case 'delivered': return 'Delivered! 🎉';
      default: return 'Processing...';
    }
  }

  IconData get _statusIcon {
    switch (widget.order['status'] ?? 'pending') {
      case 'pending': return Icons.hourglass_empty;
      case 'assigned': return Icons.person_pin;
      case 'accepted': return Icons.motorcycle;
      case 'picked_up': return Icons.local_shipping;
      case 'in_transit': return Icons.navigation;
      case 'delivered': return Icons.check_circle;
      default: return Icons.restaurant;
    }
  }

  @override
  Widget build(BuildContext context) {
    final dropLat = SafeParse.toDouble(widget.order['dropLat'], 31.47);
    final dropLng = SafeParse.toDouble(widget.order['dropLng'], 74.42);
    final pickupLat = SafeParse.toDouble(widget.order['pickupLat'], 31.5204);
    final pickupLng = SafeParse.toDouble(widget.order['pickupLng'], 74.3587);

    // Calculate real distance if rider location is available
    String distanceText = '';
    if (_riderLat != null && _riderLng != null) {
      final eta = EtaCalculator.getEtaInfo(riderLat: _riderLat!, riderLng: _riderLng!, destinationLat: dropLat, destinationLng: dropLng);
      distanceText = eta.displayString;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Live ETA Countdown Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [AppColors.orange, AppColors.orangeDark]),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: AppColors.orange.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 8))],
            ),
            child: Column(
              children: [
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(_statusIcon, color: Colors.white, size: 20), const SizedBox(width: 8), Flexible(child: Text(_statusLabel, style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis))]),
                const SizedBox(height: 16),
                Text(_formattedTime, style: const TextStyle(fontSize: 48, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 2)),
                const SizedBox(height: 8),
                const Text('remaining', style: TextStyle(fontSize: 14, color: Colors.white70)),
                const SizedBox(height: 16),
                ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: 1.0 - (_remainingSeconds / 300).clamp(0.0, 1.0), backgroundColor: Colors.white.withValues(alpha: 0.3), valueColor: const AlwaysStoppedAnimation<Color>(Colors.white), minHeight: 6)),
                const SizedBox(height: 12),
                if (distanceText.isNotEmpty) Text(distanceText, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Order Status Stepper
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: _cardDecoration(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Order Status', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.black)),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildStep(icon: Icons.check_circle, label: 'Placed', completed: true),
                    _buildStep(icon: Icons.restaurant, label: 'Preparing', active: _isStatusInRange(1), completed: _isStatusInRange(2)),
                    _buildStep(icon: Icons.motorcycle, label: 'Picked Up', active: _isStatusInRange(3), completed: _isStatusInRange(4)),
                    _buildStep(icon: Icons.home, label: 'Delivered', active: _isStatusInRange(5), completed: _isStatusInRange(6)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Map Preview
          Container(
            width: double.infinity,
            height: 200,
            decoration: _cardDecoration(),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: MapScreen(
                orderId: widget.order['id']?.toString(),
                riderLat: _riderLat ?? SafeParse.toDouble(widget.order['riderLat']),
                riderLng: _riderLng ?? SafeParse.toDouble(widget.order['riderLng']),
                pickupLat: pickupLat,
                pickupLng: pickupLng,
                dropLat: dropLat,
                dropLng: dropLng,
                riderName: widget.order['riderName'],
                riderPhone: widget.order['riderPhone'],
                estimatedTime: _formattedTime,
              ),
            ),
          ),
          if (widget.order['status'] == 'delivered') ...[
            const SizedBox(height: 16),
            // Confetti celebration card
            ConfettiCelebration(
              showConfetti: true,
              duration: const Duration(seconds: 5),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF66BB6A), Color(0xFF2E7D32)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF2E7D32).withValues(alpha: 0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const Icon(Icons.check_circle_rounded, color: Colors.white, size: 48),
                    const SizedBox(height: 12),
                    const Text('Delivered!', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white)),
                    const SizedBox(height: 4),
                    const Text('Your order has arrived', style: TextStyle(fontSize: 14, color: Colors.white70)),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => OrderRatingScreen(orderId: widget.order['id']?.toString() ?? '', restaurantName: widget.order['pickupAddress'] ?? 'Restaurant', riderName: widget.order['riderName'] ?? 'Rider'))),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: const Color(0xFF2E7D32), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
                        child: const Text('Rate Order', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ],
              ),
            ),
            ),
          ],
        ],
      ),
    );
  }

  bool _isStatusInRange(int level) {
    const statusOrder = ['pending', 'assigned', 'accepted', 'picked_up', 'in_transit', 'delivered'];
    final current = statusOrder.indexOf(widget.order['status'] ?? 'pending');
    return current >= level;
  }

  Widget _buildStep({required IconData icon, required String label, bool active = false, bool completed = false}) {
    return Expanded(
      child: Column(
        children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              color: completed ? AppColors.orange : (active ? AppColors.orange : AppColors.lightGray),
              shape: BoxShape.circle,
              border: active ? null : Border.all(color: AppColors.gray, width: 2),
            ),
            child: Icon(icon, size: 22, color: completed || active ? Colors.white : AppColors.darkGray),
          ),
          const SizedBox(height: 8),
          Text(label, textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: active ? FontWeight.w700 : FontWeight.w500, color: active ? AppColors.black : AppColors.darkGray)),
        ],
      ),
    );
  }

  BoxDecoration _cardDecoration() => BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: AppColors.orange.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, 4))]);
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// TAB 2: MAP — Real-time location
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
class _OrderMapTab extends StatelessWidget {
  final Map<String, dynamic> order;
  const _OrderMapTab({required this.order});

  @override
  Widget build(BuildContext context) {
    return MapScreen(
      orderId: order['id']?.toString(),
      riderLat: SafeParse.toDouble(order['riderLat']),
      riderLng: SafeParse.toDouble(order['riderLng']),
      pickupLat: SafeParse.toDouble(order['pickupLat'], 31.5204),
      pickupLng: SafeParse.toDouble(order['pickupLng'], 74.3587),
      dropLat: SafeParse.toDouble(order['dropLat'], 31.47),
      dropLng: SafeParse.toDouble(order['dropLng'], 74.42),
      riderName: order['riderName'],
      riderPhone: order['riderPhone'],
      estimatedTime: '5 min',
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// TAB 3: DETAILS — Real order data
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
class _OrderDetailsTab extends StatelessWidget {
  final Map<String, dynamic> order;
  const _OrderDetailsTab({required this.order});

  @override
  Widget build(BuildContext context) {
    final fare = order['fare'] != null ? double.tryParse(order['fare'].toString()) ?? 0 : 0;
    final deliveryFee = (fare * 0.08).roundToDouble();
    final taxes = (fare * 0.06).roundToDouble();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Status Banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.orange,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Order Confirmed', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text('Order #${(order['id'] ?? '').toString().substring(0, 8)}', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                    ],
                  ),
                ),
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), shape: BoxShape.circle),
                  child: const Icon(Icons.check_circle, color: Colors.white, size: 28),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Pickup & Drop Addresses with Edit Button
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: _cardDecoration(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Delivery Route', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.black)),
                    if (order['status'] == 'pending' || order['status'] == 'assigned')
                      GestureDetector(
                        onTap: () => _showChangeAddressDialog(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.orangePale,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(Icons.edit_location_alt, size: 16, color: AppColors.orange),
                              SizedBox(width: 4),
                              Text('Change', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.orange)),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                // Pickup Address
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      width: 14, 
                      height: 14, 
                      decoration: const BoxDecoration(
                        color: Color(0xFF4CAF50), 
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Pickup', style: TextStyle(fontSize: 12, color: AppColors.darkGray, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          Text(
                            order['pickupAddress'] ?? 'Pickup Location', 
                            style: const TextStyle(fontSize: 15, color: AppColors.black, fontWeight: FontWeight.w500, height: 1.4),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                Container(
                  margin: const EdgeInsets.only(left: 6, top: 8, bottom: 8),
                  width: 2, 
                  height: 32, 
                  color: AppColors.orange.withValues(alpha: 0.3),
                ),
                // Drop Address
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      width: 14, 
                      height: 14, 
                      decoration: const BoxDecoration(
                        color: AppColors.orange, 
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Drop', style: TextStyle(fontSize: 12, color: AppColors.darkGray, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          Text(
                            order['dropAddress'] ?? 'Drop Location', 
                            style: const TextStyle(fontSize: 15, color: AppColors.black, fontWeight: FontWeight.w500, height: 1.4),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Fare Summary
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: _cardDecoration(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Fare Summary', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.black)),
                const SizedBox(height: 16),
                _buildRow('Delivery Fee', 'Rs.${deliveryFee.toStringAsFixed(0)}'),
                const SizedBox(height: 10),
                _buildRow('Taxes & Fees', 'Rs.${taxes.toStringAsFixed(0)}'),
                const Divider(height: 24),
                _buildRow('Total', 'Rs.${fare.toStringAsFixed(0)}', isBold: true),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Customer Info
          if (order['customerName'] != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: _cardDecoration(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Customer', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.black)),
                  const SizedBox(height: 12),
                  Row(children: [
                    const Icon(Icons.person, color: AppColors.orange, size: 20),
                    const SizedBox(width: 10),
                    Text(order['customerName'] ?? '', style: const TextStyle(fontSize: 14, color: AppColors.black)),
                  ]),
                  if (order['customerPhone'] != null) ...[
                    const SizedBox(height: 8),
                    Row(children: [
                      const Icon(Icons.phone, color: AppColors.orange, size: 20),
                      const SizedBox(width: 10),
                      Text(order['customerPhone'] ?? '', style: const TextStyle(fontSize: 14, color: AppColors.black)),
                    ]),
                  ],
                ],
              ),
            ),
          const SizedBox(height: 16),
          // Order Time
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: _cardDecoration(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Order Info', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.black)),
                const SizedBox(height: 12),
                Row(children: [
                  const Icon(Icons.access_time, color: AppColors.orange, size: 20),
                  const SizedBox(width: 10),
                  Text('Placed: ${_formatDate(order['createdAt'])}', style: const TextStyle(fontSize: 14, color: AppColors.black)),
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  const Icon(Icons.update, color: AppColors.orange, size: 20),
                  const SizedBox(width: 10),
                  Text('Status: ${(order['status'] ?? 'pending').toString().toUpperCase()}', style: const TextStyle(fontSize: 14, color: AppColors.orange, fontWeight: FontWeight.w600)),
                ]),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildRow(String label, String value, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: isBold ? 18 : 14, fontWeight: isBold ? FontWeight.w700 : FontWeight.w400, color: isBold ? AppColors.black : AppColors.darkGray)),
        Text(value, style: TextStyle(fontSize: isBold ? 18 : 14, fontWeight: isBold ? FontWeight.w700 : FontWeight.w500, color: isBold ? AppColors.orange : AppColors.black)),
      ],
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return dateStr;
    }
  }

  void _showChangeAddressDialog(BuildContext context) {
    final addressController = TextEditingController(text: order['dropAddress']);
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(Icons.location_on, color: AppColors.orange, size: 24),
            SizedBox(width: 8),
            Text('Change Delivery Address', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Enter your new delivery address:', style: TextStyle(fontSize: 14, color: AppColors.darkGray)),
            const SizedBox(height: 16),
            TextField(
              controller: addressController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Enter address...',
                filled: true,
                fillColor: AppColors.lightGray,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                prefixIcon: const Icon(Icons.home, color: AppColors.orange),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () async {
                // Get current location and reverse geocode
                try {
                  // This would use geolocator package to get current location
                  // For now, show a message
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('📍 Getting your current location...'),
                      duration: Duration(seconds: 2),
                      backgroundColor: AppColors.orange,
                    ),
                  );
                  // In production: Use Geolocator to get lat/lng then reverse geocode
                  // addressController.text = await _getCurrentLocationAddress();
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Unable to get location'), backgroundColor: Colors.red),
                  );
                }
              },
              icon: const Icon(Icons.my_location, size: 18),
              label: const Text('Use Current Location'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.orange,
                side: const BorderSide(color: AppColors.orange),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: AppColors.darkGray)),
          ),
          ElevatedButton(
            onPressed: () async {
              final newAddress = addressController.text.trim();
              if (newAddress.isEmpty) return;
              final orderId = order['id']?.toString() ?? '';
              if (orderId.isEmpty) return;

              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Updating address...'),
                  backgroundColor: AppColors.orange,
                  duration: Duration(seconds: 2),
                ),
              );
              try {
                final updated =
                    await ApiService.updateOrderAddress(orderId, newAddress);
                order.addAll(updated);
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('✅ Delivery address updated!'),
                    backgroundColor: Color(0xFF4CAF50),
                    duration: Duration(seconds: 2),
                  ),
                );
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                        'Could not update address: ${ErrorHelper.getMessage(e)}'),
                    backgroundColor: Colors.red,
                    duration: const Duration(seconds: 3),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.orange,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Update Address'),
          ),
        ],
      ),
    );
  }

  BoxDecoration _cardDecoration() => BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: AppColors.orange.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, 4))]);
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// TAB 4: HISTORY — Real order history from API
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
class _OrderHistoryTab extends StatefulWidget {
  final Map<String, dynamic> order;
  const _OrderHistoryTab({required this.order});
  @override
  State<_OrderHistoryTab> createState() => _OrderHistoryTabState();
}

class _OrderHistoryTabState extends State<_OrderHistoryTab> {
  List<dynamic> _historyOrders = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    try {
      final orders = await ApiService.customerGetOrders();
      if (mounted) setState(() { _historyOrders = orders; _loading = false; });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(color: AppColors.orange));
    if (_historyOrders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(padding: const EdgeInsets.all(24), decoration: const BoxDecoration(color: AppColors.orangePale, shape: BoxShape.circle), child: const Icon(Icons.history, size: 48, color: AppColors.orange)),
            const SizedBox(height: 20),
            const Text('No order history', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            const Text('Your past orders will appear here', style: TextStyle(fontSize: 14, color: AppColors.darkGray)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _historyOrders.length,
      itemBuilder: (context, index) {
        final order = _historyOrders[index];
        final isDelivered = order['status'] == 'delivered';
        final fare = order['fare'] != null ? 'Rs.${order['fare']}' : '';

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: AppColors.orange.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, 4))]),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(width: 48, height: 48, decoration: BoxDecoration(color: AppColors.orangePale, borderRadius: BorderRadius.circular(12)), child: Icon(isDelivered ? Icons.check_circle : Icons.access_time, color: isDelivered ? AppColors.orange : AppColors.darkGray, size: 24)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(order['pickupAddress'] ?? 'Order', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.black)),
                        const SizedBox(height: 2),
                        Text('→ ${order['dropAddress'] ?? ''}', style: const TextStyle(fontSize: 12, color: AppColors.darkGray)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: isDelivered ? AppColors.orange : AppColors.lightGray, borderRadius: BorderRadius.circular(9999)),
                    child: Text(isDelivered ? 'Delivered' : (order['status'] ?? ''), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isDelivered ? Colors.white : AppColors.darkGray)),
                  ),
                ],
              ),
              if (fare.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(fare, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.orange)),
                    const Spacer(),
                    // Reorder button (FoodPanda-style)
                    if (isDelivered)
                      GestureDetector(
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Reordering from ${order['pickupAddress'] ?? 'restaurant'}...'),
                              backgroundColor: AppColors.orange,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.orange,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.refresh, color: Colors.white, size: 14),
                              SizedBox(width: 4),
                              Text('Reorder', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}