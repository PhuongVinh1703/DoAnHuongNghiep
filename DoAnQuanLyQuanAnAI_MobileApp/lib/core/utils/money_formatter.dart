import 'package:intl/intl.dart';

class MoneyFormatter {
  static final NumberFormat _vndFormat = NumberFormat.currency(
    locale: 'vi_VN',
    symbol: '₫',
    decimalDigits: 0,
  );

  static final NumberFormat _vndNoSymbol = NumberFormat('#,###', 'vi_VN');

  /// Format số tiền VND: 350000 → "350.000 ₫"
  static String format(num amount) => _vndFormat.format(amount);

  /// Chỉ lấy số: 350000 → "350.000"
  static String formatNumber(num amount) => _vndNoSymbol.format(amount);

  /// Rút gọn: 1500000 → "1,5tr"
  static String formatShort(num amount) {
    if (amount >= 1000000) {
      final millions = amount / 1000000;
      return '${_formatDecimal(millions)}tr';
    }
    if (amount >= 1000) {
      final thousands = amount / 1000;
      return '${_formatDecimal(thousands)}k';
    }
    return format(amount);
  }

  static String _formatDecimal(double val) {
    return val == val.roundToDouble()
        ? val.toStringAsFixed(0)
        : val.toStringAsFixed(1);
  }

  /// Parse chuỗi tiền về số: "350.000" → 350000
  static double parse(String text) {
    final cleaned = text.replaceAll(RegExp(r'[^\d]'), '');
    return double.tryParse(cleaned) ?? 0;
  }

  /// Tính tiền sau giảm giá
  static double applyDiscount(double amount, double discountAmount) {
    return (amount - discountAmount).clamp(0, double.infinity);
  }

  /// Tính thuế VAT
  static double calculateVat(double subtotal, double vatPercent) {
    return subtotal * (vatPercent / 100);
  }

  /// Tính tổng bao gồm VAT
  static double calculateTotal(double subtotal, double vatPercent, double discount) {
    final vat = calculateVat(subtotal, vatPercent);
    return applyDiscount(subtotal + vat, discount);
  }
}
