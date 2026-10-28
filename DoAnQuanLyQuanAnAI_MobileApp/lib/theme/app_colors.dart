import 'package:flutter/material.dart';

/// Bảng màu thống nhất toàn hệ thống (Stitch Design System + Semantic Helpers)
/// "AI-Powered Smart Restaurant POS"
class AppColors {
  // ── Primary (Terracotta) ────────────────────────────────
  static const Color primary = Color(0xFF9E3D00);
  static const Color primaryDark = Color(0xFF7A2E00);
  static const Color primaryLight = Color(0xFFFF8C5A);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color primaryContainer = Color(0xFFC64F00);
  static const Color onPrimaryContainer = Color(0xFFFFFBFF);
  static const Color inversePrimary = Color(0xFFFFB595);
  static const Color primaryFixed = Color(0xFFFFDBCD);
  static const Color primaryFixedDim = Color(0xFFFFB595);

  // ── Secondary (Amber) ──────────────────────────────────
  static const Color secondary = Color(0xFF735C00);
  static const Color onSecondary = Color(0xFFFFFFFF);
  static const Color secondaryContainer = Color(0xFFFED023);
  static const Color onSecondaryContainer = Color(0xFF6F5900);
  static const Color secondaryFixed = Color(0xFFFFE084);
  static const Color secondaryFixedDim = Color(0xFFEEC209);

  // ── Tertiary (Deep Charcoal) ───────────────────────────
  static const Color tertiary = Color(0xFF4C5E71);
  static const Color onTertiary = Color(0xFFFFFFFF);
  static const Color tertiaryContainer = Color(0xFF64768A);
  static const Color onTertiaryContainer = Color(0xFFFDFCFF);
  static const Color tertiaryFixed = Color(0xFFD1E4FB);
  static const Color tertiaryFixedDim = Color(0xFFB5C8DF);

  // ── Error / Info ───────────────────────────────────────
  static const Color error = Color(0xFFBA1A1A);
  static const Color onError = Color(0xFFFFFFFF);
  static const Color errorContainer = Color(0xFFFFDAD6);
  static const Color onErrorContainer = Color(0xFF93000A);
  static const Color info = Color(0xFF2196F3);

  // ── Surface & Background ───────────────────────────────
  static const Color background = Color(0xFFFFF8F6);
  static const Color surface = Color(0xFFFFF8F6);
  static const Color surfaceDark = Color(0xFF1E1E2C);
  static const Color onSurface = Color(0xFF251913);
  static const Color surfaceDim = Color(0xFFEDD5CC);
  static const Color surfaceBright = Color(0xFFFFF8F6);
  static const Color surfaceContainerLowest = Color(0xFFFFFFFF);
  static const Color surfaceContainerLow = Color(0xFFFFF1EC);
  static const Color surfaceContainer = Color(0xFFFFE9E1);
  static const Color surfaceContainerHigh = Color(0xFFFCE3DA);
  static const Color surfaceContainerHighest = Color(0xFFF6DDD4);
  static const Color onSurfaceVariant = Color(0xFF594238);
  static const Color inverseSurface = Color(0xFF3C2D27);
  static const Color inverseOnSurface = Color(0xFFFFEDE7);
  static const Color surfaceTint = Color(0xFFA23F00);

  // ── Text & Dividers (Legacy compatibility aliases) ─────
  static const Color textPrimary = Color(0xFF251913);
  static const Color textSecondary = Color(0xFF594238);
  static const Color textHint = Color(0xFF8C7166);
  static const Color textOnPrimary = Colors.white;
  static const Color divider = Color(0xFFE0C0B2);
  static const Color border = Color(0xFF8C7166);

  // ── Outline ────────────────────────────────────────────
  static const Color outline = Color(0xFF8C7166);
  static const Color outlineVariant = Color(0xFFE0C0B2);

  // ── Semantic / Functional Colors ───────────────────────
  static const Color success = Color(0xFF2E7D32);
  static const Color successContainer = Color(0xFFC8E6C9);
  static const Color warning = Color(0xFFF9A825);
  static const Color warningContainer = Color(0xFFFFF8E1);

  // ── Role Colors ────────────────────────────────────────
  static const Color staffColor = Color(0xFF2196F3);
  static const Color managerColor = Color(0xFF9C27B0);
  static const Color ownerColor = Color(0xFFFF9800);
  static const Color customerColor = Color(0xFF4CAF50);

  // ── Order & Alert Status ───────────────────────────────
  static const Color orderOpen = Color(0xFF2196F3);
  static const Color orderPaid = Color(0xFF2E7D32);
  static const Color orderCancelled = Color(0xFF9E9E9E);
  static const Color alertLow = Color(0xFF2E7D32);
  static const Color alertMedium = Color(0xFFF9A825);
  static const Color alertHigh = Color(0xFFBA1A1A);
  static const Color aiAnomaly = Color(0xFFBA1A1A);
  static const Color aiNormal = Color(0xFF2E7D32);

