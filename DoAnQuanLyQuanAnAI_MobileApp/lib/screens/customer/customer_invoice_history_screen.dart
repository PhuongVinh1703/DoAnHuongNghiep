import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:doanquanlyquananai_mobileapp/theme/app_colors.dart';
import 'package:doanquanlyquananai_mobileapp/theme/app_theme.dart';
import 'package:doanquanlyquananai_mobileapp/services/auth_service.dart';
import 'package:doanquanlyquananai_mobileapp/services/customer_provider.dart';
import 'package:doanquanlyquananai_mobileapp/services/invoice_service.dart';
import 'package:doanquanlyquananai_mobileapp/models/invoice/invoice.dart';
import 'package:doanquanlyquananai_mobileapp/widgets/common/app_snackbar.dart';

class CustomerInvoiceHistoryScreen extends StatefulWidget {
  const CustomerInvoiceHistoryScreen({super.key});

  @override
  State<CustomerInvoiceHistoryScreen> createState() => _CustomerInvoiceHistoryScreenState();
}

class _CustomerInvoiceHistoryScreenState extends State<CustomerInvoiceHistoryScreen> {
  final InvoiceService _svc = InvoiceService();
  List<Invoice> _invoices = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final auth  = context.read<AuthService>();
    final prov  = context.read<CustomerProvider>();
    final cust  = prov.currentCustomer;
    if (!auth.isLoggedIn || cust == null) {
      setState(() => _isLoading = false);
      return;
    }

    setState(() => _isLoading = true);
    final result = await _svc.getByCustomer(cust.customerId);
    if (mounted) {
      if (result.isSuccess) {
        setState(() => _invoices = result.data ?? []);
      } else {
        AppSnackbar.showError(context, result.error ?? 'Không thể tải lịch sử');
      }
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Lịch sử mua hàng'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _load,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _invoices.isEmpty
              ? _buildEmpty()
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: AppTheme.marginMobile, vertical: 12),
                    itemCount: _invoices.length,
                    separatorBuilder: (_, i2) => const SizedBox(height: 12),
                    itemBuilder: (ctx, i) => _InvoiceCard(invoice: _invoices[i], service: _svc),
                  ),
                ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(color: AppColors.surfaceContainerHigh, shape: BoxShape.circle),
            child: const Icon(Icons.receipt_long_rounded, size: 36, color: AppColors.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          const Text('Chưa có lịch sử mua hàng', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          const Text('Hóa đơn của bạn sẽ xuất hiện ở đây', style: TextStyle(color: AppColors.onSurfaceVariant)),
        ],
      ),
    );
  }
}

class _InvoiceCard extends StatefulWidget {
  final Invoice invoice;
  final InvoiceService service;
  const _InvoiceCard({required this.invoice, required this.service});

  @override
  State<_InvoiceCard> createState() => _InvoiceCardState();
}

class _InvoiceCardState extends State<_InvoiceCard> {
  bool _expanded = false;
  List<InvoiceItem>? _details;
  bool _loadingDetails = false;

  Future<void> _loadDetails() async {
    if (_details != null) {
      setState(() => _expanded = !_expanded);
      return;
    }
    setState(() => _loadingDetails = true);
    final result = await widget.service.getById(widget.invoice.invoiceId);
    if (mounted) {
      if (result.isSuccess) {
        setState(() {
          _details = result.data!.items;
          _expanded = true;
        });
      }
      setState(() => _loadingDetails = false);
    }
  }

  String _formatCurrency(double amount) {
    final f = amount.toInt().toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.');
    return '$fđ';
  }

  @override
  Widget build(BuildContext context) {
    final inv = widget.invoice;
    final earnedPts = inv.earnedPoints;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppColors.outlineVariant.withAlpha(60)),
        boxShadow: AppTheme.shadowLevel1,
      ),
      child: Column(
        children: [
          // ── Header ──
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Row 1: chi nhánh + tổng tiền
                Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(
                        '${inv.tableName ?? 'Bàn'} — ${DateFormat('HH:mm dd/MM/yyyy').format(inv.paidAt)}',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 3),
                      Text('Mã HĐ: ${inv.invoiceNo}',
                          style: const TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant)),
                    ]),
                  ),
                  Text(
                    _formatCurrency(inv.totalAmount),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.chipPaid),
                  ),
                ]),

                const SizedBox(height: 10),

                // Row 2: tags
                Wrap(spacing: 8, runSpacing: 6, children: [
                  _Tag(label: inv.paymentMethodLabel, color: AppColors.primary),
                  if (inv.discountAmount > 0)
                    _Tag(label: 'Giảm ${inv.discountPercent.toInt()}%', color: AppColors.error),
                  if (earnedPts > 0)
                    _Tag(label: '⭐ +$earnedPts điểm', color: const Color(0xFFD97706)),
                ]),

                const SizedBox(height: 12),

                // Toggle details
                GestureDetector(
                  onTap: _loadDetails,
                  child: Row(children: [
                    if (_loadingDetails)
                      const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                    else
                      Icon(
                        _expanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                        size: 18, color: AppColors.primary,
                      ),
                    const SizedBox(width: 4),
                    Text(
                      _expanded ? 'Thu gọn' : 'Xem chi tiết món',
                      style: const TextStyle(fontSize: 13, color: AppColors.primary, fontWeight: FontWeight.w600),
                    ),
                  ]),
                ),
              ],
            ),
          ),

          // ── Details (expandable) ──
          if (_expanded && _details != null) ...[
            Divider(height: 1, color: AppColors.outlineVariant.withAlpha(60)),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Items
                  ..._details!.map((item) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(children: [
                      Expanded(
                        child: Text('${item.quantity}× ${item.itemName}',
                            style: const TextStyle(fontSize: 13, color: AppColors.onSurface)),
                      ),
                      Text(_formatCurrency(item.lineTotal),
                          style: const TextStyle(fontSize: 13, color: AppColors.onSurfaceVariant, fontWeight: FontWeight.w500)),
                    ]),
                  )),

                  // Divider
                  Divider(height: 16, color: AppColors.outlineVariant.withAlpha(50)),

                  // Subtotal
                  _SummaryRow(label: 'Tạm tính', value: _formatCurrency(inv.subtotal)),
                  if (inv.discountAmount > 0)
                    _SummaryRow(
                      label: 'Giảm giá (${inv.discountPercent.toInt()}%)',
                      value: '-${_formatCurrency(inv.discountAmount)}',
                      valueColor: AppColors.error,
                    ),
                  if (inv.vatAmount > 0)
                    _SummaryRow(label: 'VAT (${inv.vatPercent.toInt()}%)', value: '+${_formatCurrency(inv.vatAmount)}'),

                  // Total
                  const SizedBox(height: 4),
                  Row(children: [
                    const Expanded(child: Text('Tổng cộng',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700))),
                    Text(_formatCurrency(inv.totalAmount),
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.chipPaid)),
                  ]),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String label;
  final Color color;
  const _Tag({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(22),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: color.withAlpha(60)),
      ),
      child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label, value;
  final Color? valueColor;
  const _SummaryRow({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(children: [
        Expanded(child: Text(label, style: const TextStyle(fontSize: 13, color: AppColors.onSurfaceVariant))),
        Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: valueColor ?? AppColors.onSurface)),
      ]),
    );
  }
}
