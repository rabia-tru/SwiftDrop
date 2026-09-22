import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';
import '../services/rider_order_feed.dart';

/// SwiftDrop Earnings — Real data from delivered orders (live).
///
/// Reads from the shared [RiderOrderFeed] so this tab, rider Home and the
/// Orders tab all show identical numbers and update the instant an order is
/// delivered — no separate fetch per screen.
class EarningsScreen extends StatefulWidget {
  const EarningsScreen({super.key});

  @override
  State<EarningsScreen> createState() => _EarningsScreenState();
}

class _EarningsScreenState extends State<EarningsScreen> {
  final RiderOrderFeed _feed = RiderOrderFeed.instance;
  double _weeklyGoal = 10; // deliveries per week (progress ring)

  @override
  void initState() {
    super.initState();
    // Home already started the shared feed; this tab just listens. A
    // refresh here covers the case where the tab is the first thing opened.
    _feed.addListener(_onFeedChanged);
    _feed.refresh();
  }

  @override
  void dispose() {
    _feed.removeListener(_onFeedChanged);
    super.dispose();
  }

  void _onFeedChanged() {
    if (mounted) setState(() {});
  }

  /// Deliveries per day over the last 7 days (oldest → today).
  List<int> _last7DayCounts() {
    final now = DateTime.now();
    final counts = List<int>.filled(7, 0);
    for (final o in _feed.deliveredOrders) {
      final raw = o['createdAt'];
      final t = raw is DateTime
          ? raw.toLocal()
          : DateTime.tryParse(raw?.toString() ?? '')?.toLocal();
      if (t == null) continue;
      final daysAgo = now.difference(t).inDays;
      if (daysAgo >= 0 && daysAgo < 7) counts[6 - daysAgo] += 1;
    }
    return counts;
  }

