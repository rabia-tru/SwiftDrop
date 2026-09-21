import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';
import 'login_screen.dart';
import 'user_login_screen.dart';
import 'user_register_screen.dart';
import 'business_login_screen.dart';

/// SwiftDrop Role Selection — "Split Rail" refined
///
/// Strict orange + white palette. Big brand header, generous whitespace,
/// tall airy role rows filling the screen — no third accent color, no
/// cramped bottom. Business tile now uses a white-on-orange outline style.
class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _floatController;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _floatController = AnimationController(
      duration: const Duration(milliseconds: 3800),
      vsync: this,
    );
    _fadeController.forward();
    _floatController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _floatController.dispose();
    super.dispose();
  }

  void _navigateToLogin({required bool isRider}) {
    // pushReplacement: login ke baad user Home pe pohnchta hai — agar hum
    // push karein to Role Selection stack mein reh jati hai aur system BACK
    // dabane par user wahan pohanch jata hai (galat flow).
    if (isRider) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const UserLoginScreen()),
      );
    }
  }

  void _navigateToRegister({required bool isRider}) {
    if (isRider) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const UserRegisterScreen()),
      );
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const UserRegisterScreen()),
      );
    }
  }

  void _navigateToBusinessLogin() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const BusinessLoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sheetColor = isDark ? const Color(0xFF0A0A0A) : Colors.white;
    final subColor = isDark ? const Color(0xFF9E9E9E) : AppColors.darkGray;

    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
    ));

    return Scaffold(
      backgroundColor: sheetColor,
      body: FadeTransition(
        opacity: _fadeController,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            children: [
              // ─── Brand header (fixed at top) ─────────
              Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: AppColors.orange,
                  borderRadius:
                      BorderRadius.vertical(bottom: Radius.circular(32)),
                ),
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
                    child: Column(
                      children: [
                        AnimatedBuilder(
                          animation: _floatController,
                          builder: (context, _) {
                            return Transform.translate(
                              offset: Offset(
                                  0, sin(_floatController.value * pi) * 6),
                              child: Container(
                                width: 80,
                                height: 80,
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black
                                          .withValues(alpha: 0.18),
                                      blurRadius: 26,
                                      offset: const Offset(0, 12),
                                    ),
                                  ],
                                ),
                                child: ClipOval(
                                  child: Image.asset(
                                    'assets/icon/app_icon.png',
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'SwiftDrop',
                          style: TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // ─── Content (centered in remaining space) ───────
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(22, 6, 22, 0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),

                      _RoleRow(
                        index: 0,
                        isDark: isDark,
                        icon: Icons.shopping_bag_rounded,
                        title: 'Customer',
                        subtitle: 'Browse, order & track live',
                        filled: true,
                        onTap: () => _navigateToLogin(isRider: false),
                      ),
                      const SizedBox(height: 16),

                      _RoleRow(
                        index: 1,
                        isDark: isDark,
                        icon: Icons.two_wheeler_rounded,
                        title: 'Rider',
                        subtitle: 'Deliver & earn on your schedule',
                        filled: true,
                        onTap: () => _navigateToLogin(isRider: true),
                      ),
                      const SizedBox(height: 16),

                      _RoleRow(
                        index: 2,
                        isDark: isDark,
                        icon: Icons.storefront_rounded,
                        title: 'Business',
                        subtitle: 'Sell online, manage your store',
                        filled: true,
                        onTap: _navigateToBusinessLogin,
                      ),

                      // ─── Footer ─────────────────────────────────
                      const SizedBox(height: 34),
                      Center(
                        child: _StaggerIn(
                          index: 3,
                          child: Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                'New here?  ',
                                style: TextStyle(
                                    fontSize: 13.5, color: subColor),
                              ),
                              GestureDetector(
                                onTap: () =>
                                    _navigateToRegister(isRider: false),
                                child: const Text(
                                  'Customer signup',
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.orange,
                                  ),
                                ),
                              ),
                              Text(
                                '  •  ',
                                style: TextStyle(
                                    fontSize: 13.5,
                                    color: AppColors.gray
                                        .withValues(alpha: 0.6)),
                              ),
                              GestureDetector(
                                onTap: () =>
                                    _navigateToRegister(isRider: true),
                                child: const Text(
                                  'Rider signup',
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.orange,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Staggered entrance wrapper ───────────────────────────────────────────

class _StaggerIn extends StatelessWidget {
  final int index;
  final Widget child;

  const _StaggerIn({required this.index, required this.child});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 460 + (index * 130)),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 24 * (1 - value)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

// ─── Role row ─────────────────────────────────────────────────────────────

class _RoleRow extends StatefulWidget {
  final int index;
  final bool isDark;

  /// true = solid orange card with white text (primary role)
  /// false = white card with orange accents (secondary roles)
  final bool filled;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _RoleRow({
    required this.index,
    required this.isDark,
    required this.filled,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  State<_RoleRow> createState() => _RoleRowState();
}

class _RoleRowState extends State<_RoleRow> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;

    final cardBg = widget.filled
        ? AppColors.orange
        : (isDark ? const Color(0xFF161616) : Colors.white);
    final titleColor = widget.filled
        ? Colors.white
        : (isDark ? Colors.white : AppColors.black);
    final subColor = widget.filled
        ? Colors.white.withValues(alpha: 0.85)
        : (isDark ? const Color(0xFF9E9E9E) : AppColors.darkGray);
    final tileBg =
        widget.filled ? Colors.white.withValues(alpha: 0.2) : AppColors.orange.withValues(alpha: 0.1);
    final tileBorder = widget.filled
        ? Colors.white.withValues(alpha: 0.35)
        : AppColors.orange.withValues(alpha: 0.25);
    final tileIcon = widget.filled ? Colors.white : AppColors.orange;
    final arrowBg = widget.filled ? Colors.white : AppColors.orange;
    final arrowIcon = widget.filled ? AppColors.orangeDark : Colors.white;

    return _StaggerIn(
      index: widget.index,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) {
          setState(() => _pressed = false);
          widget.onTap();
        },
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedScale(
          scale: _pressed ? 0.975 : 1.0,
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOut,
          child: Container(
            height: 92,
            padding: const EdgeInsets.symmetric(horizontal: 18),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(26),
              boxShadow: [
                BoxShadow(
                  color: widget.filled
                      ? AppColors.orange.withValues(alpha: 0.38)
                      : Colors.black.withValues(alpha: isDark ? 0.35 : 0.07),
                  blurRadius: 22,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Row(
              children: [
                // Icon tile
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: tileBg,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: tileBorder),
                  ),
                  child: Icon(widget.icon, color: tileIcon, size: 26),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: titleColor,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        widget.subtitle,
                        style: TextStyle(fontSize: 12.5, color: subColor),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                // Arrow
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: arrowBg,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: (widget.filled
                                ? Colors.black
                                : AppColors.orange)
                            .withValues(alpha: widget.filled ? 0.12 : 0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child:
                      Icon(Icons.arrow_forward_rounded, color: arrowIcon, size: 20),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
