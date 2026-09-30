import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../services/battery_optimization_helper.dart';
import '../services/location_permission_helper.dart';
import '../services/background_location_service.dart';
import '../services/service_watchdog.dart';
import 'package:geolocator/geolocator.dart';

/// Tracking Settings — Battery optimization, permissions, tracking config
class TrackingSettingsScreen extends StatefulWidget {
  const TrackingSettingsScreen({super.key});

  @override
  State<TrackingSettingsScreen> createState() => _TrackingSettingsScreenState();
}

class _TrackingSettingsScreenState extends State<TrackingSettingsScreen> {
  bool _batteryOptimizationDisabled = false;
  bool _locationPermissionGranted = false;
  bool _backgroundLocationGranted = false;
  bool _serviceRunning = false;
  WatchdogStatus? _watchdogStatus;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadStatuses();
    // Refresh heartbeat age periodically so the "last beat" line stays
    // live while the user stares at this screen.
    _watchdogRefreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted) _refreshWatchdogStatus();
    });
  }

  Timer? _watchdogRefreshTimer;

  @override
  void dispose() {
    _watchdogRefreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _refreshWatchdogStatus() async {
    final status = await ServiceWatchdog.status();
    if (mounted) setState(() => _watchdogStatus = status);
  }

  Future<void> _loadStatuses() async {
    final batteryOk = await BatteryOptimizationHelper.isIgnoringBatteryOptimizations();
    final permission = await Geolocator.checkPermission();
    final bgPermission = permission == LocationPermission.always;
    final serviceRunning = await BackgroundLocationService.isRunning();
    WatchdogStatus? watchdogStatus;
    try {
      watchdogStatus = await ServiceWatchdog.status();
    } catch (_) {
      watchdogStatus = null; // card simply won't render
    }

    if (mounted) {
      setState(() {
        _batteryOptimizationDisabled = batteryOk;
        _locationPermissionGranted = permission == LocationPermission.whileInUse || permission == LocationPermission.always;
        _backgroundLocationGranted = bgPermission;
        _serviceRunning = serviceRunning;
        _watchdogStatus = watchdogStatus;
        _loading = false;
      });
    }
  }

  Future<void> _requestBatteryExemption() async {
    // Show explanation first
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.battery_saver, color: AppColors.orange, size: 24),
            SizedBox(width: 10),
            Text('Battery Optimization'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'To ensure location tracking continues in the background, please disable battery optimization for SwiftDrop.',
              style: TextStyle(fontSize: 14, color: AppColors.darkGray, height: 1.5),
            ),
            SizedBox(height: 12),
            Text(
              'This will show a system dialog. Select "Allow" or "Don\'t optimize".',
              style: TextStyle(fontSize: 13, color: AppColors.darkGray),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.darkGray)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.orange,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Allow'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final result = await BatteryOptimizationHelper.requestIgnoreBatteryOptimizations();
      if (mounted) {
        setState(() => _batteryOptimizationDisabled = result);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(result ? Icons.check_circle : Icons.info, color: Colors.white, size: 18),
                const SizedBox(width: 12),
                Text(result ? 'Battery optimization disabled!' : 'Please approve in the system dialog'),
              ],
            ),
            backgroundColor: result ? AppColors.orange : AppColors.orangeDark,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    }
  }

  Future<void> _requestLocationPermission() async {
    final result = await LocationPermissionHelper.requestFullAccess();
    if (mounted) {
      setState(() {
        _locationPermissionGranted = result.granted;
        _backgroundLocationGranted = result.backgroundGranted;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(result.granted ? Icons.check_circle : Icons.warning, color: Colors.white, size: 18),
              const SizedBox(width: 12),
              Expanded(child: Text(result.message)),
            ],
          ),
          backgroundColor: result.granted ? AppColors.orange : AppColors.orangeDark,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0A0A0A) : AppColors.offWhite;
    final cardColor = isDark ? const Color(0xFF1A1A1A) : Colors.white;
    final textColor = isDark ? Colors.white : AppColors.black;
    final subTextColor = isDark ? const Color(0xFFB0B0B0) : AppColors.darkGray;
    final headerBg = isDark ? const Color(0xFF121212) : Colors.white;

    AppColors.setLightStatusBar();
    if (_loading) {
      return Scaffold(
        backgroundColor: bgColor,
        body: const Center(child: CircularProgressIndicator(color: AppColors.orange)),
      );
    }

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            _buildHeader(context, headerBg, textColor),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    // Overall Status
                    _buildOverallStatus(cardColor, textColor, subTextColor),
                    const SizedBox(height: 16),
                    // Battery Optimization
                    _buildBatteryCard(cardColor, textColor, subTextColor),
                    const SizedBox(height: 16),
                    // Location Permissions
                    _buildLocationCard(cardColor, textColor, subTextColor),
                    const SizedBox(height: 16),
                    // Tracking Service
                    _buildServiceCard(cardColor, textColor, subTextColor),
                    const SizedBox(height: 16),
                    // Kill-survival watchdog diagnostics (Android only)
                    if (Platform.isAndroid && _watchdogStatus != null) ...[
                      _buildWatchdogCard(_watchdogStatus!, cardColor, textColor, subTextColor),
                      const SizedBox(height: 16),
                    ],
                    // Manufacturer Guide
                    if (Platform.isAndroid) ...[
                      _buildManufacturerGuide(cardColor, textColor, subTextColor),
                      const SizedBox(height: 16),
                    ],
                    // Tips
                    _buildTipsCard(cardColor, textColor, subTextColor),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, Color headerBg, Color textColor) {
    final statusBarHeight = MediaQuery.of(context).padding.top;
    return Container(
      padding: EdgeInsets.fromLTRB(20, statusBarHeight + 14, 20, 14),
      decoration: BoxDecoration(
        color: headerBg,
        boxShadow: [BoxShadow(color: AppColors.orange.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: const Icon(Icons.arrow_back_ios, color: AppColors.orange, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(child: Text('Tracking Settings', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: textColor))),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: AppColors.orangePale, borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.gps_fixed, color: AppColors.orange, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildOverallStatus(Color cardColor, Color textColor, Color subTextColor) {
    final allGood = _batteryOptimizationDisabled && _locationPermissionGranted && _backgroundLocationGranted;
    final hasIssues = !allGood;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: hasIssues ? AppColors.orangePale : AppColors.statusDelivered.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasIssues ? AppColors.orange.withValues(alpha: 0.3) : AppColors.statusDelivered.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: hasIssues ? AppColors.orange : AppColors.statusDelivered,
              shape: BoxShape.circle,
            ),
            child: Icon(hasIssues ? Icons.warning : Icons.check_circle, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasIssues ? 'Setup Incomplete' : 'All Good!',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: textColor),
                ),
                const SizedBox(height: 4),
                Text(
                  hasIssues ? 'Complete the setup below for reliable tracking' : 'Background tracking is fully configured',
                  style: TextStyle(fontSize: 13, color: subTextColor),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBatteryCard(Color cardColor, Color textColor, Color subTextColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _batteryOptimizationDisabled ? AppColors.statusDelivered.withValues(alpha: 0.1) : AppColors.orangePale,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _batteryOptimizationDisabled ? Icons.battery_saver : Icons.battery_alert,
                  color: _batteryOptimizationDisabled ? AppColors.statusDelivered : AppColors.orange,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Battery Optimization', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: textColor)),
                    Text(
                      _batteryOptimizationDisabled ? 'Disabled (Good!)' : 'Enabled (May stop tracking)',
                      style: TextStyle(fontSize: 12, color: _batteryOptimizationDisabled ? AppColors.statusDelivered : AppColors.orange),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _batteryOptimizationDisabled ? AppColors.statusDelivered : AppColors.orange,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _batteryOptimizationDisabled ? 'OK' : 'FIX',
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          if (!_batteryOptimizationDisabled) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _requestBatteryExemption,
                icon: const Icon(Icons.shield, size: 18),
                label: const Text('Disable Battery Optimization'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.orange,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLocationCard(Color cardColor, Color textColor, Color subTextColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _backgroundLocationGranted ? AppColors.statusDelivered.withValues(alpha: 0.1) : AppColors.orangePale,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _backgroundLocationGranted ? Icons.location_on : Icons.location_off,
                  color: _backgroundLocationGranted ? AppColors.statusDelivered : AppColors.orange,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Location Permission', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: textColor)),
                    Text(
                      _backgroundLocationGranted
                          ? 'Allow all the time (Good!)'
                          : _locationPermissionGranted
                              ? 'While using only (Needs "All the time")'
                              : 'Not granted',
                      style: TextStyle(
                        fontSize: 12,
                        color: _backgroundLocationGranted ? AppColors.statusDelivered : AppColors.orange,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Permission details
          _buildPermissionRow('Location Access', _locationPermissionGranted),
          const SizedBox(height: 8),
          _buildPermissionRow('Background Location', _backgroundLocationGranted),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _requestLocationPermission,
              icon: const Icon(Icons.location_on, size: 18),
              label: Text(_backgroundLocationGranted ? 'Re-check Permissions' : 'Grant Location Permission'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _backgroundLocationGranted ? AppColors.lightGray : AppColors.orange,
                foregroundColor: _backgroundLocationGranted ? AppColors.darkGray : Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionRow(String label, bool granted) {
    return Row(
      children: [
        Icon(granted ? Icons.check_circle : Icons.cancel, color: granted ? AppColors.statusDelivered : AppColors.orangeDark, size: 16),
        const SizedBox(width: 8),
        Text(label, style: TextStyle(fontSize: 13, color: granted ? AppColors.statusDelivered : AppColors.orangeDark)),
        const Spacer(),
        Text(granted ? 'Granted' : 'Not granted', style: TextStyle(fontSize: 12, color: AppColors.darkGray)),
      ],
    );
  }

  Widget _buildServiceCard(Color cardColor, Color textColor, Color subTextColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _serviceRunning ? AppColors.statusDelivered.withValues(alpha: 0.1) : AppColors.orangePale,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _serviceRunning ? Icons.play_circle : Icons.stop_circle,
                  color: _serviceRunning ? AppColors.statusDelivered : AppColors.darkGray,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Tracking Service', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: textColor)),
                    Text(
                      _serviceRunning ? 'Running in background' : 'Not running',
                      style: TextStyle(fontSize: 12, color: _serviceRunning ? AppColors.statusDelivered : AppColors.darkGray),
                    ),
                  ],
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _serviceRunning ? AppColors.statusDelivered : AppColors.lightGray,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _serviceRunning ? 'ACTIVE' : 'INACTIVE',
                  style: TextStyle(
                    color: _serviceRunning ? Colors.white : AppColors.darkGray,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWatchdogCard(
      WatchdogStatus status, Color cardColor, Color textColor, Color subTextColor) {
    final health = status.health;

    // Verdict line + color per health state.
    String verdict;
    Color verdictColor;
    IconData verdictIcon;
    switch (health) {
      case WatchdogHealth.healthy:
        verdict = 'Protected — will auto-restart if killed';
        verdictColor = AppColors.statusDelivered;
        verdictIcon = Icons.verified_user;
      case WatchdogHealth.stale:
        verdict = 'Service quiet — restart expected within ~2 min';
        verdictColor = AppColors.orange;
        verdictIcon = Icons.schedule;
      case WatchdogHealth.neverRan:
        verdict = 'Armed — activates when tracking starts';
        verdictColor = AppColors.orange;
        verdictIcon = Icons.shield_outlined;
      case WatchdogHealth.disarmed:
        verdict = 'Idle — activates when tracking starts';
        verdictColor = AppColors.darkGray;
        verdictIcon = Icons.shield_outlined;
      case WatchdogHealth.broken:
        verdict = 'Alarm permission missing — auto-restart disabled!';
        verdictColor = AppColors.orangeDark;
        verdictIcon = Icons.gpp_bad;
      case WatchdogHealth.notApplicable:
        verdict = 'Not applicable on this platform';
        verdictColor = AppColors.darkGray;
        verdictIcon = Icons.info_outline;
    }

    String beatAgeText;
    final age = status.lastBeatAge;
    if (age == null) {
      beatAgeText = 'never';
    } else if (age < 1000) {
      beatAgeText = 'just now';
    } else if (age < 60000) {
      beatAgeText = '${age ~/ 1000}s ago';
    } else {
      beatAgeText = '${age ~/ 60000}m ${((age % 60000) / 1000).round()}s ago';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
        border: health == WatchdogHealth.broken
            ? Border.all(color: AppColors.orangeDark.withValues(alpha: 0.4))
            : null,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: verdictColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(health == WatchdogHealth.healthy ? Icons.verified_user : verdictIcon,
                    color: verdictColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Auto-Restart Protection', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: textColor)),
                    Text(verdict, style: TextStyle(fontSize: 12, color: verdictColor)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildWatchdogRow(
            'Watchdog armed',
            status.armed ? 'Yes' : 'No',
            status.armed,
            subTextColor,
          ),
          const SizedBox(height: 6),
          _buildWatchdogRow(
            'Exact alarm permission',
            status.canScheduleExactAlarms ? 'Granted' : 'REVOKED',
            status.canScheduleExactAlarms,
            subTextColor,
          ),
          const SizedBox(height: 6),
          _buildWatchdogRow(
            'Service heartbeat',
            beatAgeText,
            age != null && age <= WatchdogStatus.maxHealthyBeatAgeMs,
            subTextColor,
          ),
          if (status.lastBeatAt != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const SizedBox(width: 24),
                Text(
                  'Last beat: ${TimeOfDay.fromDateTime(status.lastBeatAt!).format(context)}',
                  style: TextStyle(fontSize: 11, color: subTextColor.withValues(alpha: 0.7)),
                ),
              ],
            ),
          ],
          if (health == WatchdogHealth.broken) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => BatteryOptimizationHelper.openBatteryOptimizationSettings(),
                icon: const Icon(Icons.settings, size: 18),
                label: const Text('Open Settings to Fix Alarms'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.orangeDark,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildWatchdogRow(String label, String value, bool ok, Color subTextColor) {
    return Row(
      children: [
        Icon(
          ok ? Icons.check_circle : Icons.cancel,
          color: ok ? AppColors.statusDelivered : AppColors.orangeDark,
          size: 16,
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(label, style: TextStyle(fontSize: 13, color: subTextColor))),
        Text(value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: ok ? AppColors.statusDelivered : AppColors.orangeDark,
            )),
      ],
    );
  }

  Widget _buildManufacturerGuide(Color cardColor, Color textColor, Color subTextColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.orangePale.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.orange.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.phone_android, color: AppColors.orange, size: 20),
              const SizedBox(width: 8),
              Text('Device-Specific Instructions', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: textColor)),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            BatteryOptimizationHelper.getManufacturerInstructions(),
            style: TextStyle(fontSize: 13, color: subTextColor, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildTipsCard(Color cardColor, Color textColor, Color subTextColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.lightbulb, color: AppColors.orange, size: 20),
              const SizedBox(width: 8),
              Text('Tips for Reliable Tracking', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: textColor)),
            ],
          ),
          const SizedBox(height: 12),
          _buildTipItem('Keep GPS turned on at all times', subTextColor),
          const SizedBox(height: 8),
          _buildTipItem('Don\'t force-close the app from recents', subTextColor),
          const SizedBox(height: 8),
          _buildTipItem('Add SwiftDrop to battery whitelist', subTextColor),
          const SizedBox(height: 8),
          _buildTipItem('Allow auto-start on Xiaomi/OPPO/Vivo', subTextColor),
          const SizedBox(height: 8),
          _buildTipItem('Disable "App Lock" for SwiftDrop', subTextColor),
        ],
      ),
    );
  }

  Widget _buildTipItem(String text, Color subTextColor) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.check_circle_outline, color: AppColors.orange, size: 16),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: TextStyle(fontSize: 13, color: subTextColor))),
      ],
    );
  }
}
