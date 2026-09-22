import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../widgets/floating_nav_bar.dart';
import '../services/chat_unread_service.dart';
import '../widgets/exit_confirm_dialog.dart';
import 'home_screen.dart';
import 'orders_screen.dart';
import 'earnings_screen.dart';
import 'map_screen.dart';
import 'profile_screen.dart';

/// SwiftDrop Rider Navigation — shared floating nav bar (5 tabs)
class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  /// Global key so other screens (e.g. rider Home quick actions) can switch
  /// tabs without pushing duplicate routes.
  static final GlobalKey<_MainNavigationState> navKey =
      GlobalKey<_MainNavigationState>();

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;
  late PageController _pageController;

  /// Called by child screens to jump to a tab.
  void switchToTab(int index) => _onItemTapped(index);

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
      // same pattern as the customer/business shells.
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
          systemNavigationBarColor: isDark ? const Color(0xFF0A0A0A) : Colors.white,
        ),
        child: Scaffold(
          key: MainNavigation.navKey,
          body: PageView(
            controller: _pageController,
            physics: const NeverScrollableScrollPhysics(),
            children: const [
              HomeScreen(),       // Index 0: Home
              OrdersScreen(),     // Index 1: Orders
              EarningsScreen(),   // Index 2: Earnings
              MapScreen(),        // Index 3: Map
              ProfileScreen(),    // Index 4: Profile
            ],
          ),
          bottomNavigationBar: ListenableBuilder(
            listenable: ChatUnreadService.instance,
            builder: (context, _) => FloatingNavBar(
              currentIndex: _currentIndex,
              onTap: _onItemTapped,
              isRider: true,
              notificationCount: ChatUnreadService.instance.totalUnreads,
            ),
          ),
        ),
      ),
    );
  }
}
