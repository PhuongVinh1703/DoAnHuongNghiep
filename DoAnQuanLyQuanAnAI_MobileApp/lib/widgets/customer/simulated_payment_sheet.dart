import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:doanquanlyquananai_mobileapp/theme/app_colors.dart';
import 'package:doanquanlyquananai_mobileapp/theme/app_theme.dart';
import 'package:doanquanlyquananai_mobileapp/core/utils/money_formatter.dart';

class SimulatedPaymentSheet extends StatefulWidget {
  final double amount;
  final String paymentMethod; // 'VietQR', 'MoMo', 'ZaloPay', 'Apple Pay'
  final String addInfo;
  final VoidCallback onSuccess;
  final VoidCallback onCancel;

  const SimulatedPaymentSheet({
    super.key,
    required this.amount,
    required this.paymentMethod,
    required this.addInfo,
    required this.onSuccess,
    required this.onCancel,
  });

  static void show(
    BuildContext context, {
    required double amount,
    required String paymentMethod,
    required String addInfo,
    required VoidCallback onSuccess,
    required VoidCallback onCancel,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SimulatedPaymentSheet(
        amount: amount,
        paymentMethod: paymentMethod,
        addInfo: addInfo,
        onSuccess: onSuccess,
        onCancel: onCancel,
      ),
    );
  }

  @override
  State<SimulatedPaymentSheet> createState() => _SimulatedPaymentSheetState();
}

class _SimulatedPaymentSheetState extends State<SimulatedPaymentSheet> {
  int _step = 0; // 0: Init/Setup, 1: Processing/Action, 2: Success
  String _pin = '';
  bool _faceIdScanned = false;

  @override
  void initState() {
    super.initState();
    if (widget.paymentMethod == 'VietQR') {
      _step = 0; // Show QR immediately
    } else if (widget.paymentMethod == 'Apple Pay') {
      _step = 1; // Show FaceID scanning
      _simulateFaceId();
    } else {
      _step = 1; // Passcode input for MoMo/ZaloPay
    }
  }

  Future<void> _simulateFaceId() async {
    await Future.delayed(const Duration(seconds: 1));
    if (mounted) {
      setState(() => _faceIdScanned = true);
    }
    await Future.delayed(const Duration(milliseconds: 800));
    if (mounted) {
      setState(() => _step = 2);
    }
  }

  void _handlePinPress(String value) {
    if (_pin.length >= 6) return;
    setState(() {
      _pin += value;
    });

    if (_pin.length == 6) {
      _processPayment();
    }
  }

  void _handlePinDelete() {
    if (_pin.isEmpty) return;
    setState(() {
      _pin = _pin.substring(0, _pin.length - 1);
    });
  }

