import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import '../theme/app_colors.dart';
import '../services/api_service.dart';
import '../services/error_helper.dart';
import '../config/app_support.dart';
import '../widgets/premium_dialogs.dart';
import 'notifications_screen.dart';
import 'business_home_screen.dart';
import 'role_selection_screen.dart';

/// SwiftDrop Business Profile — FoodPanda-partner style
class BusinessProfileScreen extends StatefulWidget {
  const BusinessProfileScreen({super.key});

  @override
  State<BusinessProfileScreen> createState() => _BusinessProfileScreenState();
}

class _BusinessProfileScreenState extends State<BusinessProfileScreen>
    with SingleTickerProviderStateMixin {
  Map<String, dynamic>? _business;
  bool _loading = true;
  bool _isOpen = true;
  bool _uploadingLogo = false;
  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _loadBusiness();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _loadBusiness() async {
    try {
      final biz = await ApiService.businessGetMe();
      if (mounted) {
        setState(() {
          _business = Map<String, dynamic>.from(biz);
          _isOpen = (_business?['isOpen'] ?? true) as bool;
          _loading = false;
        });
        _fadeController.forward();
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleOpen(bool value) async {
    setState(() => _isOpen = value);
    try {
      await ApiService.businessUpdateMe({'isOpen': value});
      if (mounted) {
        PremiumDialogs.showSuccess(context, value ? 'Store is now Open 🎉' : 'Store is now Closed');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isOpen = !value);
        PremiumDialogs.showError(context, ErrorHelper.getMessage(e));
      }
    }
  }

  /// Logo uploaded by the business, or the app icon as fallback.
  Widget _buildLogoImage() {
    final logo = (_business?['logoUrl'] ?? '').toString();
    if (logo.isNotEmpty) {
      return Image.network(
        logo,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Image.asset('assets/icon/app_icon.png', fit: BoxFit.cover),
      );
    }
    return Image.asset('assets/icon/app_icon.png', fit: BoxFit.cover);
  }

  void _showLogoSourcePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Update Business Logo', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _logoSourceTile(
                      icon: Icons.photo_library_rounded,
                      label: 'Gallery',
                      onTap: () => _pickLogo(ctx, ImageSource.gallery),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _logoSourceTile(
                      icon: Icons.photo_camera_rounded,
                      label: 'Camera',
                      onTap: () => _pickLogo(ctx, ImageSource.camera),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _logoSourceTile({required IconData icon, required String label, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: AppColors.orange.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.orange.withValues(alpha: 0.25)),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppColors.orange, size: 26),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.orange)),
          ],
        ),
      ),
    );
  }

  Future<void> _pickLogo(BuildContext sheetCtx, ImageSource source) async {
    Navigator.pop(sheetCtx);
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source, maxWidth: 800, imageQuality: 85);
    if (picked == null) return;

    setState(() => _uploadingLogo = true);
    try {
      final url = await ApiService.uploadImage(picked.path, type: 'logo');
      await ApiService.businessUpdateMe({'logoUrl': url});
      await _loadBusiness();
      if (mounted) PremiumDialogs.showSuccess(context, 'Logo updated! 🎉');
    } catch (e) {
      if (mounted) PremiumDialogs.showError(context, ErrorHelper.getMessage(e));
    } finally {
      if (mounted) setState(() => _uploadingLogo = false);
    }
  }

  void _showEditDialog() {
    final nameController = TextEditingController(text: _business?['name'] ?? '');
    final phoneController = TextEditingController(text: _business?['phone'] ?? '');
    final addressController = TextEditingController(text: _business?['address'] ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: EdgeInsets.fromLTRB(24, 20, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Edit Store Info', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 20),
            _buildEditField(nameController, 'Business name', Icons.store_outlined),
            const SizedBox(height: 14),
            _buildEditField(phoneController, 'Phone', Icons.phone_outlined, keyboard: TextInputType.phone),
            const SizedBox(height: 14),
            _buildEditField(addressController, 'Address', Icons.location_on_outlined),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () async {
                  try {
                    await ApiService.businessUpdateMe({
                      if (nameController.text.trim().isNotEmpty) 'name': nameController.text.trim(),
                      if (phoneController.text.trim().isNotEmpty) 'phone': phoneController.text.trim(),
                      if (addressController.text.trim().isNotEmpty) 'address': addressController.text.trim(),
                    });
                    if (ctx.mounted) Navigator.pop(ctx);
                    _loadBusiness();
                    if (mounted) PremiumDialogs.showSuccess(context, 'Store info updated!');
                  } catch (e) {
                    if (mounted) PremiumDialogs.showError(context, ErrorHelper.getMessage(e));
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.orange,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: const Text('Save Changes', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditField(TextEditingController controller, String hint, IconData icon, {TextInputType? keyboard}) {
    return TextField(
      controller: controller,
      keyboardType: keyboard,
      style: const TextStyle(fontSize: 15),
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, color: AppColors.orange, size: 20),
        fillColor: AppColors.lightGray,
        filled: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.orange, width: 2)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0A0A0A) : const Color(0xFFF6F6F6);
    final cardColor = isDark ? const Color(0xFF1A1A1A) : Colors.white;
    final textColor = isDark ? Colors.white : AppColors.black;
    final statusBarHeight = MediaQuery.of(context).padding.top;

    if (_loading) {
      return Scaffold(
        backgroundColor: bgColor,
        body: const Center(child: CircularProgressIndicator(color: AppColors.orange)),
      );
    }

    final name = (_business?['name'] ?? 'My Business').toString();
    final category = (_business?['category'] ?? 'Restaurant').toString();

    return Scaffold(
      backgroundColor: bgColor,
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: RefreshIndicator(
          onRefresh: _loadBusiness,
          color: AppColors.orange,
          child: ListView(
            padding: const EdgeInsets.only(bottom: 100),
            children: [
              // ─── Header with business avatar ───
              Container(
                width: double.infinity,
                padding: EdgeInsets.fromLTRB(20, statusBarHeight + 16, 20, 60),
                decoration: const BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(32),
                    bottomRight: Radius.circular(32),
                  ),
                ),
                child: Column(
                  children: [
                    // Business logo — tap to upload from gallery/camera
                    GestureDetector(
                      onTap: _uploadingLogo ? null : _showLogoSourcePicker,
                      child: Stack(
                        children: [
                          AnimatedOpacity(
                            duration: const Duration(milliseconds: 250),
                            opacity: _uploadingLogo ? 0.5 : 1,
                            child: Container(
                              width: 84, height: 84,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(24),
                                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 16, offset: const Offset(0, 6))],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(24),
                                child: _buildLogoImage(),
                              ),
                            ),
                          ),
                          // Camera badge
                          Positioned(
                            right: -2, bottom: -2,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                border: Border.all(color: AppColors.orange, width: 2),
                                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 6, offset: const Offset(0, 2))],
                              ),
                              child: _uploadingLogo
                                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.orange))
                                  : const Icon(Icons.photo_camera_rounded, size: 14, color: AppColors.orange),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text('Tap logo to change photo', style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.75))),
                    const SizedBox(height: 8),
                    Text(name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white)),
                    const SizedBox(height: 2),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(category, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
                    ),
                  ],
                ),
              ),
              // ─── Overlapping store status card ───
              Transform.translate(
                offset: const Offset(0, -40),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [BoxShadow(color: AppColors.orange.withValues(alpha: 0.15), blurRadius: 20, offset: const Offset(0, 8))],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: (_isOpen ? AppColors.statusDelivered : AppColors.darkGray).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(_isOpen ? Icons.storefront_rounded : Icons.storefront_outlined,
                              size: 26, color: _isOpen ? AppColors.statusDelivered : AppColors.darkGray),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_isOpen ? 'Store is Open' : 'Store is Closed',
                                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: textColor)),
                              Text(_isOpen ? 'Accepting new orders' : 'Not accepting orders',
                                  style: const TextStyle(fontSize: 12, color: AppColors.darkGray)),
                            ],
                          ),
                        ),
                        Switch(
                          value: _isOpen,
                          activeColor: AppColors.orange,
                          onChanged: _toggleOpen,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // ─── Store info section ───
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04), blurRadius: 10, offset: const Offset(0, 3))],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text('Store Information', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                          const Spacer(),
                          GestureDetector(
                            onTap: _showEditDialog,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppColors.orange.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.edit_rounded, size: 14, color: AppColors.orange),
                                  SizedBox(width: 4),
                                  Text('Edit', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.orange)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildInfoRow(Icons.phone_outlined, _business?['phone'] ?? 'Not set', textColor),
                      const SizedBox(height: 12),
                      _buildInfoRow(Icons.email_outlined, _business?['email'] ?? 'Not set', textColor),
                      const SizedBox(height: 12),
                      _buildInfoRow(Icons.location_on_outlined, _business?['address'] ?? 'Not set', textColor),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // ─── Settings section ───
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04), blurRadius: 10, offset: const Offset(0, 3))],
                  ),
                  child: Column(
                    children: [
                      _buildMenuTile(Icons.receipt_long_rounded, 'My Orders', 'View all incoming orders', () => _goToOrdersTab(), textColor),
                      _buildDivider(isDark),
                      _buildMenuTile(Icons.notifications_rounded, 'Notifications', 'Manage alerts', () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NotificationsScreen())), textColor),
                      _buildDivider(isDark),
                      _buildMenuTile(Icons.help_outline_rounded, 'Help & Support', 'Get assistance', _showBusinessHelpDialog, textColor),
                      _buildDivider(isDark),
                      _buildMenuTile(Icons.share_rounded, 'Share SwiftDrop', 'Invite other businesses', _shareApp, textColor),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // ─── Logout ───
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04), blurRadius: 10, offset: const Offset(0, 3))],
                  ),
                  child: _buildMenuTile(Icons.logout_rounded, 'Log Out', '', _showLogoutDialog, textColor, isDestructive: true),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text, Color textColor) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.orange.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 16, color: AppColors.orange),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text.toString(),
            style: TextStyle(fontSize: 13.5, color: textColor.withValues(alpha: 0.85), fontWeight: FontWeight.w500),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildDivider(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Divider(height: 1, color: (isDark ? Colors.white : AppColors.black).withValues(alpha: 0.06)),
    );
  }

  Widget _buildMenuTile(IconData icon, String title, String subtitle, VoidCallback onTap, Color textColor, {bool isDestructive = false}) {
    final color = isDestructive ? const Color(0xFFE53935) : AppColors.orange;
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, size: 20, color: color),
      ),
      title: Text(title, style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: textColor)),
      subtitle: subtitle.isNotEmpty ? Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.darkGray)) : null,
      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.darkGray),
    );
  }

  // Jump to the business Orders tab (tab index 2 in BusinessHomeScreen).
  void _goToOrdersTab() {
    BusinessHomeScreen.of(context)?.goToTab(2);
  }

  void _showBusinessHelpDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(children: [
          Icon(Icons.help_outline_rounded, color: AppColors.orange, size: 22),
          SizedBox(width: 10),
          Text('Help & Support'),
        ]),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Partner support, available 24/7:', style: TextStyle(fontSize: 13, color: AppColors.darkGray)),
            SizedBox(height: 12),
            Row(children: [Icon(Icons.email_rounded, color: AppColors.orange, size: 18), SizedBox(width: 10), Flexible(child: Text('partners@swiftdrop.pk', style: TextStyle(fontSize: 14)))]),
            SizedBox(height: 8),
            Row(children: [Icon(Icons.phone_rounded, color: AppColors.orange, size: 18), SizedBox(width: 10), Flexible(child: Text(AppSupport.supportPhone, style: TextStyle(fontSize: 14)))]),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.orange, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _shareApp() {
    Share.share(
      'Join SwiftDrop as a restaurant partner! Grow your sales with live order tracking. Download: https://swiftdrop.pk/partner',
      subject: 'SwiftDrop for Business',
    );
  }

  void _showLogoutDialog() {
    PremiumDialogs.showConfirm(
      context,
      title: 'Log Out',
      message: 'Are you sure you want to log out of your business account?',
      confirmText: 'Log Out',
      icon: Icons.logout_rounded,
    ).then((confirmed) {
      if (confirmed == true) {
        ApiService.logout();
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const RoleSelectionScreen()),
          (route) => false,
        );
      }
    });
  }
}
