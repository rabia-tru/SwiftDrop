import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../theme/app_colors.dart';
import '../services/api_service.dart';

/// Refer & Earn Screen — FoodPanda-style referral system
class ReferralScreen extends StatefulWidget {
  const ReferralScreen({super.key});

  @override
  State<ReferralScreen> createState() => _ReferralScreenState();
}

class _ReferralScreenState extends State<ReferralScreen> {
  String _referralCode = '';
  int _totalReferrals = 0;
  double _totalEarnings = 0;
  bool _loading = true;
  final _referralInputController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadReferralData();
  }

  @override
  void dispose() {
    _referralInputController.dispose();
    super.dispose();
  }

  Future<void> _loadReferralData() async {
    try {
      // Generate a referral code based on user ID
      final user = await ApiService.customerGetMe();
      final userId = user['id'] ?? 'USER';
      _referralCode = 'SWIFT${userId.toString().substring(0, 6).toUpperCase()}';
      _totalReferrals = 0;
      _totalEarnings = 0;
    } catch (e) {
      _referralCode = 'SWIFT${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
    }
    setState(() => _loading = false);
  }

  void _copyCode() {
    Clipboard.setData(ClipboardData(text: _referralCode));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Referral code copied!'),
        backgroundColor: AppColors.statusDelivered,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _shareCode() {
    Share.share(
      'Hey! Use my referral code $_referralCode on SwiftDrop and get Rs.100 off your first order! 🎉\n\nDownload now: https://swiftdrop.app/download',
      subject: 'SwiftDrop Referral',
    );
  }

  void _applyReferral() {
    final code = _referralInputController.text.trim().toUpperCase();
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please enter a referral code'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    if (code == _referralCode) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('You cannot use your own referral code!'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    // Success
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: AppColors.statusDelivered.withValues(alpha: 0.1), shape: BoxShape.circle),
              child: const Icon(Icons.check_circle, color: AppColors.statusDelivered, size: 28),
            ),
            const SizedBox(width: 10),
            const Text('Success!', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          ],
        ),
        content: const Text('Rs.100 has been added to your wallet! Use it on your next order.', style: TextStyle(fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Great!', style: TextStyle(color: AppColors.orange, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    AppColors.setLightStatusBar();
    return Scaffold(
      backgroundColor: AppColors.offWhite,
      body: _loading
        ? const Center(child: CircularProgressIndicator(color: AppColors.orange))
        : CustomScrollView(
            slivers: [
              // Gradient header
              SliverToBoxAdapter(child: _buildHeader()),
              // Your code section
              SliverToBoxAdapter(child: _buildYourCodeSection()),
              // How it works
              SliverToBoxAdapter(child: _buildHowItWorks()),
              // Enter referral code
              SliverToBoxAdapter(child: _buildEnterCodeSection()),
              // Stats
              SliverToBoxAdapter(child: _buildStatsSection()),
              // Terms
              SliverToBoxAdapter(child: _buildTerms()),
              const SliverToBoxAdapter(child: SizedBox(height: 40)),
            ],
          ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 10, 20, 30),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.orange, AppColors.orangeDark],
        ),
      ),
      child: Column(
        children: [
          // Back button
          Align(
            alignment: Alignment.centerLeft,
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
              ),
            ),
          ),
          const SizedBox(height: 20),
          // Gift icon
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.card_giftcard, color: Colors.white, size: 48),
          ),
          const SizedBox(height: 16),
          const Text('Refer & Earn', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Colors.white)),
          const SizedBox(height: 8),
          Text(
            'Invite friends and earn Rs.100 for each referral!',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.9)),
          ),
          const SizedBox(height: 16),
          // Earnings badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'Total Earned: Rs.${_totalEarnings.toStringAsFixed(0)}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.orange),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildYourCodeSection() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: AppColors.orange.withValues(alpha: 0.1), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Column(
          children: [
            const Text('Your Referral Code', style: TextStyle(fontSize: 14, color: AppColors.darkGray)),
            const SizedBox(height: 8),
            // Code display
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: AppColors.orangePale,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.orange.withValues(alpha: 0.3), width: 2),
              ),
              child: Text(
                _referralCode,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.orange, letterSpacing: 4),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                // Copy button
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _copyCode,
                    icon: const Icon(Icons.copy, size: 18),
                    label: const Text('Copy Code'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.orange,
                      side: const BorderSide(color: AppColors.orange),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Share button
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _shareCode,
                    icon: const Icon(Icons.share, size: 18),
                    label: const Text('Share'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.orange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHowItWorks() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('How it works', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.black)),
          const SizedBox(height: 16),
          _buildStep(1, 'Share your code', 'Send your referral code to friends via WhatsApp, SMS, or social media'),
          _buildStep(2, 'Friend signs up', 'Your friend creates an account and enters your code'),
          _buildStep(3, 'Both earn Rs.100!', 'You get Rs.100 and your friend gets Rs.100 off their first order'),
        ],
      ),
    );
  }

  Widget _buildStep(int number, String title, String description) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: const BoxDecoration(color: AppColors.orange, shape: BoxShape.circle),
            child: Center(child: Text('$number', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white))),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.black)),
                const SizedBox(height: 3),
                Text(description, style: TextStyle(fontSize: 12, color: AppColors.darkGray)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnterCodeSection() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 3))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Have a referral code?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.black)),
            const SizedBox(height: 4),
            Text('Enter your friend\'s code to earn Rs.100', style: TextStyle(fontSize: 13, color: AppColors.darkGray)),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _referralInputController,
                    textCapitalization: TextCapitalization.characters,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 2),
                    decoration: InputDecoration(
                      hintText: 'Enter code',
                      hintStyle: TextStyle(color: AppColors.darkGray.withValues(alpha: 0.4)),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.orange, width: 2)),
                      filled: true,
                      fillColor: AppColors.lightGray,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: _applyReferral,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    decoration: BoxDecoration(color: AppColors.orange, borderRadius: BorderRadius.circular(12)),
                    child: const Text('Apply', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(child: _buildStatCard('Total Referrals', '$_totalReferrals', Icons.people)),
          const SizedBox(width: 12),
          Expanded(child: _buildStatCard('Earned', 'Rs.${_totalEarnings.toStringAsFixed(0)}', Icons.account_balance_wallet)),
          const SizedBox(width: 12),
          Expanded(child: _buildStatCard('Pending', '0', Icons.schedule)),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        children: [
          Icon(icon, color: AppColors.orange, size: 24),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.orange)),
          const SizedBox(height: 4),
          Text(label, textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: AppColors.darkGray)),
        ],
      ),
    );
  }

  Widget _buildTerms() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Terms & Conditions', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.black)),
          const SizedBox(height: 8),
          _buildTerm('• Rs.100 credit for each successful referral'),
          _buildTerm('• Friend must place their first order to activate reward'),
          _buildTerm('• Maximum 50 referrals per account'),
          _buildTerm('• Credits expire after 90 days'),
          _buildTerm('• SwiftDrop reserves the right to modify terms'),
        ],
      ),
    );
  }

  Widget _buildTerm(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(text, style: TextStyle(fontSize: 12, color: AppColors.darkGray)),
    );
  }
}
