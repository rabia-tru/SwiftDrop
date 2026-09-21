import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';
import '../services/api_service.dart';
import '../services/websocket_service.dart';
import 'restaurant_list_screen.dart';
import 'cart_screen.dart';
import '../services/cart_service.dart';

/// Cart item with quantity
///
/// DEPRECATED local model — kept only because CartScreen's public
/// constructor still takes `List<CartItem>`. All add/remove operations
/// now go through [CartService.instance]; this class just mirrors one
/// service row so the legacy screen contract keeps compiling.
class CartItem {
  final MenuItem menuItem;
  int quantity;

  CartItem({required this.menuItem, this.quantity = 1});

  double get totalPrice => menuItem.price * quantity;
}

/// SwiftDrop Restaurant Detail — Menu browsing with cart
class RestaurantDetailScreen extends StatefulWidget {
  final Restaurant restaurant;

  const RestaurantDetailScreen({super.key, required this.restaurant});

  @override
  State<RestaurantDetailScreen> createState() => _RestaurantDetailScreenState();
}

class _RestaurantDetailScreenState extends State<RestaurantDetailScreen> {
  String _selectedMenuCategory = '';

  // Starts from whatever the restaurant list already had (so the screen
  // isn't empty while the fresh menu loads), then gets replaced with the
  // live menu from the backend — see _loadLiveMenu below.
  late List<MenuItem> _menu = widget.restaurant.menu;
  bool _menuLoading = false;
  String? _menuError;
  StreamSubscription? _menuUpdatedSub;

  @override
  void initState() {
    super.initState();
    _loadLiveMenu();

    // Live refresh: if the business changes their menu while this screen
    // is open, pull the fresh menu instead of waiting for a manual pull-to-refresh.
    final ws = WebSocketService.instance;
    ws.connect();
    _menuUpdatedSub = ws.menuUpdatedStream.listen((data) {
      if (data['businessId']?.toString() == widget.restaurant.id) {
        _loadLiveMenu();
      }
    });
  }

  @override
  void dispose() {
    _menuUpdatedSub?.cancel();
    super.dispose();
  }

  /// Fetches the restaurant's current menu directly from the backend
  /// (`GET /business/:id/menu`) instead of relying on the snapshot that
  /// was embedded in the restaurant list response — that snapshot can be
  /// stale, so newly added/updated items wouldn't show up here otherwise.
  Future<void> _loadLiveMenu() async {
    setState(() {
      _menuLoading = true;
      _menuError = null;
    });
    try {
      final raw = await ApiService.getBusinessMenu(widget.restaurant.id);
      final items = raw
          .whereType<Map<String, dynamic>>()
          .map(MenuItem.fromBackend)
          .where((m) => m.isAvailable)
          .toList();
      if (!mounted) return;
      setState(() {
        _menu = items;
        _menuLoading = false;
        // A category chip that no longer exists in the fresh menu would
        // filter every item away and look like "menu not showing".
        if (_selectedMenuCategory.isNotEmpty &&
            !items.any((m) => m.category == _selectedMenuCategory)) {
          _selectedMenuCategory = '';
        }
      });
    } catch (e) {
      // Keep whatever menu we already had, but surface the reason instead
      // of silently showing an empty screen — this is what hid the bug.
      if (!mounted) return;
      setState(() {
        _menuLoading = false;
        _menuError = e.toString();
      });
    }
  }

  List<String> get _menuCategories {
    final cats = <String>{};
    for (final item in _menu) {
      cats.add(item.category);
    }
    return cats.toList();
  }

  List<MenuItem> get _filteredMenu {
    if (_selectedMenuCategory.isEmpty) return _menu;
    return _menu.where((m) => m.category == _selectedMenuCategory).toList();
  }

  int get _totalItems => CartService.instance.totalItems;
  double get _totalPrice => CartService.instance.subtotal;

  void _addToCart(MenuItem item) {
    final cart = CartService.instance;
    if (cart.hasConflictWith(widget.restaurant.id)) {
      // Cart already holds items from another restaurant — confirm swap.
      final isDark = Theme.of(context).brightness == Brightness.dark;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1A1A1A) : Colors.white,
          title: const Text('Start a new cart?'),
          content: Text('Your cart has items from ${cart.restaurantName}. Adding from ${widget.restaurant.name} will replace them.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                cart.switchRestaurant(restaurant: widget.restaurant, item: item);
                setState(() {});
              },
              child: const Text('Replace', style: TextStyle(color: AppColors.orange, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      );
      return;
    }
    cart.tryAdd(restaurant: widget.restaurant, item: item);
    setState(() {});
  }