  // ── Customer Tier Colors ───────────────────────────────
  static const Color tierBronze = Color(0xFFCD7F32);
  static const Color tierSilver = Color(0xFF9E9E9E);
  static const Color tierGold = Color(0xFFFFD700);
  static const Color tierPlatinum = Color(0xFF00BCD4);
  static const Color tierDiamond = Color(0xFF7C4DFF);

  // ── Shimmer ────────────────────────────────────────────
  static const Color shimmerBase = Color(0xFFE0E0E0);
  static const Color shimmerHighlight = Color(0xFFF5F5F5);

  // ── Input fields ───────────────────────────────────────
  static const Color inputFill = Color(0xFFF1F3F5);
  static const Color inputFillFocused = Color(0xFFFFFFFF);

  // ── Status Chip Colors ─────────────────────────────────
  static const Color chipPaid = Color(0xFF2E7D32);
  static const Color chipPending = Color(0xFFF9A825);
  static const Color chipDraft = Color(0xFF455A64);

  // ── Table Status Colors (Enterprise F&B Multi-State) ────
  static const Color tableAvailable = Color(0xFFE8F5E9);
  static const Color tableAvailableFg = Color(0xFF2E7D32);
  static const Color tableAvailableBorder = Color(0xFFA5D6A7);

  static const Color tableOccupied = Color(0xFFFFF3E0);
  static const Color tableOccupiedFg = Color(0xFFE65100);
  static const Color tableOccupiedBorder = Color(0xFFFFCC80);

  static const Color tableReserved = Color(0xFFE3F2FD);
  static const Color tableReservedFg = Color(0xFF1565C0);
  static const Color tableReservedBorder = Color(0xFF90CAF9);

  static const Color tableOverdue = Color(0xFFFFEBEE);
  static const Color tableOverdueFg = Color(0xFFC62828);
  static const Color tableOverdueBorder = Color(0xFFEF9A9A);

  static const Color tableCleaning = Color(0xFFF3E5F5);
  static const Color tableCleaningFg = Color(0xFF7B1FA2);
  static const Color tableCleaningBorder = Color(0xFFCE93D8);

  // ── KDS (Kitchen Display System) Status Colors ─────────
  static const Color kdsNormal = Color(0xFF2E7D32);     // Dưới 10 phút: bình thường
  static const Color kdsWarning = Color(0xFFF57C00);    // 10 - 20 phút: cần chú ý
  static const Color kdsCritical = Color(0xFFD32F2F);   // Trên 20 phút: trễ đơn khẩn cấp
  static const Color kdsReady = Color(0xFF00897B);      // Bếp đã hoàn thành, chờ bưng

  // ── POS Terminal & Billing Helpers ────────────────────
  static const Color quickCashBg = Color(0xFFF5F7FA);
  static const Color quickCashBorder = Color(0xFFCFD8DC);
  static const Color splitBillBadge = Color(0xFF5C6BC0);

  // ── AI Gradient ────────────────────────────────────────
  static const LinearGradient aiGradient = LinearGradient(
    colors: [Color(0xFFC64F00), Color(0xFFF9A825)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ── Glassmorphism for Bottom Nav ───────────────────────
  static const Color glassBackground = Color(0xE6FFFFFF);
  static const Color glassBorder = Color(0x33FFFFFF);

  // ── Helper Methods ─────────────────────────────────────
  static Color tableStatusColor(int status) {
    switch (status) {
      case 0:
        return tableAvailableFg;
      case 1:
        return tableOccupiedFg;
      case 2:
        return tableReservedFg;
      case 3:
        return tableOverdueFg;
      case 4:
        return tableCleaningFg;
      default:
        return textSecondary;
    }
  }

  static Color tableStatusBg(int status) {
    switch (status) {
      case 0:
        return tableAvailable;
      case 1:
        return tableOccupied;
      case 2:
        return tableReserved;
      case 3:
        return tableOverdue;
      case 4:
        return tableCleaning;
      default:
        return surfaceContainer;
    }
  }

  static Color tableStatusBorder(int status) {
    switch (status) {
      case 0:
        return tableAvailableBorder;
      case 1:
        return tableOccupiedBorder;
      case 2:
        return tableReservedBorder;
      case 3:
        return tableOverdueBorder;
      case 4:
        return tableCleaningBorder;
      default:
        return outlineVariant;
    }
  }

  static Color alertSeverityColor(int severity) {
    switch (severity) {
      case 0:
        return alertLow;
      case 1:
        return alertMedium;
      case 2:
        return alertHigh;
      default:
        return textSecondary;
    }
  }

  static Color tierColor(int tier) {
    switch (tier) {
      case 0:
        return tierBronze;
      case 1:
        return tierSilver;
      case 2:
        return tierGold;
      case 3:
        return tierPlatinum;
      case 4:
        return tierDiamond;
      default:
        return tierBronze;
    }
  }
}
