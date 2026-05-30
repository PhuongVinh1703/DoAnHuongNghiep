import 'package:flutter/material.dart';
import 'package:doanquanlyquananai_mobileapp/core/constants/app_colors.dart';
import 'package:doanquanlyquananai_mobileapp/core/utils/money_formatter.dart';

class MoneyText extends StatelessWidget {
  final double amount;
  final double fontSize;
  final FontWeight fontWeight;
  final Color? color;
  final bool showSymbol;

  const MoneyText(
    this.amount, {
    super.key,
    this.fontSize = 14,
    this.fontWeight = FontWeight.w600,
    this.color,
    this.showSymbol = true,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      showSymbol ? MoneyFormatter.format(amount) : MoneyFormatter.formatNumber(amount),
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color ?? AppColors.textPrimary,
      ),
    );
  }
}

/// Hiển thị giá gốc vs giá sau giảm
class PriceDisplay extends StatelessWidget {
  final double originalPrice;
  final double? discountedPrice;
  final double fontSize;

  const PriceDisplay({
    super.key,
    required this.originalPrice,
    this.discountedPrice,
    this.fontSize = 14,
  });

  @override
  Widget build(BuildContext context) {
    final hasDiscount = discountedPrice != null && discountedPrice! < originalPrice;
    if (!hasDiscount) {
      return MoneyText(originalPrice, fontSize: fontSize, color: AppColors.primary);
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        MoneyText(discountedPrice!, fontSize: fontSize, color: AppColors.primary),
        const SizedBox(width: 6),
        Text(
          MoneyFormatter.format(originalPrice),
          style: TextStyle(
            fontSize: fontSize - 2,
            color: AppColors.textSecondary,
            decoration: TextDecoration.lineThrough,
          ),
        ),
      ],
    );
  }
}
