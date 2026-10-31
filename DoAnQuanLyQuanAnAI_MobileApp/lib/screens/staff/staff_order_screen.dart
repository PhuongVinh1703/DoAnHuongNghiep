import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:doanquanlyquananai_mobileapp/core/utils/ai_tracker.dart';
import 'package:doanquanlyquananai_mobileapp/theme/app_colors.dart';
import 'package:doanquanlyquananai_mobileapp/theme/app_theme.dart';
import 'package:doanquanlyquananai_mobileapp/theme/app_haptics.dart';
import 'package:doanquanlyquananai_mobileapp/widgets/status_chip.dart';
import 'package:doanquanlyquananai_mobileapp/widgets/common/app_shimmer.dart';
import 'package:doanquanlyquananai_mobileapp/models/order/order.dart';
import 'package:doanquanlyquananai_mobileapp/services/order_service.dart';
import 'package:doanquanlyquananai_mobileapp/services/order_provider.dart';
import 'package:doanquanlyquananai_mobileapp/screens/staff/menu_order_screen.dart';
import 'package:doanquanlyquananai_mobileapp/screens/staff/checkout_screen.dart';
import 'package:doanquanlyquananai_mobileapp/models/branch/branch.dart';
import 'package:doanquanlyquananai_mobileapp/services/branch_service.dart';
import 'package:doanquanlyquananai_mobileapp/services/auth_service.dart';
import 'package:doanquanlyquananai_mobileapp/config/constants.dart';

enum OrderFilterType {
  all,
  open,
  billReq,
  paid,
  cancelled,
}

class StaffOrderScreen extends StatefulWidget {
  final bool isCashierMode;
  const StaffOrderScreen({super.key, this.isCashierMode = false});

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
  OrderFilterType _activeFilter = OrderFilterType.open;
  RealtimeChannel? _realtimeChannel;

  List<Branch> _branches = [];
  int? _selectedBranchId;

  @override
  void initState() {
    super.initState();
    _initBranches();
    _setupRealtime();
  }

  Future<void> _initBranches() async {
    final user = context.read<AuthService>().currentUser;
    final res = await BranchService().getBranches();
    if (res.isSuccess && res.data != null && res.data!.isNotEmpty) {
      if (mounted) {
        setState(() {
          _branches = res.data!;
        });
      }
    }

    if (user?.branchId != null) {
      _selectedBranchId = user!.branchId;
    } else if (_branches.isNotEmpty) {
      _selectedBranchId = _branches.first.branchId;
    }

    _loadOrders();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _realtimeChannel?.unsubscribe();
    super.dispose();
  }

