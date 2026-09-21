import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// App icon with an orange-gradient circular backing + soft glow so the
/// transparent-icon artwork never disappears against orange gradients,
/// dark backgrounds, or busy imagery. Use everywhere the raw transparent
/// icon would otherwise look odd.
///
/// For a floating effect, wrap this widget in your screen's own
/// `Transform.translate` (most splash/login screens already have one).
class AppIconBadge extends StatelessWidget {
  const AppIconBadge({
    super.key,
    this.size = 72,
    this.padding = 10,
    this.showGlow = true,
  });

  /// Total outer diameter (backing circle).
  final double size;

  /// Inner padding around the icon artwork.
  final double padding;

  final bool showGlow;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: AppColors.primaryGradient,
        boxShadow: showGlow
            ? [
                BoxShadow(
                  color: AppColors.orange.withValues(alpha: 0.35),
                  blurRadius: size * 0.35,
                  offset: const Offset(0, 6),
                ),
              ]
            : null,
      ),
      padding: EdgeInsets.all(padding),
      child: Image.asset(
        'assets/icon/app_icon.png',
        fit: BoxFit.contain,
      ),
    );
  }
}
