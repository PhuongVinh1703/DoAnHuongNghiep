import 'package:flutter/material.dart';
import 'package:doanquanlyquananai_mobileapp/core/constants/app_colors.dart';
import 'package:doanquanlyquananai_mobileapp/models/alert/alert.dart';
import 'package:doanquanlyquananai_mobileapp/services/alert_service.dart';
import 'package:doanquanlyquananai_mobileapp/widgets/common/app_button.dart';
import 'package:doanquanlyquananai_mobileapp/widgets/common/app_snackbar.dart';
import 'package:doanquanlyquananai_mobileapp/widgets/common/loading_overlay.dart';
import 'package:doanquanlyquananai_mobileapp/core/utils/date_utils.dart';

class AlertDetailScreen extends StatefulWidget {
  final int alertId;
  const AlertDetailScreen({super.key, required this.alertId});

  @override
  State<AlertDetailScreen> createState() => _AlertDetailScreenState();
}

class _AlertDetailScreenState extends State<AlertDetailScreen> {
  final _svc = AlertService();
  final _noteCtrl = TextEditingController();

  Alert? _alert;
  bool _isLoading = true;
  bool _isResolving = false;

  @override
  void initState() {
    super.initState();
    _loadAlert();
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAlert() async {
    setState(() => _isLoading = true);
    final result = await _svc.getById(widget.alertId);
    setState(() => _isLoading = false);
    result.fold(
      onSuccess: (a) => setState(() => _alert = a),
      onFailure: (e) => AppSnackbar.showError(context, e),
    );
  }

  Future<void> _resolve() async {
    setState(() => _isResolving = true);
    final result = await _svc.resolveAlert(widget.alertId, note: _noteCtrl.text.trim());
    setState(() => _isResolving = false);
    result.fold(
      onSuccess: (_) {
        AppSnackbar.showSuccess(context, 'Đã xử lý cảnh báo!');
        Navigator.pop(context, true);
      },
      onFailure: (e) => AppSnackbar.showError(context, e),
    );
  }

  Future<void> _sendFeedback(bool isFalsePositive) async {
    final result = await _svc.sendFeedback(
      alertId: widget.alertId,
      isFalsePositive: isFalsePositive,
      note: _noteCtrl.text.trim(),
    );
    result.fold(
      onSuccess: (_) => AppSnackbar.showSuccess(context, 'Đã gửi phản hồi về AI'),
      onFailure: (e) => AppSnackbar.showError(context, e),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Chi Tiết Cảnh Báo'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: LoadingOverlay(
        isLoading: _isLoading,
        child: _alert == null
            ? const SizedBox.shrink()
            : _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    final a = _alert!;
    final severityColor = AppColors.alertSeverityColor(a.severity);
    final severityLabel = ['Thấp', 'Trung bình', 'Cao'][a.severity.clamp(0, 2)];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: severityColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: severityColor.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: severityColor, size: 28),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        a.alertTypeName,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: severityColor,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: severityColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        severityLabel,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: severityColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(a.description, style: const TextStyle(fontSize: 14)),
                const SizedBox(height: 10),
                _detailRow('Nhân viên', a.staffName ?? 'Không rõ'),
                _detailRow('Thời gian', AppDateUtils.formatDateTime(a.createdAt)),
                _detailRow('Điểm bất thường', a.anomalyScore != null ? '${(a.anomalyScore! * 100).toStringAsFixed(0)}%' : '0%'),
                _detailRow('Trạng thái', a.isResolved ? '✅ Đã xử lý' : '⚠️ Chưa xử lý'),
              ],
            ),
          ),

          if (!a.isResolved) ...[
            const SizedBox(height: 20),
            const Text('Ghi chú xử lý', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: _noteCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Thêm ghi chú về cảnh báo này...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
            const SizedBox(height: 16),

            // Feedback buttons
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: 'Sai (False Positive)',
                    isOutlined: true,
                    color: AppColors.warning,
                    icon: Icons.thumb_down_outlined,
                    onPressed: () => _sendFeedback(true),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: AppButton(
                    label: 'Đúng',
                    isOutlined: true,
                    color: AppColors.error,
                    icon: Icons.thumb_up_outlined,
                    onPressed: () => _sendFeedback(false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            AppButtonWide(
              label: 'Đánh dấu đã xử lý',
              onPressed: _resolve,
              isLoading: _isResolving,
              icon: Icons.check_circle_outline,
              color: AppColors.success,
            ),
          ],
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        SizedBox(
          width: 130,
          child: Text(label, style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        ),
        Expanded(
          child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        ),
      ],
    ),
  );
}
