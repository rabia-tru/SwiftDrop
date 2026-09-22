import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../theme/app_colors.dart';
import '../services/api_service.dart';
import '../services/error_helper.dart';
import '../services/favorites_service.dart';
import '../services/websocket_service.dart';
import '../widgets/app_icon_badge.dart';
import '../widgets/shimmer_loading.dart';
import '../widgets/dish_filter.dart';
import 'restaurant_detail_screen.dart';

/// Restaurant data model — from backend Business entity
class Restaurant {
  final String id;
  final String name;
  final String image;
  final String cuisine;
  final double rating;
  final int reviewCount;
  final String deliveryTime;
  final double deliveryFee;
  final double distance;
  final bool isOpen;
  final List<String> categories;
  final List<MenuItem> menu;
  final double lat;
  final double lng;
  final String? offerText; // e.g. "20% OFF" or "Free Delivery"
  final bool isFeatured;

  const Restaurant({
    required this.id,
    required this.name,
    required this.image,
    required this.cuisine,
    this.rating = 4.0,
    this.reviewCount = 0,
    this.deliveryTime = '20-30 min',
    this.deliveryFee = 30,
    this.distance = 2.0,
    required this.isOpen,
    required this.categories,
    required this.menu,
    this.lat = 0,
    this.lng = 0,
    this.offerText,
    this.isFeatured = false,
  });

  factory Restaurant.fromBackend(Map<String, dynamic> biz, {int imageIndex = 0}) {
    // The list endpoint may embed the menu under any of these keys
    // depending on the backend serializer. Reading only 'menuItems' meant a
    // freshly added item never appeared in the list snapshot.
    final rawMenu = (biz['menuItems'] ?? biz['menu'] ?? biz['items']);
    final menuItems = (rawMenu is List ? rawMenu : const <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(MenuItem.fromBackend)
        .where((m) => m.isAvailable)
        .toList();

    final categories = menuItems.map((m) => m.category).toSet().toList();
    if (categories.isEmpty && biz['category'] != null) {
      categories.add(biz['category'].toString());
    }

    // Use business logo if available, otherwise use a food image
    String bizImage = '';
    if (biz['logoUrl'] != null && biz['logoUrl'].toString().isNotEmpty) {
      bizImage = biz['logoUrl'].toString();
    } else {
      bizImage = _getFoodImageForCategory((biz['category'] ?? '').toString().toLowerCase(), imageIndex);
    }

    return Restaurant(
      id: (biz['id'] ?? biz['_id'] ?? biz['businessId'] ?? '').toString(),
      name: biz['name'] ?? 'Restaurant',
      image: bizImage,
      cuisine: biz['category']?.toString() ?? 'Food',
      isOpen: biz['isOpen'] ?? true,
      categories: categories,
      menu: menuItems,
      lat: double.tryParse(biz['latitude']?.toString() ?? '') ?? 0,
      lng: double.tryParse(biz['longitude']?.toString() ?? '') ?? 0,
      offerText: biz['offerText'],
      isFeatured: biz['isFeatured'] ?? false,
    );
  }

}

// Food images for restaurants without photos (Unsplash)
const List<String> _foodImages = [
  'https://images.unsplash.com/photo-1565299624946-b28f40a0ae38?w=400&h=300&fit=crop',
  'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=400&h=300&fit=crop',
  'https://images.unsplash.com/photo-1562967914-608f82629710?w=400&h=300&fit=crop',
  'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?w=400&h=300&fit=crop',
  'https://images.unsplash.com/photo-1466978913421-dad2ebd01d17?w=400&h=300&fit=crop',
  'https://images.unsplash.com/photo-1550547660-d9450f859349?w=400&h=300&fit=crop',
  'https://images.unsplash.com/photo-1563379926898-05f4575a45d9?w=400&h=300&fit=crop',
  'https://images.unsplash.com/photo-1555939594-58d7cb561ad1?w=400&h=300&fit=crop',
  'https://images.unsplash.com/photo-1563805042-7684c0192e29?w=400&h=300&fit=crop',
  'https://images.unsplash.com/photo-1565958011703-44f9829ba187?w=400&h=300&fit=crop',
];

String _getFoodImageForCategory(String category, int index) {
  final cat = category.toLowerCase();
  if (cat.contains('pizza')) return _foodImages[0];
  if (cat.contains('burger') || cat.contains('fast food')) return _foodImages[1];
  if (cat.contains('pasta') || cat.contains('italian')) return _foodImages[2];
  if (cat.contains('noodle') || cat.contains('chinese')) return _foodImages[3];
  if (cat.contains('chicken')) return _foodImages[5];
  if (cat.contains('sushi') || cat.contains('japanese')) return _foodImages[6];
  if (cat.contains('dessert') || cat.contains('cake') || cat.contains('sweet')) return _foodImages[7];
  if (cat.contains('drink') || cat.contains('coffee') || cat.contains('beverage')) return _foodImages[8];
  return _foodImages[index % _foodImages.length];
}

/// Menu item data model
class MenuItem {
  final String id;
  final String name;
  final String description;
  final String image;
  final double price;
  final String category;
  final bool isVeg;
  final bool isBestseller;
  final bool isAvailable;

