import 'dart:math';
import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
import '../theme/app_colors.dart';

/// Premium Confetti Celebration — High Quality with staggered bursts
class ConfettiCelebration extends StatefulWidget {
  final Widget child;
  final bool showConfetti;
  final Duration duration;

  const ConfettiCelebration({
    super.key,
    required this.child,
    this.showConfetti = false,
    this.duration = const Duration(seconds: 5),
  });

  @override
  State<ConfettiCelebration> createState() => _ConfettiCelebrationState();
}

class _ConfettiCelebrationState extends State<ConfettiCelebration>
    with TickerProviderStateMixin {
  late ConfettiController _centerController;
  late ConfettiController _leftController;
  late ConfettiController _rightController;
  late ConfettiController _burstController;

  @override
  void initState() {
    super.initState();
    _centerController = ConfettiController(duration: widget.duration);
    _leftController = ConfettiController(duration: const Duration(seconds: 4));
    _rightController = ConfettiController(duration: const Duration(seconds: 4));
    _burstController = ConfettiController(duration: const Duration(seconds: 3));

    if (widget.showConfetti) _startCelebration();
  }

  @override
  void didUpdateWidget(ConfettiCelebration oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.showConfetti && !oldWidget.showConfetti) _startCelebration();
  }

  void _startCelebration() {
    // Staggered bursts for cinematic effect
    _centerController.play();
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _leftController.play();
    });
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) _rightController.play();
    });
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) _burstController.play();
    });
  }

  @override
  void dispose() {
    _centerController.dispose();
    _leftController.dispose();
    _rightController.dispose();
    _burstController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,

        // ─── Burst 1: Center-top (main) ───
        Align(
          alignment: Alignment.topCenter,
          child: ConfettiWidget(
            confettiController: _centerController,
            blastDirectionality: BlastDirectionality.explosive,
            shouldLoop: false,
            colors: const [
              Color(0xFFFF6D00), Color(0xFFE64A19), Color(0xFFFF8A65),
              Color(0xFFFFCCBC), Colors.white, Color(0xFF4CAF50),
              Color(0xFFFFEB3B), Color(0xFF2196F3), Color(0xFFE91E63),
            ],
            numberOfParticles: 35,
            gravity: 0.08,
            emissionFrequency: 0.04,
            minimumSize: const Size(8, 8),
            maximumSize: const Size(16, 16),
            blastDirection: -pi / 2,
            createParticlePath: _drawStar,
          ),
        ),

        // ─── Burst 2: Left side (delayed) ───
        Align(
          alignment: Alignment.centerLeft,
          child: ConfettiWidget(
            confettiController: _leftController,
            blastDirectionality: BlastDirectionality.explosive,
            shouldLoop: false,
            colors: const [
              Color(0xFFFF6D00), Color(0xFFE64A19), Colors.white,
              Color(0xFFFFEB3B), Color(0xFF4CAF50),
            ],
            numberOfParticles: 20,
            gravity: 0.12,
            emissionFrequency: 0.06,
            minimumSize: const Size(6, 6),
            maximumSize: const Size(12, 12),
          ),
        ),

        // ─── Burst 3: Right side (delayed) ───
        Align(
          alignment: Alignment.centerRight,
          child: ConfettiWidget(
            confettiController: _rightController,
            blastDirectionality: BlastDirectionality.explosive,
            shouldLoop: false,
            colors: const [
              Color(0xFFFF6D00), Color(0xFFFF8A65), Colors.white,
              Color(0xFF2196F3), Color(0xFFE91E63),
            ],
            numberOfParticles: 20,
            gravity: 0.12,
            emissionFrequency: 0.06,
            minimumSize: const Size(6, 6),
            maximumSize: const Size(12, 12),
          ),
        ),

        // ─── Burst 4: Extra sparkle wave ───
        Align(
          alignment: const Alignment(0, -0.3),
          child: ConfettiWidget(
            confettiController: _burstController,
            blastDirectionality: BlastDirectionality.explosive,
            shouldLoop: false,
            colors: const [
              Color(0xFFFFEB3B), Colors.white, Color(0xFFFFCCBC),
            ],
            numberOfParticles: 15,
            gravity: 0.06,
            emissionFrequency: 0.08,
            minimumSize: const Size(4, 4),
            maximumSize: const Size(8, 8),
          ),
        ),
      ],
    );
  }

  /// Draw a star-shaped particle
  Path _drawStar(Size size) {
    final path = Path();
    final w = size.width;
    final h = size.height;
    path.moveTo(w * 0.5, 0);
    path.lineTo(w * 0.62, h * 0.38);
    path.lineTo(w, h * 0.38);
    path.lineTo(w * 0.68, h * 0.62);
    path.lineTo(w * 0.82, h);
    path.lineTo(w * 0.5, h * 0.75);
    path.lineTo(w * 0.18, h);
    path.lineTo(w * 0.32, h * 0.62);
    path.lineTo(0, h * 0.38);
    path.lineTo(w * 0.38, h * 0.38);
    path.close();
    return path;
  }
}

/// Celebration overlay dialog — premium with staggered confetti
class DeliveryCelebrationDialog extends StatefulWidget {
  final String orderId;
  final String? restaurantName;
  final VoidCallback? onRateNow;
  final VoidCallback? onContinue;

  const DeliveryCelebrationDialog({
    super.key,
    required this.orderId,
    this.restaurantName,
    this.onRateNow,
    this.onContinue,
  });

