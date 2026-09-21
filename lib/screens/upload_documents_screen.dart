import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';

/// Upload Documents Screen — Step 2 of 3 in rider onboarding
class UploadDocumentsScreen extends StatefulWidget {
  const UploadDocumentsScreen({super.key});

  @override
  State<UploadDocumentsScreen> createState() => _UploadDocumentsScreenState();
}

class _UploadDocumentsScreenState extends State<UploadDocumentsScreen> {
  bool _driversLicenseUploaded = false;
  bool _vehicleInsuranceUploaded = false;
  bool _backgroundCheckAuthorized = false;

  bool get _allUploaded => _driversLicenseUploaded && _vehicleInsuranceUploaded && _backgroundCheckAuthorized;

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ));

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            _buildHeader(),
            // Progress bar
            _buildProgressBar(),
            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 24),
                    _buildTitle(),
                    const SizedBox(height: 24),
                    _buildDocumentCard(
                      icon: Icons.badge_outlined,
                      title: "Driver's License",
                      subtitle: "Valid state-issued driver's license.",
                      uploaded: _driversLicenseUploaded,
                      onUpload: () => _simulateUpload('license'),
                      onRemove: () => setState(() => _driversLicenseUploaded = false),
                    ),
                    const SizedBox(height: 16),
                    _buildDocumentCard(
                      icon: Icons.directions_car_outlined,
                      title: 'Vehicle Insurance',
                      subtitle: 'Current proof of insurance for your vehicle.',
                      uploaded: _vehicleInsuranceUploaded,
                      onUpload: () => _simulateUpload('insurance'),
                      onRemove: () => setState(() => _vehicleInsuranceUploaded = false),
                    ),
                    const SizedBox(height: 16),
                    _buildBackgroundCheckCard(),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
            // Bottom button
            _buildBottomSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: const Icon(Icons.arrow_back_ios, color: AppColors.orange, size: 22),
          ),
          const SizedBox(width: 12),
          const Text(
            'SwiftDrop',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.orange),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Step 2 of 3', style: TextStyle(fontSize: 13, color: AppColors.darkGray)),
              const Text('66%', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.orange)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: 0.66,
              backgroundColor: AppColors.lightGray,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.orange),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTitle() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Upload Documents',
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.black),
        ),
        SizedBox(height: 8),
        Text(
          'We need a few documents to verify your eligibility to deliver with SwiftDrop.',
          style: TextStyle(fontSize: 15, color: AppColors.darkGray, height: 1.5),
        ),
      ],
    );
  }

  Widget _buildDocumentCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool uploaded,
    required VoidCallback onUpload,
    required VoidCallback onRemove,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: uploaded ? AppColors.orange.withValues(alpha: 0.3) : AppColors.lightGray,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          // Icon
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.lightGray,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.darkGray, size: 24),
          ),
          const SizedBox(width: 14),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.black)),
                const SizedBox(height: 4),
                Text(subtitle, style: const TextStyle(fontSize: 13, color: AppColors.darkGray)),
                const SizedBox(height: 8),
                if (uploaded)
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.statusDelivered.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_circle, color: AppColors.statusDelivered, size: 12),
                            SizedBox(width: 4),
                            Text('Uploaded', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.statusDelivered)),
                          ],
                        ),
                      ),
                    ],
                  )
                else
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.lightGray,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.info_outline, color: AppColors.darkGray, size: 12),
                            SizedBox(width: 4),
                            Text('Not Uploaded', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.darkGray)),
                          ],
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          // Upload/Edit button
          uploaded
              ? GestureDetector(
                  onTap: onRemove,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.lightGray,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.edit_outlined, color: AppColors.darkGray, size: 16),
                        SizedBox(width: 4),
                        Text('Edit', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.darkGray)),
                      ],
                    ),
                  ),
                )
              : GestureDetector(
                  onTap: onUpload,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.orange,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.upload_outlined, color: Colors.white, size: 16),
                        SizedBox(width: 6),
                        Text('Upload', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
                      ],
                    ),
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildBackgroundCheckCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _backgroundCheckAuthorized ? AppColors.statusDelivered.withValues(alpha: 0.3) : AppColors.lightGray,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.lightGray,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.shield_outlined, color: AppColors.darkGray, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Background Check', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.black)),
                const SizedBox(height: 4),
                const Text('Authorization to run a background check.', style: TextStyle(fontSize: 13, color: AppColors.darkGray)),
                const SizedBox(height: 8),
                if (_backgroundCheckAuthorized)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.statusDelivered,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle, color: Colors.white, size: 12),
                        SizedBox(width: 4),
                        Text('Authorized', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white)),
                      ],
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.lightGray,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.info_outline, color: AppColors.darkGray, size: 12),
                        SizedBox(width: 4),
                        Text('Not Authorized', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.darkGray)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          _backgroundCheckAuthorized
              ? GestureDetector(
                  onTap: () => setState(() => _backgroundCheckAuthorized = false),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.lightGray,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.edit_outlined, color: AppColors.darkGray, size: 16),
                        SizedBox(width: 4),
                        Text('Edit', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.darkGray)),
                      ],
                    ),
                  ),
                )
              : GestureDetector(
                  onTap: () => _showBackgroundCheckDialog(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.orange,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check, color: Colors.white, size: 16),
                        SizedBox(width: 6),
                        Text('Authorize', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
                      ],
                    ),
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildBottomSection() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 12, offset: const Offset(0, -4)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: _allUploaded
                  ? () {
                      Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => const EarningsPreviewScreen(),
                      ));
                    }
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: _allUploaded ? AppColors.orange : AppColors.orange.withValues(alpha: 0.4),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Continue', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                  SizedBox(width: 8),
                  Icon(Icons.arrow_forward, size: 20),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _allUploaded ? 'All documents uploaded!' : 'Please upload all required documents to proceed.',
            style: TextStyle(
              fontSize: 12,
              color: _allUploaded ? AppColors.statusDelivered : AppColors.darkGray,
            ),
          ),
        ],
      ),
    );
  }

  void _simulateUpload(String type) {
    // Show upload dialog
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.upload_file, color: AppColors.orange, size: 24),
            const SizedBox(width: 10),
            Text(type == 'license' ? 'Upload License' : 'Upload Insurance'),
          ],
        ),
        content: const Text(
          'Select a document from your gallery or take a photo.',
          style: TextStyle(fontSize: 14, color: AppColors.darkGray),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: AppColors.darkGray)),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                if (type == 'license') {
                  _driversLicenseUploaded = true;
                } else {
                  _vehicleInsuranceUploaded = true;
                }
              });
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      const Icon(Icons.check_circle, color: Colors.white, size: 18),
                      const SizedBox(width: 12),
                      Text('${type == 'license' ? 'License' : 'Insurance'} uploaded!'),
                    ],
                  ),
                  backgroundColor: AppColors.orange,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  margin: const EdgeInsets.all(16),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.orange,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Upload'),
          ),
        ],
      ),
    );
  }

  void _showBackgroundCheckDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.shield, color: AppColors.orange, size: 24),
            SizedBox(width: 10),
            Text('Background Check'),
          ],
        ),
        content: const Text(
          'By authorizing, you agree to SwiftDrop running a background check to verify your eligibility as a delivery partner. This is required for safety purposes.',
          style: TextStyle(fontSize: 14, color: AppColors.darkGray, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: AppColors.darkGray)),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() => _backgroundCheckAuthorized = true);
              Navigator.of(ctx).pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.orange,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Authorize'),
          ),
        ],
      ),
    );
  }
}

