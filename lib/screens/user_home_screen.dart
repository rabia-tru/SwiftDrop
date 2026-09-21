import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import '../theme/app_colors.dart';
import '../config/app_support.dart';
import '../theme/theme_provider.dart';
import '../widgets/status_badge.dart';
import '../widgets/floating_nav_bar.dart';
import '../widgets/shimmer_loading.dart';
import '../services/api_service.dart';
import '../services/error_helper.dart';
import '../services/cart_service.dart';
import '../widgets/premium_dialogs.dart';
import '../services/websocket_service.dart';
import '../services/chat_unread_service.dart';
import 'role_selection_screen.dart';
import 'track_order_screen.dart';
import 'cart_screen.dart';
import 'restaurant_list_screen.dart';
import 'restaurant_detail_screen.dart' hide CartItem;
import 'notifications_screen.dart';
import 'address_screen.dart';
import 'payment_method_screen.dart';
import 'qr_generator_screen.dart';
import 'qr_scanner_screen.dart';
import '../widgets/exit_confirm_dialog.dart';

/// SwiftDrop Customer Home — Premium bottom nav with modern tabs
class UserHomeScreen extends StatefulWidget {
  const UserHomeScreen({super.key});

  @override
  State<UserHomeScreen> createState() => _UserHomeScreenState();
}

class _UserHomeScreenState extends State<UserHomeScreen> {
  int _currentIndex = 0;
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onItemTapped(int index) {
    setState(() => _currentIndex = index);
    _pageController.jumpToPage(index);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return PopScope(
      // Non-Home tab khula ho to BACK pehle Home tab pe le aaye;
      // Home tab par BACK do baar dabao to exit-confirmation aata hai —
      // app kabhi silently exit nahi hota.
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (_currentIndex != 0) {
          setState(() => _currentIndex = 0);
          _pageController.jumpToPage(0);
          return;
        }
        await ExitConfirmDialog.show(context, isDark: isDark);
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarDividerColor: Colors.transparent,
      ),
      child: Scaffold(
        body: PageView(
          controller: _pageController,
          physics: const NeverScrollableScrollPhysics(),
          children: const [
            _RestaurantTab(),
            _OrdersTab(),
            _CartTab(),
            _ProfileTab(),
          ],
        ),
        bottomNavigationBar: ListenableBuilder(
          listenable: ChatUnreadService.instance,
          builder: (context, _) => FloatingNavBar(
            currentIndex: _currentIndex,
            onTap: _onItemTapped,
            isRider: false,
            notificationCount: ChatUnreadService.instance.totalUnreads,
          ),
        ),
      ),
      ),
    );
  }
}

// ─── Tab 1: Restaurants (Premium Home Design) ─────────────────
class _RestaurantTab extends StatefulWidget {
  const _RestaurantTab();

  @override
  State<_RestaurantTab> createState() => _RestaurantTabState();
}

/// Reloads data when the app comes back to the foreground.
class _LifecycleReload with WidgetsBindingObserver {
  final VoidCallback onResume;
  _LifecycleReload({required this.onResume});

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) onResume();
  }
}

class _RestaurantTabState extends State<_RestaurantTab> {
  List<Restaurant> _restaurants = [];
  bool _loading = true;
  String? _loadError;
  String _userLocation = 'Fetching location...';
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String? _selectedCategory;
  StreamSubscription? _menuUpdatedSub;

  // Food categories — real Unsplash photos for each category, with a
  // Material icon fallback if the image fails to load (no internet, etc).
  final List<Map<String, dynamic>> _categories = [
    {'image': 'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=200&h=200&fit=crop', 'icon': Icons.lunch_dining_rounded, 'label': 'Snacks', 'color': AppColors.orange},
    {'image': 'https://images.unsplash.com/photo-1550547660-d9450f859349?w=200&h=200&fit=crop', 'icon': Icons.restaurant_rounded, 'label': 'Meal', 'color': const Color(0xFFFF8F00)},
    {'image': 'https://images.unsplash.com/photo-1555939594-58d7cb561ad1?w=200&h=200&fit=crop', 'icon': Icons.cake_rounded, 'label': 'Dessert', 'color': const Color(0xFFE91E63)},
    {'image': 'https://images.unsplash.com/photo-1541658016709-82535e94bc69?w=200&h=200&fit=crop', 'icon': Icons.local_drink_rounded, 'label': 'Drinks', 'color': const Color(0xFF2196F3)},
  ];