  void _removeFromCart(MenuItem item) {
    CartService.instance.decrement(item.id);
    setState(() {});
  }

  int _getItemQuantity(MenuItem item) => CartService.instance.quantityOf(item.id);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0A0A0A) : AppColors.offWhite;
    final cardColor = isDark ? const Color(0xFF1A1A1A) : Colors.white;
    final textColor = isDark ? Colors.white : AppColors.black;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: isDark ? const Color(0xFF0A0A0A) : Colors.white,
      ),
      child: Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: _loadLiveMenu,
            color: AppColors.orange,
            child: CustomScrollView(
              slivers: [
                // Restaurant header
                SliverToBoxAdapter(child: _buildHeader(isDark)),
                // Menu category chips
                SliverToBoxAdapter(child: _buildMenuCategories(isDark)),
                // Loading indicator while the live menu refreshes
                if (_menuLoading && _menu.isEmpty)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Center(child: CircularProgressIndicator(color: AppColors.orange)),
                    ),
                  )
                else if (_filteredMenu.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 32),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(
                              _menuError != null ? Icons.wifi_off_rounded : Icons.restaurant_menu,
                              size: 40,
                              color: AppColors.darkGray,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _menuError ?? 'No menu items yet',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 14, color: AppColors.darkGray),
                            ),
                            const SizedBox(height: 12),
                            TextButton(
                              onPressed: _loadLiveMenu,
                              child: const Text('Retry', style: TextStyle(color: AppColors.orange, fontWeight: FontWeight.w700)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                else
                  // Menu items
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _buildMenuItem(_filteredMenu[index], cardColor, textColor, isDark),
                        ),
                        childCount: _filteredMenu.length,
                      ),
                    ),
                  ),
                // Bottom spacer for cart bar
                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            ),
          ),
          // Cart bar at bottom
          if (CartService.instance.isNotEmpty) Positioned(bottom: 0, left: 0, right: 0, child: _buildCartBar(isDark)),
        ],
      ),
    ),
    );
  }

  Widget _buildHeader(bool isDark) {
    final textColor = isDark ? Colors.white : AppColors.black;
    final r = widget.restaurant;

    return Column(
      children: [
        // Restaurant banner
        Container(
          height: 200,
          width: double.infinity,
          color: AppColors.orangePale,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Restaurant image (from backend or food fallback)
              Image.network(
                r.image.isNotEmpty ? r.image : '',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppColors.orange.withValues(alpha: 0.2), AppColors.orangePale],
                    ),
                  ),
                  child: Center(child: Icon(Icons.restaurant, size: 64, color: AppColors.orange.withValues(alpha: 0.4))),
                ),
              ),
              // Back button
              Positioned(
                top: MediaQuery.of(context).padding.top + 8,
                left: 16,
                child: GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 8)]),
                    child: const Icon(Icons.arrow_back_ios, color: AppColors.orange, size: 20),
                  ),
                ),
              ),
              // Open/Closed badge
              Positioned(
                top: MediaQuery.of(context).padding.top + 8,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: r.isOpen ? AppColors.statusDelivered : AppColors.darkGray,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(r.isOpen ? 'OPEN' : 'CLOSED', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
        // Restaurant info
        Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text(r.name, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: textColor))),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(color: AppColors.orangePale, borderRadius: BorderRadius.circular(8)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.star, color: AppColors.orange, size: 16),
                        const SizedBox(width: 4),
                        Text('${r.rating}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.orange)),
                        Text(' (${r.reviewCount})', style: TextStyle(fontSize: 13, color: AppColors.darkGray)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(r.cuisine, style: TextStyle(fontSize: 14, color: AppColors.darkGray)),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.access_time, color: AppColors.orange, size: 16),
                  const SizedBox(width: 6),
                  Text(r.deliveryTime, style: TextStyle(fontSize: 13, color: textColor, fontWeight: FontWeight.w500)),
                  const SizedBox(width: 16),
                  Icon(Icons.delivery_dining, color: AppColors.orange.withValues(alpha: 0.6), size: 16),
                  const SizedBox(width: 6),
                  Text(r.deliveryFee == 0 ? 'Free delivery' : 'Rs.${r.deliveryFee.toStringAsFixed(0)} delivery', style: TextStyle(fontSize: 13, color: r.deliveryFee == 0 ? AppColors.statusDelivered : textColor)),
                  const SizedBox(width: 16),
                  Icon(Icons.location_on, color: AppColors.orange.withValues(alpha: 0.6), size: 16),
                  const SizedBox(width: 6),
                  Text('${r.distance.toStringAsFixed(1)} km', style: TextStyle(fontSize: 13, color: textColor)),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMenuCategories(bool isDark) {
    return SizedBox(
      height: 52, // Increased height to prevent text cutting
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        scrollDirection: Axis.horizontal,
        itemCount: _menuCategories.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final isAll = index == 0;
          final cat = isAll ? '' : _menuCategories[index - 1];
          final label = isAll ? 'All' : cat;
          final isSelected = isAll ? _selectedMenuCategory.isEmpty : _selectedMenuCategory == cat;

          return GestureDetector(
            onTap: () => setState(() => _selectedMenuCategory = cat),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.orange : (isDark ? const Color(0xFF1A1A1A) : Colors.white),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: isSelected ? AppColors.orange : AppColors.gray, width: 1.5),
              ),
              child: Center(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? Colors.white : AppColors.darkGray,
                    height: 1.2, // Proper line height
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMenuItem(MenuItem item, Color cardColor, Color textColor, bool isDark) {
    final qty = _getItemQuantity(item);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Row(
        children: [
          // Item info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Veg/Non-veg indicator
                    Container(
                      width: 16, height: 16,
                      decoration: BoxDecoration(
                        border: Border.all(color: item.isVeg ? AppColors.statusDelivered : AppColors.orange, width: 1.5),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Center(
                        child: Container(
                          width: 8, height: 8,
                          decoration: BoxDecoration(
                            color: item.isVeg ? AppColors.statusDelivered : AppColors.orange,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (item.isBestseller)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: AppColors.orangePale, borderRadius: BorderRadius.circular(4)),
                        child: const Text('★ BESTSELLER', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: AppColors.orange)),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(item.name, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: textColor)),
                const SizedBox(height: 4),
                Text(item.description, style: TextStyle(fontSize: 12, color: AppColors.darkGray), maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 8),
                Text('Rs.${item.price.toStringAsFixed(0)}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.orange)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Add/Quantity button
          Column(
            children: [
              // Item image (from backend or food fallback)
              Container(
                width: 80, height: 80,
                decoration: BoxDecoration(
                  color: AppColors.orangePale,
                  borderRadius: BorderRadius.circular(12),
                ),
                clipBehavior: Clip.antiAlias,
                child: Image.network(
                  item.image.isNotEmpty ? item.image : '',
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Center(
                    child: Icon(Icons.restaurant, size: 32, color: AppColors.orange.withValues(alpha: 0.4)),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              if (qty == 0)
                GestureDetector(
                  onTap: () => _addToCart(item),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.orange,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('ADD', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                  ),
                )
              else
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.orange,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        onTap: () => _removeFromCart(item),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          child: Icon(Icons.remove, color: Colors.white, size: 16),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text('$qty', style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
                      ),
                      GestureDetector(
                        onTap: () => _addToCart(item),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          child: Icon(Icons.add, color: Colors.white, size: 16),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCartBar(bool isDark) {
    return GestureDetector(
      onTap: () async {
        // CartScreen now reads/writes CartService.instance directly —
        // the global cart shared with the nav-bar Cart tab.
        await Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => CartScreen(restaurant: widget.restaurant),
        ));
        setState(() {}); // refresh cart bar with whatever CartScreen left it as
      },
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.orange,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: AppColors.orange.withValues(alpha: 0.3), blurRadius: 15, offset: const Offset(0, 6))],
        ),
        child: Row(
          children: [
            // Cart count badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
              child: Text('$_totalItems', style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text('View Cart', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
            ),
            Text('Rs.${_totalPrice.toStringAsFixed(0)}', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_forward_ios, color: Colors.white70, size: 16),
          ],
        ),
      ),
    );
  }
}