  @override
  State<DeliveryCelebrationDialog> createState() => _DeliveryCelebrationDialogState();
}

class _DeliveryCelebrationDialogState extends State<DeliveryCelebrationDialog>
    with TickerProviderStateMixin {
  late ConfettiController _confettiController;
  late ConfettiController _burstController;
  late AnimationController _animController;
  late Animation<double> _scaleAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 6));
    _burstController = ConfettiController(duration: const Duration(seconds: 3));
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));

    _scaleAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOutBack);
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: const Interval(0.0, 0.5)),
    );

    _animController.forward();
    _confettiController.play();
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) _burstController.play();
    });
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _burstController.dispose();
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Backdrop
        FadeTransition(
          opacity: _fadeAnim,
          child: GestureDetector(
            onTap: widget.onContinue,
            child: Container(color: Colors.black54),
          ),
        ),

        // Main confetti
        Align(
          alignment: Alignment.topCenter,
          child: ConfettiWidget(
            confettiController: _confettiController,
            blastDirectionality: BlastDirectionality.explosive,
            shouldLoop: false,
            colors: const [
              Color(0xFFFF6D00), Color(0xFFE64A19), Color(0xFFFF8A65),
              Color(0xFFFFCCBC), Colors.white, Color(0xFF4CAF50),
              Color(0xFFFFEB3B), Color(0xFF2196F3),
            ],
            numberOfParticles: 45,
            gravity: 0.06,
            emissionFrequency: 0.03,
            minimumSize: const Size(8, 8),
            maximumSize: const Size(18, 18),
          ),
        ),

        // Extra sparkle burst
        Align(
          alignment: const Alignment(0, -0.2),
          child: ConfettiWidget(
            confettiController: _burstController,
            blastDirectionality: BlastDirectionality.explosive,
            shouldLoop: false,
            colors: const [Color(0xFFFFEB3B), Colors.white, Color(0xFFFFCCBC)],
            numberOfParticles: 20,
            gravity: 0.05,
            emissionFrequency: 0.06,
            minimumSize: const Size(4, 4),
            maximumSize: const Size(10, 10),
          ),
        ),

        // Center card
        Center(
          child: ScaleTransition(
            scale: _scaleAnim,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 32),
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(color: AppColors.orange.withValues(alpha: 0.25), blurRadius: 40, offset: const Offset(0, 12), spreadRadius: -4),
                  BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 20, offset: const Offset(0, 4)),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Animated check
                  Container(
                    width: 92, height: 92,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft, end: Alignment.bottomRight,
                        colors: [Color(0xFF81C784), Color(0xFF43A047), Color(0xFF2E7D32)],
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: const Color(0xFF2E7D32).withValues(alpha: 0.3), blurRadius: 24, offset: const Offset(0, 8), spreadRadius: 2),
                      ],
                    ),
                    child: const Icon(Icons.check_rounded, color: Colors.white, size: 52),
                  ),
                  const SizedBox(height: 20),
                  const Text('Delivered!', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: AppColors.black)),
                  const SizedBox(height: 8),
                  Text('Your order has been\nsuccessfully delivered', style: TextStyle(fontSize: 15, color: AppColors.darkGray, height: 1.5), textAlign: TextAlign.center),
                  if (widget.restaurantName != null) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                      decoration: BoxDecoration(
                        color: AppColors.orangePale.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.orange.withValues(alpha: 0.15), width: 1),
                      ),
                      child: Text(widget.restaurantName!, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.orange)),
                    ),
                  ],
                  const SizedBox(height: 24),
                  // Rate Now
                  SizedBox(
                    width: double.infinity, height: 52,
                    child: ElevatedButton(
                      onPressed: () { Navigator.of(context).pop(); widget.onRateNow?.call(); },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.orange,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                        shadowColor: AppColors.orange.withValues(alpha: 0.3),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.star_rounded, size: 22),
                          SizedBox(width: 8),
                          Text('Rate Order', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity, height: 48,
                    child: TextButton(
                      onPressed: () { Navigator.of(context).pop(); widget.onContinue?.call(); },
                      child: const Text('Continue Shopping', style: TextStyle(color: AppColors.orange, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Simple inline confetti
class InlineConfetti extends StatefulWidget {
  final bool active;
  final Widget child;

  const InlineConfetti({super.key, required this.active, required this.child});

  @override
  State<InlineConfetti> createState() => _InlineConfettiState();
}

class _InlineConfettiState extends State<InlineConfetti> {
  late ConfettiController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ConfettiController(duration: const Duration(seconds: 3));
    if (widget.active) _controller.play();
  }

  @override
  void didUpdateWidget(InlineConfetti oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) _controller.play();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        Align(
          alignment: Alignment.topCenter,
          child: ConfettiWidget(
            confettiController: _controller,
            blastDirectionality: BlastDirectionality.explosive,
            shouldLoop: false,
            colors: const [
              Color(0xFFFF6D00), Color(0xFFE64A19), Colors.white,
              Color(0xFF4CAF50), Color(0xFFFFEB3B), Color(0xFF2196F3),
            ],
            numberOfParticles: 30,
            gravity: 0.1,
            emissionFrequency: 0.05,
            minimumSize: const Size(6, 6),
            maximumSize: const Size(14, 14),
          ),
        ),
      ],
    );
  }
}