  @override
  void initState() {
    super.initState();
    _loadRestaurants();
    _fetchLocation();
    // Reload the restaurant list when the app resumes so newly
    // registered businesses appear without killing the app.
    WidgetsBinding.instance.addObserver(_LifecycleReload(onResume: _loadRestaurants));

    // Any business's menu changing means our cached list is stale — refresh live.
    final ws = WebSocketService.instance;
    ws.connect();
    _menuUpdatedSub = ws.menuUpdatedStream.listen((_) => _loadRestaurants());
  }

  @override
  void dispose() {
    _menuUpdatedSub?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchLocation() async {
    try {
      // Check if location services are enabled
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          setState(() => _userLocation = 'Your Area');
          _showLocationDialog(
            'Location Services Disabled',
            'Enable location to see nearby restaurants and delivery estimates.',
            true,
          );
        }
        return;
      }

      // Check and request permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) setState(() => _userLocation = 'Your Area');
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          setState(() => _userLocation = 'Your Area');
          _showLocationDialog(
            'Location Permission Required',
            'Enable location permission in settings to see nearby restaurants.',
            false,
          );
        }
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 10)),
      );
      if (mounted) setState(() => _userLocation = '${pos.latitude.toStringAsFixed(2)}, ${pos.longitude.toStringAsFixed(2)}');
    } catch (_) {
      if (mounted) setState(() => _userLocation = 'Your Area');
    }
  }

  void _showLocationDialog(String title, String message, bool isServiceDisabled) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(color: AppColors.orangePale, shape: BoxShape.circle),
              child: const Icon(Icons.location_off, color: AppColors.orange, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
          ],
        ),
        content: Text(message, style: const TextStyle(fontSize: 14, height: 1.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: AppColors.darkGray)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              if (isServiceDisabled) {
                await Geolocator.openLocationSettings();
              } else {
                await Geolocator.openAppSettings();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.orange,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  Future<void> _loadRestaurants() async {
    setState(() { _loading = true; _loadError = null; });
    try {
      final businesses = await ApiService.getAllBusinesses();
      if (mounted) {
        setState(() {
          _restaurants = businesses.map((b) => Restaurant.fromBackend(b)).toList();
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _restaurants = [];
          _loading = false;
          _loadError = ErrorHelper.getMessage(e);
        });
      }
    }
  }

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  String get _greetingSub {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Rise And Shine! It\'s Breakfast Time';
    if (hour < 17) return 'Lunch Time! Find Something Delicious';
    return 'Dinner Time! Explore Tasty Options';
  }

  List<Restaurant> get _bestSellers => _restaurants.where((r) => r.rating >= 4.3 || r.isFeatured).toList();
  List<Restaurant> get _filteredRestaurants {
    var list = _restaurants;
    if (_selectedCategory != null) {
      final cat = _selectedCategory!.toLowerCase();
      list = list.where((r) {
          final q = cat;
          if (q == 'drinks') {
            return r.menu.any((m) => m.category.toLowerCase().contains('drink') || m.name.toLowerCase().contains('cola') || m.name.toLowerCase().contains('water') || m.name.toLowerCase().contains('juice') || m.name.toLowerCase().contains('shake') || m.name.toLowerCase().contains('coffee') || m.name.toLowerCase().contains('chai') || m.name.toLowerCase().contains('lassi'));
          }
          return r.cuisine.toLowerCase().contains(q) ||
              r.categories.any((c) => c.toLowerCase().contains(q)) ||
              r.menu.any((m) => m.category.toLowerCase().contains(q) || m.name.toLowerCase().contains(q));
        }).toList();
    }
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((r) =>
          r.name.toLowerCase().contains(q) ||
          r.cuisine.toLowerCase().contains(q) ||
          r.categories.any((c) => c.toLowerCase().contains(q)) ||
          r.menu.any((m) => m.name.toLowerCase().contains(q) || m.category.toLowerCase().contains(q))).toList();
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final statusBarHeight = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0A0A) : Colors.white,
      body: RefreshIndicator(
        onRefresh: _loadRestaurants,
        color: AppColors.orange,
        child: _loading
            ? _buildShimmer(statusBarHeight)
            : CustomScrollView(
                slivers: [
                  // ─── Search Bar + Greeting ───
                  SliverToBoxAdapter(child: _buildHeader(statusBarHeight)),
                  // ─── Category Icons ───
                  SliverToBoxAdapter(child: _buildCategories()),
                  // ─── Best Seller Section ───
                  if (_bestSellers.isNotEmpty) ...[
                    SliverToBoxAdapter(child: _buildSectionHeader('Best Seller', 'View All')),
                    SliverToBoxAdapter(child: _buildBestSellers()),
                  ],
                  // ─── Promo Banner ───
                  SliverToBoxAdapter(child: _buildPromoBanner()),
                  // ─── Recommend Section ───
                  SliverToBoxAdapter(child: _buildSectionHeader('Recommend', '')),
                  if (_filteredRestaurants.isEmpty && !_loading)
                    SliverToBoxAdapter(child: _buildEmptyState())
                  else
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      sliver: SliverGrid(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.75,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) => _buildRecommendCard(_filteredRestaurants[index]),
                          childCount: _filteredRestaurants.length,
                        ),
                      ),
                    ),
                  const SliverToBoxAdapter(child: SizedBox(height: 100)),
                ],
              ),
      ),
    );
  }

  Widget _buildShimmer(double statusBarHeight) {
    return ListView(
      padding: EdgeInsets.fromLTRB(20, statusBarHeight + 16, 20, 100),
      children: [
        const ShimmerLoading(height: 50, borderRadius: BorderRadius.all(Radius.circular(16))),
        const SizedBox(height: 20),
        Row(children: List.generate(5, (_) => const Expanded(child: Padding(padding: EdgeInsets.symmetric(horizontal: 4), child: ShimmerLoading(height: 72, borderRadius: BorderRadius.all(Radius.circular(16))))))),
        const SizedBox(height: 24),
        const ShimmerLoading(height: 20, width: 120, borderRadius: BorderRadius.all(Radius.circular(8))),
        const SizedBox(height: 12),
        SizedBox(height: 180, child: ListView.separated(scrollDirection: Axis.horizontal, itemCount: 3, separatorBuilder: (_, __) => const SizedBox(width: 12), itemBuilder: (_, __) => const ShimmerLoading(width: 160, height: 180, borderRadius: BorderRadius.all(Radius.circular(16))))),
        const SizedBox(height: 20),
        const ShimmerLoading(height: 140, borderRadius: BorderRadius.all(Radius.circular(20))),
        const SizedBox(height: 24),
        Row(children: List.generate(2, (_) => const Expanded(child: Padding(padding: EdgeInsets.symmetric(horizontal: 4), child: ShimmerLoading(height: 200, borderRadius: BorderRadius.all(Radius.circular(16))))))),
      ],
    );
  }

  Widget _buildHeader(double statusBarHeight) {
    return Container(
      padding: EdgeInsets.fromLTRB(20, statusBarHeight + 16, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search bar
          Container(
            height: 50,
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(14),
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _searchQuery = v),
              decoration: InputDecoration(
                hintText: 'Search',
                hintStyle: TextStyle(color: Colors.grey[400], fontSize: 15),
                prefixIcon: const Icon(Icons.search_rounded, color: AppColors.orange, size: 22),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          const SizedBox(height: 20),
          // Greeting
          Text(_greeting, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: AppColors.orange)),
          const SizedBox(height: 4),
          Text(_greetingSub, style: TextStyle(fontSize: 14, color: Colors.grey[500])),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.location_on_rounded, color: AppColors.orange, size: 14),
              const SizedBox(width: 4),
              Text(_userLocation, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCategories() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: _categories.map((cat) {
          final label = cat['label'] as String;
          final color = cat['color'] as Color;
          final isSelected = _selectedCategory == label;
          return GestureDetector(
            onTap: () {
              setState(() {
                // Tap again to clear the filter, otherwise select this category
                _selectedCategory = isSelected ? null : label;
              });
            },
            child: Column(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? color : Colors.transparent,
                      width: 2.5,
                    ),
                  ),
                  padding: const EdgeInsets.all(2),
                  child: ClipOval(
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.network(
                          cat['image'] as String,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, progress) {
                            if (progress == null) return child;
                            return Container(color: color.withValues(alpha: 0.1));
                          },
                          errorBuilder: (context, error, stackTrace) => Container(
                            color: color.withValues(alpha: 0.1),
                            child: Icon(cat['icon'] as IconData, color: color, size: 24),
                          ),
                        ),
                        if (isSelected)
                          Container(color: color.withValues(alpha: 0.25)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    color: isSelected ? color : Colors.grey[700],
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSectionHeader(String title, String action) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.black)),
          if (action.isNotEmpty)
            GestureDetector(
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RestaurantListScreen())),
              child: Row(
                children: [
                  Text(action, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.orange)),
                  const SizedBox(width: 4),
                  const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.orange),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBestSellers() {
    return SizedBox(
      height: 200,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: _bestSellers.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final r = _bestSellers[index];
          return GestureDetector(
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => RestaurantDetailScreen(restaurant: r),
            )),
            child: Container(
              width: 160,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, 4)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Food image
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                        image: r.image.isNotEmpty
                            ? DecorationImage(image: NetworkImage(r.image), fit: BoxFit.cover)
                            : null,
                        color: r.image.isEmpty ? AppColors.orangePale : null,
                      ),
                      child: r.image.isEmpty
                          ? const Center(child: Icon(Icons.restaurant_rounded, size: 40, color: AppColors.orange))
                          : null,
                    ),
                  ),
                  // Info
                  Padding(
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(r.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        Text('Rs.${r.menu.isNotEmpty ? r.menu.first.price.toStringAsFixed(0) : '0'}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.orange)),
                      ],
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

  Widget _buildPromoBanner() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.orange, AppColors.orangeDark],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: AppColors.orange.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 6)),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Experience our\ndelicious new dish', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white, height: 1.3)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
                    child: const Text('30% OFF', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: AppColors.orange)),
                  ),
                ],
              ),
            ),
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.2),
              ),
              child: const Icon(Icons.local_offer_rounded, size: 48, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecommendCard(Restaurant r) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => RestaurantDetailScreen(restaurant: r),
      )),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 3)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            Expanded(
              flex: 3,
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  image: r.image.isNotEmpty
                      ? DecorationImage(image: NetworkImage(r.image), fit: BoxFit.cover)
                      : null,
                  color: r.image.isEmpty ? AppColors.orangePale : null,
                ),
                child: r.image.isEmpty
                    ? const Center(child: Icon(Icons.restaurant_rounded, size: 36, color: AppColors.orange))
                    : null,
              ),
            ),
            // Info
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(r.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(r.cuisine, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                    const Spacer(),
                    Row(
                      children: [
                        const Icon(Icons.star_rounded, size: 14, color: Color(0xFFFFC107)),
                        const SizedBox(width: 2),
                        Text('${r.rating}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                        const Spacer(),
                        Text('Rs.${r.menu.isNotEmpty ? r.menu.first.price.toStringAsFixed(0) : '0'}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.orange)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    // Load failure (server unreachable) — show the real error + retry,
    // not a misleading "no restaurants" message.
    if (_loadError != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
        child: Column(
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: const BoxDecoration(color: AppColors.orangePale, shape: BoxShape.circle),
              child: const Icon(Icons.wifi_off_rounded, size: 40, color: AppColors.orange),
            ),
            const SizedBox(height: 16),
            Text(_loadError!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.black)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () { setState(() => _loading = true); _loadRestaurants(); },
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.orange, foregroundColor: Colors.white),
            ),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.orangePale,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.restaurant_rounded, size: 40, color: AppColors.orange),
          ),
          const SizedBox(height: 16),
          const Text('No restaurants found', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text('Restaurants will appear here once they register', style: TextStyle(fontSize: 14, color: Colors.grey[500]), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

// ─── Tab 2: Orders ───────────────────────────────────────────
class _OrdersTab extends StatefulWidget {
  const _OrdersTab();

  @override
  State<_OrdersTab> createState() => _OrdersTabState();
}

class _OrdersTabState extends State<_OrdersTab> {
  List<dynamic> _orders = [];
  bool _loading = true;
  StreamSubscription<Map<String, dynamic>>? _orderUpdates;

  @override
  void initState() {
    super.initState();
    _loadOrders();
    _listenForOrderUpdates();
  }

  /// Business and rider actions are delivered to the customer's private
  /// WebSocket room. Reloading here keeps this tab in sync without a pull
  /// to refresh.
  Future<void> _listenForOrderUpdates() async {
    final customerId = await ApiService.getRiderId();
    if (!mounted || customerId == null || customerId.isEmpty) return;

    final ws = WebSocketService.instance;
    ws.connect(token: await ApiService.getToken());
    ws.watchCustomerOrders(customerId);
    _orderUpdates = ws.orderStatusStream.listen((_) {
      if (mounted) _loadOrders();
    });
  }

  @override
  void dispose() {
    _orderUpdates?.cancel();
    super.dispose();
  }

  Future<void> _loadOrders() async {
    setState(() => _loading = true);
    try {
      final orders = await ApiService.customerGetOrders();
      if (mounted) setState(() { _orders = orders; _loading = false; });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0A0A0A) : AppColors.offWhite;
    final textColor = isDark ? Colors.white : AppColors.black;
    final subTextColor = isDark ? const Color(0xFFB0B0B0) : AppColors.darkGray;
    final statusBarHeight = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: bgColor,
      body: RefreshIndicator(
        onRefresh: _loadOrders,
        color: AppColors.orange,
        // Rebuild order cards live when unread chat counts change
        child: ListenableBuilder(
          listenable: ChatUnreadService.instance,
          builder: (context, _) => _loading
            ? ListView(
                padding: EdgeInsets.fromLTRB(20, statusBarHeight + 16, 20, 100),
                children: [
                  Text('My Orders', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: textColor)),
                  const SizedBox(height: 16),
                  const OrderCardSkeleton(),
                  const OrderCardSkeleton(),
                  const OrderCardSkeleton(),
                  const OrderCardSkeleton(),
                  const OrderCardSkeleton(),
                ],
              )
            : _orders.isEmpty
                ? _buildEmptyOrders(textColor, subTextColor, statusBarHeight)
                : ListView.builder(
                    padding: EdgeInsets.fromLTRB(20, statusBarHeight + 16, 20, 100),
                    itemCount: _orders.length + 1,
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Text('My Orders', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: textColor)),
                        );
                      }
                      return _buildOrderCard(_orders[index - 1], textColor, subTextColor);
                    },
                  ),
        ),
      ),
    );
  }

  Widget _buildEmptyOrders(Color textColor, Color subTextColor, double statusBarHeight) {
    return Center(
      child: Padding(
        padding: EdgeInsets.only(top: statusBarHeight),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 88, height: 88,
              decoration: BoxDecoration(
                gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [AppColors.orange.withValues(alpha: 0.15), AppColors.orangePale]),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.receipt_long_rounded, size: 44, color: AppColors.orange),
            ),
            const SizedBox(height: 24),
            Text('No orders yet', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: textColor)),
            const SizedBox(height: 8),
            Text('Browse restaurants and place your first order!', style: TextStyle(fontSize: 14, color: subTextColor), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderCard(dynamic order, Color textColor, Color subTextColor) {
    final status = order['status'] ?? 'pending';
    final orderId = (order['id'] ?? '').toString();
    final unreadChats = ChatUnreadService.instance.unreadsFor(orderId);
    // Flatten nested rider object so TrackOrderScreen gets name/location
    final rider = order['rider'];
    if (rider is Map) {
      order['riderName'] ??= rider['name'];
      order['riderPhone'] ??= rider['phone'];
      order['riderLat'] ??= rider['lastKnownLat'];
      order['riderLng'] ??= rider['lastKnownLng'];
    }

    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => TrackOrderScreen(order: Map<String, dynamic>.from(order))),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 4)),
            BoxShadow(color: AppColors.orange.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(gradient: AppColors.primaryGradient, borderRadius: BorderRadius.circular(12)),
                  child: Icon(_getStatusIcon(status), color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(order['pickupAddress'] ?? 'Order', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: textColor)),
                      const SizedBox(height: 2),
                      Text('Order #${orderId.isNotEmpty && orderId.length > 8 ? orderId.substring(0, 8) : orderId}', style: TextStyle(color: subTextColor, fontSize: 12)),
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
                StatusBadge(status: status),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: AppColors.orangePale.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(10)),
              child: Column(
                children: [
                  Row(children: [
                    Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppColors.orange, shape: BoxShape.circle)),
                    const SizedBox(width: 8),
                    Expanded(child: Text(order['pickupAddress'] ?? 'Pickup', style: TextStyle(fontSize: 13, color: textColor), maxLines: 1, overflow: TextOverflow.ellipsis)),
                  ]),
                  const SizedBox(height: 6),
                  Row(children: [
                    Container(width: 8, height: 8, decoration: BoxDecoration(color: AppColors.orangeDark, shape: BoxShape.rectangle, borderRadius: BorderRadius.circular(2))),
                    const SizedBox(width: 8),
                    Expanded(child: Text(order['dropAddress'] ?? 'Drop', style: TextStyle(fontSize: 13, color: textColor), maxLines: 1, overflow: TextOverflow.ellipsis)),
                  ]),
                ],
              ),
            ),
            if (order['fare'] != null) ...[
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Total', style: TextStyle(fontSize: 13, color: subTextColor)),
                  Text('Rs.${order['fare']}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.orange)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'pending': return Icons.access_time;
      case 'assigned': return Icons.person;
      case 'accepted': return Icons.done_all;
      case 'picked_up': return Icons.shopping_cart;
      case 'in_transit': return Icons.local_shipping;
      case 'delivered': return Icons.check_circle;
      case 'cancelled': return Icons.cancel;
      default: return Icons.help;
    }
  }
}

