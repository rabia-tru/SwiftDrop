import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';
import '../widgets/app_icon_badge.dart';
import '../services/api_service.dart';
import '../services/error_helper.dart';
import '../widgets/premium_dialogs.dart';
import 'customer_splash_screen.dart';
import 'user_register_screen.dart';

/// SwiftDrop Customer Login — Theme-aware
class UserLoginScreen extends StatefulWidget {
  const UserLoginScreen({super.key});

  @override
  State<UserLoginScreen> createState() => _UserLoginScreenState();
}

class _UserLoginScreenState extends State<UserLoginScreen>
    with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  bool _loading = false;
  String? _error;
  bool _obscurePassword = true;
  bool _keepSignedIn = false;
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_emailController.text.trim().isEmpty || _passwordController.text.isEmpty) {
      setState(() => _error = 'Please fill in all fields');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await ApiService.customerLogin(
        _emailController.text.trim(),
        _passwordController.text,
      );
      await ApiService.setKeepSignedIn(_keepSignedIn);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const CustomerSplashScreen(),
          transitionsBuilder: (_, animation, __, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 500),
        ),
      );
    } catch (e) {
      print('Customer login error: ${e.runtimeType} - $e');
      setState(() => _error = ErrorHelper.getMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0A0A0A) : AppColors.offWhite;
    final textColor = isDark ? Colors.white : AppColors.black;
    final subTextColor = isDark ? const Color(0xFFB0B0B0) : AppColors.darkGray;
    final inputBg = isDark ? const Color(0xFF1E1E1E) : AppColors.lightGray;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: isDark ? const Color(0xFF0A0A0A) : Colors.white,
      ),
      child: Scaffold(
        backgroundColor: bgColor,
        body: FadeTransition(
          opacity: _fadeAnimation,
          child: SingleChildScrollView(
            child: Column(
              children: [
                // ─── Header (matching role selection design) ───
                Stack(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.fromLTRB(24, MediaQuery.of(context).padding.top + 20, 24, 28),
                      decoration: const BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.only(
                          bottomLeft: Radius.circular(32),
                          bottomRight: Radius.circular(32),
                        ),
                      ),
                      child: Column(
                        children: [
                          const AppIconBadge(size: 80, padding: 12),
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
                    // Back button
                    Positioned(
                      left: 20,
                      top: MediaQuery.of(context).padding.top + 10,
                      child: GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
                        ),
                      ),
                    ),
                  ],
                ),

                // ─── Form ───
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                  child: _buildLoginForm(textColor, subTextColor, inputBg),
                ),

                // ─── Footer ───
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
                  child: _buildRegisterLink(subTextColor),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoginForm(Color textColor, Color subTextColor, Color inputBg) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1A1A1A) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.orange.withValues(alpha: 0.1),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Customer Login', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
        const SizedBox(height: 20),
        _buildField(
          label: 'Email',
          textColor: textColor,
          child: TextField(
            controller: _emailController,
            focusNode: _emailFocus,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            onSubmitted: (_) => FocusScope.of(context).requestFocus(_passwordFocus),
            style: TextStyle(fontSize: 16, color: textColor),
            decoration: InputDecoration(
              hintText: 'customer@example.com',
              hintStyle: TextStyle(color: subTextColor.withValues(alpha: 0.6)),
              prefixIcon: const Icon(Icons.email_outlined, color: AppColors.orange, size: 20),
              fillColor: inputBg,
              filled: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.orange, width: 2)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
          ),
        ),
        const SizedBox(height: 16),
        _buildField(
          label: 'Password',
          textColor: textColor,
          labelRight: GestureDetector(
            onTap: _showForgotPassword,
            child: const Text('Forgot?', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.orange)),
          ),
          child: TextField(
            controller: _passwordController,
            focusNode: _passwordFocus,
            obscureText: _obscurePassword,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _login(),
            style: TextStyle(fontSize: 16, color: textColor),
            decoration: InputDecoration(
              hintText: '••••••••',
              hintStyle: TextStyle(color: subTextColor.withValues(alpha: 0.6)),
              prefixIcon: const Icon(Icons.lock_outline, color: AppColors.orange, size: 20),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off : Icons.visibility,
                  color: subTextColor,
                  size: 20,
                ),
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              ),
              fillColor: inputBg,
              filled: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.orange, width: 2)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: Checkbox(
                value: _keepSignedIn,
                onChanged: (v) => setState(() => _keepSignedIn = v ?? false),
                activeColor: AppColors.orange,
                side: const BorderSide(color: AppColors.gray),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              ),
            ),
            const SizedBox(width: 8),
            Text('Keep me signed in', style: TextStyle(fontSize: 14, color: subTextColor)),
          ],
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.orangePale,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning, color: AppColors.orangeDark, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(_error!, style: const TextStyle(color: AppColors.orangeDark, fontSize: 13)),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 24),
        SizedBox(
          height: 48,
          child: ElevatedButton(
            onPressed: _loading ? null : _login,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.orange,
              foregroundColor: Colors.white,
              disabledBackgroundColor: AppColors.orange.withValues(alpha: 0.6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              elevation: 0,
            ),
            child: _loading
                ? const SizedBox(
                    height: 24, width: 24,
                    child: CircularProgressIndicator(strokeWidth: 2.5, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                  )
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Sign In', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      SizedBox(width: 8),
                      Icon(Icons.arrow_forward, size: 18),
                    ],
                  ),
          ),
        ),
      ],
      ),
    );
  }

  Widget _buildField({required String label, required Widget child, Color? textColor, Widget? labelRight}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: textColor ?? AppColors.black)),
            if (labelRight != null) labelRight,
          ],
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }

  void _showForgotPassword() {
    final emailController = TextEditingController();
    final codeController = TextEditingController();
    final newPasswordController = TextEditingController();
    bool _sending = false;
    bool _codeSent = false;
    String? _error;
    String? _successEmail;
    String? _devCode; // shown only when the email could not be delivered

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 64, height: 64,
                    decoration: const BoxDecoration(color: AppColors.orangePale, shape: BoxShape.circle),
                    child: Icon(_codeSent ? Icons.lock_open_rounded : Icons.lock_reset_rounded, color: AppColors.orange, size: 32),
                  ),
                  const SizedBox(height: 20),
                  Text(_codeSent ? 'Reset Password' : 'Forgot Password?', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Text(
                    _codeSent ? 'Enter the 6-digit code and your new password.' : "Enter your email and we'll send you a reset code.\n\n⚠️ Note: Check your spam folder if you don't receive the email within 2-3 minutes.",
                    style: const TextStyle(fontSize: 14, color: AppColors.darkGray, height: 1.4),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  if (!_codeSent) ...[
                    TextField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      style: const TextStyle(fontSize: 16, color: AppColors.black),
                      decoration: InputDecoration(
                        hintText: 'Enter your email',
                        hintStyle: TextStyle(color: AppColors.darkGray.withValues(alpha: 0.5)),
                        prefixIcon: const Icon(Icons.email_outlined, color: AppColors.orange, size: 20),
                        fillColor: AppColors.lightGray, filled: true,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.orange, width: 2)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      ),
                    ),
                  ],
                  if (_codeSent) ...[
                    TextField(
                      controller: codeController,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.black, letterSpacing: 4),
                      textAlign: TextAlign.center,
                      decoration: InputDecoration(
                        hintText: '000000',
                        hintStyle: TextStyle(color: AppColors.darkGray.withValues(alpha: 0.3), letterSpacing: 4),
                        counterText: '',
                        fillColor: AppColors.lightGray, filled: true,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.orange, width: 2)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: newPasswordController,
                      obscureText: true,
                      style: const TextStyle(fontSize: 16, color: AppColors.black),
                      decoration: InputDecoration(
                        hintText: 'New password (min 6 chars)',
                        hintStyle: TextStyle(color: AppColors.darkGray.withValues(alpha: 0.5)),
                        prefixIcon: const Icon(Icons.lock_outline, color: AppColors.orange, size: 20),
                        fillColor: AppColors.lightGray, filled: true,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.orange, width: 2)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      ),
                    ),
                  ],
                  if (_devCode != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: AppColors.orangePale.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(8)),
                      child: Text('Email delivery unavailable — demo code: $_devCode', style: const TextStyle(color: AppColors.orange, fontSize: 12, fontWeight: FontWeight.w600)),
                    ),
                  ],

                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
                      child: Row(children: [
                        Icon(Icons.error_outline, color: Colors.red[700], size: 18),
                        const SizedBox(width: 8),
                        Expanded(child: Text(_error!, style: TextStyle(color: Colors.red[700], fontSize: 12))),
                      ]),
                    ),
                  ],
                  const SizedBox(height: 24),
                  Row(children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: AppColors.gray.withValues(alpha: 0.5))),
                        ),
                        child: const Text('Cancel', style: TextStyle(color: AppColors.darkGray, fontWeight: FontWeight.w600)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _sending ? null : () async {
                          if (!_codeSent) {
                            if (emailController.text.trim().isEmpty) { setDialogState(() => _error = 'Please enter your email'); return; }
                            setDialogState(() { _sending = true; _error = null; });
                            try {
                              final res = await ApiService.forgotPassword(emailController.text.trim(), role: 'customer');
                              _successEmail = emailController.text.trim();
                              _devCode = res['_devCode']?.toString();
                              setDialogState(() { _codeSent = true; _sending = false; });
                              // Show success message
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('✅ Reset code sent to your email! Check your inbox and spam folder.'),
                                  backgroundColor: AppColors.orange,
                                  duration: Duration(seconds: 5),
                                ),
                              );
                            } catch (e) { setDialogState(() { _error = ErrorHelper.getMessage(e); _sending = false; }); }
                          } else {
                            if (codeController.text.length != 6) { setDialogState(() => _error = 'Please enter the 6-digit code'); return; }
                            if (newPasswordController.text.length < 6) { setDialogState(() => _error = 'Password must be at least 6 characters'); return; }
                            setDialogState(() { _sending = true; _error = null; });
                            try {
                              await ApiService.resetPassword(_successEmail!, codeController.text, newPasswordController.text, role: 'customer');
                              Navigator.of(context).pop();
                              if (mounted) PremiumDialogs.showSuccess(context, 'Password reset successful!');
                            } catch (e) { setDialogState(() { _error = ErrorHelper.getMessage(e); _sending = false; }); }
                          }
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.orange, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
                        child: _sending
                            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : Text(_codeSent ? 'Reset Password' : 'Send Code', style: const TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ]),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRegisterLink(Color subTextColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text("Don't have an account? ", style: TextStyle(color: subTextColor, fontSize: 14)),
        GestureDetector(
          onTap: () => Navigator.of(context).push(
            PageRouteBuilder(
              pageBuilder: (_, __, ___) => const UserRegisterScreen(),
              transitionsBuilder: (_, animation, __, child) {
                return SlideTransition(
                  position: Tween<Offset>(begin: const Offset(1.0, 0.0), end: Offset.zero).animate(animation),
                  child: child,
                );
              },
              transitionDuration: const Duration(milliseconds: 300),
            ),
          ),
          child: const Text('Sign Up', style: TextStyle(color: AppColors.orange, fontWeight: FontWeight.w700, fontSize: 14)),
        ),
      ],
    );
  }
}
