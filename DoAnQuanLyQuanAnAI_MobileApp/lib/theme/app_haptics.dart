import 'package:flutter/services.dart';

/// Bộ tiện ích phản hồi xúc giác (Haptic Feedback) chuẩn trải nghiệm F&B POS.
/// Hỗ trợ nhân viên thao tác nhanh, chính xác ngay cả trong môi trường ồn ào.
class AppHaptics {
  AppHaptics._();

  /// Chạm nhẹ (Tab chuyển, chip lọc bàn, chọn phân loại món, radio/checkbox)
  static Future<void> light() async {
    try {
      await HapticFeedback.lightImpact();
    } catch (_) {}
  }

  /// Chạm vừa (Bấm nút thêm món, tăng/giảm số lượng, bật/tắt toggle)
  static Future<void> medium() async {
    try {
      await HapticFeedback.mediumImpact();
    } catch (_) {}
  }

  /// Chạm mạnh (Xác nhận đặt bàn, gửi order vào bếp, chốt ca, thanh toán)
  static Future<void> heavy() async {
    try {
      await HapticFeedback.heavyImpact();
    } catch (_) {}
  }

  /// Phản hồi hoàn tất thành công (In bill xong, thanh toán thành công)
  static Future<void> success() async {
    try {
      await HapticFeedback.mediumImpact();
      await Future.delayed(const Duration(milliseconds: 80));
      await HapticFeedback.lightImpact();
    } catch (_) {}
  }

  /// Cảnh báo / Lỗi (Hết món, bàn đang bận, cảnh báo gian lận AI)
  static Future<void> error() async {
    try {
      await HapticFeedback.vibrate();
    } catch (_) {}
  }

  /// Xoay con lăn hoặc chọn số lượng tức thì
  static Future<void> selection() async {
    try {
      await HapticFeedback.selectionClick();
    } catch (_) {}
  }
}
