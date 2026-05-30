import 'package:flutter/material.dart';
import 'package:doanquanlyquananai_mobileapp/theme/app_colors.dart';

class StatusChip extends StatelessWidget {
  final String label;
  final StatusType type;

  const StatusChip({
    super.key,
    required this.label,
    required this.type,
  });

  @override
  Widget build(BuildContext context) {
    Color bgColor;
    Color textColor;

    switch (type) {
      case StatusType.paid:
        bgColor = AppColors.chipPaid.withAlpha(30);
        textColor = AppColors.chipPaid;
        break;
      case StatusType.pending:
        bgColor = AppColors.chipPending.withAlpha(40);
        textColor = const Color(0xFF8D6E00);
        break;
      case StatusType.draft:
        bgColor = AppColors.chipDraft.withAlpha(25);
        textColor = AppColors.chipDraft;
        break;
      case StatusType.occupied:
        bgColor = AppColors.tableOccupied;
        textColor = const Color(0xFFE65100);
        break;
      case StatusType.available:
        bgColor = AppColors.tableAvailable;
        textColor = AppColors.chipPaid;
        break;
      case StatusType.reserved:
        bgColor = AppColors.tableReserved;
        textColor = const Color(0xFF1565C0);
        break;
      case StatusType.alert:
        bgColor = AppColors.errorContainer;
        textColor = AppColors.error;
        break;
      case StatusType.cancelled:
        bgColor = AppColors.outlineVariant.withAlpha(40);
        textColor = AppColors.onSurfaceVariant;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(100), // Full pill
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }
}

enum StatusType {
  paid,
  pending,
  draft,
  occupied,
  available,
  reserved,
  alert,
  cancelled,
}
