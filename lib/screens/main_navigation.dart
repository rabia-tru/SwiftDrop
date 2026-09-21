import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../widgets/floating_nav_bar.dart';
import '../services/chat_unread_service.dart';
import 'home_screen.dart';
import 'orders_screen.dart';
import 'earnings_screen.dart';
import 'map_screen.dart';
import 'profile_screen.dart';

/// SwiftDrop Rider Navigation — shared floating nav bar (5 tabs)
class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
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

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: isDark ? const Color(0xFF0A0A0A) : Colors.white,
      ),
      child: Scaffold(
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
    );
  }
}
