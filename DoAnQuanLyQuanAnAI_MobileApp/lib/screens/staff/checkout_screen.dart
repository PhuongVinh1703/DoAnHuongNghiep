import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:doanquanlyquananai_mobileapp/core/constants/app_colors.dart';
import 'package:doanquanlyquananai_mobileapp/core/utils/money_formatter.dart';
import 'package:doanquanlyquananai_mobileapp/theme/app_haptics.dart';
import 'package:doanquanlyquananai_mobileapp/core/storage/secure_storage.dart';
import 'package:doanquanlyquananai_mobileapp/models/customer/customer.dart';
import 'package:doanquanlyquananai_mobileapp/models/customer/voucher.dart';
import 'package:doanquanlyquananai_mobileapp/models/order/order.dart';
import 'package:doanquanlyquananai_mobileapp/services/cart_provider.dart';
import 'package:doanquanlyquananai_mobileapp/services/customer_service.dart';
import 'package:doanquanlyquananai_mobileapp/services/invoice_service.dart';
import 'package:doanquanlyquananai_mobileapp/services/order_provider.dart';
import 'package:doanquanlyquananai_mobileapp/services/discount_service.dart';
import 'package:doanquanlyquananai_mobileapp/models/discount/discount_campaign.dart';
import 'package:doanquanlyquananai_mobileapp/models/menu/menu_item.dart';
import 'package:doanquanlyquananai_mobileapp/widgets/common/app_button.dart';
import 'package:doanquanlyquananai_mobileapp/widgets/common/app_snackbar.dart';
import 'package:doanquanlyquananai_mobileapp/widgets/common/loading_overlay.dart';
import 'package:doanquanlyquananai_mobileapp/widgets/common/money_text.dart';
import 'package:doanquanlyquananai_mobileapp/widgets/order/order_item_tile.dart';
import 'package:doanquanlyquananai_mobileapp/widgets/order/qr_payment_dialog.dart';
import 'invoice_success_screen.dart';
import 'customer_lookup_screen.dart';
import 'customer_register_screen.dart';

class CheckoutScreen extends StatefulWidget {
  final OrderModel order;
  const CheckoutScreen({super.key, required this.order});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _phoneCtrl   = TextEditingController();
  final _voucherCtrl = TextEditingController();
  final _customerSvc = CustomerService();
  final _invoiceSvc  = InvoiceService();
  final _discountSvc = DiscountService();

  int _paymentMethod = 2; // QR default
  Customer? _customer;
  Voucher? _voucher;
  DiscountCampaign? _campaign;
  bool _isLoading = false;
  bool _isFindingCustomer = false;
  bool _isValidatingVoucher = false;

  static const double _vat = 8.0;