/// Earnings Preview Screen — Step 3 of 3 in rider onboarding
class EarningsPreviewScreen extends StatefulWidget {
  const EarningsPreviewScreen({super.key});

  @override
  State<EarningsPreviewScreen> createState() => _EarningsPreviewScreenState();
}

class _EarningsPreviewScreenState extends State<EarningsPreviewScreen> {
  double _hoursPerWeek = 30;

  // Earnings estimates based on hours
  double get _weeklyEarnings => _hoursPerWeek * 28; // ~Rs.28/hr
  double get _dailyEarnings => _weeklyEarnings / 7;
  double get _yearlyEarnings => _weeklyEarnings * 52;

  // Weekly chart data
  late List<double> _weeklyData;

  @override
  void initState() {
    super.initState();
    _updateWeeklyData();
  }

  void _updateWeeklyData() {
    // Simulated daily earnings based on hours
    final dailyHours = _hoursPerWeek / 7;
    _weeklyData = [
      dailyHours * 24, // Mon
      dailyHours * 26, // Tue
      dailyHours * 25, // Wed
      dailyHours * 28, // Thu
      dailyHours * 35, // Fri (Peak)
      dailyHours * 32, // Sat
      dailyHours * 22, // Sun
    ];
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ));

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    _buildTitle(),
                    const SizedBox(height: 24),
                    _buildWeeklyEarningsCard(),
                    const SizedBox(height: 16),
                    _buildEarningsBreakdownCard(),
                    const SizedBox(height: 16),
                    _buildReferralCard(),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
            _buildBottomSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: const Icon(Icons.arrow_back_ios, color: AppColors.orange, size: 22),
          ),
          const SizedBox(width: 12),
          const Text(
            'Earnings Preview',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.black),
          ),
          const Spacer(),
          const Text(
            'SwiftDrop',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.orange),
          ),
        ],
      ),
    );
  }

  Widget _buildTitle() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Earn on your terms',
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.black),
        ),
        SizedBox(height: 8),
        Text(
          'See how much you could make delivering with SwiftDrop.',
          style: TextStyle(fontSize: 15, color: AppColors.darkGray),
        ),
      ],
    );
  }

  Widget _buildWeeklyEarningsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.lightGray),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ESTIMATED WEEKLY EARNINGS',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.darkGray, letterSpacing: 1),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'Rs.${_weeklyEarnings.toStringAsFixed(0)}',
                style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w800, color: AppColors.black),
              ),
              const SizedBox(width: 4),
              const Padding(
                padding: EdgeInsets.only(bottom: 6),
                child: Text('/ wk', style: TextStyle(fontSize: 16, color: AppColors.darkGray)),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Hours slider
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Hours per week', style: TextStyle(fontSize: 14, color: AppColors.darkGray)),
              Text(
                '${_hoursPerWeek.toInt()} hrs',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.orange),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: AppColors.orange,
              inactiveTrackColor: AppColors.lightGray,
              thumbColor: AppColors.orange,
              overlayColor: AppColors.orange.withValues(alpha: 0.1),
              trackHeight: 6,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
            ),
            child: Slider(
              value: _hoursPerWeek,
              min: 10,
              max: 50,
              divisions: 8,
              onChanged: (value) {
                setState(() {
                  _hoursPerWeek = value;
                  _updateWeeklyData();
                });
              },
            ),
          ),
          // Top earners badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.statusDelivered.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.workspace_premium, color: AppColors.statusDelivered, size: 16),
                const SizedBox(width: 8),
                Text(
                  'Top earners in your area make Rs.${(_hoursPerWeek * 40).toStringAsFixed(0)}+',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.statusDelivered),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Weekly bar chart
          _buildWeeklyChart(),
        ],
      ),
    );
  }

  Widget _buildWeeklyChart() {
    final maxVal = _weeklyData.reduce((a, b) => a > b ? a : b);
    final days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final peakIndex = _weeklyData.indexOf(_weeklyData.reduce((a, b) => a > b ? a : b));

    return SizedBox(
      height: 140,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(7, (index) {
          final value = _weeklyData[index];
          final height = (value / maxVal) * 100;
          final isPeak = index == peakIndex;

          return Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (isPeak)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.orange,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text('Peak', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.white)),
                  ),
                const SizedBox(height: 4),
                Container(
                  height: height,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: isPeak ? AppColors.orange : AppColors.lightGray,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  days[index],
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isPeak ? FontWeight.w700 : FontWeight.w500,
                    color: isPeak ? AppColors.orange : AppColors.darkGray,
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildEarningsBreakdownCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.lightGray),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.pie_chart_outline, color: AppColors.orange, size: 22),
              SizedBox(width: 10),
              Text('Earnings Breakdown', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.black)),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'A transparent look at how your take-home pay is calculated on an average delivery.',
            style: TextStyle(fontSize: 14, color: AppColors.darkGray, height: 1.4),
          ),
          const SizedBox(height: 20),
          _buildBreakdownItem(color: AppColors.black, label: 'Base Pay', percentage: '~60%'),
          const SizedBox(height: 12),
          _buildBreakdownItem(color: AppColors.orange, label: 'Customer Tips', percentage: '~30%'),
          const SizedBox(height: 12),
          _buildBreakdownItem(color: AppColors.statusDelivered, label: 'Promos & Surges', percentage: '~10%'),
          const SizedBox(height: 16),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Row(
              children: [
                Expanded(flex: 6, child: Container(height: 8, color: AppColors.black)),
                Expanded(flex: 3, child: Container(height: 8, color: AppColors.orange)),
                Expanded(flex: 1, child: Container(height: 8, color: AppColors.statusDelivered)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'You keep 100% of tips.',
            style: TextStyle(fontSize: 13, color: AppColors.darkGray),
          ),
        ],
      ),
    );
  }

  Widget _buildBreakdownItem({required Color color, required String label, required String percentage}) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(label, style: const TextStyle(fontSize: 15, color: AppColors.black))),
        Text(percentage, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.darkGray)),
      ],
    );
  }

  Widget _buildReferralCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.orangePale.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.orange.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.orange,
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text('BONUS OFFER', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 0.5)),
          ),
          const SizedBox(height: 16),
          const Text('Refer a Friend', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.black)),
          const SizedBox(height: 8),
          const Text(
            'Know someone who wants to earn? Refer them and get a bonus when they complete 50 deliveries.',
            style: TextStyle(fontSize: 14, color: AppColors.darkGray, height: 1.4),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.lightGray),
            ),
            child: Row(
              children: [
                const Text('Potential Bonus', style: TextStyle(fontSize: 14, color: AppColors.darkGray)),
                const Spacer(),
                const Text(
                  '+Rs.25,000',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.statusDelivered),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomSection() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 12, offset: const Offset(0, -4)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: () {
                // Finish signup - go to home screen
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.orange,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: const Text('Finish Signup', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'By continuing, you agree to the Terms of Service.',
            style: TextStyle(fontSize: 11, color: AppColors.darkGray),
          ),
        ],
      ),
    );
  }
}
