import 'package:flutter/material.dart';

/// Bảng màu đầy đủ từ Stitch Design System
/// "AI-Powered Smart Restaurant POS"
class AppColors {
  // ── Primary (Terracotta) ────────────────────────────────
  static const Color primary = Color(0xFF9E3D00);
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

  // ── Error ──────────────────────────────────────────────
  static const Color error = Color(0xFFBA1A1A);
  static const Color onError = Color(0xFFFFFFFF);
  static const Color errorContainer = Color(0xFFFFDAD6);
  static const Color onErrorContainer = Color(0xFF93000A);

  // ── Surface & Background ───────────────────────────────
  static const Color surface = Color(0xFFFFF8F6);
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

  // ── Outline ────────────────────────────────────────────
  static const Color outline = Color(0xFF8C7166);
  static const Color outlineVariant = Color(0xFFE0C0B2);

  // ── Semantic / Functional Colors ───────────────────────
  static const Color success = Color(0xFF2E7D32);
  static const Color successContainer = Color(0xFFC8E6C9);
  static const Color warning = Color(0xFFF9A825);
  static const Color warningContainer = Color(0xFFFFF8E1);

  // ── Input fields ───────────────────────────────────────
  static const Color inputFill = Color(0xFFF1F3F5);
  static const Color inputFillFocused = Color(0xFFFFFFFF);

  // ── Status Chip Colors ─────────────────────────────────
  static const Color chipPaid = Color(0xFF2E7D32);
  static const Color chipPending = Color(0xFFF9A825);
  static const Color chipDraft = Color(0xFF455A64);

  // ── Table Status Colors ────────────────────────────────
  static const Color tableAvailable = Color(0xFFE8F5E9);
  static const Color tableOccupied = Color(0xFFFFF3E0);
  static const Color tableReserved = Color(0xFFE3F2FD);

  // ── AI Gradient ────────────────────────────────────────
  static const LinearGradient aiGradient = LinearGradient(
    colors: [Color(0xFFC64F00), Color(0xFFF9A825)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ── Glassmorphism for Bottom Nav ───────────────────────
  static const Color glassBackground = Color(0xE6FFFFFF); // 90% opacity white
  static const Color glassBorder = Color(0x33FFFFFF); // 20% opacity white
}