// ─── Tab 3: Cart ────────────────────────────────────────────
/// Live view of the GLOBAL cart — items added in any restaurant show
/// up here instantly (ListenableBuilder on CartService).
class _CartTab extends StatelessWidget {
  const _CartTab();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final statusBarHeight = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0A0A) : AppColors.offWhite,
      body: SafeArea(
        top: false,
        child: ListenableBuilder(
          listenable: CartService.instance,
          builder: (context, _) {
            final cart = CartService.instance;
            if (cart.isEmpty) return _buildEmptyCart(isDark, statusBarHeight);

            return Column(
              children: [
                Padding(padding: EdgeInsets.only(top: statusBarHeight + 8)),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
                    children: [
                      // Restaurant header
                      Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: cart.restaurantImage != null && cart.restaurantImage!.isNotEmpty
                                ? Image.network(cart.restaurantImage!, width: 52, height: 52, fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => const Icon(Icons.storefront, size: 40, color: AppColors.orange))
                                : const Icon(Icons.storefront, size: 40, color: AppColors.orange),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(cart.restaurantName ?? 'Restaurant',
                                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800,
                                        color: isDark ? Colors.white : AppColors.black)),
                                Text('${cart.totalItems} item(s)',
                                    style: const TextStyle(fontSize: 13, color: AppColors.darkGray)),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => _confirmClearCart(context),
                            icon: Icon(Icons.delete_outline, color: isDark ? Colors.white70 : AppColors.darkGray),
                            tooltip: 'Clear cart',
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Items
                      ...cart.items.map((item) => Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 3))],
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(item.name,
                                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
                                              color: isDark ? Colors.white : AppColors.black)),
                                      const SizedBox(height: 2),
                                      Text('Rs.${item.price.toStringAsFixed(0)} × ${item.quantity} = Rs.${item.totalPrice.toStringAsFixed(0)}',
                                          style: const TextStyle(fontSize: 12, color: AppColors.darkGray)),
                                    ],
                                  ),
                                ),
                                // Quantity stepper
                                Container(
                                  decoration: BoxDecoration(color: AppColors.orange, borderRadius: BorderRadius.circular(8)),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      GestureDetector(
                                        onTap: () => _confirmRemoveItem(context, item),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                          child: Icon(item.quantity == 1 ? Icons.delete_outline : Icons.remove,
                                              color: Colors.white, size: 16),
                                        ),
                                      ),
                                      Text('${item.quantity}',
                                          style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
                                      GestureDetector(
                                        onTap: () => cart.increment(item.menuItemId),
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
                          )),
                    ],
                  ),
                ),
                // Checkout button
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                    child: SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.orange,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                        icon: const Icon(Icons.shopping_bag_rounded, size: 20),
                        label: Text('View Cart • Rs.${cart.subtotal.toStringAsFixed(0)}',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                        onPressed: () {
                          Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => CartScreen(),
                          ));
                        },
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// Asks for confirmation before deleting an item (when it's the last
  /// piece) or wiping the whole cart — a stray tap no longer empties the
  /// cart silently.
  Future<void> _confirmRemoveItem(BuildContext context, CartItem item) async {
    final cart = CartService.instance;
    if (item.quantity > 1) {
      cart.decrement(item.menuItemId);
      return;
    }
    final confirmed = await PremiumDialogs.showConfirm(
      context,
      title: 'Remove item?',
      message: 'Remove "${item.name}" from your cart?',
      confirmText: 'Remove',
      icon: Icons.delete_outline_rounded,
      isDestructive: true,
    );
    if (confirmed) {
      cart.remove(item.menuItemId);
    }
  }

  Future<void> _confirmClearCart(BuildContext context) async {
    final cart = CartService.instance;
    final confirmed = await PremiumDialogs.showConfirm(
      context,
      title: 'Clear cart?',
      message: 'All ${cart.totalItems} item(s) will be removed from your cart.',
      confirmText: 'Clear',
      icon: Icons.delete_sweep_rounded,
      isDestructive: true,
    );
    if (confirmed) {
      cart.clear();
    }
  }

  Widget _buildEmptyCart(bool isDark, double statusBarHeight) {
    final textColor = isDark ? Colors.white : AppColors.black;
    final subTextColor = isDark ? const Color(0xFFB0B0B0) : AppColors.darkGray;
    return Center(
      child: Padding(
        padding: EdgeInsets.only(top: statusBarHeight),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 88, height: 88,
              decoration: BoxDecoration(
                gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [AppColors.orange.withValues(alpha: 0.15), AppColors.orangePale]),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.shopping_cart_rounded, size: 44, color: AppColors.orange),
            ),
            const SizedBox(height: 24),
            Text('Your cart is empty', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: textColor)),
            const SizedBox(height: 8),
            Text('Browse restaurants and add items', style: TextStyle(fontSize: 14, color: subTextColor)),
          ],
        ),
      ),
    );
  }
}