  /// Fare earned per day over the last 7 days, aligned with [_last7DayCounts].
  List<double> _last7DayEarnings() {
    final now = DateTime.now();
    final sums = List<double>.filled(7, 0);
    for (final o in _feed.deliveredOrders) {
      final raw = o['createdAt'];
      final t = raw is DateTime
          ? raw.toLocal()
          : DateTime.tryParse(raw?.toString() ?? '')?.toLocal();
      if (t == null) continue;
      final fare = double.tryParse((o['fare'] ?? '0').toString()) ?? 0;
      final daysAgo = now.difference(t).inDays;
      if (daysAgo >= 0 && daysAgo < 7) sums[6 - daysAgo] += fare;
    }
    return sums;
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

    final loading = _feed.loading && !_feed.loadedOnce;
    final error = _feed.loadedOnce ? _feed.error : null;

    return Scaffold(
      backgroundColor: bgColor,
      body: loading
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
          : error != null
              ? _buildError(textColor, subTextColor)
              : SafeArea(
                  child: Column(
                    children: [
                      _buildHeader(context, headerBg, textColor),
                      Expanded(
                        child: RefreshIndicator(
                          onRefresh: () => _feed.refresh(force: true),
                          color: AppColors.orange,
                          child: SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Column(
                              children: [
                                const SizedBox(height: 20),
                                _buildTotalEarningsCard(context, textColor),
                                const SizedBox(height: 16),
                                _buildWeeklyCard(cardColor, textColor, subTextColor),
                                const SizedBox(height: 16),
                                _buildWeeklyChart(cardColor, textColor, subTextColor),
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
            Text(_feed.error ?? '', textAlign: TextAlign.center, style: TextStyle(color: subTextColor, fontSize: 14)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _feed.refresh(force: true),
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
          const Icon(Icons.account_balance_wallet_rounded, color: AppColors.orange, size: 22),
          const SizedBox(width: 12),
          Expanded(child: Text('Earnings', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: textColor))),
          GestureDetector(
            onTap: () => _feed.refresh(force: true),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: AppColors.orangePale, borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.refresh_rounded, color: AppColors.orange, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalEarningsCard(BuildContext context, Color textColor) {
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
            'Rs.${_feed.totalEarnings.toStringAsFixed(0)}',
            style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            'From ${_feed.deliveredOrders.length} deliveries',
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Today', style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 11)),
                      const SizedBox(height: 2),
                      Text('Rs.${_feed.todayEarnings.toStringAsFixed(0)}', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('This Week', style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 11)),
                      const SizedBox(height: 2),
                      Text('Rs.${_feed.weeklyEarnings.toStringAsFixed(0)}', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyCard(Color cardColor, Color textColor, Color subTextColor) {
    final weeklyDel = _feed.deliveredOrders.where((o) {
      final raw = o['createdAt'];
      final t = raw is DateTime
          ? raw.toLocal()
          : DateTime.tryParse(raw?.toString() ?? '')?.toLocal();
      if (t == null) return false;
      return DateTime.now().difference(t).inDays < 7;
    }).length;

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
                    value: (weeklyDel / _weeklyGoal).clamp(0.0, 1.0),
                    strokeWidth: 8,
                    backgroundColor: AppColors.lightGray,
                    valueColor: const AlwaysStoppedAnimation<Color>(AppColors.orange),
                    strokeCap: StrokeCap.round,
                  ),
                ),
                Text(
                  weeklyDel.toString(),
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
                Text('Weekly Goal', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: textColor)),
                const SizedBox(height: 4),
                Text(
                  'Rs.${_feed.weeklyEarnings.toStringAsFixed(0)} this week',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.orange),
                ),
                const SizedBox(height: 4),
                Text(
                  '$weeklyDel of ${_weeklyGoal.toStringAsFixed(0)} deliveries',
                  style: TextStyle(fontSize: 12, color: subTextColor),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 7-day bar chart of deliveries (amount on tap), built from real data.
  Widget _buildWeeklyChart(Color cardColor, Color textColor, Color subTextColor) {
    final counts = _last7DayCounts();
    final earnings = _last7DayEarnings();
    const dayLabels = ['6d', '5d', '4d', '3d', '2d', '1d', 'Today'];
    final maxCount = counts.fold(1, (a, b) => a > b ? a : b);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: AppColors.orange.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Last 7 Days', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: textColor)),
          const SizedBox(height: 16),
          SizedBox(
            height: 140,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(7, (i) {
                final count = counts[i];
                final isToday = i == 6;
                final barHeight = count == 0 ? 4.0 : 18.0 + (count / maxCount) * 96.0;
                return Expanded(
                  child: Tooltip(
                    message: count == 0
                        ? 'No deliveries'
                        : '$count deliver${count == 1 ? 'y' : 'ies'} • Rs.${earnings[i].toStringAsFixed(0)}',
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (count > 0)
                            Text('$count', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: isToday ? AppColors.orange : subTextColor)),
                          const SizedBox(height: 4),
                          Container(
                            width: double.infinity,
                            height: barHeight,
                            decoration: BoxDecoration(
                              color: count == 0
                                  ? AppColors.lightGray
                                  : (isToday ? AppColors.orange : AppColors.orangeLight),
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: List.generate(7, (i) {
              return Expanded(
                child: Text(
                  dayLabels[i],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: i == 6 ? FontWeight.w800 : FontWeight.w500,
                    color: i == 6 ? AppColors.orange : subTextColor,
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(Color cardColor, Color textColor, Color subTextColor) {
    final delivered = _feed.deliveredOrders;
    final avgEarnings = delivered.isNotEmpty ? _feed.totalEarnings / delivered.length : 0.0;
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            icon: Icons.receipt_long,
            label: 'Total Orders',
            value: '${delivered.length}',
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
            label: 'Today',
            value: '${_feed.todayDeliveries}',
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
    final delivered = _feed.deliveredOrders;
    if (delivered.isEmpty) {
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
                const Icon(Icons.receipt_long, size: 48, color: AppColors.orangeLight),
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
        ...delivered.take(10).map((order) => _buildTransactionItem(order, cardColor, textColor, subTextColor)),
      ],
    );
  }

  Widget _buildTransactionItem(dynamic order, Color cardColor, Color textColor, Color subTextColor) {
    final customerName = order['customerName'] ?? 'Customer';
    final businessName = order['businessName'];
    final pickup = order['pickupAddress'] ?? 'Pickup';
    final fare = double.tryParse((order['fare'] ?? '0').toString()) ?? 0;
    final raw = order['createdAt'];
    final createdAt = raw is DateTime
        ? raw.toLocal()
        : DateTime.tryParse(raw?.toString() ?? '');

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
                Text(
                  businessName != null && businessName.toString().isNotEmpty
                      ? '$businessName • $customerName'
                      : customerName,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textColor),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
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
