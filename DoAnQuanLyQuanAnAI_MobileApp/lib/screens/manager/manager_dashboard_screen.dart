import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:doanquanlyquananai_mobileapp/theme/app_colors.dart';
import 'package:doanquanlyquananai_mobileapp/theme/app_theme.dart';
import 'package:doanquanlyquananai_mobileapp/config/constants.dart';
import 'package:doanquanlyquananai_mobileapp/services/auth_service.dart';
import 'package:doanquanlyquananai_mobileapp/services/locale_service.dart';
import 'package:doanquanlyquananai_mobileapp/l10n/app_localizations.dart';
import 'package:doanquanlyquananai_mobileapp/screens/login_screen.dart';
import 'package:doanquanlyquananai_mobileapp/services/dashboard_provider.dart';
import 'package:doanquanlyquananai_mobileapp/services/branch_service.dart';
import 'package:doanquanlyquananai_mobileapp/models/branch/branch.dart';
import 'package:doanquanlyquananai_mobileapp/screens/manager/customer_management_screen.dart';
import 'package:doanquanlyquananai_mobileapp/screens/manager/staff_management_screen.dart';
import 'package:doanquanlyquananai_mobileapp/screens/manager/menu_availability_screen.dart';
import 'package:doanquanlyquananai_mobileapp/screens/manager/ai_alerts_screen.dart';
import 'package:doanquanlyquananai_mobileapp/screens/manager/discount_management_screen.dart';
import 'package:doanquanlyquananai_mobileapp/screens/manager/reservation_manage_screen.dart';
import 'package:doanquanlyquananai_mobileapp/screens/staff/staff_main_screen.dart';
import 'package:doanquanlyquananai_mobileapp/services/booking_notification_provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

class ManagerDashboardScreen extends StatefulWidget {
  const ManagerDashboardScreen({super.key});

  @override
  State<ManagerDashboardScreen> createState() => _ManagerDashboardScreenState();
}