  const MenuItem({
    required this.id,
    required this.name,
    required this.description,
    required this.image,
    required this.price,
    required this.category,
    this.isVeg = false,
    this.isBestseller = false,
    this.isAvailable = true,
  });

  /// Builds a [MenuItem] from a raw menu item map returned by the backend
  /// (used both when loading the restaurant list and when refreshing a
  /// single restaurant's menu via `ApiService.getBusinessMenu`).
  factory MenuItem.fromBackend(Map<String, dynamic> item) {
    // Assign food images based on category for items without images.
    // Everything is read defensively: a single unexpected type (an int id,
    // a null category, imageUrl absent) used to throw and blank the menu.
    String itemImage = (item['imageUrl'] ?? item['image'] ?? '').toString().trim();
    final cat = (item['category'] ?? '').toString().toLowerCase();
    // Dead URLs (typos like "bsnsjejdjej", spaces, non-http strings) made
    // DecorationImage fail silently → grey cards. Anything that isn't a
    // plausible https URL gets the category fallback image instead.
    final validImage = itemImage.startsWith('https://') && !itemImage.contains(' ');
    if (!validImage) {
      itemImage = _getFoodImageForCategory(cat, _foodImages.length);
    }

    final rawCategory = (item['category'] ?? '').toString().trim().isEmpty
        ? 'Other'
        : (item['category'] ?? '').toString().trim();
    final tags = item['tags'];

    return MenuItem(
      id: (item['id'] ?? item['_id'] ?? '').toString(),
      name: (item['name'] ?? '').toString(),
      description: (item['description'] ?? '').toString(),
      image: itemImage,
      price: double.tryParse(item['price']?.toString() ?? '0') ?? 0,
      category: rawCategory.isEmpty ? 'Other' : rawCategory,
      isVeg: tags is List ? tags.map((t) => t.toString()).contains('vegetarian') : false,
      isBestseller: item['isFeatured'] == true,
      // Only an explicit `false` hides the item. A backend that doesn't
      // send this field at all must NOT make everything disappear.
      isAvailable: item['isAvailable'] != false && item['available'] != false,
    );
  }
}

/// FoodPanda-style cuisine categories with icons
class _CuisineCategory {
  final String name;
  final IconData icon;
  final String emoji;
  final String? imageUrl;

  const _CuisineCategory(this.name, this.icon, this.emoji, [this.imageUrl]);
}

/// Pinned search header — keeps the search bar docked at the top while the
/// restaurant list scrolls under it (FoodPanda/Glovo behaviour).
class _SearchHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  final Color bgColor;

  _SearchHeaderDelegate({required this.child, required this.bgColor});

  static const double _extent = 104; // search pill + suggestion chips row

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: bgColor, // opaque so list content never shows through
      alignment: Alignment.bottomCenter,
      child: child,
    );
  }

  @override
  double get maxExtent => _extent;

  @override
  double get minExtent => _extent;

  @override
  bool shouldRebuild(_SearchHeaderDelegate oldDelegate) =>
      oldDelegate.child != child || oldDelegate.bgColor != bgColor;
}

const List<_CuisineCategory> _cuisineCategories = [
  _CuisineCategory('All', Icons.grid_view_rounded, '🍽️',
      'https://images.unsplash.com/photo-1504674900247-0877df9cc836?w=160&h=160&fit=crop&auto=format&q=70'),
  _CuisineCategory('Burgers', Icons.lunch_dining, '🍔',
      'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=160&h=160&fit=crop&auto=format&q=70'),
  _CuisineCategory('Pizza', Icons.local_pizza, '🍕',
      'https://images.unsplash.com/photo-1513104890138-7c749659a591?w=160&h=160&fit=crop&auto=format&q=70'),
  _CuisineCategory('Chicken', Icons.set_meal, '🍗',
      'https://images.unsplash.com/photo-1626645738196-c2a7c87a8f58?w=160&h=160&fit=crop&auto=format&q=70'),
  _CuisineCategory('Biryani', Icons.rice_bowl, '🍛',
      'https://images.unsplash.com/photo-1633945274405-b6c8069047b0?w=160&h=160&fit=crop&auto=format&q=70'),
  _CuisineCategory('Chinese', Icons.takeout_dining, '🥡',
      'https://images.unsplash.com/photo-1585032226651-759b368d7246?w=160&h=160&fit=crop&auto=format&q=70'),
  _CuisineCategory('Desserts', Icons.cake, '🍰',
      'https://images.unsplash.com/photo-1551024506-0bccd828d307?w=160&h=160&fit=crop&auto=format&q=70'),
  _CuisineCategory('Drinks', Icons.local_cafe, '☕',
      'https://images.unsplash.com/photo-1541519227354-08fa5d50c44d?w=160&h=160&fit=crop&auto=format&q=70'),
  _CuisineCategory('Fast Food', Icons.fastfood, '🌮',
      'https://images.unsplash.com/photo-1550547660-d9450f859349?w=160&h=160&fit=crop&auto=format&q=70'),
  _CuisineCategory('BBQ', Icons.outdoor_grill, '🥩',
      'https://images.unsplash.com/photo-1555939594-58d7cb561ad1?w=160&h=160&fit=crop&auto=format&q=70'),
];