// ─── Tab 4: Profile (Premium Design) ─────────────────────────
class _ProfileTab extends StatefulWidget {
  const _ProfileTab();

  @override
  State<_ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<_ProfileTab> {
  Map<String, dynamic>? _customer;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final data = await ApiService.customerGetMe();
      if (mounted) setState(() { _customer = data; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(backgroundColor: AppColors.offWhite, body: Center(child: CircularProgressIndicator(color: AppColors.orange, strokeWidth: 3)));
    }

    final statusBarHeight = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: AppColors.orange,
      body: Column(
        children: [
          // ─── Orange Header with Profile ───
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(24, statusBarHeight + 16, 24, 32),
            child: Row(
              children: [
                // Profile Photo
                Container(
                  width: 64, height: 64,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.25),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 2),
                  ),
                  child: Center(
                    child: Text((_customer?['name'] ?? 'U')[0].toUpperCase(), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Colors.white)),
                  ),
                ),
                const SizedBox(width: 16),
                // Name & Email
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_customer?['name'] ?? 'User', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white)),
                      const SizedBox(height: 4),
                      Text(_customer?['email'] ?? '', style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.8)), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // ─── White Menu Card ───
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(topLeft: Radius.circular(28), topRight: Radius.circular(28)),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 100),
                child: Column(
                  children: [
                    _buildProfileMenuItem(Icons.receipt_long_rounded, 'My Orders', () => _switchTab(1)),
                    _buildProfileMenuItem(Icons.person_rounded, 'Edit Profile', _showEditProfileSheet),
                    _buildProfileMenuItem(Icons.person_outline_rounded, 'View Profile', _showMyProfileSheet),
                    _buildProfileMenuItem(Icons.notifications_rounded, 'Notifications', () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NotificationsScreen()))),
                    _buildProfileMenuItem(Icons.location_on_rounded, 'Delivery Address', () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AddressScreen()))),
                    _buildProfileMenuItem(Icons.payment_rounded, 'Payment Methods', () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PaymentMethodScreen(totalAmount: 0)))),
                    _buildProfileMenuItem(Icons.qr_code_scanner_rounded, 'Scan QR Code', () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const QrScannerScreen()))),
                    _buildProfileMenuItem(Icons.qr_code_2_rounded, 'QR Generator', () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const QrGeneratorScreen()))),
                    _buildProfileMenuItem(Icons.phone_rounded, 'Contact Us', _showContactDialog),
                    _buildProfileMenuItem(Icons.help_rounded, 'Help & FAQs', _showHelpDialog),
                    _buildProfileMenuItem(Icons.settings_rounded, 'Settings', _showSettingsSheet),
                    const Divider(height: 1, color: Color(0xFFEEEEEE)),
                    const SizedBox(height: 8),
                    _buildProfileMenuItem(Icons.logout_rounded, 'Log Out', () async {
                      await ApiService.logout();
                      if (!mounted) return;
                      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const RoleSelectionScreen()));
                    }),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _switchTab(int index) {
    // Access parent to switch tabs
    final parentState = context.findAncestorStateOfType<State<UserHomeScreen>>();
    if (parentState != null && parentState is _UserHomeScreenState) {
      parentState._onItemTapped(index);
    }
  }

  /// Edit customer profile — name, phone & address (saved to backend).
  void _showEditProfileSheet() {
    final c = _customer ?? {};
    final nameController = TextEditingController(text: (c['name'] ?? '').toString());
    final phoneController = TextEditingController(text: (c['phone'] ?? '').toString());
    final addressController = TextEditingController(text: (c['address'] ?? '').toString());

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => Container(
        padding: EdgeInsets.fromLTRB(24, 20, 24, MediaQuery.of(sheetCtx).viewInsets.bottom + 24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Edit Profile', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 20),
            _editField(nameController, 'Full name', Icons.person_outline),
            const SizedBox(height: 14),
            _editField(phoneController, 'Phone number', Icons.phone_outlined, keyboard: TextInputType.phone),
            const SizedBox(height: 14),
            _editField(addressController, 'Delivery address', Icons.location_on_outlined),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () async {
                  if (nameController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(sheetCtx).showSnackBar(
                      const SnackBar(content: Text('Name cannot be empty'), backgroundColor: AppColors.orange),
                    );
                    return;
                  }
                  try {
                    await ApiService.customerUpdateProfile({
                      'name': nameController.text.trim(),
                      if (phoneController.text.trim().isNotEmpty) 'phone': phoneController.text.trim(),
                      if (addressController.text.trim().isNotEmpty) 'address': addressController.text.trim(),
                    });
                    if (sheetCtx.mounted) Navigator.pop(sheetCtx);
                    _loadProfile();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Profile updated ✓'), backgroundColor: AppColors.orange),
                      );
                    }
                  } catch (e) {
                    if (sheetCtx.mounted) {
                      ScaffoldMessenger.of(sheetCtx).showSnackBar(
                        SnackBar(content: Text(ErrorHelper.getMessage(e)), backgroundColor: const Color(0xFFE53935)),
                      );
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.orange,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: const Text('Save Changes', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _editField(TextEditingController controller, String hint, IconData icon, {TextInputType? keyboard}) {
    return TextField(
      controller: controller,
      keyboardType: keyboard,
      style: const TextStyle(fontSize: 15),
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, color: AppColors.orange, size: 20),
        fillColor: AppColors.lightGray,
        filled: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.orange, width: 2)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  void _showMyProfileSheet() {
    final c = _customer ?? {};
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Container(
                    width: 56, height: 56,
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text((c['name'] ?? 'U')[0].toUpperCase(), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.white)),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(c['name'] ?? 'User', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.black)),
                        const SizedBox(height: 2),
                        Text(c['email'] ?? '', style: const TextStyle(fontSize: 13, color: AppColors.darkGray)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _profileInfoRow(Icons.email_rounded, 'Email', c['email'] ?? '—'),
              _profileInfoRow(Icons.phone_rounded, 'Phone', (c['phone'] ?? '').toString().isEmpty ? 'Not set' : (c['phone'] ?? '—')),
              _profileInfoRow(Icons.location_on_rounded, 'Address', (c['address'] ?? '').toString().isEmpty ? 'Not set' : (c['address'] ?? '—')),
            ],
          ),
        ),
      ),
    );
  }

  Widget _profileInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: AppColors.orange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.orange, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 11, color: AppColors.darkGray)),
                Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.black)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showContactDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(children: [
          Icon(Icons.phone_rounded, color: AppColors.orange, size: 22),
          SizedBox(width: 10),
          Text('Contact Us'),
        ]),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('We are here to help, 24/7:', style: TextStyle(fontSize: 13, color: AppColors.darkGray)),
            SizedBox(height: 12),
            Row(children: [Icon(Icons.email_rounded, color: AppColors.orange, size: 18), SizedBox(width: 10), Flexible(child: Text('support@swiftdrop.pk', style: TextStyle(fontSize: 14)))]),
            SizedBox(height: 8),
            Row(children: [Icon(Icons.phone_rounded, color: AppColors.orange, size: 18), SizedBox(width: 10), Flexible(child: Text(AppSupport.supportPhone, style: TextStyle(fontSize: 14)))]),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.orange, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(children: [
          Icon(Icons.help_rounded, color: AppColors.orange, size: 22),
          SizedBox(width: 10),
          Text('Help & FAQs'),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _faqItem('How do I track my order?', 'Open Orders tab and tap your active order to see the rider live on the map.'),
            _faqItem('Can I cancel my order?', 'Yes, tap the order in Orders tab and choose Cancel while it is still pending.'),
            _faqItem('How do I pay?', 'Choose Cash, Card or UPI at checkout — pay on delivery for cash orders.'),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.orange, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Widget _faqItem(String q, String a) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('• $q', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.black)),
          const SizedBox(height: 2),
          Text(a, style: const TextStyle(fontSize: 12, color: AppColors.darkGray)),
        ],
      ),
    );
  }

  void _showSettingsSheet() {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                secondary: Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(themeProvider.isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded, color: AppColors.orange, size: 20),
                ),
                title: const Text('Dark Mode', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                subtitle: Text(themeProvider.isDark ? 'Dark theme on' : 'Light theme on', style: const TextStyle(fontSize: 12, color: AppColors.darkGray)),
                value: themeProvider.isDark,
                onChanged: (_) => themeProvider.toggleTheme(),
                activeThumbColor: AppColors.orange,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileMenuItem(IconData icon, String title, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: AppColors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: AppColors.orange, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.black)),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Color(0xFFCCCCCC)),
          ],
        ),
      ),
    );
  }
}