class _ManagerDashboardScreenState extends State<ManagerDashboardScreen> {
  int? _selectedBranchId;
  List<Branch> _branches = [];
  bool _isLoadingBranches = false;
  DateTimeRange? _selectedDateRange;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initDashboard();
    });
  }

  Future<void> _initDashboard() async {
    final authService = context.read<AuthService>();
    final user = authService.currentUser;
    
    if (user?.role == 0) {
      setState(() => _isLoadingBranches = true);
      final res = await BranchService().getBranches();
      if (res.isSuccess) {
        _branches = res.data ?? [];
      }
      setState(() => _isLoadingBranches = false);
    }
    
    _loadDashboardData();
  }

  void _loadDashboardData() {
    final authService = context.read<AuthService>();
    final user = authService.currentUser;
    int? bId = user?.role == 0 ? _selectedBranchId : user?.branchId;
    context.read<DashboardProvider>().loadDashboardData(
      branchId: bId,
      from: _selectedDateRange?.start,
      to: _selectedDateRange?.end,
    );
    // Fetch pending reservation notifications
    if (bId != null) {
      context.read<BookingNotificationProvider>().fetchPendingReservations(bId);
    } else {
      context.read<BookingNotificationProvider>().fetchPendingReservations(1);
    }
  }

  void _setDateRange(DateTimeRange range) {
    setState(() => _selectedDateRange = range);
    _loadDashboardData();
    Navigator.pop(context);
  }

  Future<void> _showDateFilterBottomSheet() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radiusLg)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: AppTheme.marginMobile),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Thời gian thống kê', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                  ],
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    ActionChip(
                      label: const Text('Hôm nay'),
                      onPressed: () => _setDateRange(DateTimeRange(start: today, end: today)),
                    ),
                    ActionChip(
                      label: const Text('Hôm qua'),
                      onPressed: () => _setDateRange(DateTimeRange(start: today.subtract(const Duration(days: 1)), end: today.subtract(const Duration(days: 1)))),
                    ),
                    ActionChip(
                      label: const Text('7 ngày qua'),
                      onPressed: () => _setDateRange(DateTimeRange(start: today.subtract(const Duration(days: 6)), end: today)),
                    ),
                    ActionChip(
                      label: const Text('Tháng này'),
                      onPressed: () => _setDateRange(DateTimeRange(start: DateTime(now.year, now.month, 1), end: today)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.date_range_rounded, color: AppColors.primary),
                  title: const Text('Tùy chỉnh thời gian...', style: TextStyle(fontWeight: FontWeight.w500)),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () async {
                    Navigator.pop(context);
                    final initialDateRange = _selectedDateRange ?? DateTimeRange(
                      start: today.subtract(const Duration(days: 7)),
                      end: today,
                    );
                    final picked = await showDateRangePicker(
                      context: context,
                      firstDate: DateTime(2020),
                      lastDate: today,
                      initialDateRange: initialDateRange,
                      builder: (context, child) {
                        return Theme(
                          data: Theme.of(context).copyWith(
                            colorScheme: ColorScheme.light(
                              primary: AppColors.primary,
                              onPrimary: Colors.white,
                              onSurface: AppColors.onSurface,
                            ),
                          ),
                          child: child!,
                        );
                      },
                    );
                    if (picked != null) {
                      setState(() => _selectedDateRange = picked);
                      _loadDashboardData();
                    }
                  },
                ),
              ],
            ),
          ),
        );
      }
    );
  }

  String _formatCurrencyShort(double amount) {
    if (amount >= 1000000) {
      return '₫${(amount / 1000000).toStringAsFixed(1)}M';
    } else if (amount >= 1000) {
      return '₫${(amount / 1000).toStringAsFixed(0)}K';
    }
    return '₫${amount.toStringAsFixed(0)}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.marginMobile),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SizedBox(height: 16),
            // Admin Console header
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(l10n.translate('admin_console'), style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600, letterSpacing: 1)),
                Text(AppConstants.appName, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700)),
              ]),
              Row(children: [
                Consumer<BookingNotificationProvider>(
                  builder: (context, notifyProv, _) {
                    return Stack(
                      clipBehavior: Clip.none,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.notifications_rounded),
                          color: AppColors.primary,
                          tooltip: 'Thông báo đặt bàn',
                          onPressed: () {
                            notifyProv.clearUnread();
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const ReservationManageScreen()),
                            );
                          },
                        ),
                        if (notifyProv.unreadCount > 0)
                          Positioned(
                            right: 4,
                            top: 4,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                              constraints: const BoxConstraints(
                                minWidth: 18,
                                minHeight: 18,
                              ),
                              child: Text(
                                '${notifyProv.unreadCount}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.language_rounded),
                  onPressed: () => context.read<LocaleService>().toggleLocale(),
                  color: AppColors.primary,
                  tooltip: l10n.translate('language'),
                ),
                IconButton(
                  icon: const Icon(Icons.logout_rounded),
                  color: AppColors.error,
                  tooltip: l10n.translate('log_out'),
                  onPressed: () async {
                    await context.read<AuthService>().logout();
                    if (context.mounted) {
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                        (route) => false,
                      );
                    }
                  },
                ),
              ]),
            ]),
            if (context.read<AuthService>().currentUser?.role == 0) ...[
              const SizedBox(height: 16),
              if (_isLoadingBranches)
                const CircularProgressIndicator()
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    border: Border.all(color: AppColors.outlineVariant.withAlpha(50)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int?>(
                      value: _selectedBranchId,
                      isExpanded: true,
                      hint: const Text('Tất cả chi nhánh'),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('Tất cả chi nhánh')),
                        ..._branches.map((b) => DropdownMenuItem(value: b.branchId, child: Text(b.name))),
                      ],
                      onChanged: (val) {
                        setState(() => _selectedBranchId = val);
                        _loadDashboardData();
                      },
                    ),
                  ),
                ),
            ],
            const SizedBox(height: 24),

            // Navigation tiles
            _NavGrid(loadDashboardData: _loadDashboardData),
            const SizedBox(height: 24),

            // Dashboard Overview
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.translate('dashboard_overview'), style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 4),
                    Text(l10n.translate('realtime_metrics'), style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
                TextButton.icon(
                  onPressed: _showDateFilterBottomSheet,
                  icon: const Icon(Icons.calendar_month_rounded, size: 18),
                  label: Text(_selectedDateRange == null 
                    ? '30 ngày qua' 
                    : '${DateFormat('dd/MM').format(_selectedDateRange!.start)} - ${DateFormat('dd/MM').format(_selectedDateRange!.end)}'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    backgroundColor: AppColors.primaryContainer.withAlpha(50),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Metric cards
            Consumer<DashboardProvider>(
              builder: (context, provider, child) {
                if (provider.isLoading) {
                  return const SizedBox(height: 150, child: Center(child: CircularProgressIndicator()));
                }

                if (provider.errorMessage != null) {
                  return Center(child: Text(provider.errorMessage!));
                }

                final sum = provider.summary;
                if (sum == null) return const SizedBox.shrink();

                return Column(
                  children: [
                    Row(children: [
                      _MetricCard(label: l10n.translate('revenue'), value: _formatCurrencyShort(sum.totalRevenue), change: '', icon: Icons.trending_up_rounded, positive: true),
                      const SizedBox(width: 12),
                      _MetricCard(label: l10n.translate('orders'), value: '${sum.totalInvoices}', change: '', icon: Icons.receipt_long_rounded, positive: true),
                    ]),
                    const SizedBox(height: 12),
                    Row(children: [
                      _MetricCard(label: l10n.translate('avg_order'), value: _formatCurrencyShort(sum.avgOrderValue), change: '', icon: Icons.analytics_rounded, positive: true),
                      const SizedBox(width: 12),
                      _MetricCard(label: l10n.translate('cancels'), value: '${sum.openOrders}', change: '', icon: Icons.cancel_outlined, positive: false),
                    ]),
                    
                    const SizedBox(height: 24),

                    // Action Required
                    if (sum.unresolvedAlerts > 0)
                    Container(width: double.infinity, padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: AppColors.warningContainer,
                        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                        border: Border.all(color: AppColors.warning.withAlpha(80)),
                      ),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Container(padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: AppColors.warning.withAlpha(40), borderRadius: BorderRadius.circular(10)),
                          child: const Icon(Icons.warning_amber_rounded, size: 20, color: Color(0xFF8D6E00)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(l10n.translate('action_required'), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF8D6E00))),
                          const SizedBox(height: 4),
                          Text('${sum.unresolvedAlerts} ${l10n.translate('fraud_alerts')}',
                            style: TextStyle(fontSize: 13, color: const Color(0xFF8D6E00).withAlpha(200))),
                        ])),
                      ]),
                    ),
                    if (sum.unresolvedAlerts > 0) const SizedBox(height: 24),

                    // Revenue Chart
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Biểu đồ doanh thu', style: Theme.of(context).textTheme.titleLarge)
                    ),
                    const SizedBox(height: 16),
                    if (provider.revenueDays.isNotEmpty)
                      Container(
                        height: 250,
                        padding: const EdgeInsets.only(right: 16, top: 16, bottom: 16),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainerLowest,
                          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                          border: Border.all(color: AppColors.outlineVariant.withAlpha(60)),
                          boxShadow: AppTheme.shadowLevel1,
                        ),
                        child: _buildLineChart(provider.revenueDays),
                      )
                    else
                      Container(
                        height: 200,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainerLowest,
                          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                          border: Border.all(color: AppColors.outlineVariant.withAlpha(60)),
                        ),
                        child: const Text('Không có dữ liệu trong khoảng thời gian này'),
                      ),
                    const SizedBox(height: 24),

                    // Top selling
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(l10n.translate('top_selling'), style: Theme.of(context).textTheme.titleLarge)
                    ),
                    const SizedBox(height: 12),
                    ...provider.topItems.asMap().entries.map((e) {
                      return _TopItem(
                        rank: e.key + 1, 
                        name: e.value.itemName, 
                        orders: e.value.totalQty, 
                        revenue: _formatCurrencyShort(e.value.totalRevenue)
                      );
                    }),
                  ],
                );
              },
            ),
            const SizedBox(height: 40),
          ]),
        ),
      ),
    );
  }
  Widget _buildLineChart(List<DashboardRevenueDay> data) {
    if (data.isEmpty) return const SizedBox();

    double maxRev = data.map((e) => e.revenue).reduce((a, b) => a > b ? a : b);
    if (maxRev == 0) maxRev = 100000;

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: maxRev / 4,
          getDrawingHorizontalLine: (value) => FlLine(
            color: AppColors.outlineVariant.withAlpha(40),
            strokeWidth: 1,
            dashArray: [5, 5],
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: (data.length / 5).ceilToDouble(),
              getTitlesWidget: (value, meta) {
                if (value.toInt() < 0 || value.toInt() >= data.length) return const SizedBox.shrink();
                final date = data[value.toInt()].date;
                return Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(DateFormat('dd/MM').format(date), style: const TextStyle(fontSize: 10, color: Colors.grey)),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 45,
              interval: maxRev / 4,
              getTitlesWidget: (value, meta) {
                return Text(_formatCurrencyShort(value), style: const TextStyle(fontSize: 10, color: Colors.grey));
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        minX: 0,
        maxX: (data.length - 1).toDouble(),
        minY: 0,
        maxY: maxRev * 1.1,
        lineBarsData: [
          LineChartBarData(
            spots: data.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.revenue)).toList(),
            isCurved: true,
            color: AppColors.primary,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: AppColors.primary.withAlpha(30),
            ),
          ),
        ],
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                final date = data[spot.x.toInt()].date;
                return LineTooltipItem(
                  '${DateFormat('dd/MM/yyyy').format(date)}\n',
                  const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  children: [
                    TextSpan(
                      text: _formatCurrencyShort(spot.y),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.normal),
                    ),
                  ],
                );
              }).toList();
            },
          ),
        ),
      ),
    );
  }
}

