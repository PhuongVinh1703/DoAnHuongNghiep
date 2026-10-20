import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:doanquanlyquananai_mobileapp/theme/app_colors.dart';
import 'package:doanquanlyquananai_mobileapp/theme/app_theme.dart';
import 'package:doanquanlyquananai_mobileapp/widgets/status_chip.dart';
import 'package:doanquanlyquananai_mobileapp/models/order/order.dart';
import 'package:doanquanlyquananai_mobileapp/services/order_service.dart';
import 'package:doanquanlyquananai_mobileapp/services/order_provider.dart';
import 'package:doanquanlyquananai_mobileapp/screens/staff/menu_order_screen.dart';

class StaffOrderScreen extends StatefulWidget {
  const StaffOrderScreen({super.key});

  @override
  State<StaffOrderScreen> createState() => _StaffOrderScreenState();
}

class _StaffOrderScreenState extends State<StaffOrderScreen> {
  final OrderService _orderService = OrderService();
  final TextEditingController _searchCtrl = TextEditingController();
  List<OrderModel> _orders = [];
  bool _isLoading = true;
  String? _error;
  String _searchQuery = '';
  int? _statusFilter; // null=All, 0=Pending, 1=Paid, 2=Cancelled

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadOrders() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final result = await _orderService.getOrders(status: _statusFilter);

    if (mounted) {
      setState(() {
        _isLoading = false;
        result.fold(
          onSuccess: (data) => _orders = data,
          onFailure: (e) => _error = e,
        );
      });
    }
  }

  List<OrderModel> get _filteredOrders {
    if (_searchQuery.trim().isEmpty) return _orders;
    final q = _searchQuery.trim().toLowerCase();
    return _orders.where((o) {
      return o.orderId.toString().contains(q) ||
          o.tableName.toLowerCase().contains(q) ||
          o.items.any((i) => i.itemName.toLowerCase().contains(q));
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final displayed = _filteredOrders;
    return Column(
      children: [
        // ─── Search Bar ──────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(
              AppTheme.marginMobile, 8, AppTheme.marginMobile, 16),
          child: TextField(
            controller: _searchCtrl,
            onChanged: (v) => setState(() => _searchQuery = v),
            decoration: InputDecoration(
              hintText: 'Tìm theo mã đơn, tên bàn, món ăn...',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: PopupMenuButton<int?>(
                icon: Icon(
                  Icons.tune_rounded,
                  size: 20,
                  color: _statusFilter != null
                      ? AppColors.primary
                      : AppColors.onSurfaceVariant,
                ),
                onSelected: (val) {
                  setState(() => _statusFilter = val == -1 ? null : val);
                  _loadOrders();
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: -1, child: Text('Tất cả đơn hàng')),
                  PopupMenuItem(value: 0, child: Text('Đang phục vụ (Pending)')),
                  PopupMenuItem(value: 1, child: Text('Đã thanh toán (Paid)')),
                  PopupMenuItem(value: 2, child: Text('Đã hủy (Cancelled)')),
                ],
              ),
            ),
          ),
        ),

        // ─── Order List ──────────────────────────────
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(child: Text(_error!))
                  : RefreshIndicator(
                      onRefresh: _loadOrders,
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppTheme.marginMobile),
                        itemCount: displayed.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final order = displayed[index];
                          return _OrderCard(
                            order: order,
                            onTap: order.status == 0
                                ? () async {
                                    final orderProvider =
                                        context.read<OrderProvider>();
                                    await orderProvider
                                        .fetchOpenOrderForTable(order.tableId);
                                    if (!context.mounted) return;
                                    if (orderProvider.currentOrder != null) {
                                      await Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => MenuOrderScreen(
                                            tableName: order.tableName,
                                          ),
                                        ),
                                      );
                                      if (mounted) _loadOrders();
                                    }
                                  }
                                : null,
                          );
                        },
                      ),
                    ),
        ),
      ],
    );
  }
}

class _OrderCard extends StatelessWidget {
  final OrderModel order;
  final VoidCallback? onTap;

  const _OrderCard({required this.order, this.onTap});

  String _formatCurrency(double amount) {
    final formatted = amount.toInt().toString().replaceAllMapped(
          RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]}.',
        );
    return '$formattedđ';
  }

  @override
  Widget build(BuildContext context) {
    StatusType statusType;
    String statusStr;
    switch (order.status) {
      case 1:
        statusType = StatusType.paid;
        statusStr = 'Paid';
        break;
      case 2:
        statusType = StatusType.cancelled;
        statusStr = 'Cancelled';
        break;
      default:
        statusType = StatusType.pending;
        statusStr = 'Pending';
    }

    final itemCount = order.items.fold(0, (sum, item) => sum + item.quantity);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          border: Border.all(color: AppColors.outlineVariant.withAlpha(60)),
          boxShadow: AppTheme.shadowLevel1,
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ─── Header ──────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text(
                        '#${order.orderId}',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          order.tableName,
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                  StatusChip(
                    label: statusStr,
                    type: statusType,
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // ─── Items ───────────────────────────────
              ...List.generate(
                order.items.length > 3 ? 3 : order.items.length,
                (i) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.circle,
                          size: 5, color: AppColors.onSurfaceVariant),
                      const SizedBox(width: 8),
                      Text(
                        '${order.items[i].itemName} x${order.items[i].quantity}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppColors.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
              if (order.items.length > 3)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.circle,
                          size: 5, color: Colors.transparent),
                      const SizedBox(width: 8),
                      Text(
                        '... and ${order.items.length - 3} more items',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppColors.onSurfaceVariant,
                              fontStyle: FontStyle.italic,
                            ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 14),

              // ─── Footer ──────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '$itemCount items · ${order.openedAt.hour.toString().padLeft(2, '0')}:${order.openedAt.minute.toString().padLeft(2, '0')}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  Text(
                    _formatCurrency(order.subtotal),
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontSize: 18,
                        ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