/// FoodPanda-style promotional banner
class _PromoBanner {
  final String title;
  final String subtitle;
  final String? imageUrl;
  final Color bgColor;
  final Color textColor;
  final IconData icon;
  final int discountOff;

  const _PromoBanner({
    required this.title,
    required this.subtitle,
    this.imageUrl,
    this.bgColor = AppColors.orange,
    this.textColor = Colors.white,
    this.icon = Icons.local_offer,
    this.discountOff = 0,
  });
}

/// SwiftDrop Restaurant Listing — Foodpanda-style browsing
class RestaurantListScreen extends StatefulWidget {
  const RestaurantListScreen({super.key});

  @override
  State<RestaurantListScreen> createState() => _RestaurantListScreenState();
}

class _RestaurantListScreenState extends State<RestaurantListScreen> {
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();
  final _bannerController = PageController(viewportFraction: 0.92);
  String _selectedCategory = 'All';
  DishSort _dishSort = DishSort.relevance;
  List<Restaurant> _restaurants = [];
  bool _loading = true;
  String? _loadError;
  int _currentBanner = 0;
  Timer? _bannerTimer;
  String _userLocation = 'Fetching location...';

  /// Trending quick-search chips shown under the search bar.
  static const List<String> _searchSuggestions = [
    'Biryani', 'Pizza', 'Burger', 'BBQ', 'Shawarma', 'Cake',
  ];

    final List<_PromoBanner> _banners = [
    _PromoBanner(
      title: 'Super Sizzling Deals',
      subtitle: 'Free delivery on first 3 orders',
      bgColor: Color(0xFFE23744),
      textColor: Colors.white,
      icon: Icons.local_fire_department_rounded,
      imageUrl: _foodImages[0],
      discountOff: 30,
    ),
    _PromoBanner(
      title: 'Burger Bonanza',
      subtitle: 'Up to Rs.200 off on combos',
      bgColor: AppColors.orange,
      textColor: Colors.white,
      icon: Icons.lunch_dining_rounded,
      imageUrl: _foodImages[1],
      discountOff: 25,
    ),
    _PromoBanner(
      title: 'Noodle Night',
      subtitle: 'Chicken + Veggie noodles',
      bgColor: Color(0xFF1E3A5F),
      textColor: Colors.white,
      icon: Icons.air_rounded,
      imageUrl: _foodImages[2],
      discountOff: 20,
    ),
    _PromoBanner(
      title: 'Breakfast Bundle',
      subtitle: 'Coffee + Sandwich Rs.149',
      bgColor: Color(0xFF2D4A2D),
      textColor: Colors.white,
      icon: Icons.kitchen_rounded,
      imageUrl: _foodImages[3],
      discountOff: 40,
    ),
    _PromoBanner(
      title: 'Pasta Paradise',
      subtitle: 'Italian specials all week',
      bgColor: Color(0xFF8B0000),
      textColor: Colors.white,
      icon: Icons.restaurant_rounded,
      imageUrl: _foodImages[4],
      discountOff: 35,
    ),
  ];

  StreamSubscription? _menuUpdatedSub;

  @override
  void initState() {
    super.initState();
    _loadBusinesses();
    _startBannerAutoScroll();
    _loadFavorites();
    _fetchUserLocation();

    // Any business's menu changing means our cached list (which embeds a
    // menu snapshot per business) is stale — refetch it live.
    final ws = WebSocketService.instance;
    ws.connect();
    _menuUpdatedSub = ws.menuUpdatedStream.listen((_) => _loadBusinesses());
  }

  Future<void> _fetchUserLocation() async {
    try {
      // Check if location services are enabled
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          setState(() => _userLocation = 'Location services disabled');
          _showLocationDialog(
            'Location Services Disabled',
            'Please enable location services to see nearby restaurants.',
            true,
          );
        }
        return;
      }

