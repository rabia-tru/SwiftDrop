import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Premium Shimmer Loading Skeleton
class ShimmerLoading extends StatefulWidget {
  final double? width;
  final double height;
  final BorderRadius borderRadius;

  const ShimmerLoading({
    super.key,
    this.width,
    required this.height,
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
  });

  @override
  State<ShimmerLoading> createState() => _ShimmerLoadingState();
}

class _ShimmerLoadingState extends State<ShimmerLoading>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: widget.borderRadius,
            gradient: LinearGradient(
              begin: Alignment(-1.0 + 2.0 * _controller.value, 0),
              end: Alignment(-0.5 + 2.0 * _controller.value, 0),
              colors: [
                AppColors.lightGray,
                AppColors.lightGray.withValues(alpha: 0.5),
                AppColors.lightGray,
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Pre-built restaurant card skeleton
class RestaurantCardSkeleton extends StatelessWidget {
  const RestaurantCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image skeleton
          const ShimmerLoading(width: double.infinity, height: 140, borderRadius: BorderRadius.only(topLeft: Radius.circular(18), topRight: Radius.circular(18))),
          // Info skeleton
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                ShimmerLoading(width: 160, height: 16, borderRadius: BorderRadius.all(Radius.circular(8))),
                SizedBox(height: 8),
                ShimmerLoading(width: 120, height: 12, borderRadius: BorderRadius.all(Radius.circular(6))),
                SizedBox(height: 10),
                Row(
                  children: [
                    ShimmerLoading(width: 50, height: 12, borderRadius: BorderRadius.all(Radius.circular(6))),
                    SizedBox(width: 12),
                    ShimmerLoading(width: 60, height: 12, borderRadius: BorderRadius.all(Radius.circular(6))),
                    SizedBox(width: 12),
                    ShimmerLoading(width: 40, height: 12, borderRadius: BorderRadius.all(Radius.circular(6))),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Pre-built order card skeleton
class OrderCardSkeleton extends StatelessWidget {
  const OrderCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        children: const [
          ShimmerLoading(width: 44, height: 44, borderRadius: BorderRadius.all(Radius.circular(12))),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShimmerLoading(width: 140, height: 14, borderRadius: BorderRadius.all(Radius.circular(7))),
                SizedBox(height: 6),
                ShimmerLoading(width: 100, height: 11, borderRadius: BorderRadius.all(Radius.circular(5))),
              ],
            ),
          ),
          ShimmerLoading(width: 70, height: 24, borderRadius: BorderRadius.all(Radius.circular(12))),
        ],
      ),
    );
  }
}
