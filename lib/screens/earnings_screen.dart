import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';
import '../services/api_service.dart';
import '../services/error_helper.dart';

/// SwiftDrop Earnings — Real data from delivered orders
class EarningsScreen extends StatefulWidget {
  const EarningsScreen({super.key});

  @override
  State<EarningsScreen> createState() => _EarningsScreenState();
}

class _EarningsScreenState extends State<EarningsScreen> {
  List<dynamic> _orders = [];
  bool _loading = true;
  String? _error;

  double _totalEarnings = 0;
  double _weeklyEarnings = 0;
  int _totalDeliveries = 0;
  int _weeklyDeliveries = 0;

  @override
  void initState() {
    super.initState();
    _loadEarnings();
  }

  Future<void> _loadEarnings() async {
    setState(() { _loading = true; _error = null; });
    try {
      final orders = await ApiService.getMyOrders();
      
      double total = 0;
      double weekly = 0;
      int totalDel = 0;
      int weeklyDel = 0;
      final now = DateTime.now();
      final weekAgo = now.subtract(const Duration(days: 7));

      for (final order in orders) {
        final status = order['status'] ?? '';
        final fare = double.tryParse((order['fare'] ?? '0').toString()) ?? 0;
        final createdAt = order['createdAt'] != null 
            ? DateTime.tryParse(order['createdAt']) 
            : null;

        if (status == 'delivered') {
          total += fare;
          totalDel++;
          if (createdAt != null && createdAt.isAfter(weekAgo)) {
            weekly += fare;
            weeklyDel++;
          }
        }
      }

      if (mounted) {
        setState(() {
          _orders = orders.where((o) => o['status'] == 'delivered').toList();
          _totalEarnings = total;
          _weeklyEarnings = weekly;
          _totalDeliveries = totalDel;
          _weeklyDeliveries = weeklyDel;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() {
        _error = ErrorHelper.getMessage(e);
        _loading = false;
      });
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

    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
    ));

    return Scaffold(
      backgroundColor: bgColor,
      body: _loading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 48, height: 48,
                    decoration: const BoxDecoration(color: AppColors.orange, shape: BoxShape.circle),
                    child: const Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3)),
                  ),
                  const SizedBox(height: 20),
                  Text('Loading earnings...', style: TextStyle(fontSize: 14, color: subTextColor)),
                ],
              ),
            )
          : _error != null
              ? _buildError(textColor, subTextColor)
              : SafeArea(
                  child: Column(
                    children: [
                      _buildHeader(context, headerBg, textColor),
                      Expanded(
                        child: RefreshIndicator(
                          onRefresh: _loadEarnings,
                          color: AppColors.orange,
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Column(
                              children: [
                                const SizedBox(height: 20),
                                _buildTotalEarningsCard(context, cardColor, textColor, subTextColor),
                                const SizedBox(height: 16),
                                _buildWeeklyCard(cardColor, textColor, subTextColor),
                                const SizedBox(height: 16),
                                _buildStatsRow(cardColor, textColor, subTextColor),
                                const SizedBox(height: 16),
                                _buildRecentTransactions(cardColor, textColor, subTextColor),
                                const SizedBox(height: 32),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildError(Color textColor, Color subTextColor) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(color: AppColors.orangePale, shape: BoxShape.circle),
              child: const Icon(Icons.warning, size: 48, color: AppColors.orange),
            ),
            const SizedBox(height: 20),
            Text('Oops!', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: textColor)),
            const SizedBox(height: 8),
            Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: subTextColor, fontSize: 14)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadEarnings,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.orange, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, Color headerBg, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
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
          Expanded(child: Text('Earnings', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: textColor))),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: AppColors.orangePale, borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.refresh_rounded, color: AppColors.orange, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalEarningsCard(BuildContext context, Color cardColor, Color textColor, Color subTextColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.orange, AppColors.orangeDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: AppColors.orange.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.account_balance_wallet, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              const Text('Total Earnings', style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500)),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            'Rs.${_totalEarnings.toStringAsFixed(0)}',
            style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            'From $_totalDeliveries deliveries',
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyCard(Color cardColor, Color textColor, Color subTextColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: AppColors.orange.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          SizedBox(
            width: 64, height: 64,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 64, height: 64,
                  child: CircularProgressIndicator(
                    value: _weeklyDeliveries / 10.0, // Goal of 10 per week
                    strokeWidth: 8,
                    backgroundColor: AppColors.lightGray,
                    valueColor: const AlwaysStoppedAnimation<Color>(AppColors.orange),
                    strokeCap: StrokeCap.round,
                  ),
                ),
                Text(
                  _weeklyDeliveries.toString(),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.orange),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('This Week', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: textColor)),
                const SizedBox(height: 4),
                Text(
                  'Rs.${_weeklyEarnings.toStringAsFixed(0)}',
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.orange),
                ),
                const SizedBox(height: 4),
                Text(
                  '$_weeklyDeliveries deliveries',
                  style: TextStyle(fontSize: 12, color: subTextColor),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(Color cardColor, Color textColor, Color subTextColor) {
    final avgEarnings = _totalDeliveries > 0 ? _totalEarnings / _totalDeliveries : 0.0;
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            icon: Icons.receipt_long,
            label: 'Total Orders',
            value: '$_totalDeliveries',
            cardColor: cardColor,
            textColor: textColor,
            subTextColor: subTextColor,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            icon: Icons.trending_up,
            label: 'Avg/Order',
            value: 'Rs.${avgEarnings.toStringAsFixed(0)}',
            cardColor: cardColor,
            textColor: textColor,
            subTextColor: subTextColor,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            icon: Icons.calendar_today,
            label: 'This Week',
            value: '$_weeklyDeliveries',
            cardColor: cardColor,
            textColor: textColor,
            subTextColor: subTextColor,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color cardColor,
    required Color textColor,
    required Color subTextColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: AppColors.orange.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Column(
        children: [
          Icon(icon, color: AppColors.orange, size: 22),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: textColor)),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: subTextColor)),
        ],
      ),
    );
  }

  Widget _buildRecentTransactions(Color cardColor, Color textColor, Color subTextColor) {
    if (_orders.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Recent Deliveries', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: textColor)),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                const Icon(Icons.receipt_long, size: 48, color: AppColors.orangePale),
                const SizedBox(height: 12),
                Text('No deliveries yet', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: textColor)),
                const SizedBox(height: 4),
                Text('Your completed deliveries will appear here', style: TextStyle(fontSize: 13, color: subTextColor)),
              ],
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Recent Deliveries', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: textColor)),
        const SizedBox(height: 12),
        ..._orders.take(10).map((order) => _buildTransactionItem(order, cardColor, textColor, subTextColor)),
      ],
    );
  }

  Widget _buildTransactionItem(dynamic order, Color cardColor, Color textColor, Color subTextColor) {
    final customerName = order['customerName'] ?? 'Customer';
    final pickup = order['pickupAddress'] ?? 'Pickup';
    final fare = double.tryParse((order['fare'] ?? '0').toString()) ?? 0;
    final createdAt = order['createdAt'] != null ? DateTime.tryParse(order['createdAt']) : null;
    
    String timeAgo = '';
    if (createdAt != null) {
      final diff = DateTime.now().difference(createdAt);
      if (diff.inMinutes < 60) {
        timeAgo = '${diff.inMinutes}m ago';
      } else if (diff.inHours < 24) {
        timeAgo = '${diff.inHours}h ago';
      } else {
        timeAgo = '${diff.inDays}d ago';
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: AppColors.orange.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: const BoxDecoration(color: AppColors.orangePale, shape: BoxShape.circle),
            child: const Icon(Icons.check_circle, color: AppColors.orange, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(customerName, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textColor)),
                const SizedBox(height: 3),
                Text(pickup, style: TextStyle(fontSize: 12, color: subTextColor), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '+Rs.${fare.toStringAsFixed(0)}',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.orange),
              ),
              const SizedBox(height: 3),
              Text(timeAgo, style: TextStyle(fontSize: 11, color: subTextColor)),
            ],
          ),
        ],
      ),
    );
  }
}