      // Check location permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            setState(() => _userLocation = 'Location permission denied');
            _showLocationDialog(
              'Location Permission Required',
              'SwiftDrop needs location access to show nearby restaurants.',
              false,
            );
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          setState(() => _userLocation = 'Location permission denied');
          _showLocationDialog(
            'Location Permission Required',
            'Please enable location permission in app settings to see nearby restaurants.',
            false,
          );
        }
        return;
      }

      // Get current position
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
      
      if (mounted) {
        setState(() {
          _userLocation = '${position.latitude.toStringAsFixed(2)}, ${position.longitude.toStringAsFixed(2)}';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _userLocation = 'Location unavailable');
      }
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
              decoration: const BoxDecoration(
                color: AppColors.orangePale,
                shape: BoxShape.circle,
              ),
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

  Future<void> _loadFavorites() async {
    await FavoritesService.loadFavorites();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _bannerTimer?.cancel();
    _bannerController.dispose();
    _searchController.dispose();
    _searchFocus.dispose();
    _menuUpdatedSub?.cancel();
    super.dispose();
  }

  void _startBannerAutoScroll() {
    _bannerTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (_bannerController.hasClients) {
        final next = (_currentBanner + 1) % _banners.length;
        _bannerController.animateToPage(next,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  Future<void> _loadBusinesses() async {
    try {
      final businesses = await ApiService.getAllBusinesses();
      if (mounted) {
        setState(() {
          _restaurants = businesses.asMap().entries.map((entry) {
            return Restaurant.fromBackend(entry.value, imageIndex: entry.key);
          }).toList();
          _loading = false;
          _loadError = null;
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



  /// Restaurants matching the search query only. When a category chip is
  /// active the screen shows matching MENU ITEMS instead (see
  /// [_filteredItems]) — same behavior as the home screen's chips.
  List<Restaurant> get _filteredRestaurants {
    var list = _restaurants;

    final query = _searchController.text.toLowerCase();
    if (query.isNotEmpty) {
      list = list.where((r) =>
        r.name.toLowerCase().contains(query) ||
        r.cuisine.toLowerCase().contains(query) ||
        r.menu.any((m) => m.name.toLowerCase().contains(query))
      ).toList();
    }

    return list;
  }

  /// Menu items (dish + its restaurant) matching the selected category chip.
  /// Tapping "Desserts" shows dessert dishes, "Drinks" shows drinks — not
  /// whole restaurants that merely contain them.
  List<MapEntry<MenuItem, Restaurant>> get _filteredItems {
    if (_selectedCategory == 'All') return const [];
    final matchesCategory = categoryMatcher(_selectedCategory);
    final result = <MapEntry<MenuItem, Restaurant>>[];
    for (final r in _restaurants) {
      final query = _searchController.text.toLowerCase();
      if (query.isNotEmpty) {
        final restaurantMatches = r.name.toLowerCase().contains(query) ||
            r.cuisine.toLowerCase().contains(query) ||
            r.menu.any((m) => m.name.toLowerCase().contains(query));
        if (!restaurantMatches) continue;
      }
      for (final m in r.menu) {
        if (matchesCategory(m.category) || matchesCategory(m.name)) {
          result.add(MapEntry(m, r));
        }
      }
    }
    sortDishes(result, _dishSort);
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0A0A0A) : AppColors.offWhite;
    final textColor = isDark ? Colors.white : AppColors.black;

    AppColors.setLightStatusBar();
    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          onRefresh: _loadBusinesses,
          color: AppColors.orange,
          child: CustomScrollView(
            slivers: [
              // Header
              SliverToBoxAdapter(child: _buildHeader(textColor)),
              // Search bar — pinned: stays visible when the list scrolls
              SliverPersistentHeader(
                pinned: true,
                floating: true,
                delegate: _SearchHeaderDelegate(
                  child: _buildSearchBar(isDark),
                  bgColor: bgColor,
                ),
              ),
              // Promo banners carousel
              SliverToBoxAdapter(child: _buildPromoBanners()),
              // Cuisine category icons
              SliverToBoxAdapter(child: _buildCuisineIcons(isDark)),
              // Category chip active → dishes of that category (same as home)
              if (_selectedCategory != 'All') ...[
                SliverToBoxAdapter(child: _buildSectionHeaderWithSort(
                  _selectedCategory,
                  textColor,
                  subtitle: _loading ? null : '${_filteredItems.length} item${_filteredItems.length == 1 ? '' : 's'} found',
                )),
                if (_loading)
                  SliverToBoxAdapter(child: const SizedBox(height: 200))
                else if (_filteredItems.isEmpty)
                  SliverToBoxAdapter(child: _buildEmptyState(textColor))
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
                        (context, index) {
                          final e = _filteredItems[index];
                          return DishCard(item: e.key, restaurant: e.value);
                        },
                        childCount: _filteredItems.length,
                      ),
                    ),
                  ),
              ] else ...[
              // Featured/Recommended section
              if (!_loading && _restaurants.isNotEmpty)
                SliverToBoxAdapter(child: _buildSectionHeader('Featured', textColor)),
              if (!_loading && _restaurants.where((r) => r.isFeatured).isNotEmpty)
                SliverToBoxAdapter(child: _buildFeaturedRestaurants(isDark)),
              // All Restaurants header
              SliverToBoxAdapter(child: _buildSectionHeader('All Restaurants', textColor)),
              // Shimmer Loading Skeletons
              if (_loading)
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      const SizedBox(height: 8),
                      const RestaurantCardSkeleton(),
                      const RestaurantCardSkeleton(),
                      const RestaurantCardSkeleton(),
                      const RestaurantCardSkeleton(),
                    ]),
                  ),
                )
              // Restaurant list
              else if (_filteredRestaurants.isEmpty)
                SliverToBoxAdapter(child: _buildEmptyState(textColor))
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: _buildRestaurantCard(_filteredRestaurants[index], isDark),
                      ),
                      childCount: _filteredRestaurants.length,
                    ),
                  ),
                ),
              ],
              // Bottom padding
              const SliverToBoxAdapter(child: SizedBox(height: 20)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(Color textColor) {
    final statusBarHeight = MediaQuery.of(context).padding.top;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, statusBarHeight + 8, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const AppIconBadge(size: 44, padding: 6, showGlow: false),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('SwiftDrop', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: textColor)),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.location_on_rounded, color: AppColors.orange, size: 12),
                        const SizedBox(width: 3),
                        Text(_userLocation, style: TextStyle(fontSize: 12, color: AppColors.darkGray)),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                width: 38, height: 38,
                decoration: BoxDecoration(color: AppColors.orangePale, borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.notifications_none_rounded, color: AppColors.orange, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('What are you craving?', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: textColor)),
              const Spacer(),
              Text('Today • 12:00 PM', style: TextStyle(fontSize: 12, color: AppColors.darkGray)),
            ],
          ),
          const SizedBox(height: 2),
          Text('Order from your favourite restaurants', style: TextStyle(fontSize: 13, color: AppColors.darkGray)),
        ],
      ),
    );
  }

  Widget _buildSearchBar(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── Search field — soft pill, animated focus glow ───
          Focus(
            onFocusChange: (_) => setState(() {}),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              height: 54,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
                borderRadius: BorderRadius.circular(27),
                border: Border.all(
                  color: _searchFocus.hasFocus
                      ? AppColors.orange
                      : AppColors.orange.withValues(alpha: 0.12),
                  width: _searchFocus.hasFocus ? 1.8 : 1,
                ),
                boxShadow: _searchFocus.hasFocus
                    ? [
                        BoxShadow(color: AppColors.orange.withValues(alpha: 0.18), blurRadius: 16, offset: const Offset(0, 4)),
                        BoxShadow(color: AppColors.orange.withValues(alpha: 0.06), blurRadius: 4, offset: const Offset(0, 1)),
                      ]
                    : [BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05), blurRadius: 10, offset: const Offset(0, 3))],
              ),
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocus,
                onChanged: (_) => setState(() {}),
                textInputAction: TextInputAction.search,
                style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w500, color: isDark ? Colors.white : AppColors.black),
                cursorColor: AppColors.orange,
                decoration: InputDecoration(
                  hintText: 'Search restaurants or cravings...',
                  hintStyle: TextStyle(color: AppColors.darkGray.withValues(alpha: 0.45), fontSize: 14.5, fontWeight: FontWeight.w400),
                  prefixIcon: Container(
                    margin: const EdgeInsets.only(left: 6, right: 10),
                    child: Center(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        width: 38, height: 38,
                        decoration: BoxDecoration(
                          gradient: _searchFocus.hasFocus || _searchController.text.isNotEmpty
                              ? const LinearGradient(colors: [AppColors.orange, Color(0xFFFF8A3D)])
                              : null,
                          color: _searchFocus.hasFocus || _searchController.text.isNotEmpty
                              ? null
                              : AppColors.orange.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.search_rounded, color: Colors.white, size: 19),
                      ),
                    ),
                  ),
                  prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                  suffixIcon: _searchController.text.isNotEmpty
                    ? Padding(
                        padding: const EdgeInsets.only(right: 14),
                        child: GestureDetector(
                          onTap: () { _searchController.clear(); setState(() {}); },
                          child: Container(
                            width: 26, height: 26,
                            decoration: BoxDecoration(
                              color: AppColors.darkGray.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close_rounded, color: AppColors.darkGray, size: 15),
                          ),
                        ),
                      )
                    : null,
                  suffixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ),
          // ─── Quick suggestion chips (show when search empty) ───
          AnimatedBuilder(
            animation: _searchController,
            builder: (context, _) {
              if (_searchController.text.isNotEmpty) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(top: 10),
                child: SizedBox(
                  height: 30,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    itemCount: _searchSuggestions.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, i) {
                      final suggestion = _searchSuggestions[i];
                      return GestureDetector(
                        onTap: () {
                          _searchController.text = suggestion;
                          _searchController.selection = TextSelection.fromPosition(TextPosition(offset: suggestion.length));
                          setState(() {});
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white.withValues(alpha: 0.06) : AppColors.orange.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(color: AppColors.orange.withValues(alpha: 0.15), width: 1),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.trending_up_rounded, size: 13, color: AppColors.orange),
                              const SizedBox(width: 5),
                              Text(suggestion, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : AppColors.darkGray)),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // PROMO BANNERS CAROUSEL (FoodPanda-style)
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Widget _buildPromoBanners() {
    return Column(
      children: [
        SizedBox(
          height: 170,
          child: PageView.builder(
            controller: _bannerController,
            itemCount: _banners.length,
            onPageChanged: (i) => setState(() => _currentBanner = i),
            itemBuilder: (context, index) => _buildBannerCard(_banners[index]),
          ),
        ),
        const SizedBox(height: 10),
        // Dot indicators
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(_banners.length, (i) => AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: i == _currentBanner ? 20 : 6,
            height: 6,
            decoration: BoxDecoration(
              color: i == _currentBanner ? AppColors.orange : AppColors.orange.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(3),
            ),
          )),
        ),
      ],
    );
  }

  /// Offers & Deals bottom sheet — shown when a promo banner is tapped.
  /// Lists live discount businesses from the backend plus the banner deal.
  void _showOffersSheet(_PromoBanner banner) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sheetColor = isDark ? const Color(0xFF1A1A1A) : Colors.white;
    final textColor = isDark ? Colors.white : AppColors.black;

    // Restaurants currently running an offer, from loaded data.
    final offerRestaurants = _restaurants
        .where((r) => r.offerText != null && r.offerText!.isNotEmpty)
        .toList();

    showModalBottomSheet(
      context: context,
      backgroundColor: sheetColor,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.62,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        builder: (ctx, scrollController) => Column(
          children: [
            // Grab handle + title
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
              decoration: BoxDecoration(
                color: sheetColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 2))],
              ),
              child: Column(
                children: [
                  Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.darkGray.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Container(
                        width: 42, height: 42,
                        decoration: BoxDecoration(
                          color: banner.bgColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(banner.icon, color: banner.bgColor == AppColors.orange ? AppColors.orange : banner.bgColor, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Offers & Deals', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: textColor)),
                            const SizedBox(height: 2),
                            Text('${banner.discountOff}% OFF • ${banner.title}', style: TextStyle(fontSize: 12.5, color: AppColors.darkGray)),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pop(ctx),
                        child: Container(
                          width: 30, height: 30,
                          decoration: BoxDecoration(
                            color: AppColors.darkGray.withValues(alpha: 0.08),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close_rounded, size: 16, color: AppColors.darkGray),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Deal highlight card
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [banner.bgColor, banner.bgColor.withValues(alpha: 0.75)],
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text('${banner.discountOff}% OFF', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white)),
                          ),
                          const SizedBox(height: 8),
                          Text(banner.title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Colors.white)),
                          const SizedBox(height: 2),
                          Text(banner.subtitle, style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.85))),
                        ],
                      ),
                    ),
                    Icon(banner.icon, size: 44, color: Colors.white.withValues(alpha: 0.9)),
                  ],
                ),
              ),
            ),
            // Live offer restaurants
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Restaurants with live offers', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: textColor)),
              ),
            ),
            Expanded(
              child: offerRestaurants.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.local_offer_rounded, size: 44, color: AppColors.darkGray.withValues(alpha: 0.3)),
                        const SizedBox(height: 10),
                        Text('No live offers right now', style: TextStyle(fontSize: 13.5, color: AppColors.darkGray)),
                        const SizedBox(height: 4),
                        Text('Check back soon for new deals!', style: TextStyle(fontSize: 12, color: AppColors.darkGray.withValues(alpha: 0.6))),
                      ],
                    ),
                  )
                : ListView.separated(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                    itemCount: offerRestaurants.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (ctx, i) {
                      final r = offerRestaurants[i];
                      return GestureDetector(
                        onTap: () {
                          Navigator.pop(ctx);
                          Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => RestaurantDetailScreen(restaurant: r),
                          ));
                        },
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white.withValues(alpha: 0.05) : AppColors.offWhite,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.orange.withValues(alpha: 0.15)),
                          ),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.network(
                                  r.image, width: 56, height: 56, fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => Container(
                                    width: 56, height: 56,
                                    color: AppColors.orangePale,
                                    child: const Icon(Icons.storefront_rounded, color: AppColors.orange, size: 22),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(r.name, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: textColor), maxLines: 1, overflow: TextOverflow.ellipsis),
                                    const SizedBox(height: 2),
                                    Text(r.cuisine, style: TextStyle(fontSize: 11.5, color: AppColors.darkGray), maxLines: 1, overflow: TextOverflow.ellipsis),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.orange,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(r.offerText ?? '', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white)),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBannerCard(_PromoBanner banner) {
    return GestureDetector(
      onTap: () => _showOffersSheet(banner),
      child: Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: banner.bgColor.withValues(alpha: 0.4), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Background image
            if (banner.imageUrl != null && banner.imageUrl!.isNotEmpty)
              Image.network(banner.imageUrl!, fit: BoxFit.cover,
                errorBuilder: (c, e, s) => Container(color: banner.bgColor)),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [banner.bgColor.withValues(alpha: 0.7), banner.bgColor.withValues(alpha: 0.1)],
                ),
              ),
            ),
            // Discount badge top-left
            Positioned(
              top: 10, left: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(banner.icon, size: 12, color: banner.textColor.withValues(alpha: 0.95)),
                    SizedBox(width: 4),
                    Text('${banner.discountOff}% OFF', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: banner.textColor)),
                  ],
                ),
              ),
            ),
            // Free shipping tag
            if (banner.discountOff >= 20)
              Positioned(
                top: 10, right: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.local_shipping_rounded, size: 11, color: Colors.white),
                      SizedBox(width: 2),
                      Text('Free Shipping', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: Colors.white)),
                    ],
                  ),
                ),
              ),
            // Bottom content
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(banner.title, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: banner.textColor)),
                    const SizedBox(height: 4),
                    Text(banner.subtitle, style: TextStyle(fontSize: 13, color: banner.textColor.withValues(alpha: 0.85))),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(25),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('ORDER NOW', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: banner.textColor)),
                                SizedBox(width: 8),
                                const Icon(Icons.arrow_forward, size: 14, color: Colors.white),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text('${banner.discountOff}% OFF', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: banner.textColor)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // CUISINE CATEGORY ICONS (FoodPanda-style visual categories)
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Widget _buildCuisineIcons(bool isDark) {
    return SizedBox(
      height: 100,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        itemCount: _cuisineCategories.length,
        itemBuilder: (context, index) {
          final cat = _cuisineCategories[index];
          final isSelected = cat.name == _selectedCategory;
          return GestureDetector(
            onTap: () => setState(() => _selectedCategory = cat.name),
            child: Container(
              width: 72,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 56, height: 56,
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.orange : (isDark ? const Color(0xFF1A1A1A) : Colors.white),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? AppColors.orange : AppColors.orange.withValues(alpha: 0.15),
                        width: isSelected ? 2.5 : 1.5,
                      ),
                      boxShadow: isSelected
                        ? [BoxShadow(color: AppColors.orange.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 3))]
                        : [],
                    ),
                    child: ClipOval(
                      child: cat.imageUrl != null
                          ? Image.network(
                              cat.imageUrl!,
                              width: 56, height: 56,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Center(
                                child: Text(cat.emoji, style: const TextStyle(fontSize: 24)),
                              ),
                              loadingBuilder: (context, child, progress) {
                                if (progress == null) return child;
                                return Center(
                                  child: Text(cat.emoji, style: TextStyle(fontSize: 24, color: AppColors.orange.withValues(alpha: 0.5))),
                                );
                              },
                            )
                          : Center(
                              child: Text(cat.emoji, style: const TextStyle(fontSize: 24)),
                            ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    cat.name,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected ? AppColors.orange : AppColors.darkGray,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title, Color textColor) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Row(
        children: [
          Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: textColor)),
          const Spacer(),
          if (title == 'All Restaurants')
            Text('${_filteredRestaurants.length} places', style: TextStyle(fontSize: 13, color: AppColors.darkGray)),
        ],
      ),
    );
  }

  /// Header for the dish grid shown while a category chip is active —
  /// count on the left, sort selector on the right.
  Widget _buildSectionHeaderWithSort(String title, Color textColor, {String? subtitle}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: textColor)),
                if (subtitle != null)
                  Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
              ],
            ),
          ),
          DishSortButton(
            current: _dishSort,
            onChanged: (s) => setState(() => _dishSort = s),
          ),
        ],
      ),
    );
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // FEATURED RESTAURANTS (horizontal scroll)
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Widget _buildFeaturedRestaurants(bool isDark) {
    final featured = _restaurants.where((r) => r.isFeatured).toList();
    if (featured.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 200,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: featured.length,
        itemBuilder: (context, index) => _buildFeaturedCard(featured[index], isDark),
      ),
    );
  }

  Widget _buildFeaturedCard(Restaurant r, bool isDark) {
    final cardColor = isDark ? const Color(0xFF1A1A1A) : Colors.white;
    final img = r.image.isNotEmpty ? r.image : '';
    return GestureDetector(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => RestaurantDetailScreen(restaurant: r),
      )),
      child: Container(
        width: 210,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 3))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(img, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft, end: Alignment.bottomRight,
                          colors: [AppColors.orange.withValues(alpha: 0.15), AppColors.orangePale],
                        ),
                      ),
                      child: const Center(child: Icon(Icons.restaurant, size: 32, color: AppColors.orange)),
                    ),
                  ),
                  // Featured badge
                  Positioned(
                    top: 8, left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(color: AppColors.orange, borderRadius: BorderRadius.circular(6)),
                      child: const Text('★ FEATURED', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.white)),
                    ),
                  ),
                  // Offer badge
                  if (r.offerText != null)
                    Positioned(
                      bottom: 0, left: 0, right: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: Color(0xFFE23744),
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                        ),
                        child: Text(r.offerText!, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.white)),
                      ),
                    ),
                  // Delivery time
                  Positioned(
                    top: 8, right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.access_time, color: AppColors.orange, size: 10),
                          const SizedBox(width: 2),
                          Text(r.deliveryTime, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(r.name, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: isDark ? Colors.white : AppColors.black), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      const Icon(Icons.star, color: AppColors.orange, size: 12),
                      const SizedBox(width: 3),
                      Text('${r.rating}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.orange)),
                      const SizedBox(width: 8),
                      Icon(Icons.delivery_dining, color: AppColors.darkGray.withValues(alpha: 0.5), size: 12),
                      const SizedBox(width: 3),
                      Text(r.deliveryFee == 0 ? 'Free' : 'Rs.${r.deliveryFee.toStringAsFixed(0)}', style: TextStyle(fontSize: 11, color: r.deliveryFee == 0 ? AppColors.statusDelivered : AppColors.darkGray)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRestaurantCard(Restaurant restaurant, bool isDark) {
    final img = restaurant.image.isNotEmpty ? restaurant.image : '';
    final cardColor = isDark ? const Color(0xFF1A1A1A) : Colors.white;
    final textColor = isDark ? Colors.white : AppColors.black;

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => RestaurantDetailScreen(restaurant: restaurant),
        ));
      },
      child: Container(
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 3))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Restaurant image with stacked badges
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
              child: Container(
                height: 140,
                width: double.infinity,
                color: AppColors.orangePale,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.network(
                      img, fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft, end: Alignment.bottomRight,
                              colors: [AppColors.orange.withValues(alpha: 0.1), AppColors.orangePale],
                            ),
                          ),
                          child: const Center(child: SizedBox(width: 24, height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(AppColors.orange)))),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) => _buildFallbackImage(),
                    ),
                    // Offer badge
                    if (restaurant.offerText != null)
                      Positioned(
                        bottom: 0, left: 0, right: 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                              colors: [Color(0xFFE23744), Color(0xFFFF6B6B)],
                            ),
                            borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
                          ),
                          child: Text(restaurant.offerText!, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
                        ),
                      ),
                    // OPEN/CLOSED badge
                    Positioned(
                      top: 10, left: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: restaurant.isOpen ? AppColors.statusDelivered : AppColors.darkGray,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(restaurant.isOpen ? 'OPEN' : 'CLOSED',
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
                      ),
                    ),
                    // Delivery time badge
                    Positioned(
                      top: 10, right: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 3)],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.access_time, color: AppColors.orange, size: 12),
                            const SizedBox(width: 3),
                            Text(restaurant.deliveryTime, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),
                    // Favorite button
                    Positioned(
                      bottom: 10, right: 10,
                      child: GestureDetector(
                        onTap: () async {
                          await FavoritesService.toggleFavorite(restaurant.id);
                          if (mounted) setState(() {});
                        },
                        child: Container(
                          width: 32, height: 32,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4)],
                          ),
                          child: Icon(
                            FavoritesService.isFavorite(restaurant.id)
                              ? Icons.favorite
                              : Icons.favorite_border,
                            color: AppColors.orange,
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Restaurant info
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(restaurant.name, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: textColor), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(color: AppColors.orangePale, borderRadius: BorderRadius.circular(6)),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.star, color: AppColors.orange, size: 12),
                            const SizedBox(width: 2),
                            Text('${restaurant.rating}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.orange)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(restaurant.cuisine, style: TextStyle(fontSize: 12, color: AppColors.darkGray), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.circle, color: AppColors.orange.withValues(alpha: 0.5), size: 6),
                      const SizedBox(width: 4),
                      Text('${restaurant.distance.toStringAsFixed(1)} km', style: TextStyle(fontSize: 11, color: AppColors.darkGray)),
                      const SizedBox(width: 10),
                      Icon(Icons.delivery_dining, color: AppColors.orange.withValues(alpha: 0.5), size: 12),
                      const SizedBox(width: 3),
                      Text(restaurant.deliveryFee == 0 ? 'Free' : 'Rs.${restaurant.deliveryFee.toStringAsFixed(0)}',
                          style: TextStyle(fontSize: 11, color: restaurant.deliveryFee == 0 ? AppColors.statusDelivered : AppColors.darkGray)),
                      const SizedBox(width: 10),
                      Icon(Icons.restaurant_menu, color: AppColors.orange.withValues(alpha: 0.5), size: 12),
                      const SizedBox(width: 3),
                      Text('${restaurant.menu.length} items', style: TextStyle(fontSize: 11, color: AppColors.darkGray)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFallbackImage() {
    return const Center(child: Icon(Icons.restaurant_rounded, size: 40, color: AppColors.orange));
  }

  Widget _buildEmptyState(Color textColor) {
    // Load failure (server unreachable) — show error + retry, not "no results"
    if (_loadError != null) {
      return Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(color: AppColors.orangePale, shape: BoxShape.circle),
              child: const Icon(Icons.wifi_off_rounded, size: 48, color: AppColors.orange),
            ),
            const SizedBox(height: 16),
            Text(_loadError!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.black)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () { setState(() => _loading = true); _loadBusinesses(); },
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.orange, foregroundColor: Colors.white),
            ),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(color: AppColors.orangePale, shape: BoxShape.circle),
            child: const Icon(Icons.search_off, size: 48, color: AppColors.orange),
          ),
          const SizedBox(height: 16),
          Text('No restaurants found', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: textColor)),
          const SizedBox(height: 8),
          Text('Try a different search or category', style: TextStyle(fontSize: 14, color: AppColors.darkGray)),
        ],
      ),
    );
  }
}