import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// SwiftDrop Status Badge — Premium with visible pulse animation
class StatusBadge extends StatefulWidget {
  final String status;
  final bool isLarge;

  const StatusBadge({super.key, required this.status, this.isLarge = false});

  @override
  State<StatusBadge> createState() => _StatusBadgeState();
}

class _StatusBadgeState extends State<StatusBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  bool get _shouldPulse => ['online', 'in_transit'].contains(widget.status.toLowerCase());
  bool get _isSuccess => widget.status.toLowerCase() == 'delivered';

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    if (_shouldPulse) _pulseController.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(StatusBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_shouldPulse && !_pulseController.isAnimating) {
      _pulseController.repeat(reverse: true);
    } else if (!_shouldPulse && _pulseController.isAnimating) {
      _pulseController.stop();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = _getBackgroundColor();
    final textColor = _getTextColor();
    final label = _getLabel();
    final pulse = _shouldPulse ? _pulseController.value : 0.0;

    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return Container(
          padding: widget.isLarge
              ? const EdgeInsets.symmetric(horizontal: 10, vertical: 5)
              : const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            gradient: _isSuccess
                ? const LinearGradient(colors: [Color(0xFF66BB6A), Color(0xFF2E7D32)])
                : (_shouldPulse ? LinearGradient(colors: [bgColor, bgColor.withValues(alpha: 0.85)]) : null),
            color: _isSuccess || _shouldPulse ? null : bgColor,
            borderRadius: BorderRadius.circular(9999),
            boxShadow: _shouldPulse
                ? [
                    // Inner glow
                    BoxShadow(
                      color: bgColor.withValues(alpha: 0.2 + (pulse * 0.2)),
                      blurRadius: 6 + (pulse * 4),
                      spreadRadius: pulse * 2,
                    ),
                    // Outer glow
                    BoxShadow(
                      color: bgColor.withValues(alpha: 0.08 + (pulse * 0.1)),
                      blurRadius: 12 + (pulse * 6),
                      spreadRadius: pulse * 3,
                    ),
                  ]
                : _isSuccess
                    ? [
                        BoxShadow(
                          color: const Color(0xFF2E7D32).withValues(alpha: 0.25),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Animated pulse dot for active states
              if (_shouldPulse)
                Container(
                  width: widget.isLarge ? 8 : 6,
                  height: widget.isLarge ? 8 : 6,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.white.withValues(alpha: 0.3 + (pulse * 0.4)),
                        blurRadius: 4 + (pulse * 3),
                        spreadRadius: pulse * 1,
                      ),
                    ],
                  ),
                )
              else
                Icon(
                  _isSuccess ? Icons.check_circle_rounded : _getIcon(),
                  size: widget.isLarge ? 14 : 11,
                  color: textColor,
                ),
              SizedBox(width: widget.isLarge ? 5 : 3),
              Text(label, style: TextStyle(
                fontSize: widget.isLarge ? 10 : 9,
                fontWeight: FontWeight.w700,
                color: textColor,
                letterSpacing: 0.5,
              )),
            ],
          ),
        );
      },
    );
  }

  Color _getTextColor() {
    switch (widget.status.toLowerCase()) {
      case 'online': return Colors.white;
      case 'offline': return AppColors.darkGray;
      case 'pending': return AppColors.orangeDark;
      case 'preparing': return Colors.white; // business accepted
      case 'assigned': return AppColors.darkGray;
      case 'accepted': return Colors.white;
      case 'picked_up': return Colors.white;
      case 'in_transit': return Colors.white;
      case 'delivered': return Colors.white;
      case 'cancelled': return AppColors.darkGray;
      default: return AppColors.darkGray;
    }
  }

  Color _getBackgroundColor() {
    switch (widget.status.toLowerCase()) {
      case 'online': return AppColors.orange;
      case 'offline': return AppColors.lightGray;
      case 'pending': return AppColors.orangePale;
      case 'preparing': return const Color(0xFF2E7D32); // green like business app
      case 'assigned': return AppColors.lightGray;
      case 'accepted': return AppColors.orange;
      case 'picked_up': return AppColors.orangeLight;
      case 'in_transit': return AppColors.orange;
      case 'delivered': return const Color(0xFF2E7D32);
      case 'cancelled': return AppColors.gray;
      default: return AppColors.lightGray;
    }
  }

  IconData _getIcon() {
    switch (widget.status.toLowerCase()) {
      case 'online': return Icons.check_circle;
      case 'offline': return Icons.power_settings_new;
      case 'pending': return Icons.access_time;
      case 'preparing': return Icons.restaurant; // business accepted
      case 'assigned': return Icons.person;
      case 'accepted': return Icons.done_all;
      case 'picked_up': return Icons.shopping_cart;
      case 'in_transit': return Icons.local_shipping;
      case 'delivered': return Icons.check_circle;
      case 'cancelled': return Icons.cancel;
      default: return Icons.help;
    }
  }

  String _getLabel() {
    switch (widget.status.toLowerCase()) {
      case 'picked_up': return 'PICKED UP';
      case 'in_transit': return 'IN TRANSIT';
      case 'pending': return 'PENDING';
      case 'preparing': return 'PREPARING 🔥'; // business accepted
      case 'assigned': return 'ASSIGNED';
      case 'accepted': return 'ACCEPTED';
      case 'delivered': return 'DELIVERED';
      case 'cancelled': return 'CANCELLED';
      case 'online': return 'ONLINE';
      case 'offline': return 'OFFLINE';
      default: return widget.status.toUpperCase();
    }
  }
}
