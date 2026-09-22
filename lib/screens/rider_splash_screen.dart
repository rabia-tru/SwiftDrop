import 'dart:math';
import 'package:flutter/material.dart';
import 'main_navigation.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';

/// Rider Splash — Delivery/earning theme, white background
class RiderSplashScreen extends StatefulWidget {
  const RiderSplashScreen({super.key});

  @override
  State<RiderSplashScreen> createState() => _RiderSplashScreenState();
}

class _RiderSplashScreenState extends State<RiderSplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _mainController;
  late AnimationController _floatController;
  late AnimationController _dotsController;

  @override
  void initState() {
    super.initState();
    _mainController = AnimationController(
      duration: const Duration(milliseconds: 2500),
      vsync: this,
    );
    _floatController = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    );
    _dotsController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _startSequence();
  }

  void _startSequence() async {
    _mainController.forward();
    _floatController.repeat(reverse: true);
    _dotsController.repeat();
    await Future.delayed(const Duration(milliseconds: 3500));
    _navigateToHome();
  }

  void _navigateToHome() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const MainNavigation(),
        transitionsBuilder: (context, anim, secondaryAnimation, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 600),
      ),
    );
  }

  @override
  void dispose() {
    _mainController.dispose();
    _floatController.dispose();
    _dotsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ));

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        top: false,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Compensate for the title/subtitle/chip + dots block below
              // the icon so the icon itself sits at the true screen center
              // — same trick as the main splash, and where the Android 12
              // system splash draws its icon.
              const SizedBox(height: 150),
              _buildAnimatedIcon(),
              const SizedBox(height: 32),
              _buildTitle(),
              const SizedBox(height: 8),
              _buildSubtitle(),
              const SizedBox(height: 12),
              _buildRoleChip(),
              const SizedBox(height: 50),
              _buildLoadingDots(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedIcon() {
    return AnimatedBuilder(
      animation: _mainController,
      builder: (context, child) {
        final scale = Curves.elasticOut.transform(_mainController.value);
        final opacity = Curves.easeIn.transform(_mainController.value);
        return Transform.scale(
          scale: scale,
          child: Opacity(
            opacity: opacity,
            child: AnimatedBuilder(
              animation: _floatController,
              builder: (context, _) {
                return Transform.translate(
                  offset: Offset(0, sin(_floatController.value * pi) * 6),
                  child: Image.asset(
                    'assets/icon/app_icon.png',
                    width: 110,
                    height: 110,
                    fit: BoxFit.cover,
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildTitle() {
    return AnimatedBuilder(
      animation: _mainController,
      builder: (context, child) {
        final opacity = Curves.easeIn.transform(
          (_mainController.value * 2).clamp(0.0, 1.0),
        );
        return Opacity(
          opacity: opacity,
          child: ShaderMask(
            shaderCallback: (bounds) {
              return const LinearGradient(
                colors: [Color(0xFFFF8A50), Color(0xFFFF5722)],
              ).createShader(bounds);
            },
            child: const Text(
              'SwiftDrop',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: 1,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSubtitle() {
    return AnimatedBuilder(
      animation: _mainController,
      builder: (context, child) {
        final opacity = Curves.easeIn.transform(
          ((_mainController.value - 0.3) * 2).clamp(0.0, 1.0),
        );
        return Opacity(
          opacity: opacity,
          child: const Text(
            'Start earning with every delivery',
            style: TextStyle(
              fontSize: 15,
              color: AppColors.darkGray,
              fontWeight: FontWeight.w500,
            ),
          ),
        );
      },
    );
  }

  Widget _buildRoleChip() {
    return AnimatedBuilder(
      animation: _mainController,
      builder: (context, child) {
        final opacity = Curves.easeIn.transform(
          ((_mainController.value - 0.5) * 3).clamp(0.0, 1.0),
        );
        return Opacity(
          opacity: opacity,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.orangePale,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.delivery_dining, color: AppColors.orange, size: 16),
                SizedBox(width: 6),
                Text(
                  'Rider Mode',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.orange,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLoadingDots() {
    return AnimatedBuilder(
      animation: _dotsController,
      builder: (context, _) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(3, (index) {
            final delay = index * 0.15;
            final value = (_dotsController.value + delay) % 1.0;
            final size = 4 + (sin(value * pi) * 4);
            return Container(
              width: size,
              height: size,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: AppColors.orange.withValues(alpha: 0.3 + (value * 0.7)),
                shape: BoxShape.circle,
              ),
            );
          }),
        );
      },
    );
  }
}
