import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';

/// Premium Floating Navigation Bar — one shared design for the whole app.
/// White pill container, orange gradient active pill, smooth animations.
/// Used by Customer, Rider and Business home shells so the design stays identical.
class FloatingNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  /// Badge count shown on the Orders tab (pending orders for business, etc.)
  final int? notificationCount;

  /// false = Customer (4 tabs), true = Rider (5 tabs).
  final bool isRider;

  /// true = Business shell (Home, Menu, Orders, Profile + pending badge)
  final bool isBusiness;

  const FloatingNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.notificationCount,
    this.isRider = false,
    this.isBusiness = false,
  });

  List<_NavItem> _items() {
    if (isBusiness) {
      return const [
        _NavItem(icon: Icons.home_rounded, label: 'Home'),
        _NavItem(icon: Icons.restaurant_menu_rounded, label: 'Menu'),
        _NavItem(icon: Icons.receipt_long_rounded, label: 'Orders'),
        _NavItem(icon: Icons.storefront_rounded, label: 'Profile'),
      ];
    }
    if (isRider) {
      return const [
        _NavItem(icon: Icons.home_rounded, label: 'Home'),
        _NavItem(icon: Icons.receipt_long_rounded, label: 'Orders'),
        _NavItem(icon: Icons.account_balance_wallet_rounded, label: 'Earnings'),
        _NavItem(icon: Icons.map_rounded, label: 'Map'),
        _NavItem(icon: Icons.person_rounded, label: 'Profile'),
      ];
    }
    return const [
      _NavItem(icon: Icons.home_rounded, label: 'Home'),
      _NavItem(icon: Icons.receipt_long_rounded, label: 'Orders'),
      _NavItem(icon: Icons.shopping_cart_rounded, label: 'Cart'),
      _NavItem(icon: Icons.person_rounded, label: 'Profile'),
    ];
  }

  /// Index of the Orders tab per role (badge target).
  int get _ordersIndex => isBusiness ? 2 : 1;

  @override
  Widget build(BuildContext context) {
    final items = _items();
    final safeIndex = currentIndex.clamp(0, items.length - 1);

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Container(
        height: 70,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: AppColors.orange.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(items.length, (index) {
            return _buildNavItem(
              item: items[index],
              index: index,
              isSelected: safeIndex == index,
              badgeCount: index == _ordersIndex ? notificationCount : null,
            );
          }),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required _NavItem item,
    required int index,
    required bool isSelected,
    int? badgeCount,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap(index);
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOutCubic,
        padding: EdgeInsets.symmetric(
          horizontal: isSelected ? 14 : 8,
          vertical: 10,
        ),
        decoration: BoxDecoration(
          gradient: isSelected ? AppColors.primaryGradient : null,
          borderRadius: BorderRadius.circular(16),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.orange.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  item.icon,
                  size: 22,
                  color: isSelected ? Colors.white : AppColors.darkGray,
                ),
                if (badgeCount != null && badgeCount > 0)
                  Positioned(
                    top: -5,
                    right: -6,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                      child: Text(
                        badgeCount > 9 ? '9+' : '$badgeCount',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            if (isSelected) ...[
              const SizedBox(width: 8),
              Text(
                item.label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;

  const _NavItem({required this.icon, required this.label});
}
