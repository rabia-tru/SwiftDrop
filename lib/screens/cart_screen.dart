import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../theme/app_colors.dart';
import '../services/api_service.dart';
import '../services/customer_background_service.dart';
import 'restaurant_list_screen.dart';
import '../widgets/premium_dialogs.dart';
import '../services/error_helper.dart';
import '../services/cart_service.dart';
import 'restaurant_detail_screen.dart' show Restaurant;
import 'track_order_screen.dart';
import 'payment_method_screen.dart';

/// SwiftDrop Cart — Review items, apply coupon, checkout
///
/// Reads/writes the GLOBAL [CartService] — the same cart the restaurant
/// detail screen fills and the nav-bar Cart tab displays. The optional
/// [restaurant] is kept for backwards-compatible navigation from the
/// detail screen's cart bar.
class CartScreen extends StatefulWidget {
  final Restaurant? restaurant;

  const CartScreen({super.key, this.restaurant});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final _addressController = TextEditingController(text: '');
  final _couponController = TextEditingController();
  final _instructionsController = TextEditingController();
  bool _couponApplied = false;
  String? _couponError;
  bool _placingOrder = false;
  Map<String, String>? _selectedPayment;
  int _selectedTip = 0; // 0, 30, 50, 100

  // Real coordinates for the drop point, fetched from the device's GPS.
  // Previously this screen sent a hardcoded lat/lng for every single order
  // (always the same fixed point in Lahore) regardless of the address text
  // the customer typed — so the rider/map always pointed at the wrong spot.
  double? _dropLat;
  double? _dropLng;

  static const List<int> _tipOptions = [0, 30, 50, 100];

  @override
  void initState() {
    super.initState();
    _fetchCurrentLocation();
  }

