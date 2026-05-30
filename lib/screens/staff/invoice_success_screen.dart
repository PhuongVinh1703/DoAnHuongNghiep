import 'package:flutter/material.dart';
import 'package:doanquanlyquananai_mobileapp/core/constants/app_colors.dart';
import 'package:doanquanlyquananai_mobileapp/core/utils/money_formatter.dart';
import 'package:doanquanlyquananai_mobileapp/models/customer/customer.dart';
import 'package:doanquanlyquananai_mobileapp/models/invoice/checkout_response.dart';
import 'package:doanquanlyquananai_mobileapp/widgets/alert/ai_alert_badge.dart';
import 'package:doanquanlyquananai_mobileapp/widgets/common/app_button.dart';
import 'package:qr_flutter/qr_flutter.dart';

class InvoiceSuccessScreen extends StatelessWidget {
  final CheckoutResponse response;
  final Customer? customer;

  const InvoiceSuccessScreen({
    super.key,
    required this.response,
    this.customer,
  });

  @override
  Widget build(BuildContext context) {
    final hasAlert = response.aiAlert != null && response.aiAlert!.isAnomaly;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 20),

              // Success icon
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  size: 56,
                  color: AppColors.success,
                ),
              ),
              const SizedBox(height: 16),

              const Text(
                'Thanh Toán Thành Công!',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                response.invoiceNo,
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 32),

              // Receipt card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.07),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    _receiptRow(
                      label: 'Tổng tiền',
                      value: MoneyFormatter.format(response.totalAmount),
                      isLarge: true,
                    ),
                    const Divider(height: 24),

                    if (customer != null) ...[
                      _receiptRow(
                        label: 'Khách hàng',
                        value: customer!.fullName,
                      ),
                      _receiptRow(
                        label: 'Điểm tích lũy',
                        value: '+${response.earnedPoints} điểm 🎉',
                        valueColor: AppColors.success,
                      ),
                      const SizedBox(height: 8),
                    ] else ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                        ),
                        child: Column(
                          children: [
                            const Text(
                              'Khách hàng quét mã để nhận điểm & xem hóa đơn',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(8),
                              color: Colors.white,
                              child: QrImageView(
                                data: 'INVOICE:${response.invoiceNo}',
                                version: QrVersions.auto,
                                size: 140.0,
                                backgroundColor: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // AI Alert (nếu có)
              if (hasAlert) ...[
                AiAlertBadge(alert: response.aiAlert!, expanded: true),
                const SizedBox(height: 16),
              ],

              const SizedBox(height: 8),
              AppButtonWide(
                label: 'Về Danh Sách Bàn',
                onPressed: () {
                  // Pop về root (tất cả màn hình trên stack)
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
                color: AppColors.primary,
              ),
              const SizedBox(height: 12),
              AppButtonWide(
                label: 'Đơn Mới',
                isOutlined: true,
                onPressed: () {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _receiptRow({
    required String label,
    required String value,
    bool isLarge = false,
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isLarge ? 16 : 14,
              color: AppColors.textSecondary,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: isLarge ? 20 : 14,
              fontWeight: isLarge ? FontWeight.bold : FontWeight.w600,
              color: valueColor ?? (isLarge ? AppColors.primary : AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}
