import 'package:flutter/material.dart';
import 'package:doanquanlyquananai_mobileapp/core/constants/app_colors.dart';
import 'package:doanquanlyquananai_mobileapp/models/invoice/checkout_response.dart';

class AiAlertBadge extends StatelessWidget {
  final AiAlertSummary alert;
  final bool expanded;

  const AiAlertBadge({super.key, required this.alert, this.expanded = false});

  Color get _color {
    switch (alert.riskLevel.toUpperCase()) {
      case 'HIGH':   return AppColors.alertHigh;
      case 'MEDIUM': return AppColors.alertMedium;
      default:       return AppColors.alertLow;
    }
  }

  IconData get _icon {
    switch (alert.riskLevel.toUpperCase()) {
      case 'HIGH':   return Icons.warning_amber_rounded;
      case 'MEDIUM': return Icons.info_outline;
      default:       return Icons.check_circle_outline;
    }
  }

  String get _label {
    switch (alert.riskLevel.toUpperCase()) {
      case 'HIGH':   return 'Nguy cơ CAO';
      case 'MEDIUM': return 'Nguy cơ TRUNG BÌNH';
      default:       return 'Bình thường';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!alert.isAnomaly) return const SizedBox.shrink();

    if (!expanded) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: _color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _color.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_icon, size: 14, color: _color),
            const SizedBox(width: 5),
            Text(
              'AI: $_label',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _color,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(_icon, color: _color, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '⚠️ Cảnh báo AI: $_label',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _color,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Điểm bất thường: ${(alert.anomalyScore * 100).toStringAsFixed(0)}%',
                  style: TextStyle(
                    fontSize: 12,
                    color: _color.withValues(alpha: 0.8),
                  ),
                ),
                Text(
                  'Giao dịch này đã được đánh dấu để quản lý xem xét.',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