  void _setupRealtime() {
    try {
      final supabase = Supabase.instance.client;
      _realtimeChannel = supabase.channel('public:orders_staff_orders')
        ..onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'Orders',
          callback: (_) {
            if (mounted) _loadOrders(showLoading: false);
          },
        )
        ..subscribe();
    } catch (_) {}
  }

  Future<void> _loadOrders({bool showLoading = true}) async {
    if (showLoading) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    int? statusParam;
    if (_activeFilter == OrderFilterType.open ||
        _activeFilter == OrderFilterType.billReq) {
      statusParam = 0;
    } else if (_activeFilter == OrderFilterType.paid) {
      statusParam = 1;
    } else if (_activeFilter == OrderFilterType.cancelled) {
      statusParam = 2;
    }

    final result = await _orderService.getOrders(
      status: statusParam,
      branchId: _selectedBranchId,
    );

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

  Widget _buildBranchFilter() {
    final user = context.read<AuthService>().currentUser;
    final canSwitch = user?.role == AppConstants.roleOwner ||
        user?.role == AppConstants.roleManager ||
        user?.role == AppConstants.roleCashier ||
        user?.branchId == null;

    final branchName = _branches
        .firstWhere(
          (b) => b.branchId == _selectedBranchId,
          orElse: () => _branches.isNotEmpty
              ? _branches.first
              : Branch(branchId: 1, name: 'Chi nhánh 1', address: '', phone: '', isActive: true),
        )
        .name;

    return Container(
      margin: const EdgeInsets.fromLTRB(AppTheme.marginMobile, 8, AppTheme.marginMobile, 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: AppTheme.cardDecoration(
        color: AppColors.surfaceContainerLowest,
        radius: AppTheme.radiusMd,
      ),
      child: Row(
        children: [
          const Icon(Icons.store_rounded, color: AppColors.primary, size: 20),
          const SizedBox(width: 8),
          const Text(
            'Chi nhánh:',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: canSwitch
                ? DropdownButtonHideUnderline(
                    child: DropdownButton<int?>(
                      value: _selectedBranchId,
                      isExpanded: true,
                      hint: const Text('Chọn chi nhánh'),
                      items: [
                        ..._branches.map((b) => DropdownMenuItem<int?>(
                              value: b.branchId,
                              child: Text(
                                b.name,
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                overflow: TextOverflow.ellipsis,
                              ),
                            )),
                        const DropdownMenuItem<int?>(
                          value: null,
                          child: Text(
                            'Tất cả chi nhánh',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                      onChanged: (val) {
                        AppHaptics.selection();
                        setState(() => _selectedBranchId = val);
                        _loadOrders();
                      },
                    ),
                  )
                : Text(
                    branchName,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
          ),
        ],
      ),
    );
  }

  List<OrderModel> get _filteredOrders {
    var list = _orders;

    // Lọc theo tag Chờ tính tiền nếu filter billReq
    if (_activeFilter == OrderFilterType.billReq) {
      list = list.where((o) => AiTracker.isPaymentRequested(o.note)).toList();
    }

    // Tìm kiếm theo từ khóa
    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.trim().toLowerCase();
      list = list.where((o) {
        return o.orderId.toString().contains(q) ||
            o.tableName.toLowerCase().contains(q) ||
            o.items.any((i) => i.itemName.toLowerCase().contains(q));
      }).toList();
    }

    // Ghim các đơn có yêu cầu tính tiền [BILL_REQ] lên đầu
    final sorted = List<OrderModel>.from(list);
    sorted.sort((a, b) {
      final aReq = a.status == 0 && AiTracker.isPaymentRequested(a.note);
      final bReq = b.status == 0 && AiTracker.isPaymentRequested(b.note);
      if (aReq && !bReq) return -1;
      if (!aReq && bReq) return 1;
      return b.openedAt.compareTo(a.openedAt);
    });

    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    final displayed = _filteredOrders;

    return Column(
      children: [
        // ─── Branch Filter & Indicator ───────────────
        _buildBranchFilter(),

        // ─── Search Bar ──────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppTheme.marginMobile,
            8,
            AppTheme.marginMobile,
            8,
          ),
          child: TextField(
            controller: _searchCtrl,
            onChanged: (v) => setState(() => _searchQuery = v),
            decoration: InputDecoration(
              hintText: 'Tìm theo mã đơn, số bàn, tên món...',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 18),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
            ),
          ),
        ),

        // ─── Filter Chips Bar ────────────────────────
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.marginMobile,
            vertical: 4,
          ),
          child: Row(
            children: [
              _buildFilterChip(
                label: 'Đang phục vụ',
                type: OrderFilterType.open,
              ),
              const SizedBox(width: 8),
              _buildFilterChip(
                label: '💳 Chờ thu tiền',
                type: OrderFilterType.billReq,
                isHighlight: true,
              ),
              const SizedBox(width: 8),
              _buildFilterChip(
                label: 'Đã thanh toán',
                type: OrderFilterType.paid,
              ),
              const SizedBox(width: 8),
              _buildFilterChip(
                label: 'Đã hủy',
                type: OrderFilterType.cancelled,
              ),
              const SizedBox(width: 8),
              _buildFilterChip(
                label: 'Tất cả',
                type: OrderFilterType.all,
              ),
            ],
          ),
        ),

        const SizedBox(height: 8),

        // ─── Order List ──────────────────────────────
        Expanded(
          child: _isLoading
              ? const CardListShimmer(count: 5, cardHeight: 130)
              : _error != null
                  ? Center(child: Text(_error!))
                  : displayed.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _activeFilter == OrderFilterType.billReq
                                    ? Icons.check_circle_outline_rounded
                                    : Icons.receipt_long_outlined,
                                size: 54,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _activeFilter == OrderFilterType.billReq
                                    ? 'Không có bàn nào đang chờ tính tiền!'
                                    : 'Không có đơn hàng nào phù hợp',
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: () => _loadOrders(showLoading: true),
                          child: ListView.separated(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppTheme.marginMobile,
                              vertical: 8,
                            ),
                            itemCount: displayed.length,
                            separatorBuilder: (context, index) =>
                                const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final order = displayed[index];
                              return _OrderCard(
                                order: order,
                                isCashierMode: widget.isCashierMode,
                                onRefresh: () => _loadOrders(showLoading: false),
                              );
                            },
                          ),
                        ),
        ),
      ],
    );
  }

  Widget _buildFilterChip({
    required String label,
    required OrderFilterType type,
    bool isHighlight = false,
  }) {
    final isSelected = _activeFilter == type;
    return GestureDetector(
      onTap: () {
        AppHaptics.selection();
        setState(() => _activeFilter = type);
        _loadOrders();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? (isHighlight ? Colors.amber[700] : AppColors.primary)
              : (isHighlight
                  ? Colors.amber.withAlpha(30)
                  : AppColors.surfaceContainerHigh),
          borderRadius: BorderRadius.circular(AppTheme.radiusFull),
          border: Border.all(
            color: isSelected
                ? (isHighlight ? Colors.amber[800]! : AppColors.primary)
                : (isHighlight
                    ? Colors.amber.withAlpha(120)
                    : AppColors.outlineVariant),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected
                ? Colors.white
                : (isHighlight
                    ? Colors.amber[900]
                    : AppColors.onSurfaceVariant),
          ),
        ),
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final OrderModel order;
  final bool isCashierMode;
  final VoidCallback onRefresh;

  const _OrderCard({
    required this.order,
    required this.isCashierMode,
    required this.onRefresh,
  });

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
        statusStr = 'Đã thanh toán';
        break;
      case 2:
        statusType = StatusType.cancelled;
        statusStr = 'Đã hủy';
        break;
      default:
        statusType = StatusType.pending;
        statusStr = 'Đang phục vụ';
    }

    final isPaymentRequested =
        order.status == 0 && AiTracker.isPaymentRequested(order.note);
    final isKitchenReady =
        order.status == 0 && AiTracker.isKitchenReady(order.note);
    final cleanNote = AiTracker.cleanDisplayNote(order.note);
    final itemCount = order.items.fold(0, (sum, item) => sum + item.quantity);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(
          color: isPaymentRequested
              ? Colors.amber[700]!
              : AppColors.outlineVariant.withAlpha(70),
          width: isPaymentRequested ? 2.0 : 1.0,
        ),
        boxShadow: isPaymentRequested
            ? [
                BoxShadow(
                  color: Colors.amber.withAlpha(60),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                )
              ]
            : AppTheme.shadowLevel1,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
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
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withAlpha(20),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        order.tableName,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    if (isPaymentRequested) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.amber[700],
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          '💳 Chờ thu tiền',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                    if (isKitchenReady) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.success,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          '🍲 Bếp đã xong',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                    StatusChip(
                      label: statusStr,
                      type: statusType,
                    ),
                  ],
                ),
              ],
            ),

            if (cleanNote.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                'Ghi chú: $cleanNote',
                style: const TextStyle(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  color: Colors.grey,
                ),
              ),
            ],

            const SizedBox(height: 10),

            // ─── Items List ──────────────────────────
            ...List.generate(
              order.items.length > 3 ? 3 : order.items.length,
              (i) => Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Row(
                  children: [
                    const Icon(
                      Icons.circle,
                      size: 4,
                      color: AppColors.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${order.items[i].itemName} x${order.items[i].quantity}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppColors.onSurfaceVariant,
                              fontSize: 13,
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      _formatCurrency(
                        order.items[i].unitPrice * order.items[i].quantity,
                      ),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (order.items.length > 3)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  '... và ${order.items.length - 3} món khác',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.onSurfaceVariant,
                        fontStyle: FontStyle.italic,
                      ),
                ),
              ),

            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 8),

            // ─── Footer: Subtotal + Actions ──────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$itemCount món · ${order.openedAt.hour.toString().padLeft(2, '0')}:${order.openedAt.minute.toString().padLeft(2, '0')}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    Text(
                      _formatCurrency(order.subtotal),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),

                // Các nút hành động khi đơn đang mở (Status == 0)
                if (order.status == 0)
                  Row(
                    children: [
                      // Nút 1: Xem / Sửa món
                      OutlinedButton.icon(
                        onPressed: () async {
                          AppHaptics.light();
                          final orderProvider = context.read<OrderProvider>();
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
                            onRefresh();
                          }
                        },
                        icon: const Icon(Icons.edit_note_rounded, size: 16),
                        label: const Text('Sửa món'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusMd),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Nút 2: Tính tiền tại quầy (Nổi bật)
                      ElevatedButton.icon(
                        onPressed: () async {
                          AppHaptics.heavy();
                          final orderProvider = context.read<OrderProvider>();
                          orderProvider.setCurrentOrder(order);
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => CheckoutScreen(order: order),
                            ),
                          );
                          onRefresh();
                        },
                        icon: const Icon(Icons.point_of_sale_rounded, size: 16),
                        label: const Text('Tính tiền'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isPaymentRequested
                              ? Colors.amber[800]
                              : AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusMd),
                          ),
                          elevation: 0,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
