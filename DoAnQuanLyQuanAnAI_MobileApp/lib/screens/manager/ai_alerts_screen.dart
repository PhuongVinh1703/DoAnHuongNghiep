import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:doanquanlyquananai_mobileapp/theme/app_colors.dart';
import 'package:doanquanlyquananai_mobileapp/theme/app_theme.dart';
import 'package:doanquanlyquananai_mobileapp/theme/app_haptics.dart';
import 'package:doanquanlyquananai_mobileapp/widgets/status_chip.dart';
import 'package:doanquanlyquananai_mobileapp/services/alert_service.dart';
import 'package:doanquanlyquananai_mobileapp/models/alert/alert.dart';
import 'package:doanquanlyquananai_mobileapp/services/branch_service.dart';
import 'package:doanquanlyquananai_mobileapp/models/branch/branch.dart';
import 'package:doanquanlyquananai_mobileapp/services/auth_service.dart';
import 'package:doanquanlyquananai_mobileapp/config/constants.dart';
import 'package:doanquanlyquananai_mobileapp/widgets/common/app_snackbar.dart';
import 'package:intl/intl.dart';
import 'package:doanquanlyquananai_mobileapp/screens/manager/alert_detail_screen.dart';
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
  bool _isOwner = false;

  List<Alert> _alerts = [];
  List<Branch> _branches = [];
  bool _isLoading = true;
  bool _isRetraining = false;

  RealtimeChannel? _realtimeChannel;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = context.read<AuthService>().currentUser;
      _isOwner = (user?.role == AppConstants.roleOwner);
      if (!_isOwner && user?.branchId != null) {
        _selectedBranchId = user!.branchId;
      }
      _loadData();
    });
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

    final user = context.read<AuthService>().currentUser;
    _isOwner = (user?.role == AppConstants.roleOwner);
    if (!_isOwner && user?.branchId != null) {
      _selectedBranchId = user!.branchId;
    }

    // Load branches
    final branchResult = await _branchSvc.getBranches();
    if (branchResult.isSuccess) {
      _branches = branchResult.data ?? [];
    }

    // Load alerts
    final alertsResult = await _alertSvc.getAlerts();
    if (alertsResult.isSuccess) {
      final allAlerts = alertsResult.data ?? [];
      // Quản lý chi nhánh chỉ được xem cảnh báo của đúng chi nhánh mình
      if (!_isOwner && user?.branchId != null) {
        _alerts = allAlerts.where((a) => a.branchId == user!.branchId).toList();
      } else {
        _alerts = allAlerts;
      }
    } else {
      if (mounted) {
        AppSnackbar.showError(
          context,
          alertsResult.error ?? 'Lỗi tải cảnh báo',
        );
      }
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
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
        _loadData();
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

                  // ─── Branch Filter Chips (Chỉ Admin/Owner mới được chọn chi nhánh khác) ──
                  if (_isOwner)
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
                            itemBuilder: (context, index) {
                              final alert = _filteredAlerts[index];
                              return _AlertCard(
                                alert: alert,
                                onTap: () async {
                                  final resolved = await Navigator.push<bool>(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => AlertDetailScreen(
                                        alertId: alert.alertId,
                                      ),
                                    ),
                                  );
                                  if (mounted && resolved == true) {
                                    _loadData(showLoading: false);
                                  }
                                },
                              );
                            },
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(color: color.withAlpha(50), width: 1.2),
          boxShadow: AppTheme.shadowLevel1,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, size: 18, color: color),
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              countText ?? '$count',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: color,
                letterSpacing: -0.5,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: AppColors.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _AlertCard extends StatelessWidget {
  final Alert alert;
  final VoidCallback onTap;

  const _AlertCard({required this.alert, required this.onTap});

  IconData _iconForType(String typeName) {
    final lower = typeName.toLowerCase();
    if (lower.contains('speed') || lower.contains('nhanh')) {
      return Icons.bolt_rounded;
    } else if (lower.contains('cancel') || lower.contains('void') || lower.contains('hủy')) {
      return Icons.remove_circle_outline_rounded;
    } else if (lower.contains('discount') || lower.contains('giảm')) {
      return Icons.local_offer_outlined;
    }
    return Icons.psychology_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final severity = alert.severity;
    final score = alert.anomalyScore ?? 0.0;
    final isUnread = !alert.isResolved;

    String risk;
    Color riskColor;
    StatusType statusType;
    if (severity == 2) {
      risk = 'RỦI RO CAO';
      riskColor = AppColors.error;
      statusType = StatusType.alert;
    } else if (severity == 1) {
      risk = 'TRUNG BÌNH';
      riskColor = AppColors.warning;
      statusType = StatusType.pending;
    } else {
      risk = 'THEO DÕI';
      riskColor = AppColors.chipDraft;
      statusType = StatusType.draft;
    }

    final typeIcon = _iconForType(alert.alertTypeName);

    return GestureDetector(
      onTap: () {
        AppHaptics.selection();
        onTap();
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          border: Border.all(
            color: isUnread
                ? riskColor.withAlpha(90)
                : AppColors.outlineVariant.withAlpha(70),
            width: isUnread ? 1.5 : 1.0,
          ),
          boxShadow: AppTheme.shadowLevel1,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Dải màu chỉ báo mức độ nghiêm trọng ở cạnh trái (Distilled Visual Cue)
                Container(
                  width: 5,
                  color: riskColor,
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header: Mã ALT + Icon phân loại + Badge mức rủi ro
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: riskColor.withAlpha(20),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(typeIcon, size: 18, color: riskColor),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        'ALT-${alert.alertId.toString().padLeft(4, '0')}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.onSurfaceVariant,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      if (isUnread)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                          decoration: BoxDecoration(
                                            color: riskColor,
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: const Text(
                                            'MỚI',
                                            style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900),
                                          ),
                                        ),
                                    ],
                                  ),
                                  Text(
                                    alert.alertTypeName,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            StatusChip(label: risk, type: statusType),
                          ],
                        ),

                        const SizedBox(height: 10),

                        // Mô tả chi tiết hành vi gian lận
                        Text(
                          alert.description,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: const Color(0xFF334155),
                            height: 1.45,
                            fontSize: 13,
                          ),
                        ),

                        const SizedBox(height: 12),

                        // AI Confidence Bar (Độ tin cậy của thuật toán)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceContainerLowest,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.outlineVariant.withAlpha(50)),
                          ),
                          child: Row(
                            children: [
                              Text(
                                'AI Anomaly Score:',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(3),
                                  child: LinearProgressIndicator(
                                    value: score,
                                    backgroundColor: const Color(0xFFE2E8F0),
                                    valueColor: AlwaysStoppedAnimation(riskColor),
                                    minHeight: 5,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${(score * 100).toInt()}%',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                  color: riskColor,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 10),

                        // Footer: Chi nhánh & Nhân sự & Thời gian
                        Row(
                          children: [
                            Icon(Icons.store_outlined, size: 13, color: AppColors.onSurfaceVariant),
                            const SizedBox(width: 4),
                            Text(
                              alert.branchName ?? 'Hệ thống',
                              style: TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(width: 10),
                            Icon(Icons.person_outline_rounded, size: 13, color: AppColors.onSurfaceVariant),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                alert.staffName ?? 'Không rõ',
                                style: TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant, fontWeight: FontWeight.w600),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              DateFormat('dd/MM · HH:mm').format(alert.createdAt),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: AppColors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
