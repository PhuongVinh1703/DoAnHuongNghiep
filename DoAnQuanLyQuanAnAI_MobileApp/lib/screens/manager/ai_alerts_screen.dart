import 'package:flutter/material.dart';
import 'package:doanquanlyquananai_mobileapp/theme/app_colors.dart';
import 'package:doanquanlyquananai_mobileapp/theme/app_theme.dart';
import 'package:doanquanlyquananai_mobileapp/widgets/status_chip.dart';
import 'package:doanquanlyquananai_mobileapp/services/alert_service.dart';
import 'package:doanquanlyquananai_mobileapp/models/alert/alert.dart';
import 'package:doanquanlyquananai_mobileapp/services/branch_service.dart';
import 'package:doanquanlyquananai_mobileapp/models/branch/branch.dart';
import 'package:doanquanlyquananai_mobileapp/widgets/common/app_snackbar.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AiAlertsScreen extends StatefulWidget {
  const AiAlertsScreen({super.key});

  @override
  State<AiAlertsScreen> createState() => _AiAlertsScreenState();
}

class _AiAlertsScreenState extends State<AiAlertsScreen> {
  final AlertService _alertSvc = AlertService();
  final BranchService _branchSvc = BranchService();

  String _selectedFilter = 'All';
  int? _selectedBranchId;

  List<Alert> _alerts = [];
  List<Branch> _branches = [];
  bool _isLoading = true;
  bool _isRetraining = false;

  RealtimeChannel? _realtimeChannel;

  @override
  void initState() {
    super.initState();
    _loadData();
    _setupRealtime();
  }

  @override
  void dispose() {
    if (_realtimeChannel != null) {
      Supabase.instance.client.removeChannel(_realtimeChannel!);
    }
    super.dispose();
  }