  Future<void> _processPayment() async {
    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) {
      setState(() => _step = 2); // Success state
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                widget.paymentMethod == 'VietQR' ? 'Thanh toán VietQR' : 'Cổng thanh toán điện tử',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () {
                  Navigator.pop(context);
                  widget.onCancel();
                },
              ),
            ],
          ),
          const Divider(),
          const SizedBox(height: 12),

          // Steps
          if (_step == 0 && widget.paymentMethod == 'VietQR') _buildVietQrContent(),
          if (_step == 1 && widget.paymentMethod == 'Apple Pay') _buildApplePayContent(),
          if (_step == 1 && (widget.paymentMethod == 'MoMo' || widget.paymentMethod == 'ZaloPay')) _buildPinInputContent(),
          if (_step == 2) _buildSuccessContent(),
        ],
      ),
    );
  }

  Widget _buildVietQrContent() {
    // Generate VietQR url
    final qrUrl = 'https://img.vietqr.io/image/vietinbank-108876927706-compact.png'
        '?amount=${widget.amount.toInt()}'
        '&addInfo=${Uri.encodeComponent(widget.addInfo)}'
        '&accountName=TRAN%20PHUONG%20VINH';

    return Column(
      children: [
        const Text(
          'Vui lòng quét mã bên dưới để thanh toán chuyển khoản',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.onSurfaceVariant, fontSize: 13),
        ),
        const SizedBox(height: 16),

        // QR Image container
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: AppTheme.shadowLevel1,
            border: Border.all(color: AppColors.outlineVariant),
          ),
          child: CachedNetworkImage(
            imageUrl: qrUrl,
            width: 240,
            height: 320,
            fit: BoxFit.contain,
            placeholder: (context, url) => Container(
              width: 240,
              height: 320,
              color: Colors.grey[100],
              child: const Center(child: CircularProgressIndicator()),
            ),
            errorWidget: (context, url, error) => const SizedBox(
              width: 240,
              height: 320,
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

        // VietQR Account details
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.outlineVariant.withAlpha(80)),
          ),
          child: Column(
            children: [
              _buildDetailRow('Chủ tài khoản', 'TRAN PHUONG VINH', isBold: true),
              const Divider(height: 16),
              _buildDetailRow('Số tài khoản', '108876927706', isCopyable: true),
              const Divider(height: 16),
              _buildDetailRow('Ngân hàng', 'VietinBank'),
              const Divider(height: 16),
              _buildDetailRow('Chi nhánh', 'CN BA RIA - VUNG TAU - PGD XUYEN MOC'),
              const Divider(height: 16),
              _buildDetailRow('Số tiền', MoneyFormatter.format(widget.amount), color: AppColors.primary, isBold: true),
              const Divider(height: 16),
              _buildDetailRow('Nội dung chuyển khoản', widget.addInfo, color: AppColors.tertiary, isBold: true),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Action button
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () => setState(() => _step = 2),
            icon: const Icon(Icons.check_circle_rounded),
            label: const Text('Tôi đã chuyển khoản thành công', style: TextStyle(fontWeight: FontWeight.bold)),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: AppColors.primary,
            ),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildApplePayContent() {
    return Column(
      children: [
        const SizedBox(height: 24),
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: Colors.black,
            shape: BoxShape.circle,
            boxShadow: AppTheme.shadowLevel2,
          ),
          child: Icon(
            _faceIdScanned ? Icons.face_retouching_natural : Icons.face,
            color: Colors.white,
            size: 40,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          _faceIdScanned ? 'Đã xác thực Face ID!' : 'Đang quét Face ID...',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 8),
        Text(
          'Thanh toán qua Apple Pay: ${MoneyFormatter.format(widget.amount)}',
          style: TextStyle(color: AppColors.onSurfaceVariant, fontSize: 13),
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildPinInputContent() {
    final themeColor = widget.paymentMethod == 'MoMo' ? const Color(0xFFA50064) : const Color(0xFF0068FF);
    final logoText = widget.paymentMethod;

    return Column(
      children: [
        // App header inside sheet
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: themeColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                logoText,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'Nhập mật khẩu ví điện tử',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'Số tiền giao dịch: ${MoneyFormatter.format(widget.amount)}',
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 20),

        // Pin Dots
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(6, (index) {
            final hasValue = index < _pin.length;
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 8),
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: hasValue ? themeColor : Colors.grey[200],
                border: Border.all(color: hasValue ? themeColor : Colors.grey[300]!),
              ),
            );
          }),
        ),
        const SizedBox(height: 24),

        // Passcode keypad
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: ['1', '2', '3'].map(_buildKeypadButton).toList(),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: ['4', '5', '6'].map(_buildKeypadButton).toList(),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: ['7', '8', '9'].map(_buildKeypadButton).toList(),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  const SizedBox(width: 60, height: 60),
                  _buildKeypadButton('0'),
                  SizedBox(
                    width: 60,
                    height: 60,
                    child: IconButton(
                      icon: const Icon(Icons.backspace_rounded, color: Colors.grey),
                      onPressed: _handlePinDelete,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildKeypadButton(String number) {
    return InkWell(
      onTap: () => _handlePinPress(number),
      borderRadius: BorderRadius.circular(30),
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: Colors.grey[50],
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Text(
          number,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
        ),
      ),
    );
  }

  Widget _buildSuccessContent() {
    return Column(
      children: [
        const SizedBox(height: 30),
        Container(
          width: 80,
          height: 80,
          decoration: const BoxDecoration(
            color: AppColors.chipPaid,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.check_rounded,
            color: Colors.white,
            size: 48,
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'Thanh Toán Thành Công!',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: AppColors.chipPaid),
        ),
        const SizedBox(height: 8),
        Text(
          'Giao dịch trị giá ${MoneyFormatter.format(widget.amount)} đã được ghi nhận.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.onSurfaceVariant, fontSize: 13),
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () {
              Navigator.pop(context);
              widget.onSuccess();
            },
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: AppColors.chipPaid,
            ),
            child: const Text('Hoàn tất', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isBold = false, Color? color, bool isCopyable = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: AppColors.onSurfaceVariant)),
        Row(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
                color: color ?? AppColors.onSurface,
              ),
            ),
            if (isCopyable) ...[
              const SizedBox(width: 4),
              Icon(Icons.copy_rounded, size: 14, color: AppColors.primary.withAlpha(180)),
            ]
          ],
        ),
      ],
    );
  }
}
