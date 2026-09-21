import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_colors.dart';
import '../theme/theme_provider.dart';
import '../services/api_service.dart';
import '../services/background_location_service.dart';
import '../services/error_helper.dart';
import '../config/app_support.dart';
import 'role_selection_screen.dart';
import 'all_orders_screen.dart';
import 'earnings_screen.dart';
import 'tracking_settings_screen.dart';
import 'notifications_screen.dart';

/// SwiftDrop Rider Profile — Premium Design
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _rider;
  bool _loading = true;
  int _totalDeliveries = 0;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final rider = await ApiService.getMe();
      final orders = await ApiService.getMyOrders();
      if (mounted) {
        setState(() {
          _rider = rider;
          _totalDeliveries = orders.where((o) => o['status'] == 'delivered').length;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel', style: TextStyle(color: AppColors.darkGray))),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Logout', style: TextStyle(color: AppColors.orange))),
        ],
      ),
    );

    if (confirm == true) {
      await BackgroundLocationService.stop();
      await ApiService.logout();
      if (!mounted) return;
      // Was: pushed straight back into the rider's own LoginScreen, skipping
      // Role Selection entirely. That's a trap — if someone logs out meaning
      // to log back in as a customer (or just picked the wrong role by
      // mistake), they'd land on the Rider login form with no obvious way
      // back to choose a role, and entering the wrong-role credentials there
      // would just log them into whichever account matches, e.g. still the
      // rider account. RoleSelectionScreen is what "Switch to Customer"
      // below already goes to — regular Logout should behave the same way.
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const RoleSelectionScreen()),
        (route) => false,
      );
    }
  }

  IconData _getVehicleIcon() {
    switch (_rider?['vehicleType']?.toLowerCase()) {
      case 'bike': return Icons.pedal_bike;
      case 'car': return Icons.directions_car;
      case 'van': return Icons.local_shipping;
      default: return Icons.motorcycle;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: AppColors.offWhite,
        body: Center(child: CircularProgressIndicator(color: AppColors.orange, strokeWidth: 3)),
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0A0A0A) : AppColors.offWhite;
    final cardColor = isDark ? const Color(0xFF1A1A1A) : Colors.white;
    final textColor = isDark ? Colors.white : AppColors.black;
    final subTextColor = isDark ? const Color(0xFFB0B0B0) : AppColors.darkGray;
    final statusBarHeight = MediaQuery.of(context).padding.top;

    AppColors.setLightStatusBar();
    return Scaffold(
      backgroundColor: bgColor,
      body: ListView(
        padding: EdgeInsets.fromLTRB(0, 0, 0, 40),
        children: [
          // ─── Premium Profile Header (Full Width Gradient) ───
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(24, statusBarHeight + 24, 24, 28),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.orange, AppColors.orangeDark],
              ),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(32),
                bottomRight: Radius.circular(32),
              ),
            ),
            child: Column(
              children: [
                // Avatar
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 3),
                  ),
                  child: Center(
                    child: Text(
                      (_rider?['name'] ?? 'R')[0].toUpperCase(),
                      style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w800, color: Colors.white),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  _rider?['name'] ?? 'Rider',
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white),
                ),
                const SizedBox(height: 4),
                Text(
                  _rider?['email'] ?? '',
                  style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.8)),
                ),
                const SizedBox(height: 2),
                Text(
                  _rider?['phone'] ?? '',
                  style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.6)),
                ),
                const SizedBox(height: 10),
                // Vehicle badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_getVehicleIcon(), size: 14, color: Colors.white),
                      const SizedBox(width: 6),
                      Text(
                        _rider?['vehicleType']?.toString().toUpperCase() ?? 'RIDER',
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ─── Stats Row ───
                Row(
                  children: [
                    _buildStatItem(icon: Icons.inventory_2, label: 'Delivered', value: _totalDeliveries.toString(), cardColor: cardColor, textColor: textColor),
                    const SizedBox(width: 12),
                    _buildStatItem(icon: Icons.star, label: 'Status', value: _rider?['status']?.toString().toUpperCase() ?? 'OFF', cardColor: cardColor, textColor: textColor),
                    const SizedBox(width: 12),
                    _buildStatItem(icon: Icons.emoji_events, label: 'Vehicle', value: _rider?['vehicleType']?.toString().toUpperCase() ?? 'N/A', cardColor: cardColor, textColor: textColor),
                  ],
                ),
                const SizedBox(height: 24),

                // ─── Profile Completion Card ───
                _buildEditProfileCard(cardColor, textColor, subTextColor),
                const SizedBox(height: 24),

                // ─── Settings Section ───
                Text('Settings', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: textColor)),
                const SizedBox(height: 12),
                _buildSettingsCard(cardColor, textColor, subTextColor),
                const SizedBox(height: 20),

                // ─── Logout ───
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _logout,
                    icon: const Icon(Icons.logout_rounded, size: 20),
                    label: const Text('Logout', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.orange,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(color: AppColors.orange.withValues(alpha: 0.3), width: 1.5),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Edit Profile Card — tap to edit name, phone & vehicle info ───
  Widget _buildEditProfileCard(Color cardColor, Color textColor, Color subTextColor) {
    return GestureDetector(
      onTap: _showEditProfileSheet,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: AppColors.orange.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, 3))],
        ),
        child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft, end: Alignment.bottomRight,
                colors: [AppColors.orange.withValues(alpha: 0.12), AppColors.orangePale.withValues(alpha: 0.4)],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.edit_rounded, color: AppColors.orange, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Edit Profile', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: textColor)),
                const SizedBox(height: 2),
                Text('Update your name, phone & vehicle details', style: TextStyle(color: subTextColor, fontSize: 12)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppColors.orange, size: 20),
        ],
        ),
      ),
    );
  }

  void _showEditProfileSheet() {
    final nameController = TextEditingController(text: _rider?['name'] ?? '');
    final phoneController = TextEditingController(text: _rider?['phone'] ?? '');
    final plateController = TextEditingController(text: _rider?['vehiclePlateNumber'] ?? '');
    String vehicleType = (_rider?['vehicleType'] ?? 'bike').toString().toLowerCase();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => StatefulBuilder(
        builder: (sheetCtx, setSheetState) => Container(
          padding: EdgeInsets.fromLTRB(24, 20, 24, MediaQuery.of(sheetCtx).viewInsets.bottom + 24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SingleChildScrollView(
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
                const Text('Edit Profile', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                const SizedBox(height: 20),
                _buildEditField(nameController, 'Full name', Icons.person_outline),
                const SizedBox(height: 14),
                _buildEditField(phoneController, 'Phone number', Icons.phone_outlined, keyboard: TextInputType.phone),
                const SizedBox(height: 14),
                // Vehicle type picker
                Row(
                  children: [
                    Expanded(child: _vehicleChoice('Bike', Icons.pedal_bike, vehicleType == 'bike', () => setSheetState(() => vehicleType = 'bike'))),
                    const SizedBox(width: 10),
                    Expanded(child: _vehicleChoice('Car', Icons.directions_car, vehicleType == 'car', () => setSheetState(() => vehicleType = 'car'))),
                    const SizedBox(width: 10),
                    Expanded(child: _vehicleChoice('Van', Icons.local_shipping, vehicleType == 'van', () => setSheetState(() => vehicleType = 'van'))),
                  ],
                ),
                const SizedBox(height: 14),
                _buildEditField(plateController, 'Vehicle plate number', Icons.pin_outlined),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (nameController.text.trim().isEmpty) {
                        ScaffoldMessenger.of(sheetCtx).showSnackBar(
                          const SnackBar(content: Text('Name cannot be empty'), backgroundColor: AppColors.orange),
                        );
                        return;
                      }
                      try {
                        await ApiService.riderUpdateProfile({
                          'name': nameController.text.trim(),
                          if (phoneController.text.trim().isNotEmpty) 'phone': phoneController.text.trim(),
                          'vehicleType': vehicleType,
                          'vehiclePlateNumber': plateController.text.trim(),
                        });
                        if (sheetCtx.mounted) Navigator.pop(sheetCtx);
                        _loadProfile();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Profile updated ✓'), backgroundColor: AppColors.orange),
                          );
                        }
                      } catch (e) {
                        if (sheetCtx.mounted) {
                          ScaffoldMessenger.of(sheetCtx).showSnackBar(
                            SnackBar(content: Text(ErrorHelper.getMessage(e)), backgroundColor: const Color(0xFFE53935)),
                          );
                        }
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
        ),
      ),
    );
  }

  Widget _vehicleChoice(String label, IconData icon, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? AppColors.orange.withValues(alpha: 0.12) : AppColors.lightGray,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? AppColors.orange : Colors.transparent, width: 1.5),
        ),
        child: Column(
          children: [
            Icon(icon, color: selected ? AppColors.orange : AppColors.darkGray, size: 22),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: selected ? AppColors.orange : AppColors.darkGray)),
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

  Widget _buildStatItem({required IconData icon, required String label, required String value, Color? cardColor, Color? textColor}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: AppColors.orange.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, 3))],
        ),
        child: Column(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                  colors: [AppColors.orange.withValues(alpha: 0.15), AppColors.orangePale.withValues(alpha: 0.5)],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: AppColors.orange, size: 18),
            ),
            const SizedBox(height: 8),
            Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: textColor)),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(fontSize: 11, color: AppColors.darkGray)),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsCard(Color cardColor, Color textColor, Color subTextColor) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDark;

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: AppColors.orange.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          // Dark Mode Toggle
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                  colors: [AppColors.orange.withValues(alpha: 0.12), AppColors.orangePale.withValues(alpha: 0.4)],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(isDark ? Icons.dark_mode : Icons.light_mode, color: AppColors.orange, size: 18),
            ),
            title: Text('Dark Mode', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: textColor)),
            subtitle: Text(isDark ? 'Dark theme enabled' : 'Light theme enabled', style: TextStyle(color: subTextColor, fontSize: 12)),
            trailing: Switch(
              value: isDark,
              onChanged: (_) => themeProvider.toggleTheme(),
              activeThumbColor: AppColors.orange,
              activeTrackColor: AppColors.orange.withValues(alpha: 0.3),
              inactiveThumbColor: AppColors.darkGray,
              inactiveTrackColor: AppColors.lightGray,
            ),
          ),
          _buildSettingsItem(icon: Icons.receipt_long, title: 'All Orders', subtitle: 'View, search & filter orders', onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AllOrdersScreen())), textColor: textColor, subTextColor: subTextColor),
          _buildSettingsItem(icon: Icons.account_balance_wallet, title: 'Earnings', subtitle: 'Track your earnings & payments', onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const EarningsScreen())), textColor: textColor, subTextColor: subTextColor),
          _buildSettingsItem(icon: Icons.notifications_outlined, title: 'Notifications', subtitle: 'Manage push notifications', onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NotificationsScreen())), textColor: textColor, subTextColor: subTextColor),
          _buildSettingsItem(icon: Icons.location_on_outlined, title: 'Tracking Settings', subtitle: 'Battery, permissions & tracking', onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TrackingSettingsScreen())), textColor: textColor, subTextColor: subTextColor),
          _buildSettingsItem(icon: Icons.help_outline, title: 'Help & Support', subtitle: 'Get help or contact us', onTap: _showHelpDialog, textColor: textColor, subTextColor: subTextColor),
          _buildSettingsItem(icon: Icons.info_outline, title: 'About', subtitle: 'App version 1.0.0', onTap: _showAboutDialog, textColor: textColor, subTextColor: subTextColor),
          const Divider(color: AppColors.lightGray, height: 16, indent: 16, endIndent: 16),
          _buildSettingsItem(icon: Icons.swap_horiz, title: 'Switch to Customer', subtitle: 'Place orders as a customer', onTap: () => _showSwitchDialog('customer'), textColor: textColor, subTextColor: subTextColor),
        ],
      ),
    );
  }

  Widget _buildSettingsItem({required IconData icon, required String title, required String subtitle, required VoidCallback onTap, Color? textColor, Color? subTextColor}) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [AppColors.orange.withValues(alpha: 0.12), AppColors.orangePale.withValues(alpha: 0.4)],
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: AppColors.orange, size: 18),
      ),
      title: Text(title, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: textColor ?? AppColors.black)),
      subtitle: Text(subtitle, style: TextStyle(color: subTextColor ?? AppColors.darkGray, fontSize: 12)),
      trailing: const Icon(Icons.chevron_right, color: AppColors.orange, size: 20),
      onTap: onTap,
    );
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.help_outline, color: AppColors.orange, size: 24),
            SizedBox(width: 10),
            Text('Help & Support'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Need help? Contact us:', style: TextStyle(fontSize: 14, color: AppColors.darkGray)),
            SizedBox(height: 12),
            Row(children: [Icon(Icons.email, color: AppColors.orange, size: 18), SizedBox(width: 10), Flexible(child: Text('support@swiftdrop.pk', style: TextStyle(fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis))]),
            SizedBox(height: 8),
            Row(children: [Icon(Icons.phone, color: AppColors.orange, size: 18), SizedBox(width: 10), Flexible(child: Text(AppSupport.supportPhone, style: TextStyle(fontSize: 14)))]),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.orange, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.local_shipping, color: AppColors.orange, size: 24),
            SizedBox(width: 10),
            Text('SwiftDrop'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Real-time delivery tracking app', style: TextStyle(fontSize: 14, color: AppColors.darkGray)),
            SizedBox(height: 12),
            Text('Version: 1.0.0', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            SizedBox(height: 8),
            Text('Built with Flutter + NestJS', style: TextStyle(fontSize: 13, color: AppColors.darkGray)),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.orange, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _showSwitchDialog(String role) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Switch to ${role == 'customer' ? 'Customer' : 'Rider'}'),
        content: Text('Switch to ${role == 'customer' ? 'customer' : 'rider'} mode?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel', style: TextStyle(color: AppColors.darkGray))),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Switch', style: TextStyle(color: AppColors.orange))),
        ],
      ),
    );
    if (confirm == true && mounted) {
      await BackgroundLocationService.stop();
      await ApiService.logout();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const RoleSelectionScreen()),
        (route) => false,
      );
    }
  }
}