  void _setupRealtime() {
    _realtimeChannel = Supabase.instance.client
        .channel('alerts-realtime-channel')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'Alerts',
          callback: (payload) {
            if (mounted) {
              _loadData(showLoading: false);
            }
          },
        );
    _realtimeChannel!.subscribe();
  }

  Future<void> _loadData({bool showLoading = true}) async {
    if (showLoading) {
      setState(() => _isLoading = true);
    }

    // Load branches
    final branchResult = await _branchSvc.getBranches();
    if (branchResult.isSuccess) {
      _branches = branchResult.data ?? [];
    }

    // Load alerts
    final alertsResult = await _alertSvc.getAlerts();
    if (alertsResult.isSuccess) {
      _alerts = alertsResult.data ?? [];
    } else {
      if (mounted) {
        AppSnackbar.showError(
          context,
          alertsResult.error ?? 'Lỗi tải cảnh báo',
        );
      }
    }

    setState(() => _isLoading = false);
  }

  Future<void> _retrainAi() async {
    setState(() => _isRetraining = true);
    if (mounted) {
      AppSnackbar.showWarning(
        context,
        'Đang gửi yêu cầu huấn luyện lại AI module...',
      );
    }

    final result = await _alertSvc.triggerRetrain();
    setState(() => _isRetraining = false);

    if (mounted) {
      if (result.isSuccess) {
        AppSnackbar.showSuccess(
          context,
          'Huấn luyện lại AI module thành công! Dữ liệu đã được cập nhật.',
        );
        _loadData(); // Reload alerts
      } else {
        AppSnackbar.showError(
          context,
          result.error ?? 'Lỗi khi huấn luyện lại AI.',
        );
      }
    }
  }

  List<Alert> get _filteredAlerts {
    List<Alert> list = _alerts;

    // Filter by branch
    if (_selectedBranchId != null) {
      list = list.where((a) => a.branchId == _selectedBranchId).toList();
    }

    // Filter by risk level
    if (_selectedFilter != 'All') {
      int targetSeverity = 0; // Low
      if (_selectedFilter == 'High') {
        targetSeverity = 2;
      } else if (_selectedFilter == 'Medium') {
        targetSeverity = 1;
      }
      list = list.where((a) => a.severity == targetSeverity).toList();
    }

    return list;
  }

  @override
  Widget build(BuildContext context) {
    final highCount = _alerts.where((a) => a.severity == 2).length;
    final medCount = _alerts.where((a) => a.severity == 1).length;
    final unreadCount = _alerts.where((a) => a.isResolved == false).length;

    double avgScore = 0.0;
    final scoredAlerts = _alerts.where((a) => a.anomalyScore != null).toList();
    if (scoredAlerts.isNotEmpty) {
      avgScore =
          scoredAlerts.fold<double>(0.0, (sum, a) => sum + a.anomalyScore!) /
          scoredAlerts.length;
    }

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('AI Fraud Alerts'),
        actions: [
          IconButton(
            icon: _isRetraining
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primary,
                    ),
                  )
                : const Icon(Icons.model_training_rounded),
            tooltip: 'Retrain AI Module',
            onPressed: _isRetraining ? null : _retrainAi,
          ),
          Container(
            margin: const EdgeInsets.only(right: 16, left: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.error.withAlpha(25),
              borderRadius: BorderRadius.circular(100),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.notifications_active_rounded,
                  size: 16,
                  color: AppColors.error,
                ),
                const SizedBox(width: 4),
                Text(
                  '$unreadCount new',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.error,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: Column(
                children: [
                  // ─── Summary Cards ────────────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.marginMobile,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        _SummaryCard(
                          icon: Icons.gpp_maybe_rounded,
                          label: 'High Risk',
                          count: highCount,
                          color: AppColors.error,
                        ),
                        const SizedBox(width: 10),
                        _SummaryCard(
                          icon: Icons.warning_amber_rounded,
                          label: 'Medium',
                          count: medCount,
                          color: AppColors.warning,
                        ),
                        const SizedBox(width: 10),
                        _SummaryCard(
                          icon: Icons.auto_awesome_rounded,
                          label: 'Avg AI Score',
                          countText: avgScore.toStringAsFixed(2),
                          color: AppColors.primary,
                        ),
                      ],
                    ),
                  ),

                  // ─── Filter Chips (Risk Level) ──────────────────────────
                  SizedBox(
                    height: 44,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.marginMobile,
                      ),
                      children: ['All', 'High', 'Medium', 'Low'].map((f) {
                        final isSelected = _selectedFilter == f;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            label: Text(f),
                            selected: isSelected,
                            onSelected: (_) =>
                                setState(() => _selectedFilter = f),
                            selectedColor: AppColors.primary.withAlpha(25),
                            checkmarkColor: AppColors.primary,
                            labelStyle: TextStyle(
                              color: isSelected
                                  ? AppColors.primary
                                  : AppColors.onSurfaceVariant,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                              fontSize: 13,
                            ),
                            backgroundColor: AppColors.surfaceContainerLowest,
                            side: BorderSide(
                              color: isSelected
                                  ? AppColors.primary
                                  : AppColors.outlineVariant,
                            ),
                            shape: const StadiumBorder(),
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                  // ─── Branch Filter Chips ──────────────────────────
                  SizedBox(
                    height: 44,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.marginMobile,
                      ),
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            label: const Text('Tất cả chi nhánh'),
                            selected: _selectedBranchId == null,
                            onSelected: (_) =>
                                setState(() => _selectedBranchId = null),
                            selectedColor: AppColors.primary.withAlpha(25),
                            checkmarkColor: AppColors.primary,
                            labelStyle: TextStyle(
                              color: _selectedBranchId == null
                                  ? AppColors.primary
                                  : AppColors.onSurfaceVariant,
                              fontWeight: _selectedBranchId == null
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                              fontSize: 13,
                            ),
                            backgroundColor: AppColors.surfaceContainerLowest,
                            side: BorderSide(
                              color: _selectedBranchId == null
                                  ? AppColors.primary
                                  : AppColors.outlineVariant,
                            ),
                            shape: const StadiumBorder(),
                          ),
                        ),
                        ..._branches.map((b) {
                          final isSelected = _selectedBranchId == b.branchId;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: FilterChip(
                              label: Text(b.name),
                              selected: isSelected,
                              onSelected: (_) => setState(
                                () => _selectedBranchId = b.branchId,
                              ),
                              selectedColor: AppColors.primary.withAlpha(25),
                              checkmarkColor: AppColors.primary,
                              labelStyle: TextStyle(
                                color: isSelected
                                    ? AppColors.primary
                                    : AppColors.onSurfaceVariant,
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                                fontSize: 13,
                              ),
                              backgroundColor: AppColors.surfaceContainerLowest,
                              side: BorderSide(
                                color: isSelected
                                    ? AppColors.primary
                                    : AppColors.outlineVariant,
                              ),
                              shape: const StadiumBorder(),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // ─── Alert List ────────────────────────────
                  Expanded(
                    child: _filteredAlerts.isEmpty
                        ? const Center(
                            child: Text('Không có cảnh báo nào phù hợp'),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppTheme.marginMobile,
                            ),
                            itemCount: _filteredAlerts.length,
                            separatorBuilder: (context, index) =>
                                const SizedBox(height: 12),
                            itemBuilder: (context, index) =>
                                _AlertCard(alert: _filteredAlerts[index]),
                          ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final int? count;
  final String? countText;
  final Color color;

  const _SummaryCard({
    required this.icon,
    required this.label,
    this.count,
    this.countText,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withAlpha(15),
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(color: color.withAlpha(40)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(height: 8),
            Text(
              countText ?? '$count',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: color.withAlpha(180),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AlertCard extends StatelessWidget {
  final Alert alert;

  const _AlertCard({required this.alert});

  @override
  Widget build(BuildContext context) {
    final severity = alert.severity;
    final score = alert.anomalyScore ?? 0.0;
    final isUnread = !alert.isResolved;

    String risk;
    Color riskColor;
    StatusType statusType;
    if (severity == 2) {
      risk = 'HIGH';
      riskColor = AppColors.error;
      statusType = StatusType.alert;
    } else if (severity == 1) {
      risk = 'MEDIUM';
      riskColor = AppColors.warning;
      statusType = StatusType.pending;
    } else {
      risk = 'LOW';
      riskColor = AppColors.chipDraft;
      statusType = StatusType.draft;
    }

    return Container(
      decoration: BoxDecoration(
        color: isUnread
            ? riskColor.withAlpha(8)
            : AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(
          color: isUnread
              ? riskColor.withAlpha(60)
              : AppColors.outlineVariant.withAlpha(60),
          width: isUnread ? 1.5 : 1,
        ),
        boxShadow: AppTheme.shadowLevel1,
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        riskColor.withAlpha(30),
                        riskColor.withAlpha(15),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.psychology_rounded,
                    size: 20,
                    color: riskColor,
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
                            'ALT-${alert.alertId.toString().padLeft(4, '0')}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (isUnread)
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: riskColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                      Text(
                        alert.alertTypeName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                StatusChip(label: risk, type: statusType),
              ],
            ),

            const SizedBox(height: 14),

            // Description
            Text(
              alert.description,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.onSurfaceVariant,
                height: 1.5,
              ),
            ),

            const SizedBox(height: 14),

            // Score bar
            Row(
              children: [
                Text(
                  'AI Confidence',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: score,
                      backgroundColor: AppColors.surfaceContainerHigh,
                      valueColor: AlwaysStoppedAnimation(riskColor),
                      minHeight: 6,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${(score * 100).toInt()}%',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: riskColor,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Footer
            Column(
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.store_rounded,
                      size: 14,
                      color: AppColors.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        alert.branchName ?? 'Hệ thống',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.onSurfaceVariant,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Icon(
                      Icons.person_outline_rounded,
                      size: 14,
                      color: AppColors.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        alert.staffName ?? 'Hệ thống',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.onSurfaceVariant,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Divider(height: 1, thickness: 0.5),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.access_time_rounded,
                          size: 14,
                          color: AppColors.onSurfaceVariant.withAlpha(180),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Thời gian ghi nhận',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.onSurfaceVariant.withAlpha(180),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '${DateFormat('dd/MM/yyyy').format(alert.createdAt)} · ${DateFormat('HH:mm').format(alert.createdAt)}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
