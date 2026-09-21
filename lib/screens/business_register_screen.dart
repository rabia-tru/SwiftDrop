import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';
import '../widgets/app_icon_badge.dart';
import '../services/api_service.dart';
import '../services/error_helper.dart';
import '../services/biometric_service.dart';
import 'business_home_screen.dart';
import 'business_login_screen.dart';

/// SwiftDrop Business Register — Same header as rider/customer
class BusinessRegisterScreen extends StatefulWidget {
  const BusinessRegisterScreen({super.key});

  @override
  State<BusinessRegisterScreen> createState() => _BusinessRegisterScreenState();
}

class _BusinessRegisterScreenState extends State<BusinessRegisterScreen>
    with SingleTickerProviderStateMixin {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _addressController = TextEditingController();
  String _selectedCategory = 'Restaurant';
  bool _loading = false;
  bool _obscurePassword = true;
  String? _error;
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  final _categories = ['Restaurant', 'Cafe', 'Grocery', 'Pharmacy', 'Bakery', 'Clothing', 'Electronics', 'Other'];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
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
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (_nameController.text.isEmpty ||
        _phoneController.text.isEmpty ||
        _emailController.text.isEmpty ||
        _passwordController.text.isEmpty) {
      setState(() => _error = 'Please fill all required fields');
      return;
    }
    if (_passwordController.text.length < 6) {
      setState(() => _error = 'Password must be at least 6 characters');
      return;
    }
    if (!_emailController.text.trim().contains('@') || !_emailController.text.trim().contains('.')) {
      setState(() => _error = 'Please enter a valid email address');
      return;
    }
    if (_phoneController.text.trim().length < 10) {
      setState(() => _error = 'Please enter a valid phone number (min 10 digits)');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ApiService.businessRegister(
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
        category: _selectedCategory,
        address: _addressController.text.trim().isNotEmpty ? _addressController.text.trim() : null,
      );
      if (mounted) {
        // Show biometric setup prompt
        await BiometricService.showSetupDialog(context);
        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const BusinessHomeScreen()),
          (route) => false,
        );
      }
    } catch (e) {
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

    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
    ));

    return Scaffold(
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
                child: _buildRegisterForm(textColor, subTextColor, inputBg),
              ),

              // ─── Footer ───
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
                child: _buildFooter(subTextColor),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRegisterForm(Color textColor, Color subTextColor, Color inputBg) {
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
          const Text('Create Business Account', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 20),

          // Name
          _buildField(
            label: 'Business Name',
            textColor: textColor,
            child: TextField(
              controller: _nameController,
              textInputAction: TextInputAction.next,
              style: TextStyle(fontSize: 16, color: textColor),
              decoration: InputDecoration(
                hintText: 'e.g. Pizza Hub',
                hintStyle: TextStyle(color: subTextColor.withValues(alpha: 0.6)),
                prefixIcon: const Icon(Icons.store_outlined, color: AppColors.orange, size: 20),
                fillColor: inputBg,
                filled: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.orange, width: 2)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Phone
          _buildField(
            label: 'Phone',
            textColor: textColor,
            child: TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              style: TextStyle(fontSize: 16, color: textColor),
              decoration: InputDecoration(
                hintText: '03XX XXXXXXX',
                hintStyle: TextStyle(color: subTextColor.withValues(alpha: 0.6)),
                prefixIcon: const Icon(Icons.phone_outlined, color: AppColors.orange, size: 20),
                fillColor: inputBg,
                filled: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.orange, width: 2)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Email
          _buildField(
            label: 'Email',
            textColor: textColor,
            child: TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              style: TextStyle(fontSize: 16, color: textColor),
              decoration: InputDecoration(
                hintText: 'business@example.com',
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

          // Password
          _buildField(
            label: 'Password',
            textColor: textColor,
            child: TextField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              textInputAction: TextInputAction.done,
              style: TextStyle(fontSize: 16, color: textColor),
              decoration: InputDecoration(
                hintText: 'Min 6 characters',
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
          const SizedBox(height: 16),

          // Category Dropdown
          _buildField(
            label: 'Category',
            textColor: textColor,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: inputBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedCategory,
                  isExpanded: true,
                  dropdownColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E1E1E) : Colors.white,
                  style: TextStyle(fontSize: 16, color: textColor),
                  icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.orange),
                  items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                  onChanged: (v) => setState(() => _selectedCategory = v ?? _selectedCategory),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Address
          _buildField(
            label: 'Address (optional)',
            textColor: textColor,
            child: TextField(
              controller: _addressController,
              textInputAction: TextInputAction.done,
              style: TextStyle(fontSize: 16, color: textColor),
              decoration: InputDecoration(
                hintText: 'Shop address',
                hintStyle: TextStyle(color: subTextColor.withValues(alpha: 0.6)),
                prefixIcon: const Icon(Icons.location_on_outlined, color: AppColors.orange, size: 20),
                fillColor: inputBg,
                filled: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.orange, width: 2)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              ),
            ),
          ),

          // Error
          if (_error != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.orangePale, borderRadius: BorderRadius.circular(8)),
              child: Row(
                children: [
                  const Icon(Icons.warning, color: AppColors.orangeDark, size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_error!, style: const TextStyle(color: AppColors.orangeDark, fontSize: 13))),
                ],
              ),
            ),
          ],

          const SizedBox(height: 24),

          // Register Button
          SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: _loading ? null : _register,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.orange,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: _loading
                  ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2.5, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))
                  : const Text('Create Account', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildField({required String label, required Color textColor, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textColor)),
        const SizedBox(height: 8),
        child,
      ],
    );
  }

  Widget _buildFooter(Color subTextColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('Already have an account? ', style: TextStyle(color: subTextColor, fontSize: 14)),
        GestureDetector(
          onTap: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const BusinessLoginScreen())),
          child: const Text('Sign In', style: TextStyle(color: AppColors.orange, fontWeight: FontWeight.w700, fontSize: 14)),
        ),
      ],
    );
  }
}