  double get _subtotal => widget.order.subtotal;
  double get _discount => _voucher != null 
      ? (_subtotal * _voucher!.discountAmount / 100) 
      : (_campaign != null ? (_subtotal * _campaign!.discountValue / 100) : 0);
  double get _vatAmount => (_subtotal - _discount) * _vat / 100;
  double get _total => (_subtotal - _discount + _vatAmount).clamp(0, double.infinity);

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _voucherCtrl.dispose();
    super.dispose();
  }

  // ── Tìm khách theo SĐT ───────────────────────────────────────
  Future<void> _findCustomer() async {
    final phone = _phoneCtrl.text.trim();
    if (phone.isEmpty) return;
    setState(() => _isFindingCustomer = true);
    final result = await _customerSvc.findByPhone(phone);
    setState(() => _isFindingCustomer = false);
    result.fold(
      onSuccess: (c) {
        setState(() => _customer = c);
        if (c == null) {
          AppSnackbar.showWarning(context, 'Không tìm thấy khách hàng. Có thể tạo mới.');
        }
      },
      onFailure: (e) => AppSnackbar.showError(context, e),
    );
  }

  // ── Kiểm tra voucher ─────────────────────────────────────────
  Future<void> _validateVoucher() async {
    final code = _voucherCtrl.text.trim();
    if (code.isEmpty) return;
    setState(() => _isValidatingVoucher = true);

    // 1. Thử xác thực mã voucher cá nhân (CustomerVouchers)
    final vResult = await _customerSvc.validateVoucher(code, _subtotal);
    if (vResult.isSuccess && vResult.data != null) {
      setState(() {
        _voucher = vResult.data;
        _campaign = null;
        _isValidatingVoucher = false;
      });
      if (mounted) {
        AppSnackbar.showSuccess(context, 'Áp dụng Voucher thành công! Giảm ${_voucher!.discountAmount.toInt()}%');
      }
      return;
    }

    // 2. Nếu thất bại, thử xác thực mã khuyến mãi chung (DiscountCampaigns)
    final cResult = await _discountSvc.validateCampaign(code, _subtotal);
    setState(() => _isValidatingVoucher = false);

    if (cResult.isSuccess && cResult.data != null) {
      setState(() {
        _campaign = cResult.data;
        _voucher = null;
      });
      if (mounted) {
        AppSnackbar.showSuccess(context, 'Áp dụng Mã khuyến mãi thành công! Giảm ${_campaign!.discountValue.toInt()}%');
      }
      return;
    }

    // 3. Nếu cả hai đều không hợp lệ, hiển thị thông báo lỗi
    setState(() {
      _voucher = null;
      _campaign = null;
    });
    if (mounted) {
      AppSnackbar.showError(context, cResult.error ?? vResult.error ?? 'Mã không hợp lệ hoặc đã hết hạn.');
    }
  }

  // ── Thanh toán ───────────────────────────────────────────────
  Future<void> _doCheckout() async {
    if (_paymentMethod == 2) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => QrPaymentDialog(
          amount: _total,
          orderId: widget.order.orderId.toString(),
        ),
      );
      if (confirmed != true) return;
    }

    if (!mounted) return;
    final orderProvider = context.read<OrderProvider>();
    orderProvider.markConfirmClicked(); // Đánh dấu đã confirm cho AI tracker

    final accountId = await SecureStorage.getUserId();
    if (accountId == null) return;

    setState(() => _isLoading = true);
    final result = await _invoiceSvc.checkout(
      orderId:       widget.order.orderId,
      accountId:     int.parse(accountId),
      tableId:       widget.order.tableId,
      paymentMethod: _paymentMethod,
      tracker:       orderProvider.getAiTracker(),
      customerId:    _customer?.customerId,
      voucherCode:   _voucher?.voucherCode,
      discountCampaignCode: _campaign?.code,
      appliedDiscountPercent: _voucher != null
          ? _voucher!.discountAmount
          : (_campaign != null ? _campaign!.discountValue : 0.0),
      vatPercent:    _vat,
    );
    if (!mounted) return;
    setState(() => _isLoading = false);

    result.fold(
      onSuccess: (resp) {
        AppHaptics.success();
        context.read<CartProvider>().clear();
        orderProvider.clearCurrentOrderAfterCheckout();
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => InvoiceSuccessScreen(
              response: resp,
              customer: _customer,
            ),
          ),
        );
      },
      onFailure: (e) {
        AppHaptics.error();
        if (!mounted) return;
        AppSnackbar.showError(context, e);
      },
    );
  }

  // ── UI ───────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Thanh Toán'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: LoadingOverlay(
        isLoading: _isLoading,
        message: 'Đang xử lý thanh toán...',
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _orderSummaryCard(),
              const SizedBox(height: 16),
              _customerCard(),
              const SizedBox(height: 16),
              _voucherCard(),
              const SizedBox(height: 16),
              _paymentMethodCard(),
              const SizedBox(height: 16),
              _totalsCard(),
              const SizedBox(height: 24),
              AppButtonWide(
                label: 'Xác Nhận Thanh Toán ${MoneyFormatter.format(_total)}',
                onPressed: _doCheckout,
                isLoading: _isLoading,
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(
      title,
      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
    ),
  );

  Widget _card({required Widget child}) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8)],
    ),
    child: child,
  );

  Widget _orderSummaryCard() => _card(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('📋 Đơn hàng — ${widget.order.tableName}'),
        ...widget.order.items.map(
          (item) {
            final cartItem = CartItem(
              menuItem: MenuItemModel(
                itemId: item.itemId,
                categoryId: 0,
                name: item.itemName,
                description: '',
                price: item.unitPrice,
                emoji: item.emoji ?? '🍽️',
                imagePath: item.imagePath,
                isAvailable: true,
                categoryName: '',
              ),
              quantity: item.quantity,
              note: item.note,
            );
            return OrderItemTile(item: cartItem, isEditable: false);
          },
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _showPreCheckoutBillDialog,
            icon: const Icon(Icons.receipt_outlined, size: 18),
            label: const Text('Xem Phiếu Tạm Tính (Bill kiểm món)'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.primary),
              padding: const EdgeInsets.symmetric(vertical: 11),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
      ],
    ),
  );

  void _showPreCheckoutBillDialog() {
    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(
                    child: Text(
                      'TIỆM MÌ CAY SƠN BỘ HẢI',
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Center(
                    child: Text(
                      'PHIẾU KIỂM MÓN / TẠM TÍNH',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        letterSpacing: 1.1,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Bàn: ${widget.order.tableName}', style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text(
                        'Giờ vào: ${widget.order.openedAt.hour.toString().padLeft(2, '0')}:${widget.order.openedAt.minute.toString().padLeft(2, '0')}',
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                  const Divider(thickness: 1.5, height: 20),
                  const Row(
                    children: [
                      Expanded(flex: 4, child: Text('Món', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                      Expanded(flex: 1, child: Text('SL', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                      Expanded(flex: 2, child: Text('Đơn giá', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                      Expanded(flex: 3, child: Text('T.Tiền', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...widget.order.items.map((item) {
                    final itemTotal = item.unitPrice * item.quantity;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                flex: 4,
                                child: Text(item.itemName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                              ),
                              Expanded(
                                flex: 1,
                                child: Text('${item.quantity}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 12)),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(MoneyFormatter.format(item.unitPrice), textAlign: TextAlign.right, style: const TextStyle(fontSize: 11)),
                              ),
                              Expanded(
                                flex: 3,
                                child: Text(MoneyFormatter.format(itemTotal), textAlign: TextAlign.right, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                              ),
                            ],
                          ),
                          if (item.note != null && item.note!.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(left: 4, top: 2),
                              child: Text(
                                '• ${item.note}',
                                style: const TextStyle(fontSize: 10, color: Colors.grey, fontStyle: FontStyle.italic),
                              ),
                            ),
                        ],
                      ),
                    );
                  }),
                  const Divider(thickness: 1, height: 20),
                  _billRow('Tạm tính:', MoneyFormatter.format(_subtotal)),
                  if (_discount > 0)
                    _billRow('Giảm giá:', '-${MoneyFormatter.format(_discount)}', color: AppColors.error),
                  _billRow('VAT (8%):', MoneyFormatter.format(_vatAmount)),
                  const Divider(thickness: 1.5, height: 16),
                  _billRow('TỔNG CỘNG:', MoneyFormatter.format(_total), isBold: true, fontSize: 16, color: AppColors.primary),
                  const SizedBox(height: 16),
                  const Center(
                    child: Text(
                      'Phiếu tạm tính dùng để đối chiếu món trước khi thanh toán.\nCảm ơn quý khách đã ghé thăm!',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 10, color: Colors.grey, fontStyle: FontStyle.italic),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Đóng'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _billRow(String label, String value, {bool isBold = false, double fontSize = 13, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: fontSize, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
          Text(value, style: TextStyle(fontSize: fontSize, fontWeight: isBold ? FontWeight.bold : FontWeight.w600, color: color)),
        ],
      ),
    );
  }

  Widget _customerCard() => _card(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('👤 Khách hàng (tuỳ chọn)'),
        if (_customer != null)
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.person, color: AppColors.success),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_customer!.fullName, style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text('${_customer!.phone} · ${_customer!.totalPoints} điểm',
                          style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () => setState(() => _customer = null),
                ),
              ],
            ),
          )
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _phoneCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        hintText: 'Nhập số điện thoại khách...',
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  AppButton(
                    label: 'Tìm',
                    onPressed: _findCustomer,
                    isLoading: _isFindingCustomer,
                    height: 44,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  TextButton.icon(
                    onPressed: () async {
                      final selected = await Navigator.push<Customer>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const CustomerLookupScreen(),
                        ),
                      );
                      if (selected != null && mounted) {
                        setState(() {
                          _customer = selected;
                          _phoneCtrl.text = selected.phone;
                        });
                      }
                    },
                    icon: const Icon(Icons.person_search_outlined, size: 18),
                    label: const Text('Tra cứu nâng cao'),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: () async {
                      final registered = await Navigator.push<Customer>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CustomerRegisterScreen(
                            prefillPhone: _phoneCtrl.text.trim(),
                          ),
                        ),
                      );
                      if (registered != null && mounted) {
                        setState(() {
                          _customer = registered;
                          _phoneCtrl.text = registered.phone;
                        });
                      }
                    },
                    icon: const Icon(Icons.person_add_alt_1_outlined, size: 18),
                    label: const Text('Đăng ký khách mới'),
                  ),
                ],
              ),
            ],
          ),
      ],
    ),
  );

  Widget _voucherCard() {
    final hasDiscount = _voucher != null || _campaign != null;
    String codeText = '';
    int discountPercent = 0;
    if (_voucher != null) {
      codeText = _voucher!.voucherCode;
      discountPercent = _voucher!.discountAmount.toInt();
    } else if (_campaign != null) {
      codeText = _campaign!.code;
      discountPercent = _campaign!.discountValue.toInt();
    }

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('🎟️ Mã voucher / Khuyến mãi (tuỳ chọn)'),
          if (hasDiscount)
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.local_offer, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '$codeText — Giảm $discountPercent%',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => setState(() {
                      _voucher = null;
                      _campaign = null;
                      _voucherCtrl.clear();
                    }),
                  ),
                ],
              ),
            )
          else
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _voucherCtrl,
                    decoration: InputDecoration(
                      hintText: 'Nhập mã voucher hoặc khuyến mãi...',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                AppButton(
                  label: 'Áp dụng',
                  onPressed: _validateVoucher,
                  isLoading: _isValidatingVoucher,
                  height: 44,
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _paymentMethodCard() => _card(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('💳 Phương thức thanh toán'),
        RadioGroup<int>(
          groupValue: _paymentMethod,
          onChanged: (v) {
            AppHaptics.selection();
            setState(() => _paymentMethod = v!);
          },
          child: Column(
            children: [
              (0, Icons.money, 'Tiền mặt'),
              (1, Icons.credit_card, 'Thẻ'),
              (2, Icons.qr_code, 'QR Code'),
            ].map((e) {
              final (val, icon, label) = e;
              return RadioListTile<int>(
                value: val,
                title: Row(
                  children: [
                    Icon(icon, size: 18, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Text(label),
                  ],
                ),
                contentPadding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
                activeColor: AppColors.primary,
              );
            }).toList(),
          ),
        ),
      ],
    ),
  );

  Widget _totalsCard() => _card(
    child: Column(
      children: [
        _totalRow('Tạm tính', _subtotal),
        if (_discount > 0) _totalRow('Giảm giá', -_discount, color: AppColors.success),
        _totalRow('VAT (${_vat.toStringAsFixed(0)}%)', _vatAmount),
        const Divider(height: 20),
        _totalRow('Tổng cộng', _total, isBold: true, fontSize: 18, color: AppColors.primary),
      ],
    ),
  );

  Widget _totalRow(String label, double amount, {
    bool isBold = false,
    double fontSize = 14,
    Color? color,
  }) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(fontSize: fontSize, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
            MoneyText(amount.abs(), fontSize: fontSize, fontWeight: isBold ? FontWeight.bold : FontWeight.w600, color: color),
          ],
        ),
      );
}
