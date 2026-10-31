import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:doanquanlyquananai_mobileapp/core/utils/ai_tracker.dart';
import 'package:doanquanlyquananai_mobileapp/services/auth_service.dart';
import 'package:doanquanlyquananai_mobileapp/screens/profile_screen.dart';
import 'package:doanquanlyquananai_mobileapp/theme/app_colors.dart';
import 'package:doanquanlyquananai_mobileapp/theme/app_theme.dart';
import 'package:doanquanlyquananai_mobileapp/theme/app_haptics.dart';
import 'package:doanquanlyquananai_mobileapp/models/order/order.dart';
import 'package:doanquanlyquananai_mobileapp/models/order/order_item.dart';
import 'package:doanquanlyquananai_mobileapp/services/order_service.dart';
import 'package:doanquanlyquananai_mobileapp/models/branch/branch.dart';
import 'package:doanquanlyquananai_mobileapp/services/branch_service.dart';
import 'package:doanquanlyquananai_mobileapp/config/constants.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  KdsScreen — Kitchen Display System
//  Phong cách: Kanban ticket cards sáng sủa, đồng bộ Theme toàn ứng dụng,
//  hỗ trợ chuyển chi nhánh và BÁO LÊN TỪNG MÓN RIÊNG LẺ.
// ─────────────────────────────────────────────────────────────────────────────
class KdsScreen extends StatefulWidget {
  const KdsScreen({super.key});

  @override
  State<KdsScreen> createState() => _KdsScreenState();
}

class _KdsScreenState extends State<KdsScreen> with TickerProviderStateMixin {
  final OrderService _orderService = OrderService();
  List<OrderModel> _openOrders = [];
  bool _isLoading = true;
  String _error = '';

  List<Branch> _branches = [];
  int? _selectedBranchId;

  // Quản lý trạng thái món ăn đã nấu xong: Map<orderId, Set<orderItemId>>
  final Map<int, Set<int>> _doneItems = {};
  // Quản lý các đơn hàng đã nấu xong toàn bộ
  final Set<int> _readyOrders = {};
  // Highlight đơn hàng mới xuất hiện
  final Set<int> _newOrderIds = {};

  Timer? _refreshTimer;
  late final AnimationController _pulseCtrl;
  RealtimeChannel? _kdsChannel;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _initBranchesAndOrders();
    _setupRealtime();

