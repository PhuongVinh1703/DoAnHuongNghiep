import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:doanquanlyquananai_mobileapp/theme/app_colors.dart';
import 'package:doanquanlyquananai_mobileapp/core/utils/money_formatter.dart';

class QrPaymentDialog extends StatelessWidget {
  final double amount;
  final String orderId;

  const QrPaymentDialog({
    super.key,
    required this.amount,
    required this.orderId,
  });

  Widget _detailRow(String label, String value, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
              color: Colors.black87,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // Generate VietQR url matching the booking section
    final qrUrl = 'https://img.vietqr.io/image/vietinbank-108876927706-compact.png'
        '?amount=${amount.toInt()}'
        '&addInfo=${Uri.encodeComponent('RR BILL $orderId')}'
        '&accountName=TRAN%20PHUONG%20VINH';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Quét mã thanh toán',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Vui lòng dùng ứng dụng Ngân hàng hoặc Ví điện tử để quét mã bên dưới',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppColors.onSurfaceVariant),
              ),
              const SizedBox(height: 20),
              
              // QR Image Container loading dynamically from VietQR
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.outlineVariant),
                ),
                child: CachedNetworkImage(
                  imageUrl: qrUrl,
                  width: 200,
                  height: 250,
                  fit: BoxFit.contain,
                  placeholder: (context, url) => Container(
                    width: 200,
                    height: 250,
                    color: Colors.grey[100],
                    child: const Center(child: CircularProgressIndicator()),
                  ),
                  errorWidget: (context, url, error) => const SizedBox(
                    width: 200,
                    height: 250,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.broken_image_rounded, size: 48, color: AppColors.error),
                          SizedBox(height: 8),
                          Text('Lỗi tải mã QR', style: TextStyle(color: AppColors.error, fontSize: 13)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              
              Text(
                MoneyFormatter.format(amount),
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Mã đơn: $orderId',
                style: const TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant),
              ),
              const SizedBox(height: 16),

              // VietQR Account details aligned with customer booking section
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Column(
                  children: [
                    _detailRow('Chủ tài khoản', 'TRAN PHUONG VINH', isBold: true),
                    const Divider(height: 12),
                    _detailRow('Số tài khoản', '108876927706'),
                    const Divider(height: 12),
                    _detailRow('Ngân hàng', 'VietinBank'),
                    const Divider(height: 12),
                    _detailRow('Chi nhánh', 'CN BA RIA - VUNG TAU - PGD XUYEN MOC'),
                    const Divider(height: 12),
                    _detailRow('Nội dung chuyển khoản', 'RR BILL $orderId', isBold: true),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Đã thanh toán', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Hủy'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