  Future<void> _fetchCurrentLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return; // Falls back to the restaurant's own coordinates below.
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
      if (mounted) {
        setState(() {
          _dropLat = position.latitude;
          _dropLng = position.longitude;
        });
      }
    } catch (_) {
      // Keep _dropLat/_dropLng null — _placeOrder() falls back safely.
    }
  }

  @override
  void dispose() {
    _addressController.dispose();
    _couponController.dispose();
    _instructionsController.dispose();
    super.dispose();
  }

  CartService get _cart => CartService.instance;

  double get _subtotal => _cart.subtotal;
  double get _deliveryFee => _cart.deliveryFee;
  double get _discount => _couponApplied ? _subtotal * 0.1 : 0; // 10% coupon
  double get _total => _subtotal + _deliveryFee - _discount + _selectedTip;

  Future<void> _updateQuantity(int index, bool increment) async {
    final id = _cart.items[index].menuItemId;
    // Removing the last piece of an item asks for confirmation first —
    // a single stray tap no longer wipes the item out of the cart.
    if (!increment && _cart.quantityOf(id) == 1) {
      final item = _cart.items.firstWhere((i) => i.menuItemId == id);
      final confirmed = await PremiumDialogs.showConfirm(
        context,
        title: 'Remove item?',
        message: 'Remove "${item.name}" from your cart?',
        confirmText: 'Remove',
        icon: Icons.delete_outline_rounded,
        isDestructive: true,
      );
      if (!confirmed) return;
      if (!mounted) return;
    }
    setState(() {
      if (increment) {
        _cart.increment(id);
      } else {
        _cart.decrement(id);
      }
    });
  }

  void _applyCoupon() {
    final code = _couponController.text.trim().toUpperCase();
    if (code == 'SWIFT10' || code == 'FOOD10') {
      setState(() {
        _couponApplied = true;
        _couponError = null;
      });
      PremiumDialogs.showSuccess(context, '10% discount applied!');
    } else {
      setState(() {
        _couponApplied = false;
        _couponError = 'Invalid coupon code';
      });
    }
  }

  Future<void> _placeOrder() async {
    if (_addressController.text.trim().isEmpty) {
      PremiumDialogs.showError(context, 'Please enter delivery address');
      return;
    }

    // Navigate to payment method screen if not selected
    if (_selectedPayment == null) {
      final result = await Navigator.of(context).push<Map<String, String>>(
        MaterialPageRoute(
          builder: (_) => PaymentMethodScreen(totalAmount: _total),
        ),
      );
      if (result != null) {
        setState(() => _selectedPayment = result);
      } else {
        return; // User went back
      }
    }

    setState(() => _placingOrder = true);

    try {
      // Structured items for the business dashboard (FoodPanda-style)
      final orderItems = _cart.items
          .map((c) => {'name': c.name, 'quantity': c.quantity, 'price': c.price.toInt()})
          .toList();
      final itemNames = _cart.items.map((c) => '${c.name} x${c.quantity}').join(', ');

      // The cart knows which restaurant it belongs to — works no matter
      // which screen opened it (detail-screen cart bar or nav-bar tab).
      final restaurantId = _cart.restaurantId ?? widget.restaurant?.id;
      final restaurantName = _cart.restaurantName ?? widget.restaurant?.name ?? 'Restaurant';
      if (restaurantId == null) {
        PremiumDialogs.showError(context, 'Your cart is empty.');
        return;
      }

      final result = await ApiService.customerCreateOrder(
        pickupAddress: restaurantName,
        pickupLat: widget.restaurant?.lat ?? 31.5204,
        pickupLng: widget.restaurant?.lng ?? 74.3587,
        dropAddress: _addressController.text.trim(),
        // Real GPS location when available; only fall back to a fixed
        // point (rather than crash) if location permission was denied.
        dropLat: _dropLat ?? widget.restaurant?.lat ?? 31.5204,
        dropLng: _dropLng ?? widget.restaurant?.lng ?? 74.3587,
        fare: _total,
        businessId: restaurantId,
        businessName: restaurantName,
        items: orderItems,
        paymentMethod: _selectedPayment?['label'] ?? _selectedPayment?['type'],
        notes: '${_instructionsController.text.isNotEmpty ? "[INSTRUCTIONS: ${_instructionsController.text}] " : ""}${_couponApplied ? "[COUPON: ${_couponController.text.toUpperCase()}] " : ""}${_selectedTip > 0 ? "[TIP: Rs.${_selectedTip}]" : ""}',
      );

      if (!mounted) return;

      // Get the order ID for tracking
      final orderId = result['id']?.toString() ?? '';
      final orderData = Map<String, dynamic>.from(result);
      orderData['customerName'] = (await ApiService.customerGetMe())['name'] ?? 'Customer';

      // Order placed — empty the global cart so the nav-bar Cart tab
      // resets (and the restaurant cart bar disappears).
      _cart.clear();

      // Start background order tracking (FoodPanda-style)
      if (orderId.isNotEmpty) {
        await CustomerBackgroundService.trackOrder(orderId);
      }

      // Show premium success dialog
      if (mounted) {
        PremiumDialogs.showSuccessDialog(
          context,
          title: 'Order Placed!',
          message: 'Your order from $restaurantName has been placed successfully.\nTotal: Rs.${_total.toStringAsFixed(0)}',
          buttonText: 'Track Order',
          onPressed: () {
            Navigator.of(context).pop();
            Navigator.of(context).popUntil((route) => route.isFirst);
            if (orderId.isNotEmpty) {
              Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => TrackOrderScreen(order: orderData),
              ));
            }
          },
        );
      }
    } catch (e) {
      if (!mounted) return;
      PremiumDialogs.showError(context, ErrorHelper.getMessage(e));
    } finally {
      if (mounted) setState(() => _placingOrder = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0A0A0A) : AppColors.offWhite;
    final cardColor = isDark ? const Color(0xFF1A1A1A) : Colors.white;
    final textColor = isDark ? Colors.white : AppColors.black;

    AppColors.setLightStatusBar();
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: AppColors.orange,
        foregroundColor: Colors.white,
        title: Text('Cart • ${_cart.restaurantName ?? widget.restaurant?.name ?? "SwiftDrop"}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _cart.isEmpty
          ? _buildEmptyCart(textColor)
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // Delivery address
                _buildAddressSection(cardColor, textColor, isDark),
                const SizedBox(height: 16),
                // Cart items
                _buildCartItemsSection(cardColor, textColor, isDark),
                const SizedBox(height: 16),
                // Delivery Instructions (FoodPanda-style)
                _buildDeliveryInstructions(cardColor, textColor, isDark),
                const SizedBox(height: 16),
                // Tip the Rider (FoodPanda-style)
                _buildTipSection(cardColor, textColor),
                const SizedBox(height: 16),
                // Coupon
                _buildCouponSection(cardColor, textColor, isDark),
                const SizedBox(height: 16),
                // Payment Method
                _buildPaymentSection(cardColor, textColor, isDark),
                const SizedBox(height: 16),
                // Price breakdown
                _buildPriceSection(cardColor, textColor),
                const SizedBox(height: 24),
                // Place order button
                _buildPlaceOrderButton(),
                const SizedBox(height: 20),
              ],
            ),
    );
  }

  Widget _buildEmptyCart(Color textColor) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(color: AppColors.orangePale, shape: BoxShape.circle),
            child: const Icon(Icons.shopping_cart_outlined, size: 56, color: AppColors.orange),
          ),
          const SizedBox(height: 20),
          Text('Your cart is empty', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: textColor)),
          const SizedBox(height: 8),
          Text('Add items from the menu to get started', style: TextStyle(fontSize: 14, color: AppColors.darkGray)),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.orange, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: const Text('Browse Menu', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _buildAddressSection(Color cardColor, Color textColor, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.location_on, color: AppColors.orange, size: 20),
              const SizedBox(width: 8),
              Text('Delivery Address', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: textColor)),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _addressController,
            style: TextStyle(fontSize: 14, color: textColor),
            decoration: InputDecoration(
              hintText: 'Enter delivery address',
              hintStyle: TextStyle(color: AppColors.darkGray.withValues(alpha: 0.6)),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.orange, width: 2)),
              filled: true,
              fillColor: isDark ? const Color(0xFF252525) : AppColors.lightGray,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              prefixIcon: const Icon(Icons.edit_location_alt, color: AppColors.orange, size: 18),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCartItemsSection(Color cardColor, Color textColor, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${_cart.items.length} item(s) in cart', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: textColor)),
          const SizedBox(height: 12),
          ..._cart.items.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            return _buildCartItem(item, index, textColor, isDark);
          }),
        ],
      ),
    );
  }

  Widget _buildCartItem(CartItem item, int index, Color textColor, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: index < _cart.items.length - 1
          ? BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.gray.withValues(alpha: 0.5))))
          : null,
      child: Row(
        children: [
          // Veg/Non-veg indicator
          Container(
            width: 14, height: 14,
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.orange, width: 1.5),
              borderRadius: BorderRadius.circular(3),
            ),
            child: Center(
              child: Container(
                width: 6, height: 6,
                decoration: const BoxDecoration(
                  color: AppColors.orange,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textColor)),
                Text('Rs.${item.price.toStringAsFixed(0)} × ${item.quantity}', style: TextStyle(fontSize: 12, color: AppColors.darkGray)),
              ],
            ),
          ),
          // Quantity controls
          Container(
            decoration: BoxDecoration(color: AppColors.orange, borderRadius: BorderRadius.circular(8)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () => _updateQuantity(index, false),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    child: Icon(item.quantity == 1 ? Icons.delete_outline : Icons.remove, color: Colors.white, size: 16),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Text('${item.quantity}', style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
                ),
                GestureDetector(
                  onTap: () => _updateQuantity(index, true),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    child: Icon(Icons.add, color: Colors.white, size: 16),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // DELIVERY INSTRUCTIONS (FoodPanda-style)
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Widget _buildDeliveryInstructions(Color cardColor, Color textColor, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.edit_note, color: AppColors.orange, size: 20),
              const SizedBox(width: 8),
              Text('Delivery Instructions', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: textColor)),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _instructionsController,
            maxLines: 2,
            style: TextStyle(fontSize: 14, color: textColor),
            decoration: InputDecoration(
              hintText: 'e.g. Ring the doorbell, leave at reception...',
              hintStyle: TextStyle(color: AppColors.darkGray.withValues(alpha: 0.6)),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.orange, width: 2)),
              filled: true,
              fillColor: isDark ? const Color(0xFF252525) : AppColors.lightGray,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // TIP THE RIDER (FoodPanda-style)
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Widget _buildTipSection(Color cardColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.volunteer_activism, color: AppColors.orange, size: 20),
              const SizedBox(width: 8),
              Text('Tip Your Rider', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: textColor)),
              const Spacer(),
              if (_selectedTip > 0)
                Text('Rs.$_selectedTip', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.orange)),
            ],
          ),
          const SizedBox(height: 4),
          Text('Show appreciation for your rider', style: TextStyle(fontSize: 12, color: AppColors.darkGray)),
          const SizedBox(height: 12),
          Row(
            children: _tipOptions.map((tip) {
              final isSelected = _selectedTip == tip;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _selectedTip = tip),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.orange : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected ? AppColors.orange : AppColors.gray,
                        width: 1.5,
                      ),
                    ),
                    child: Text(
                      tip == 0 ? 'None' : 'Rs.$tip',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? Colors.white : AppColors.darkGray,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildCouponSection(Color cardColor, Color textColor, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_couponApplied ? Icons.check_circle : Icons.local_offer, color: _couponApplied ? AppColors.statusDelivered : AppColors.orange, size: 20),
              const SizedBox(width: 8),
              Text(_couponApplied ? 'Coupon Applied!' : 'Apply Coupon', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: textColor)),
            ],
          ),
          const SizedBox(height: 10),
          if (_couponApplied)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.statusDelivered.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
              child: Row(
                children: [
                  const Icon(Icons.discount, color: AppColors.statusDelivered, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('${_couponController.text.toUpperCase()} — 10% off applied', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.statusDelivered)),
                  ),
                  GestureDetector(
                    onTap: () => setState(() { _couponApplied = false; _couponController.clear(); }),
                    child: const Icon(Icons.close, color: AppColors.statusDelivered, size: 18),
                  ),
                ],
              ),
            )
          else
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _couponController,
                    textCapitalization: TextCapitalization.characters,
                    style: TextStyle(fontSize: 14, color: textColor),
                    decoration: InputDecoration(
                      hintText: 'Enter coupon code (try SWIFT10)',
                      hintStyle: TextStyle(color: AppColors.darkGray.withValues(alpha: 0.6)),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.orange, width: 2)),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF252525) : AppColors.lightGray,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      errorText: _couponError,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: _applyCoupon,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(color: AppColors.orange, borderRadius: BorderRadius.circular(8)),
                    child: const Text('Apply', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildPaymentSection(Color cardColor, Color textColor, bool isDark) {
    return GestureDetector(
      onTap: () async {
        final result = await Navigator.of(context).push<Map<String, String>>(
          MaterialPageRoute(
            builder: (_) => PaymentMethodScreen(totalAmount: _total),
          ),
        );
        if (result != null) {
          setState(() => _selectedPayment = result);
        }
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 3))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.payment, color: AppColors.orange, size: 20),
                const SizedBox(width: 8),
                Text('Payment Method', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: textColor)),
                const Spacer(),
                const Icon(Icons.chevron_right, color: AppColors.orange, size: 20),
              ],
            ),
            const SizedBox(height: 10),
            if (_selectedPayment != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.orangePale.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(
                      _selectedPayment!['type'] == 'upi'
                          ? Icons.phone_android
                          : _selectedPayment!['type'] == 'card'
                              ? Icons.credit_card
                              : Icons.payments,
                      color: AppColors.orange,
                      size: 22,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_selectedPayment!['label'] ?? '', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textColor)),
                          const SizedBox(height: 2),
                          Text(_selectedPayment!['detail'] ?? '', style: const TextStyle(fontSize: 12, color: AppColors.darkGray)),
                        ],
                      ),
                    ),
                    const Icon(Icons.check_circle, color: AppColors.statusDelivered, size: 20),
                  ],
                ),
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.orangePale.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.add_circle_outline, color: AppColors.orange, size: 22),
                    SizedBox(width: 12),
                    Text('Select payment method', style: TextStyle(fontSize: 14, color: AppColors.orange, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPriceSection(Color cardColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Column(
        children: [
          _buildPriceRow('Subtotal', 'Rs.${_subtotal.toStringAsFixed(0)}', textColor),
          const SizedBox(height: 8),
          _buildPriceRow('Delivery Fee', _deliveryFee == 0 ? 'FREE' : 'Rs.${_deliveryFee.toStringAsFixed(0)}', textColor, valueColor: _deliveryFee == 0 ? AppColors.statusDelivered : null),
          if (_selectedTip > 0) ...[
            const SizedBox(height: 8),
            _buildPriceRow('Rider Tip', 'Rs.$_selectedTip', textColor, valueColor: AppColors.orange),
          ],
          if (_couponApplied) ...[
            const SizedBox(height: 8),
            _buildPriceRow('Discount (10%)', '-Rs.${_discount.toStringAsFixed(0)}', textColor, valueColor: AppColors.statusDelivered),
          ],
          const Divider(height: 24),
          Row(
            children: [
              Text('Total', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: textColor)),
              const Spacer(),
              Text('Rs.${_total.toStringAsFixed(0)}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.orange)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPriceRow(String label, String value, Color textColor, {Color? valueColor}) {
    return Row(
      children: [
        Text(label, style: TextStyle(fontSize: 14, color: AppColors.darkGray)),
        const Spacer(),
        Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: valueColor ?? textColor)),
      ],
    );
  }

  Widget _buildPlaceOrderButton() {
    final hasPayment = _selectedPayment != null;
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: (_placingOrder || _cart.isEmpty) ? null : _placeOrder,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.orange,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.orange.withValues(alpha: 0.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
        ),
        child: _placingOrder
            ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2.5, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))
            : Text(
                hasPayment
                    ? 'Pay Rs.${_total.toStringAsFixed(0)} via ${_selectedPayment!['label']}'
                    : 'Place Order • Rs.${_total.toStringAsFixed(0)}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
      ),
    );
  }
}