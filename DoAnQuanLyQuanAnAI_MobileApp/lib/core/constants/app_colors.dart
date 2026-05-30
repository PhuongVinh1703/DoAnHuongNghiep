import 'package:flutter/material.dart';

class AppColors {
  // === Primary Brand ===
  static const Color primary      = Color(0xFFFF6B35);   // Cam ấm - màu chủ đạo
  static const Color primaryDark  = Color(0xFFE55A24);
  static const Color primaryLight = Color(0xFFFF8C5A);

  // === Role Colors ===
  static const Color staffColor   = Color(0xFF2196F3);   // Xanh dương - Staff
  static const Color managerColor = Color(0xFF9C27B0);   // Tím - Manager
  static const Color ownerColor   = Color(0xFFFF9800);   // Cam - Owner
  static const Color customerColor = Color(0xFF4CAF50);  // Xanh lá - Customer

  // === Table Status Colors ===
  static const Color tableAvailable = Color(0xFF4CAF50); // Xanh - Trống
  static const Color tableOccupied  = Color(0xFFF44336); // Đỏ - Có khách
  static const Color tableReserved  = Color(0xFFFF9800); // Cam - Đã đặt

  // === Order Status ===
  static const Color orderOpen      = Color(0xFF2196F3);
  static const Color orderPaid      = Color(0xFF4CAF50);
  static const Color orderCancelled = Color(0xFF9E9E9E);

  // === Alert Severity ===
  static const Color alertLow    = Color(0xFF4CAF50);
  static const Color alertMedium = Color(0xFFFF9800);
  static const Color alertHigh   = Color(0xFFF44336);

  // === AI Alert ===
  static const Color aiAnomaly   = Color(0xFFF44336);
  static const Color aiNormal    = Color(0xFF4CAF50);

  // === Background & Surface ===
  static const Color background  = Color(0xFFF5F5F5);
  static const Color surface     = Colors.white;
  static const Color surfaceDark = Color(0xFF1E1E2C);

  // === Text ===
  static const Color textPrimary   = Color(0xFF212121);
  static const Color textSecondary = Color(0xFF757575);
  static const Color textHint      = Color(0xFFBDBDBD);
  static const Color textOnPrimary = Colors.white;

  // === Divider & Border ===
  static const Color divider = Color(0xFFE0E0E0);
  static const Color border  = Color(0xFFBDBDBD);

  // === Success / Error / Warning / Info ===
  static const Color success = Color(0xFF4CAF50);
  static const Color error   = Color(0xFFF44336);
  static const Color warning = Color(0xFFFF9800);
  static const Color info    = Color(0xFF2196F3);

  // === Customer Tier ===
  static const Color tierBronze = Color(0xFFCD7F32);
  static const Color tierSilver = Color(0xFF9E9E9E);
  static const Color tierGold   = Color(0xFFFFD700);

  // === Shimmer ===
  static const Color shimmerBase      = Color(0xFFE0E0E0);
  static const Color shimmerHighlight = Color(0xFFF5F5F5);

  // Helpers
  static Color tableStatusColor(int status) {
    switch (status) {
      case 0: return tableAvailable;
      case 1: return tableOccupied;
      case 2: return tableReserved;
      default: return textSecondary;
    }
  }

  static Color alertSeverityColor(int severity) {
    switch (severity) {
      case 0: return alertLow;
      case 1: return alertMedium;
      case 2: return alertHigh;
      default: return textSecondary;
    }
  }

  static Color tierColor(int tier) {
    switch (tier) {
      case 0: return tierBronze;
      case 1: return tierSilver;
      case 2: return tierGold;
      default: return tierBronze;
    }
  }
}