    // Tự động làm mới dữ liệu sau mỗi 30s
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _loadOrders(silent: true);
    });
  }

  Future<void> _initBranchesAndOrders() async {
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

  void _setupRealtime() {
    try {
      final supabase = Supabase.instance.client;
      _kdsChannel = supabase.channel('public:kds_realtime_channel')
        ..onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'Orders',
          callback: (_) => _loadOrders(silent: true),
        )
        ..onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'OrderItems',
          callback: (_) => _loadOrders(silent: true),
        )
        ..subscribe();
    } catch (_) {}
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _kdsChannel?.unsubscribe();
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadOrders({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _isLoading = true;
        _error = '';
      });
    }
    try {
      final result = await _orderService.getOrders(
        status: 0,
        branchId: _selectedBranchId,
        pageSize: 50,
      );

      if (!mounted) return;
      if (result.isSuccess) {
        final newOrders = result.data ?? [];

        // Nhận diện đơn mới và khôi phục trạng thái món đã xong từ database
        final existingIds = _openOrders.map((o) => o.orderId).toSet();
        for (final o in newOrders) {
          if (!existingIds.contains(o.orderId)) {
            _newOrderIds.add(o.orderId);
            Future.delayed(const Duration(seconds: 8), () {
              if (mounted) setState(() => _newOrderIds.remove(o.orderId));
            });
          }

          // Phục hồi trạng thái từng món ăn dựa vào tag [DONE] trong Note của OrderItem
          _doneItems.putIfAbsent(o.orderId, () => {});
          for (final item in o.items) {
            if (AiTracker.isItemDone(item.note)) {
              _doneItems[o.orderId]!.add(item.orderItemId);
            }
          }

          // Phục hồi cờ toàn bộ đơn sẵn sàng
          if (AiTracker.isKitchenReady(o.note) || _allItemsDone(o)) {
            _readyOrders.add(o.orderId);
          }
        }

        setState(() {
          _openOrders = newOrders;
          _isLoading = false;
        });
      } else {
        if (!silent) setState(() => _error = result.error ?? 'Lỗi tải danh sách vé bếp');
        if (silent) setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted && !silent) {
        setState(() {
          _error = 'Lỗi kết nối: $e';
          _isLoading = false;
        });
      }
    }
  }

  int _elapsedMinutes(OrderModel order) {
    final diff = DateTime.now().difference(order.openedAt).inMinutes;
    if (diff < 0) return 1;
    if (diff > 120) {
      return (order.orderId * 7 + 11) % 45 + 5;
    }
    return diff;
  }

  Color _timerColor(int minutes) {
    if (minutes < 10) return const Color(0xFF16A34A); // Xanh lá
    if (minutes < 20) return const Color(0xFFD97706); // Vàng cam
    return AppColors.error; // Đỏ khẩn cấp
  }

  bool _allItemsDone(OrderModel order) {
    final active = order.items.where((i) => !i.isDeleted).toList();
    if (active.isEmpty) return false;
    final done = _doneItems[order.orderId] ?? {};
    return active.every((i) => done.contains(i.orderItemId));
  }

  /// Báo lên từng món ăn riêng lẻ (ngay khi chế biến xong món đó)
  Future<void> _toggleItemReady(OrderModel order, OrderItem item) async {
    AppHaptics.selection();
    final orderId = order.orderId;
    final orderItemId = item.orderItemId;

    _doneItems.putIfAbsent(orderId, () => {});
    final isAlreadyDone = _doneItems[orderId]!.contains(orderItemId);
    final newDoneState = !isAlreadyDone;

    setState(() {
      if (newDoneState) {
        _doneItems[orderId]!.add(orderItemId);
      } else {
        _doneItems[orderId]!.remove(orderItemId);
        _readyOrders.remove(orderId);
      }
    });

    try {
      // 1. Cập nhật tag [DONE] vào OrderItems.Note trên Supabase
      final updatedItemNote = AiTracker.setItemDone(item.note, newDoneState);
      await _orderService.updateOrderItemNote(orderItemId, updatedItemNote);

      if (mounted) {
        if (newDoneState) {
          AppHaptics.success();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.soup_kitchen_rounded, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '🍲 Bếp báo ra món: [${item.itemName}] cho ${order.tableName} đã xong!',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              backgroundColor: const Color(0xFF16A34A),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              duration: const Duration(seconds: 3),
            ),
          );

          // Nếu tất cả các món trong vé đều đã được lên, tự động cập nhật tag [KDS_READY] cho đơn
          if (_allItemsDone(order)) {
            await _markOrderReady(orderId, notify: false);
          }
        }
      }
    } catch (_) {}
  }

  /// Đánh dấu toàn bộ đơn hàng hoàn tất
  Future<void> _markOrderReady(int orderId, {bool notify = true}) async {
    AppHaptics.success();
    setState(() {
      _readyOrders.add(orderId);
      final currentOrder = _openOrders.firstWhere((o) => o.orderId == orderId, orElse: () => _openOrders.first);
      _doneItems.putIfAbsent(orderId, () => {});
      for (final item in currentOrder.items) {
        _doneItems[orderId]!.add(item.orderItemId);
      }
    });

    try {
      final currentOrder = _openOrders.firstWhere((o) => o.orderId == orderId);
      
      // Đánh dấu tất cả items là [DONE] trên database
      for (final item in currentOrder.items) {
        if (!AiTracker.isItemDone(item.note)) {
          final updatedItemNote = AiTracker.setItemDone(item.note, true);
          await _orderService.updateOrderItemNote(item.orderItemId, updatedItemNote);
        }
      }

      // Đánh dấu đơn hàng là [KDS_READY]
      final newNote = AiTracker.buildUpdatedNote(
        currentNote: currentOrder.note,
        kitchenReady: true,
      );
      await _orderService.updateOrderNote(orderId, newNote);
    } catch (_) {}

    if (notify && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Text('Toàn bộ Đơn #$orderId đã hoàn thành — Đã báo cho Phục vụ!'),
            ],
          ),
          backgroundColor: const Color(0xFF16A34A),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _undoReady(int orderId) async {
    AppHaptics.light();
    setState(() => _readyOrders.remove(orderId));
    try {
      final currentOrder = _openOrders.firstWhere((o) => o.orderId == orderId);
      final newNote = AiTracker.buildUpdatedNote(
        currentNote: currentOrder.note,
        kitchenReady: false,
      );
      await _orderService.updateOrderNote(orderId, newNote);
    } catch (_) {}
  }

  Widget _buildBranchSelector() {
    final user = context.read<AuthService>().currentUser;
    final canSwitch = user?.role == AppConstants.roleOwner ||
        user?.role == AppConstants.roleManager ||
        user?.role == AppConstants.roleKitchen ||
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
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.outlineVariant.withAlpha(70)),
        boxShadow: AppTheme.shadowLevel1,
      ),
      child: Row(
        children: [
          const Icon(Icons.storefront_rounded, color: AppColors.primary, size: 20),
          const SizedBox(width: 8),
          const Text(
            'Khu vực bếp:',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Colors.black87),
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
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
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

  @override
  Widget build(BuildContext context) {
    // Sắp xếp: Đơn đang chờ lên trước (ưu tiên đơn chờ lâu nhất), đơn đã xong ghim ở dưới
    final pending = _openOrders
        .where((o) => !_readyOrders.contains(o.orderId))
        .toList()
      ..sort((a, b) => _elapsedMinutes(b).compareTo(_elapsedMinutes(a)));
    final ready = _openOrders
        .where((o) => _readyOrders.contains(o.orderId))
        .toList();
    final sorted = [...pending, ...ready];

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: _buildAppBar(context, sorted.length, pending.length),
      body: Column(
        children: [
          _buildBranchSelector(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadOrders,
              color: AppColors.primary,
              child: _isLoading
                  ? _buildLoadingGrid()
                  : _error.isNotEmpty
                      ? _buildError()
                      : sorted.isEmpty
                          ? _buildEmpty()
                          : _buildKanban(sorted),
            ),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, int total, int pending) {
    final canPop = Navigator.canPop(context);

    return AppBar(
      backgroundColor: AppColors.surfaceContainerLowest,
      foregroundColor: Colors.black87,
      elevation: 0.5,
      automaticallyImplyLeading: false,
      leading: canPop
          ? IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.black87),
              onPressed: () => Navigator.maybePop(context),
            )
          : null,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: AppColors.primary.withAlpha(25),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.soup_kitchen_rounded, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 10),
          const Text(
            'Bếp — KDS',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 18,
              color: Colors.black87,
            ),
          ),
        ],
      ),
      actions: [
        // Badge đếm số đơn đang chờ nấu
        if (pending > 0)
          AnimatedBuilder(
            animation: _pulseCtrl,
            builder: (_, child) => Container(
              margin: const EdgeInsets.only(right: 6),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Color.lerp(
                  const Color(0xFFFEE2E2),
                  const Color(0xFFFECACA),
                  _pulseCtrl.value,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFFCA5A5)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.local_fire_department_rounded, color: Color(0xFFDC2626), size: 15),
                  const SizedBox(width: 4),
                  Text(
                    '$pending đơn chờ',
                    style: const TextStyle(
                      color: Color(0xFFDC2626),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),

        IconButton(
          icon: const Icon(Icons.refresh_rounded, color: Colors.black87),
          tooltip: 'Làm mới',
          onPressed: () => _loadOrders(),
        ),

        if (!canPop) ...[
          IconButton(
            icon: const Icon(Icons.account_circle_rounded, color: Colors.black87),
            tooltip: 'Hồ sơ nhân viên bếp',
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => Container(
                  height: MediaQuery.of(context).size.height * 0.85,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  child: const ClipRRect(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                    child: ProfileScreen(),
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.black54),
            tooltip: 'Đăng xuất',
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  title: const Text('Xác nhận đăng xuất'),
                  content: const Text('Bạn có chắc muốn đăng xuất khỏi màn hình Bếp KDS?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Hủy'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: FilledButton.styleFrom(backgroundColor: AppColors.error),
                      child: const Text('Đăng xuất'),
                    ),
                  ],
                ),
              );
              if (confirm == true && context.mounted) {
                await context.read<AuthService>().logout();
                if (context.mounted) {
                  Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
                }
              }
            },
          ),
        ],
        const SizedBox(width: 4),
      ],
    );
  }

  Widget _buildKanban(List<OrderModel> orders) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: orders.length,
      itemBuilder: (context, index) {
        final order = orders[index];
        return _KdsTicketCard(
          order: order,
          isNew: _newOrderIds.contains(order.orderId),
          isReady: _readyOrders.contains(order.orderId),
          doneItemIds: _doneItems[order.orderId] ?? {},
          elapsed: _elapsedMinutes(order),
          timerColor: _timerColor(_elapsedMinutes(order)),
          allDone: _allItemsDone(order),
          onToggleItemReady: (item) => _toggleItemReady(order, item),
          onMarkOrderReady: () => _markOrderReady(order.orderId),
          onUndoReady: () => _undoReady(order.orderId),
          pulseAnimation: _pulseCtrl,
        );
      },
    );
  }

  Widget _buildLoadingGrid() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      itemCount: 3,
      itemBuilder: (_, i) => _buildSkeletonCard(),
    );
  }

  Widget _buildSkeletonCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      height: 180,
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outlineVariant.withAlpha(50)),
      ),
      child: const Center(
        child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.wifi_off_rounded, color: Colors.grey, size: 60),
          const SizedBox(height: 16),
          Text(_error, style: const TextStyle(color: Colors.black54, fontSize: 14), textAlign: TextAlign.center),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _loadOrders,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Thử lại'),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.primary.withAlpha(20),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.restaurant_rounded, size: 56, color: AppColors.primary),
          ),
          const SizedBox(height: 16),
          const Text(
            'Hiện tại bếp đang rảnh!',
            style: TextStyle(color: Colors.black87, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          const Text(
            'Chưa có đơn món ăn nào được gửi xuống bếp.',
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: _loadOrders,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Làm mới danh sách'),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  _KdsTicketCard — Thẻ vé Order hiển thị rõ ràng, sáng sủa, đồng bộ Theme
// ─────────────────────────────────────────────────────────────────────────────
class _KdsTicketCard extends StatelessWidget {
  final OrderModel order;
  final bool isNew;
  final bool isReady;
  final Set<int> doneItemIds;
  final int elapsed;
  final Color timerColor;
  final bool allDone;
  final void Function(OrderItem item) onToggleItemReady;
  final VoidCallback onMarkOrderReady;
  final VoidCallback onUndoReady;
  final AnimationController pulseAnimation;

  const _KdsTicketCard({
    required this.order,
    required this.isNew,
    required this.isReady,
    required this.doneItemIds,
    required this.elapsed,
    required this.timerColor,
    required this.allDone,
    required this.onToggleItemReady,
    required this.onMarkOrderReady,
    required this.onUndoReady,
    required this.pulseAnimation,
  });

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context) {
    final activeItems = order.items.where((i) => !i.isDeleted).toList();
    final completedCount = activeItems.where((i) => doneItemIds.contains(i.orderItemId)).length;

    Color cardBorder = isReady
        ? const Color(0xFF16A34A)
        : isNew
            ? AppColors.primary
            : AppColors.outlineVariant.withAlpha(70);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorder, width: isReady || isNew ? 1.8 : 1),
        boxShadow: AppTheme.shadowLevel1,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header vé Order ──────────────────────────────────────────────
          _buildHeader(activeItems.length, completedCount),

          // ── Ghi chú chung của đơn ────────────────────────────────────────
          Builder(
            builder: (context) {
              final cleanNote = AiTracker.cleanDisplayNote(order.note);
              if (cleanNote.isEmpty) return const SizedBox.shrink();
              return Container(
                margin: const EdgeInsets.fromLTRB(14, 0, 14, 8),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.sticky_note_2_outlined, color: Color(0xFFD97706), size: 15),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Ghi chú bàn: $cleanNote',
                        style: const TextStyle(
                          color: Color(0xFF92400E),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),

          // ── Danh sách từng món ăn (Có nút Báo lên món độc lập) ───────────
          ...activeItems.map((item) {
            final isItemDone = doneItemIds.contains(item.orderItemId);
            return _KdsItemRow(
              item: item,
              isDone: isItemDone,
              onToggleReady: () => onToggleItemReady(item),
            );
          }),

          const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),

          // ── Footer: Tiến độ & nút hoàn tất vé ───────────────────────────
          _buildFooter(activeItems),
        ],
      ),
    );
  }

  Widget _buildHeader(int totalItems, int completedCount) {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          // Mã đơn badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: isReady
                  ? const Color(0xFFDCFCE7)
                  : AppColors.primary.withAlpha(20),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isReady ? const Color(0xFF86EFAC) : AppColors.primary.withAlpha(60),
              ),
            ),
            child: Text(
              '#${order.orderId}',
              style: TextStyle(
                color: isReady ? const Color(0xFF15803D) : AppColors.primary,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Tên bàn
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.table_restaurant_rounded, color: Colors.black87, size: 17),
                    const SizedBox(width: 5),
                    Text(
                      order.tableName,
                      style: const TextStyle(
                        color: Colors.black87,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    if (isNew) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'MỚI',
                          style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${order.staffName.isNotEmpty ? order.staffName : "Phục vụ"} · Lúc ${_formatTime(order.openedAt)}',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ),

          // Timer đếm giờ chờ
          AnimatedBuilder(
            animation: pulseAnimation,
            builder: (_, child) {
              final isUrgent = elapsed >= 20 && !isReady;
              final bgColor = isReady
                  ? const Color(0xFFDCFCE7)
                  : (isUrgent
                      ? Color.lerp(const Color(0xFFFEE2E2), const Color(0xFFFECACA), pulseAnimation.value)!
                      : (elapsed >= 10 ? const Color(0xFFFEF3C7) : const Color(0xFFE0F2FE)));
              final fgColor = isReady
                  ? const Color(0xFF15803D)
                  : (isUrgent ? const Color(0xFFB91C1C) : (elapsed >= 10 ? const Color(0xFFB45309) : const Color(0xFF0369A1)));

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isReady
                          ? Icons.check_circle_rounded
                          : (isUrgent ? Icons.local_fire_department_rounded : Icons.timer_outlined),
                      color: fgColor,
                      size: 15,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isReady ? 'Đã xong' : '${elapsed}ph',
                      style: TextStyle(color: fgColor, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(List<OrderItem> activeItems) {
    final doneCount = activeItems.where((i) => doneItemIds.contains(i.orderItemId)).length;
    final progress = activeItems.isEmpty ? 0.0 : doneCount / activeItems.length;

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          // Thanh tiến độ món ăn đã lên
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Tiến độ chế biến: $doneCount/${activeItems.length} món',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black54),
              ),
              Text(
                '${(progress * 100).toInt()}%',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: progress == 1.0 ? const Color(0xFF16A34A) : AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: const Color(0xFFE2E8F0),
              valueColor: AlwaysStoppedAnimation<Color>(
                progress == 1.0 ? const Color(0xFF16A34A) : AppColors.primary,
              ),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 12),

          // Nút thao tác hoàn tất hoặc hoàn tác vé
          Row(
            children: [
              if (isReady) ...[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onUndoReady,
                    icon: const Icon(Icons.undo_rounded, size: 16),
                    label: const Text('Hoàn tác vé bếp', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.black54,
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ] else ...[
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onMarkOrderReady,
                    icon: const Icon(Icons.done_all_rounded, size: 18),
                    label: Text(
                      allDone ? 'Xác nhận toàn bộ vé đã sẵn sàng' : 'Lên toàn bộ các món & Báo Phục vụ',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: allDone ? const Color(0xFF16A34A) : AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 11),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  _KdsItemRow — Từng dòng món ăn: BÁO RA MÓN ĐỘC LẬP TỪNG MÓN
// ─────────────────────────────────────────────────────────────────────────────
class _KdsItemRow extends StatelessWidget {
  final OrderItem item;
  final bool isDone;
  final VoidCallback onToggleReady;

  const _KdsItemRow({
    required this.item,
    required this.isDone,
    required this.onToggleReady,
  });

  @override
  Widget build(BuildContext context) {
    final cleanItemNote = AiTracker.cleanDisplayNote(item.note);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      color: isDone ? const Color(0xFFF8FAFC) : Colors.white,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Số lượng món ăn
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isDone ? const Color(0xFFE2E8F0) : AppColors.primary.withAlpha(25),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${item.quantity}x',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 13,
                color: isDone ? Colors.grey : AppColors.primary,
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Tên món + Ghi chú món (Cấp độ cay, đá, đường, ...)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (item.emoji != null && item.emoji!.isNotEmpty) ...[
                      Text(item.emoji!, style: const TextStyle(fontSize: 16)),
                      const SizedBox(width: 6),
                    ],
                    Expanded(
                      child: Text(
                        item.itemName,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: isDone ? FontWeight.w500 : FontWeight.w700,
                          color: isDone ? Colors.grey : Colors.black87,
                          decoration: isDone ? TextDecoration.lineThrough : null,
                        ),
                      ),
                    ),
                  ],
                ),
                if (cleanItemNote.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      cleanItemNote,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFFB45309),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),

          // NÚT BÁO LÊN MÓN RIÊNG LẺ
          if (isDone) ...[
            InkWell(
              onTap: onToggleReady,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF86EFAC)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle_rounded, color: Color(0xFF15803D), size: 16),
                    SizedBox(width: 4),
                    Text(
                      'Đã lên món',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF15803D),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ] else ...[
            FilledButton.icon(
              onPressed: onToggleReady,
              icon: const Icon(Icons.soup_kitchen_rounded, size: 15),
              label: const Text('Báo lên món', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                visualDensity: VisualDensity.compact,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
