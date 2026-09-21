import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// SwiftDrop Notifications — Orange gradient with white cards
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final List<_NotificationItem> _notifications = [
    _NotificationItem(
      icon: Icons.store_rounded,
      title: 'We have added new restaurants you might like.',
      time: '2 min ago',
    ),
    _NotificationItem(
      icon: Icons.favorite_rounded,
      title: 'One of your favourite is on promotion!',
      time: '15 min ago',
    ),
    _NotificationItem(
      icon: Icons.local_shipping_rounded,
      title: 'Your order has been delivered',
      time: '1 hour ago',
    ),
    _NotificationItem(
      icon: Icons.delivery_dining_rounded,
      title: 'The delivery is on his way',
      time: '2 hours ago',
    ),
    _NotificationItem(
      icon: Icons.store_rounded,
      title: 'New restaurant "Pizza Hub" is now open near you!',
      time: '3 hours ago',
    ),
    _NotificationItem(
      icon: Icons.local_offer_rounded,
      title: 'Flash Sale! 30% off on all orders today',
      time: '5 hours ago',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final statusBarHeight = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: const Color(0xFFFF6D00),
      body: Column(
        children: [
          // ─── Orange Header ───
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(20, statusBarHeight + 16, 20, 24),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white, size: 20),
                  ),
                ),
                const SizedBox(width: 16),
                const Icon(Icons.notifications_rounded, color: Colors.white, size: 24),
                const SizedBox(width: 10),
                const Text(
                  'Notifications',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white),
                ),
              ],
            ),
          ),
          // ─── White Notification List ───
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(topLeft: Radius.circular(28), topRight: Radius.circular(28)),
              ),
              child: _notifications.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 100),
                      itemCount: _notifications.length,
                      itemBuilder: (context, index) {
                        return _buildNotificationCard(_notifications[index], index);
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationCard(_NotificationItem item, int index) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 400 + (index * 100)),
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - value)),
            child: child,
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFF0F0F0)),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2)),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon container
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFFF6D00).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(item.icon, color: const Color(0xFFFF6D00), size: 22),
            ),
            const SizedBox(width: 14),
            // Text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.black, height: 1.4),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item.time,
                    style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: const Color(0xFFFF6D00).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.notifications_none_rounded, size: 40, color: Color(0xFFFF6D00)),
          ),
          const SizedBox(height: 16),
          const Text('No notifications', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text('You\'re all caught up!', style: TextStyle(fontSize: 14, color: Colors.grey[500])),
        ],
      ),
    );
  }
}

class _NotificationItem {
  final IconData icon;
  final String title;
  final String time;

  const _NotificationItem({
    required this.icon,
    required this.title,
    required this.time,
  });
}
