import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/cart_service.dart';
import '../screens/restaurant_list_screen.dart' show MenuItem, Restaurant;
import '../screens/restaurant_detail_screen.dart' hide CartItem;
import '../theme/app_colors.dart';

/// Shared category-filter logic + dish card used by the customer home screen
/// and the restaurant list screen, so both behave identically.
///
/// Filters must show what they promise: "Dessert" shows desserts, "Drinks"
/// shows cold drinks. Menu items (not restaurants) are shown for a category.

/// Maps a category chip label to the DB menu-item categories and dish names
/// it should match. Keys are matched case-insensitively against the chip.
const Map<String, List<String>> kCategoryKeywords = {
  'snacks': ['snack', 'sides', 'starters', 'rolls', 'shawarma', 'fried chicken', 'wings', 'fries'],
  'meal': ['pizza', 'burger', 'desi', 'bbq', 'biryani', 'chinese', 'breakfast', 'ramen', 'sushi', 'bowls', 'main course', 'platters', 'salads', 'wraps', 'fast food', 'deals'],
  'dessert': ['dessert', 'desserts', 'bakery', 'cake', 'sweet', 'kulfi', 'ice cream', 'gulab', 'kheer'],
  'drinks': ['drink', 'beverage', 'shake', 'juice', 'cola', 'coffee', 'chai', 'lassi', 'water', 'mojito', 'smoothie'],
};

/// True when [chipLabel] matches [text] (a dish name or menu category).
/// Unknown chips (e.g. "Pizza" on the list screen) fall back to a substring
/// check so every chip still filters meaningfully.
bool categoryMatches(String chipLabel, String text) {
  final keywords = kCategoryKeywords[chipLabel.toLowerCase().trim()];
  final t = text.toLowerCase();
  if (keywords != null) return keywords.any(t.contains);
  return t.contains(chipLabel.toLowerCase().trim());
}

/// Predicate form for matching many texts against one chip label.
bool Function(String) categoryMatcher(String chipLabel) =>
    (String text) => categoryMatches(chipLabel, text);

/// How the dish grid is ordered.
enum DishSort { relevance, priceLowHigh, priceHighLow, ratingHighLow }

/// Sorts dish+restaurant pairs in place according to [sort].
/// relevance = original API order (nothing done).
void sortDishes(List<MapEntry<MenuItem, Restaurant>> dishes, DishSort sort) {
  switch (sort) {
    case DishSort.relevance:
      break;
    case DishSort.priceLowHigh:
      dishes.sort((a, b) => a.key.price.compareTo(b.key.price));
      break;
    case DishSort.priceHighLow:
      dishes.sort((a, b) => b.key.price.compareTo(a.key.price));
      break;
    case DishSort.ratingHighLow:
      dishes.sort((a, b) => b.value.rating.compareTo(a.value.rating));
      break;
  }
}

/// Human labels for the sort options.
const Map<DishSort, String> kDishSortLabels = {
  DishSort.relevance: 'Default',
  DishSort.priceLowHigh: 'Price: Low to High',
  DishSort.priceHighLow: 'Price: High to Low',
  DishSort.ratingHighLow: 'Top Rated',
};

/// A single dish card for category-filtered results — the dish's image,
/// price, its restaurant, and a quick add-to-cart "＋" button with a
/// quantity badge. Tapping the card opens the restaurant.
class DishCard extends StatelessWidget {
  const DishCard({super.key, required this.item, required this.restaurant});

  final MenuItem item;
  final Restaurant restaurant;

  @override
  Widget build(BuildContext context) {
    // Rebuild only when the cart changes so the qty badge stays live.
    final cart = context.watch<CartService>();
    final qty = cart.quantityOf(item.id);
    return GestureDetector(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => RestaurantDetailScreen(restaurant: restaurant),
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
            // Dish image with quick add button
            Expanded(
              flex: 3,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Image.network (not DecorationImage) so a dead URL shows
                  // the food-icon fallback instead of a silent grey box.
                  Container(
                    color: AppColors.orangePale,
                    child: Image.network(
                      item.image,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => const Center(
                        child: Icon(Icons.restaurant_rounded, size: 36, color: AppColors.orange),
                      ),
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;
                        return Center(
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.orange),
                              value: progress.expectedTotalBytes != null
                                  ? progress.cumulativeBytesLoaded / progress.expectedTotalBytes!
                                  : null,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  Positioned(
                    right: 6,
                    bottom: 6,
                    child: GestureDetector(
                      onTap: () => _addToCart(context, cart),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: AppColors.orange,
                          shape: BoxShape.circle,
                          boxShadow: [BoxShadow(color: AppColors.orange.withValues(alpha: 0.4), blurRadius: 6, offset: const Offset(0, 2))],
                        ),
                        child: Center(
                          child: qty > 0
                              ? Text('$qty', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800))
                              : const Icon(Icons.add_rounded, color: Colors.white, size: 20),
                        ),
                      ),
                    ),
                  ),
                ],
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
                    Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text('from ${restaurant.name}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                    const Spacer(),
                    Row(
                      children: [
                        const Icon(Icons.star_rounded, size: 13, color: Color(0xFFFFC107)),
                        const SizedBox(width: 2),
                        Text('${restaurant.rating}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                        const Spacer(),
                        Text('Rs.${item.price.toStringAsFixed(0)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.orange)),
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

  void _addToCart(BuildContext context, CartService cart) {
    if (cart.hasConflictWith(restaurant.id)) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Start a new cart?'),
          content: Text('Your cart has items from ${cart.restaurantName}. Adding from ${restaurant.name} will replace them.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                cart.switchRestaurant(restaurant: restaurant, item: item);
              },
              child: const Text('Replace', style: TextStyle(color: AppColors.orange, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      );
      return;
    }
    cart.tryAdd(restaurant: restaurant, item: item);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('${item.name} added to cart'),
      backgroundColor: AppColors.orange,
      duration: const Duration(milliseconds: 1200),
    ));
  }
}

/// Bottom sheet to pick a sort option. Returns the chosen [DishSort], or
/// null if dismissed without changing anything.
Future<DishSort?> showDishSortSheet(BuildContext context, DishSort current) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return showModalBottomSheet<DishSort>(
    context: context,
    backgroundColor: isDark ? const Color(0xFF1A1A1A) : Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Sort by', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            ),
          ),
          ...kDishSortLabels.entries.map((e) => ListTile(
                leading: Icon(
                  e.key == DishSort.priceLowHigh || e.key == DishSort.priceHighLow
                      ? Icons.payments_outlined
                      : e.key == DishSort.ratingHighLow
                          ? Icons.star_rounded
                          : Icons.sort,
                  color: AppColors.orange,
                ),
                title: Text(e.value),
                trailing: e.key == current
                    ? const Icon(Icons.check_rounded, color: AppColors.orange)
                    : null,
                onTap: () => Navigator.pop(ctx, e.key),
              )),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

/// Small pill button that shows the active sort and opens the sort sheet.
/// Returns the chosen sort (or null = keep current) via its callback.
class DishSortButton extends StatelessWidget {
  const DishSortButton({super.key, required this.current, required this.onChanged});

  final DishSort current;
  final ValueChanged<DishSort> onChanged;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final picked = await showDishSortSheet(context, current);
        if (picked != null) onChanged(picked);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.orange.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.orange.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.sort_rounded, size: 15, color: AppColors.orange),
            const SizedBox(width: 5),
            Text(
              kDishSortLabels[current]!,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.orange),
            ),
          ],
        ),
      ),
    );
  }
}
