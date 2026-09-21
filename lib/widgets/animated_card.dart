import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';

/// Premium Animated Card — Smooth slide-in with fade + scale + press feedback
class AnimatedCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final int index;
  final Duration delay;
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry? padding;
  final double borderRadius;
  final Color? color;

  const AnimatedCard({
    super.key,
    required this.child,
    this.onTap,
    this.index = 0,
    this.delay = const Duration(milliseconds: 80),
    this.margin,
    this.padding,
    this.borderRadius = 20,
    this.color,
  });

  @override
  State<AnimatedCard> createState() => _AnimatedCardState();
}

class _AnimatedCardState extends State<AnimatedCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    final startDelay = Duration(milliseconds: widget.index * widget.delay.inMilliseconds);

    Future.delayed(startDelay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.5)),
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.12),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic)),
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.96, end: 1.0).animate(
            CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
          ),
          child: GestureDetector(
            onTapDown: (_) { HapticFeedback.lightImpact(); setState(() => _pressed = true); },
            onTapUp: (_) { setState(() => _pressed = false); widget.onTap?.call(); },
            onTapCancel: () => setState(() => _pressed = false),
            child: AnimatedScale(
              scale: _pressed ? 0.97 : 1.0,
              duration: const Duration(milliseconds: 120),
              curve: Curves.easeOutCubic,
              child: Container(
                margin: widget.margin ?? const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: widget.color ?? Colors.white,
                  borderRadius: BorderRadius.circular(widget.borderRadius),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: _pressed ? 0.06 : 0.04),
                      blurRadius: _pressed ? 16 : 12,
                      offset: Offset(0, _pressed ? 6 : 4),
                    ),
                    BoxShadow(
                      color: AppColors.orange.withValues(alpha: _pressed ? 0.08 : 0.04),
                      blurRadius: _pressed ? 12 : 8,
                      offset: Offset(0, _pressed ? 4 : 2),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(widget.borderRadius),
                  child: Padding(
                    padding: widget.padding ?? const EdgeInsets.all(16),
                    child: widget.child,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
