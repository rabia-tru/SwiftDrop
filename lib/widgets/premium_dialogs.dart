import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Premium Animated Dialogs & Toasts — High Quality
class PremiumDialogs {
  // ─── Success SnackBar ──────────────────────────────────
  static void showSuccess(BuildContext context, String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: _AnimatedToast(icon: Icons.check_rounded, message: message, bgColor: const Color(0xFF2E7D32)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // ─── Error SnackBar ────────────────────────────────────
  static void showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: _AnimatedToast(icon: Icons.error_outline_rounded, message: message, bgColor: const Color(0xFFC62828)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  // ─── Info SnackBar ─────────────────────────────────────
  static void showInfo(BuildContext context, String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: _AnimatedToast(icon: Icons.info_outline_rounded, message: message, bgColor: AppColors.orange),
        backgroundColor: Colors.transparent,
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // ─── Confirm Dialog ────────────────────────────────────
  static Future<bool> showConfirm(
    BuildContext context, {
    required String title,
    required String message,
    String confirmText = 'Confirm',
    String cancelText = 'Cancel',
    IconData icon = Icons.help_outline_rounded,
    Color iconColor = AppColors.orange,
    bool isDestructive = false,
  }) async {
    final result = await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 350),
      transitionBuilder: (ctx, a1, a2, child) {
        final curved = CurvedAnimation(parent: a1, curve: Curves.easeOutBack);
        return ScaleTransition(
          scale: curved,
          child: FadeTransition(opacity: CurvedAnimation(parent: a1, curve: const Interval(0.0, 0.7)), child: child),
        );
      },
      pageBuilder: (ctx, a1, a2) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        backgroundColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _AnimatedIconCircle(icon: icon, color: iconColor, size: 64),
              const SizedBox(height: 20),
              Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800), textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(message, style: const TextStyle(fontSize: 14, color: AppColors.darkGray, height: 1.5), textAlign: TextAlign.center),
              const SizedBox(height: 28),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: BorderSide(color: AppColors.gray.withValues(alpha: 0.5)),
                        ),
                      ),
                      child: Text(cancelText, style: const TextStyle(color: AppColors.darkGray, fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _GradientButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      label: confirmText,
                      isDestructive: isDestructive,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    return result ?? false;
  }

  // ─── Success Dialog ────────────────────────────────────
  static void showSuccessDialog(
    BuildContext context, {
    required String title,
    required String message,
    String buttonText = 'Continue',
    VoidCallback? onPressed,
  }) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 400),
      transitionBuilder: (ctx, a1, a2, child) {
        final curved = CurvedAnimation(parent: a1, curve: Curves.easeOutBack);
        return ScaleTransition(
          scale: curved,
          child: FadeTransition(opacity: CurvedAnimation(parent: a1, curve: const Interval(0.0, 0.6)), child: child),
        );
      },
      pageBuilder: (ctx, a1, a2) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        backgroundColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _AnimatedSuccessCheck(),
              const SizedBox(height: 24),
              Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800), textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(message, style: const TextStyle(fontSize: 14, color: AppColors.darkGray, height: 1.5), textAlign: TextAlign.center),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: _GradientButton(
                  onPressed: onPressed ?? () => Navigator.of(context).pop(),
                  label: buttonText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Loading Dialog ────────────────────────────────────
  static void showLoading(BuildContext context, {String message = 'Please wait...'}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        backgroundColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _AnimatedLoadingDots(),
              const SizedBox(height: 20),
              Text(message, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ),
    );
  }

