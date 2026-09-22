import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';

/// Premium Animated Tag/Chip with bounce selection animation
class AnimatedTag extends StatefulWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final IconData? icon;
  final bool isSmall;

  const AnimatedTag({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.icon,
    this.isSmall = false,
  });

  @override
  State<AnimatedTag> createState() => _AnimatedTagState();
}

class _AnimatedTagState extends State<AnimatedTag>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.92).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        HapticFeedback.lightImpact();
        _controller.forward();
      },
      onTapUp: (_) {
        _controller.reverse();
        widget.onTap();
      },
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(
        scale: _scaleAnim,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          padding: EdgeInsets.symmetric(
            horizontal: widget.isSmall ? 10 : 14,
            vertical: widget.isSmall ? 6 : 8,
          ),
          decoration: BoxDecoration(
            gradient: widget.isSelected
                ? AppColors.primaryGradient
                : null,
            color: widget.isSelected ? null : Colors.white,
            borderRadius: BorderRadius.circular(widget.isSmall ? 10 : 12),
            border: Border.all(
              color: widget.isSelected
                  ? AppColors.orange
                  : AppColors.orange.withValues(alpha: 0.15),
              width: widget.isSelected ? 1.5 : 1,
            ),
            boxShadow: widget.isSelected
                ? [
                    BoxShadow(
                      color: AppColors.orange.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.icon != null) ...[
                Icon(
                  widget.icon,
                  size: widget.isSmall ? 14 : 16,
                  color: widget.isSelected ? Colors.white : AppColors.orange,
                ),
                SizedBox(width: widget.isSmall ? 4 : 6),
              ],
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: widget.isSmall ? 11 : 13,
                  fontWeight: FontWeight.w600,
                  color: widget.isSelected ? Colors.white : AppColors.orange,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
