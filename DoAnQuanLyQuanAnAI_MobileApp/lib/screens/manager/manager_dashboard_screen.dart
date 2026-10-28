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
import 'package:doanquanlyquananai_mobileapp/screens/staff/kds_screen.dart';
import 'package:doanquanlyquananai_mobileapp/services/booking_notification_provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:doanquanlyquananai_mobileapp/theme/app_haptics.dart';
import 'package:doanquanlyquananai_mobileapp/widgets/common/app_shimmer.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  ManagerDashboardScreen — Enterprise F&B Operations Console
//  Phase 5 Optimization: Bento KPI, Multi-branch switcher, AI Alert Banner,
//  Interactive Charts, Top Selling with progress indicators.
// ─────────────────────────────────────────────────────────────────────────────
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
  bool _isBarChart = false;

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
    AppHaptics.selection();
    setState(() => _selectedDateRange = range);
    _loadDashboardData();
    Navigator.pop(context);
  }

  Future<void> _showDateFilterBottomSheet() async {
    AppHaptics.light();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTheme.radiusLg),
        ),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              vertical: 20,
              horizontal: AppTheme.marginMobile,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Thời gian thống kê',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    ActionChip(
                      label: const Text('Hôm nay'),
                      onPressed: () => _setDateRange(
                        DateTimeRange(start: today, end: today),
                      ),
                    ),
                    ActionChip(
                      label: const Text('Hôm qua'),
                      onPressed: () => _setDateRange(
                        DateTimeRange(
                          start: today.subtract(const Duration(days: 1)),
                          end: today.subtract(const Duration(days: 1)),
                        ),
                      ),
                    ),
                    ActionChip(
                      label: const Text('7 ngày qua'),
                      onPressed: () => _setDateRange(
                        DateTimeRange(
                          start: today.subtract(const Duration(days: 6)),
                          end: today,
                        ),
                      ),
                    ),
                    ActionChip(
                      label: const Text('Tháng này'),
                      onPressed: () => _setDateRange(
                        DateTimeRange(
                          start: DateTime(now.year, now.month, 1),
                          end: today,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.date_range_rounded,
                    color: AppColors.primary,
                  ),
                  title: const Text(
                    'Tùy chỉnh thời gian...',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () async {
                    Navigator.pop(context);
                    final initialDateRange = _selectedDateRange ??
                        DateTimeRange(
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
                            colorScheme: const ColorScheme.light(
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
                      AppHaptics.selection();
                      setState(() => _selectedDateRange = picked);
                      _loadDashboardData();
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showBranchPickerModal() {
    AppHaptics.light();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTheme.radiusLg),
        ),
      ),
      builder: (context) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                vertical: 20,
                horizontal: AppTheme.marginMobile,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.storefront_rounded, color: AppColors.primary),
                        SizedBox(width: 8),
                        Text(
                          'Chọn chi nhánh',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: _selectedBranchId == null
                        ? AppColors.primary
                        : Colors.grey.shade200,
                    child: Icon(
                      Icons.hub_rounded,
                      color: _selectedBranchId == null
                          ? Colors.white
                          : Colors.grey.shade700,
                      size: 20,
                    ),
                  ),
                  title: const Text(
                    'Toàn bộ chuỗi (Tất cả chi nhánh)',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text('Dữ liệu tổng hợp toàn hệ thống'),
                  trailing: _selectedBranchId == null
                      ? const Icon(Icons.check_circle_rounded,
                          color: AppColors.primary)
                      : null,
                  onTap: () {
                    AppHaptics.selection();
                    setState(() => _selectedBranchId = null);
                    _loadDashboardData();
                    Navigator.pop(context);
                  },
                ),
                const Divider(),
                if (_isLoadingBranches)
                  const Expanded(
                    child: Center(
                      child: CircularProgressIndicator(color: AppColors.primary),
                    ),
                  )
                else
                  Expanded(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _branches.length,
                      itemBuilder: (context, idx) {
                        final b = _branches[idx];
                        final isSelected = _selectedBranchId == b.branchId;
                        final addressText = (b.address != null && b.address!.isNotEmpty)
                            ? b.address!
                            : 'Chi nhánh #${b.branchId}';
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: isSelected
                                ? AppColors.primary
                                : Colors.grey.shade200,
                            child: Icon(
                              Icons.store_rounded,
                              color: isSelected
                                  ? Colors.white
                                  : Colors.grey.shade700,
                              size: 20,
                            ),
                          ),
                          title: Text(
                            b.name,
                            style: TextStyle(
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                          ),
                          subtitle: Text(
                            addressText,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: isSelected
                              ? const Icon(Icons.check_circle_rounded,
                                  color: AppColors.primary)
                              : null,
                          onTap: () {
                            AppHaptics.selection();
                            setState(() => _selectedBranchId = b.branchId);
                            _loadDashboardData();
                            Navigator.pop(context);
                          },
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    },
  );
  }

  String _formatCurrencyShort(double amount) {
    if (amount >= 1000000000) {
      return '₫${(amount / 1000000000).toStringAsFixed(2)}B';
    } else if (amount >= 1000000) {
      return '₫${(amount / 1000000).toStringAsFixed(1)}M';
    } else if (amount >= 1000) {
      return '₫${(amount / 1000).toStringAsFixed(0)}K';
    }
    return '₫${amount.toStringAsFixed(0)}';
  }

  String _getSelectedBranchName() {
    if (_selectedBranchId == null) {
      return 'Tất cả chi nhánh';
    }
    final match = _branches.where((b) => b.branchId == _selectedBranchId);
    if (match.isNotEmpty) {
      return match.first.name;
    }
    return 'Chi nhánh #$_selectedBranchId';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final authService = context.watch<AuthService>();
    final user = authService.currentUser;
    final isAdmin = user?.role == 0;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            AppHaptics.medium();
            _loadDashboardData();
          },
          color: AppColors.primary,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.marginMobile,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),

                // ── Top Bar / Header ──────────────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: AppColors.success,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              l10n.translate('admin_console').toUpperCase(),
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.2,
                                    color: AppColors.onSurfaceVariant,
                                  ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          AppConstants.appName,
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Consumer<BookingNotificationProvider>(
                          builder: (context, notifyProv, _) {
                            return Stack(
                              clipBehavior: Clip.none,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.notifications_outlined),
                                  color: AppColors.onSurface,
                                  tooltip: 'Thông báo đặt bàn',
                                  onPressed: () {
                                    AppHaptics.light();
                                    notifyProv.clearUnread();
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            const ReservationManageScreen(),
                                      ),
                                    );
                                  },
                                ),
                                if (notifyProv.unreadCount > 0)
                                  Positioned(
                                    right: 6,
                                    top: 6,
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: const BoxDecoration(
                                        color: Colors.red,
                                        shape: BoxShape.circle,
                                      ),
                                      constraints: const BoxConstraints(
                                        minWidth: 16,
                                        minHeight: 16,
                                      ),
                                      child: Text(
                                        '${notifyProv.unreadCount}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 9,
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
                          onPressed: () {
                            AppHaptics.light();
                            context.read<LocaleService>().toggleLocale();
                          },
                          color: AppColors.onSurface,
                          tooltip: l10n.translate('language'),
                        ),
                        IconButton(
                          icon: const Icon(Icons.logout_rounded),
                          color: AppColors.error,
                          tooltip: l10n.translate('log_out'),
                          onPressed: () async {
                            AppHaptics.medium();
                            await context.read<AuthService>().logout();
                            if (context.mounted) {
                              Navigator.pushAndRemoveUntil(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const LoginScreen(),
                                ),
                                (route) => false,
                              );
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                // ── Multi-branch Switcher Pill ────────────────────────────────
                if (isAdmin)
                  _buildBranchSwitcherPill()
                else if (user?.branchId != null)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryContainer.withAlpha(35),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.store_rounded,
                            size: 16, color: AppColors.primary),
                        const SizedBox(width: 6),
                        Text(
                          'Chi nhánh #${user?.branchId}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 18),

                // ── Operational Navigation Grid ──────────────────────────────
                _NavGrid(loadDashboardData: _loadDashboardData),

                const SizedBox(height: 24),

                // ── Dashboard Overview Header & Time Filter ───────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.translate('dashboard_overview'),
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          l10n.translate('realtime_metrics'),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppColors.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                    InkWell(
                      onTap: _showDateFilterBottomSheet,
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.primaryContainer.withAlpha(45),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: AppColors.primary.withAlpha(60),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.calendar_month_rounded,
                                size: 15, color: AppColors.primary),
                            const SizedBox(width: 6),
                            Text(
                              _selectedDateRange == null
                                  ? '30 ngày qua'
                                  : '${DateFormat('dd/MM').format(_selectedDateRange!.start)} - ${DateFormat('dd/MM').format(_selectedDateRange!.end)}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.arrow_drop_down,
                                size: 16, color: AppColors.primary),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // ── Bento Grid Metric Cards ──────────────────────────────────
                Consumer<DashboardProvider>(
                  builder: (context, provider, child) {
                    if (provider.isLoading) {
                      return const DashboardStatShimmer();
                    }

                    if (provider.errorMessage != null) {
                      return Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.errorContainer.withAlpha(50),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline,
                                color: AppColors.error),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                provider.errorMessage!,
                                style: const TextStyle(color: AppColors.error),
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    final sum = provider.summary;
                    if (sum == null) return const SizedBox.shrink();

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Bento Layout: Hero Card (Revenue) + 3 Secondary Cards
                        _buildBentoGrid(context, sum, l10n),

                        const SizedBox(height: 20),

                        // AI Anomaly / Security Status Banner
                        _buildAiSecurityBanner(context, sum.unresolvedAlerts),

                        const SizedBox(height: 24),

                        // ── Interactive Revenue Chart ─────────────────────────
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Phân tích doanh thu',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            // Chart Type Toggle
                            Container(
                              decoration: BoxDecoration(
                                color: AppColors.surfaceContainerHigh,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  _buildChartTypeTab(
                                    icon: Icons.show_chart_rounded,
                                    isSelected: !_isBarChart,
                                    onTap: () {
                                      AppHaptics.selection();
                                      setState(() => _isBarChart = false);
                                    },
                                  ),
                                  _buildChartTypeTab(
                                    icon: Icons.bar_chart_rounded,
                                    isSelected: _isBarChart,
                                    onTap: () {
                                      AppHaptics.selection();
                                      setState(() => _isBarChart = true);
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 14),

                        if (provider.revenueDays.isNotEmpty)
                          Container(
                            height: 260,
                            padding: const EdgeInsets.fromLTRB(12, 18, 18, 12),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceContainerLowest,
                              borderRadius:
                                  BorderRadius.circular(AppTheme.radiusLg),
                              border: Border.all(
                                color: AppColors.outlineVariant.withAlpha(60),
                              ),
                              boxShadow: AppTheme.shadowLevel1,
                            ),
                            child: _isBarChart
                                ? _buildBarChart(provider.revenueDays)
                                : _buildLineChart(provider.revenueDays),
                          )
                        else
                          Container(
                            height: 180,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: AppColors.surfaceContainerLowest,
                              borderRadius:
                                  BorderRadius.circular(AppTheme.radiusLg),
                              border: Border.all(
                                color: AppColors.outlineVariant.withAlpha(60),
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.bar_chart_rounded,
                                    size: 40, color: Colors.grey.shade400),
                                const SizedBox(height: 8),
                                const Text(
                                  'Chưa có dữ liệu doanh thu trong khoảng này',
                                  style: TextStyle(
                                      color: Colors.grey, fontSize: 13),
                                ),
                              ],
                            ),
                          ),

                        const SizedBox(height: 24),

                        // ── Top Selling Products with Progress Bars ───────────
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              l10n.translate('top_selling'),
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            Text(
                              '${provider.topItems.length} món phổ biến',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: AppColors.onSurfaceVariant),
                            ),
                          ],
                        ),

                        const SizedBox(height: 12),

                        if (provider.topItems.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(24),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: AppColors.surfaceContainerLowest,
                              borderRadius:
                                  BorderRadius.circular(AppTheme.radiusMd),
                              border: Border.all(
                                color: AppColors.outlineVariant.withAlpha(50),
                              ),
                            ),
                            child: const Text('Chưa có dữ liệu món bán chạy'),
                          )
                        else ...[
                          _buildTopItemsList(provider.topItems),
                        ],
                      ],
                    );
                  },
                ),

                const SizedBox(height: 48),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  Branch Switcher Pill Widget
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildBranchSwitcherPill() {
    return InkWell(
      onTap: _showBranchPickerModal,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.outlineVariant.withAlpha(70)),
          boxShadow: AppTheme.shadowLevel1,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.primary.withAlpha(20),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.storefront_rounded,
                  size: 18, color: AppColors.primary),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'ĐANG XEM CHI NHÁNH',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          _getSelectedBranchName(),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.success.withAlpha(25),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'Đang hoạt động',
                          style: TextStyle(
                            color: AppColors.success,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.swap_vert_rounded, color: Colors.grey, size: 20),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  Bento Grid Implementation
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildBentoGrid(
      BuildContext context, DashboardSummary sum, AppLocalizations l10n) {
    return Column(
      children: [
        // 1. Hero Revenue Card (Full width bento element)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF7A1C16), // Deep brand wine
                AppColors.primary,  // Standard primary
              ],
            ),
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withAlpha(70),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(40),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.account_balance_wallet_rounded,
                            color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        l10n.translate('revenue').toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(35),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.trending_up_rounded,
                            color: Colors.white, size: 14),
                        SizedBox(width: 4),
                        Text(
                          'Doanh thu thuần',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                _formatCurrencyShort(sum.totalRevenue),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Trung bình ${_formatCurrencyShort(sum.avgOrderValue)} / đơn hàng',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // 2. Bento Secondary Row: 3 compact KPI tiles
        Row(
          children: [
            // Total Invoices
            Expanded(
              child: _BentoMiniCard(
                title: l10n.translate('orders'),
                value: '${sum.totalInvoices}',
                subtitle: 'Đã hoàn tất',
                icon: Icons.receipt_long_rounded,
                iconColor: const Color(0xFF2E7D32),
                iconBg: const Color(0xFFE8F5E9),
              ),
            ),
            const SizedBox(width: 10),
            // Average Order Value
            Expanded(
              child: _BentoMiniCard(
                title: 'Giá trị TB',
                value: _formatCurrencyShort(sum.avgOrderValue),
                subtitle: 'Mỗi hóa đơn',
                icon: Icons.analytics_rounded,
                iconColor: const Color(0xFF1565C0),
                iconBg: const Color(0xFFE3F2FD),
              ),
            ),
            const SizedBox(width: 10),
            // Open Tables / Live Orders
            Expanded(
              child: _BentoMiniCard(
                title: 'Bàn mở',
                value: '${sum.openOrders}',
                subtitle: 'Đang phục vụ',
                icon: Icons.table_restaurant_rounded,
                iconColor: const Color(0xFFE65100),
                iconBg: const Color(0xFFFFF3E0),
                hasLiveBadge: true,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  AI Fraud & Anomaly Banner
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildAiSecurityBanner(BuildContext context, int alertCount) {
    final hasAlerts = alertCount > 0;
    return GestureDetector(
      onTap: () {
        AppHaptics.medium();
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AiAlertsScreen()),
        ).then((_) => _loadDashboardData());
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: hasAlerts
              ? const Color(0xFFFFF4E5)
              : AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(
            color: hasAlerts
                ? const Color(0xFFFFA726)
                : AppColors.outlineVariant.withAlpha(60),
            width: hasAlerts ? 1.5 : 1.0,
          ),
          boxShadow: hasAlerts
              ? [
                  BoxShadow(
                    color: const Color(0xFFFFA726).withAlpha(50),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ]
              : AppTheme.shadowLevel1,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: hasAlerts
                    ? const Color(0xFFFF9800)
                    : AppColors.success.withAlpha(20),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                hasAlerts
                    ? Icons.warning_amber_rounded
                    : Icons.shield_rounded,
                color: hasAlerts ? Colors.white : AppColors.success,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        hasAlerts
                            ? 'Cảnh báo gian lận AI'
                            : 'Bảo mật AI Hoạt động',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: hasAlerts
                              ? const Color(0xFFB78103)
                              : AppColors.onSurface,
                        ),
                      ),
                      if (hasAlerts) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '$alertCount mới',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    hasAlerts
                      ? '$alertCount đơn có dấu hiệu bất thường cần kiểm tra'
                      : 'Hệ thống chống thất thoát & gian lận đang giám sát liên tục',
                    style: TextStyle(
                      fontSize: 12,
                      color: hasAlerts
                          ? const Color(0xFF8F6300)
                          : AppColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  Chart Type Selector Tab
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildChartTypeTab({
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          size: 18,
          color: isSelected ? Colors.white : AppColors.onSurfaceVariant,
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  Revenue Line Chart with gradient styling
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildLineChart(List<DashboardRevenueDay> data) {
    if (data.isEmpty) return const SizedBox();

    double maxRev =
        data.map((e) => e.revenue).reduce((a, b) => a > b ? a : b);
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
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: (data.length / 5).clamp(1.0, 99.0).ceilToDouble(),
              getTitlesWidget: (value, meta) {
                if (value.toInt() < 0 || value.toInt() >= data.length) {
                  return const SizedBox.shrink();
                }
                final date = data[value.toInt()].date;
                return Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    DateFormat('dd/MM').format(date),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade600,
                    ),
                  ),
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
                return Text(
                  _formatCurrencyShort(value),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade600,
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        minX: 0,
        maxX: (data.length - 1).toDouble(),
        minY: 0,
        maxY: maxRev * 1.15,
        lineBarsData: [
          LineChartBarData(
            spots: data
                .asMap()
                .entries
                .map((e) => FlSpot(e.key.toDouble(), e.value.revenue))
                .toList(),
            isCurved: true,
            curveSmoothness: 0.35,
            color: AppColors.primary,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: data.length <= 15,
              getDotPainter: (spot, percent, barData, index) =>
                  FlDotCirclePainter(
                radius: 3,
                color: Colors.white,
                strokeWidth: 2,
                strokeColor: AppColors.primary,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.primary.withAlpha(80),
                  AppColors.primary.withAlpha(5),
                ],
              ),
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
                  const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                  children: [
                    TextSpan(
                      text: _formatCurrencyShort(spot.y),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
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

  // ─────────────────────────────────────────────────────────────────────────
  //  Revenue Bar Chart
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildBarChart(List<DashboardRevenueDay> data) {
    if (data.isEmpty) return const SizedBox();

    double maxRev =
        data.map((e) => e.revenue).reduce((a, b) => a > b ? a : b);
    if (maxRev == 0) maxRev = 100000;

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxRev * 1.15,
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
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx < 0 || idx >= data.length) return const SizedBox();
                if (data.length > 7 && idx % ((data.length / 5).ceil()) != 0) {
                  return const SizedBox();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    DateFormat('dd/MM').format(data[idx].date),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade600,
                    ),
                  ),
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
                return Text(
                  _formatCurrencyShort(value),
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey.shade600,
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        barGroups: data.asMap().entries.map((e) {
          return BarChartGroupData(
            x: e.key,
            barRods: [
              BarChartRodData(
                toY: e.value.revenue,
                color: AppColors.primary,
                width: data.length > 14 ? 8 : 16,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  Top Items with Progress Bars
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildTopItemsList(List<DashboardTopItem> items) {
    final maxQty = items.isEmpty
        ? 1
        : items.map((e) => e.totalQty).reduce((a, b) => a > b ? a : b);

    return Column(
      children: items.asMap().entries.map((e) {
        final rank = e.key + 1;
        final item = e.value;
        final ratio = maxQty > 0 ? (item.totalQty / maxQty).clamp(0.0, 1.0) : 0.0;

        return _TopItemCard(
          rank: rank,
          name: item.itemName,
          orders: item.totalQty,
          revenue: _formatCurrencyShort(item.totalRevenue),
          progressRatio: ratio,
        );
      }).toList(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Bento Mini Card Component
// ─────────────────────────────────────────────────────────────────────────────
class _BentoMiniCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final bool hasLiveBadge;

  const _BentoMiniCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    this.hasLiveBadge = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppColors.outlineVariant.withAlpha(60)),
        boxShadow: AppTheme.shadowLevel1,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: iconColor),
              ),
              if (hasLiveBadge)
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.success,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.onSurfaceVariant,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Top Item Card Component with Progress Bar
// ─────────────────────────────────────────────────────────────────────────────
class _TopItemCard extends StatelessWidget {
  final int rank;
  final String name;
  final String revenue;
  final int orders;
  final double progressRatio;

  const _TopItemCard({
    required this.rank,
    required this.name,
    required this.orders,
    required this.revenue,
    required this.progressRatio,
  });

  Color _badgeColor() {
    switch (rank) {
      case 1:
        return const Color(0xFFFFD700); // Gold
      case 2:
        return const Color(0xFFC0C0C0); // Silver
      case 3:
        return const Color(0xFFCD7F32); // Bronze
      default:
        return Colors.grey.shade300;
    }
  }

  Color _badgeTextColor() {
    if (rank <= 3) return Colors.black87;
    return Colors.grey.shade700;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppColors.outlineVariant.withAlpha(50)),
        boxShadow: AppTheme.shadowLevel1,
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _badgeColor(),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '#$rank',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                    color: _badgeTextColor(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$orders đơn đã bán',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                revenue,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progressRatio,
              backgroundColor: Colors.grey.shade100,
              valueColor: AlwaysStoppedAnimation<Color>(
                rank == 1 ? AppColors.primary : AppColors.primary.withAlpha(150),
              ),
              minHeight: 5,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Operational Navigation Grid Component
// ─────────────────────────────────────────────────────────────────────────────
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
      {
        'icon': Icons.layers_rounded,
        'label': l10n.translate('floor_plan'),
        'route': '/staff_main',
        'color': const Color(0xFF1565C0),
        'bg': const Color(0xFFE3F2FD),
      },
      {
        'icon': Icons.restaurant_menu_rounded,
        'label': 'Bếp KDS',
        'route': '/kds',
        'color': const Color(0xFFE65100),
        'bg': const Color(0xFFFFF3E0),
      },
      {
        'icon': Icons.menu_book_rounded,
        'label': l10n.translate('menu_editor'),
        'route': '/menu',
        'color': const Color(0xFF2E7D32),
        'bg': const Color(0xFFE8F5E9),
      },
      {
        'icon': Icons.badge_rounded,
        'label': l10n.translate('staff_registry'),
        'route': '/staff',
        'color': const Color(0xFF6A1B9A),
        'bg': const Color(0xFFF3E5F5),
      },
      if (isAdmin)
        {
          'icon': Icons.people_alt_rounded,
          'label': 'Khách hàng',
          'route': '/customers',
          'color': const Color(0xFF00838F),
          'bg': const Color(0xFFE0F7FA),
        },
      {
        'icon': Icons.event_seat_rounded,
        'label': 'Đặt bàn',
        'route': '/reservations',
        'color': const Color(0xFFC2185B),
        'bg': const Color(0xFFFCE4EC),
      },
      {
        'icon': Icons.gpp_maybe_rounded,
        'label': l10n.translate('fraud_alerts'),
        'route': '/ai_alerts',
        'color': const Color(0xFFD32F2F),
        'bg': const Color(0xFFFFEBEE),
      },
      if (isAdmin)
        {
          'icon': Icons.card_giftcard_rounded,
          'label': 'Khuyến mãi',
          'route': '/discounts',
          'color': const Color(0xFFF57F17),
          'bg': const Color(0xFFFFFDE7),
        },
    ];

    return SizedBox(
      height: 94,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (context, index) => const SizedBox(width: 12),
        itemBuilder: (context, i) {
          final item = items[i];
          final color = item['color'] as Color;
          final bg = item['bg'] as Color;

          return GestureDetector(
            onTap: () {
              AppHaptics.light();
              final route = item['route'] as String?;
              if (route == '/customers') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const CustomerManagementScreen(),
                  ),
                ).then((_) => loadDashboardData());
              } else if (route == '/kds') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const KdsScreen()),
                ).then((_) => loadDashboardData());
              } else if (route == '/staff') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const StaffManagementScreen(),
                  ),
                );
              } else if (route == '/menu') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const MenuAvailabilityScreen(),
                  ),
                ).then((_) => loadDashboardData());
              } else if (route == '/ai_alerts') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AiAlertsScreen()),
                ).then((_) => loadDashboardData());
              } else if (route == '/discounts') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const DiscountManagementScreen(),
                  ),
                );
              } else if (route == '/reservations') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ReservationManageScreen(),
                  ),
                );
              } else if (route == '/staff_main') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const StaffMainScreen()),
                ).then((_) => loadDashboardData());
              }
            },
            child: SizedBox(
              width: 82,
              child: Column(
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: bg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: color.withAlpha(40)),
                      boxShadow: [
                        BoxShadow(
                          color: color.withAlpha(20),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(
                      item['icon'] as IconData,
                      size: 24,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item['label'] as String,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