  static void hideLoading(BuildContext context) {
    Navigator.of(context).pop();
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// HIGH-QUALITY ANIMATED INTERNAL WIDGETS
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

/// Animated toast with slide-in + bounce + glow shadow
class _AnimatedToast extends StatefulWidget {
  final IconData icon;
  final String message;
  final Color bgColor;

  const _AnimatedToast({required this.icon, required this.message, required this.bgColor});

  @override
  State<_AnimatedToast> createState() => _AnimatedToastState();
}

class _AnimatedToastState extends State<_AnimatedToast>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _controller.forward();
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
        final slideY = Curves.easeOutBack.transform(_controller.value.clamp(0.0, 1.0));
        final scale = 0.85 + (Curves.easeOutBack.transform(_controller.value.clamp(0.0, 1.0)) * 0.15);
        final opacity = Curves.easeIn.transform(_controller.value.clamp(0.0, 1.0));

        return Transform.translate(
          offset: Offset(0, (1 - slideY) * 30),
          child: Transform.scale(
            scale: scale,
            child: Opacity(
              opacity: opacity,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: widget.bgColor,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: widget.bgColor.withValues(alpha: 0.4),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                      spreadRadius: -2,
                    ),
                    BoxShadow(
                      color: widget.bgColor.withValues(alpha: 0.15),
                      blurRadius: 30,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // Animated icon circle with scale
                    Transform.scale(
                      scale: Curves.elasticOut.transform(_controller.value.clamp(0.0, 1.0)),
                      child: Container(
                        width: 34, height: 34,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.25),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white.withValues(alpha: 0.15), width: 1),
                        ),
                        child: Icon(widget.icon, color: Colors.white, size: 18),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(widget.message, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white, height: 1.3)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Animated icon circle with double pulse ring
class _AnimatedIconCircle extends StatefulWidget {
  final IconData icon;
  final Color color;
  final double size;

  const _AnimatedIconCircle({required this.icon, required this.color, required this.size});

  @override
  State<_AnimatedIconCircle> createState() => _AnimatedIconCircleState();
}

class _AnimatedIconCircleState extends State<_AnimatedIconCircle>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))
      ..repeat(reverse: true);
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
        final pulse = _controller.value;
        return SizedBox(
          width: widget.size + 32,
          height: widget.size + 32,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Outer pulse ring (large, faint)
              Container(
                width: widget.size + 24 + (pulse * 12),
                height: widget.size + 24 + (pulse * 12),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: widget.color.withValues(alpha: 0.08 + (pulse * 0.04)),
                    width: 1.5,
                  ),
                ),
              ),
              // Inner pulse ring (medium, more visible)
              Container(
                width: widget.size + 12 + (pulse * 6),
                height: widget.size + 12 + (pulse * 6),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: widget.color.withValues(alpha: 0.12 + (pulse * 0.08)),
                    width: 2,
                  ),
                ),
              ),
              // Main circle with gradient
              Container(
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [widget.color.withValues(alpha: 0.15), widget.color.withValues(alpha: 0.08)],
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: widget.color.withValues(alpha: 0.1),
                    width: 1,
                  ),
                ),
                child: Icon(widget.icon, color: widget.color, size: widget.size * 0.5),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Animated success check with elastic bounce + draw effect
class _AnimatedSuccessCheck extends StatefulWidget {
  const _AnimatedSuccessCheck();

  @override
  State<_AnimatedSuccessCheck> createState() => _AnimatedSuccessCheckState();
}

class _AnimatedSuccessCheckState extends State<_AnimatedSuccessCheck>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))
      ..forward();
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
        final scale = Curves.elasticOut.transform(_controller.value);
        final glowIntensity = Curves.easeIn.transform(_controller.value);
        return Transform.scale(
          scale: scale,
          child: Container(
            width: 88, height: 88,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF81C784), Color(0xFF43A047), Color(0xFF2E7D32)],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF2E7D32).withValues(alpha: 0.2 + (glowIntensity * 0.2)),
                  blurRadius: 20 + (glowIntensity * 10),
                  offset: const Offset(0, 8),
                  spreadRadius: glowIntensity * 4,
                ),
              ],
            ),
            child: const Icon(Icons.check_rounded, color: Colors.white, size: 48),
          ),
        );
      },
    );
  }
}

/// Animated loading dots — bouncing with gradient
class _AnimatedLoadingDots extends StatefulWidget {
  const _AnimatedLoadingDots();

  @override
  State<_AnimatedLoadingDots> createState() => _AnimatedLoadingDotsState();
}

class _AnimatedLoadingDotsState extends State<_AnimatedLoadingDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))
      ..repeat();
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
      builder: (context, _) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(3, (index) {
            final delay = index * 0.18;
            final value = (_controller.value + delay) % 1.0;
            // Smooth sine wave: 0→1→0
            final bounce = sin(value * pi);
            final size = 8 + (bounce * 10);
            final yOffset = -bounce * 8;

            return Transform.translate(
              offset: Offset(0, yOffset),
              child: Container(
                width: size, height: size,
                margin: const EdgeInsets.symmetric(horizontal: 5),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.orange, AppColors.orangeDark],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.orange.withValues(alpha: bounce * 0.3),
                      blurRadius: bounce * 8,
                    ),
                  ],
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

/// Gradient button with press scale + glow
class _GradientButton extends StatefulWidget {
  final VoidCallback? onPressed;
  final String label;
  final bool isDestructive;

  const _GradientButton({required this.onPressed, required this.label, this.isDestructive = false});

  @override
  State<_GradientButton> createState() => _GradientButtonState();
}

class _GradientButtonState extends State<_GradientButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) { setState(() => _pressed = false); widget.onPressed?.call(); },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.94 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: double.infinity,
          height: 52,
          decoration: BoxDecoration(
            gradient: widget.isDestructive
                ? const LinearGradient(colors: [Color(0xFFE53935), Color(0xFFC62828)])
                : const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.orange, AppColors.orangeDark],
                  ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: (widget.isDestructive ? const Color(0xFFE53935) : AppColors.orange)
                    .withValues(alpha: _pressed ? 0.5 : 0.3),
                blurRadius: _pressed ? 20 : 12,
                offset: Offset(0, _pressed ? 8 : 4),
                spreadRadius: _pressed ? 1 : 0,
              ),
            ],
          ),
          child: Center(
            child: Text(
              widget.label,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 0.3),
            ),
          ),
        ),
      ),
    );
  }
}
