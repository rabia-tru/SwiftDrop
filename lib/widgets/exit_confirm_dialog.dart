import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';

/// Modern "Exit app?" confirmation — shown when BACK is pressed on a home
/// screen. Second BACK within the dialog (or tapping Exit) closes the app
/// via SystemNavigator so the app never silently exits on a single back.
class ExitConfirmDialog {
  ExitConfirmDialog._();

  /// Returns true if the user confirmed exit (and the app should close).
  static Future<bool> show(BuildContext context, {required bool isDark}) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.45),
      builder: (dialogCtx) => PopScope(
        canPop: true,
        child: Center(
          child: _DialogCard(isDark: isDark),
        ),
      ),
    );
    if (result == true) {
      await SystemNavigator.pop(); // close the app cleanly
    }
    return result ?? false;
  }
}

class _DialogCard extends StatefulWidget {
  const _DialogCard({required this.isDark});
  final bool isDark;

  @override
  State<_DialogCard> createState() => _DialogCardState();
}

class _DialogCardState extends State<_DialogCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 220));
    _scale = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack);
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bg = widget.isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final titleColor = widget.isDark ? Colors.white : AppColors.black;
    final subColor = widget.isDark ? const Color(0xFFB0B0B0) : AppColors.darkGray;

    return FadeTransition(
      opacity: _fade,
      child: ScaleTransition(
        scale: _scale,
        child: Material(
          color: Colors.transparent,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 40),
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.18),
                  blurRadius: 32,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.exit_to_app_rounded,
                      color: Colors.white, size: 30),
                ),
                const SizedBox(height: 18),
                Text(
                  'Exit SwiftDrop?',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: titleColor,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Tracking continues in the background —\nyou can come back anytime.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: subColor,
                  ),
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: BorderSide(
                              color: widget.isDark
                                  ? Colors.white24
                                  : AppColors.lightGray,
                            ),
                          ),
                        ),
                        child: Text(
                          'Stay',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: titleColor,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.orange,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text(
                          'Exit',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