class _NavGrid extends StatelessWidget {
  final VoidCallback loadDashboardData;
  const _NavGrid({required this.loadDashboardData});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final authService = context.read<AuthService>();
    final user = authService.currentUser;
    final isAdmin = user?.role == 0;

    final items = [
      {'icon': Icons.layers_rounded, 'label': l10n.translate('floor_plan'), 'route': '/staff_main'},
      {'icon': Icons.menu_book_rounded, 'label': l10n.translate('menu_editor'), 'route': '/menu'},
      {'icon': Icons.badge_rounded, 'label': l10n.translate('staff_registry'), 'route': '/staff'},
      if (isAdmin) {'icon': Icons.people_alt_rounded, 'label': 'Khách hàng', 'route': '/customers'},
      {'icon': Icons.event_seat_rounded, 'label': 'Đặt bàn', 'route': '/reservations'},
      {'icon': Icons.gpp_maybe_rounded, 'label': l10n.translate('fraud_alerts'), 'route': '/ai_alerts'},
      {'icon': Icons.card_giftcard_rounded, 'label': 'Khuyến mãi', 'route': '/discounts'},
    ];
    return SizedBox(height: 90,
      child: ListView.separated(scrollDirection: Axis.horizontal,
        itemCount: items.length, separatorBuilder: (context, index) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final item = items[i];
          return GestureDetector(
            onTap: () {
              final route = item['route'] as String?;
              if (route == '/customers') {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const CustomerManagementScreen())).then((_) => loadDashboardData());
              } else if (route == '/staff') {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const StaffManagementScreen()));
              } else if (route == '/menu') {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const MenuAvailabilityScreen())).then((_) => loadDashboardData());
              } else if (route == '/ai_alerts') {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const AiAlertsScreen())).then((_) => loadDashboardData());
              } else if (route == '/discounts') {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const DiscountManagementScreen()));
              } else if (route == '/reservations') {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const ReservationManageScreen()));
              } else if (route == '/staff_main') {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const StaffMainScreen()));
              } else if (route != null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Sắp tới sẽ mở $route')),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Tính năng đang phát triển')),
                );
              }
            },
            child: SizedBox(width: 85, child: Column(children: [
              Container(width: 56, height: 56,
                decoration: BoxDecoration(
                  color: i == 4 ? AppColors.errorContainer : AppColors.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                ),
                child: Icon(item['icon'] as IconData, size: 24,
                  color: i == 4 ? AppColors.error : AppColors.onSurfaceVariant),
              ),
              const SizedBox(height: 6),
              Text(item['label'] as String, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
            ])),
          );
        },
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label, value, change;
  final IconData icon;
  final bool positive;
  const _MetricCard({required this.label, required this.value, required this.change, required this.icon, required this.positive});

  @override
  Widget build(BuildContext context) {
    return Expanded(child: Container(padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppColors.outlineVariant.withAlpha(60)),
        boxShadow: AppTheme.shadowLevel1),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(label, style: TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant, fontWeight: FontWeight.w500)),
          Icon(icon, size: 18, color: AppColors.onSurfaceVariant),
        ]),
        const SizedBox(height: 8),
        Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: positive ? AppColors.successContainer : AppColors.errorContainer,
            borderRadius: BorderRadius.circular(100)),
          child: Text(change, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
            color: positive ? AppColors.success : AppColors.error)),
        ),
      ]),
    ));
  }
}

class _TopItem extends StatelessWidget {
  final int rank;
  final String name, revenue;
  final int orders;
  const _TopItem({required this.rank, required this.name, required this.orders, required this.revenue});

  @override
  Widget build(BuildContext context) {
    return Padding(padding: const EdgeInsets.only(bottom: 10),
      child: Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(color: AppColors.outlineVariant.withAlpha(50))),
        child: Row(children: [
          Container(width: 32, height: 32, alignment: Alignment.center,
            decoration: BoxDecoration(
              color: rank == 1 ? AppColors.secondaryContainer : AppColors.surfaceContainer,
              borderRadius: BorderRadius.circular(8)),
            child: Text('#$rank', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13,
              color: rank == 1 ? const Color(0xFF6F5900) : AppColors.onSurfaceVariant)),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            Text('$orders ${AppLocalizations.of(context).translate('orders').toLowerCase()}', style: TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant)),
          ])),
          Text(revenue, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.primary)),
        ]),
      ),
    );
  }
}
