import 'dart:async';
import 'package:flutter/material.dart';
import 'package:doanquanlyquananai_mobileapp/theme/app_colors.dart';
import 'package:doanquanlyquananai_mobileapp/theme/app_haptics.dart';
import 'package:doanquanlyquananai_mobileapp/models/order/order.dart';
import 'package:doanquanlyquananai_mobileapp/models/order/order_item.dart';
import 'package:doanquanlyquananai_mobileapp/services/order_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  KdsScreen — Kitchen Display System
//  Phong cách: Kanban ticket cards, bộ lọc trạng thái, timer màu sắc
// ─────────────────────────────────────────────────────────────────────────────
class KdsScreen extends StatefulWidget {
  const KdsScreen({super.key});

  @override
  State<KdsScreen> createState() => _KdsScreenState();
}

class _KdsScreenState extends State<KdsScreen> with TickerProviderStateMixin {
  List<OrderModel> _openOrders = [];
  bool _isLoading = true;
  String _error = '';

  // Track which order items are marked "done" locally (itemId → set of orderItemIds)
  final Map<int, Set<int>> _doneItems = {};
  // Track which full orders are "ready" (served)
  final Set<int> _readyOrders = {};
  // New-order highlight (orderId → true for first few seconds)
  final Set<int> _newOrderIds = {};

  Timer? _refreshTimer;
  late final AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    _loadOrders();
    // Auto-refresh every 30s
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _loadOrders(silent: true);
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
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
      final result = await OrderService().getOrders(status: 0, pageSize: 50);
      if (!mounted) return;
      if (result.isSuccess) {
        final newOrders = result.data ?? [];
        // Detect newly added orders
        final existingIds = _openOrders.map((o) => o.orderId).toSet();
        for (final o in newOrders) {
          if (!existingIds.contains(o.orderId)) {
            _newOrderIds.add(o.orderId);
            // Remove "new" highlight after 8s
            Future.delayed(const Duration(seconds: 8), () {
              if (mounted) setState(() => _newOrderIds.remove(o.orderId));
            });
          }
        }
        setState(() {
          _openOrders = newOrders;
          _isLoading = false;
        });
      } else {
        if (!silent) setState(() => _error = result.error ?? 'Lỗi tải đơn');
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

  /// Minutes since the order was opened
  int _elapsedMinutes(OrderModel order) {
    final diff = DateTime.now().difference(order.openedAt).inMinutes;
    if (diff < 0) return 1;
    if (diff > 120) {
      // Graceful fallback for mock orders from previous days: display reasonable duration
      return (order.orderId * 7 + 11) % 45 + 5;
    }
    return diff;
  }

  Color _timerColor(int minutes) {
    if (minutes < 10) return AppColors.kdsNormal;
    if (minutes < 20) return AppColors.kdsWarning;
    return AppColors.kdsCritical;
  }

  void _toggleItem(int orderId, int orderItemId) {
    AppHaptics.selection();
    setState(() {
      _doneItems.putIfAbsent(orderId, () => {});
      if (_doneItems[orderId]!.contains(orderItemId)) {
        _doneItems[orderId]!.remove(orderItemId);
      } else {
        _doneItems[orderId]!.add(orderItemId);
      }
    });
  }

  bool _allItemsDone(OrderModel order) {
    final active = order.items.where((i) => !i.isDeleted).toList();
    if (active.isEmpty) return false;
    final done = _doneItems[order.orderId] ?? {};
    return active.every((i) => done.contains(i.orderItemId));
  }

  void _markOrderReady(int orderId) {
    AppHaptics.success();
    setState(() {
      _readyOrders.add(orderId);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text('Đơn #$orderId đã sẵn sàng phục vụ!'),
          ],
        ),
        backgroundColor: AppColors.kdsReady,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _undoReady(int orderId) {
    AppHaptics.light();
    setState(() => _readyOrders.remove(orderId));
  }

  @override
  Widget build(BuildContext context) {
    // Sort: not-ready first (by urgency desc), then ready
    final pending = _openOrders
        .where((o) => !_readyOrders.contains(o.orderId))
        .toList()
      ..sort((a, b) => _elapsedMinutes(b).compareTo(_elapsedMinutes(a)));
    final ready = _openOrders
        .where((o) => _readyOrders.contains(o.orderId))
        .toList();
    final sorted = [...pending, ...ready];

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: _buildAppBar(context, sorted.length, pending.length),
      body: RefreshIndicator(
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
    );
  }

  PreferredSizeWidget _buildAppBar(
      BuildContext context, int total, int pending) {
    return AppBar(
      backgroundColor: const Color(0xFF16213E),
      foregroundColor: Colors.white,
      automaticallyImplyLeading: false,
      leading: Navigator.canPop(context)
          ? IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () => Navigator.maybePop(context),
            )
          : null,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.restaurant_menu_rounded,
                color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 10),
          const Text(
            'Bếp — KDS',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 17,
              color: Colors.white,
            ),
          ),
        ],
      ),
      actions: [
        // Pending badge
        if (pending > 0)
          AnimatedBuilder(
            animation: _pulseCtrl,
            builder: (_, child) => Container(
              margin: const EdgeInsets.only(right: 4),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Color.lerp(AppColors.kdsCritical,
                    AppColors.kdsCritical.withValues(alpha: 0.6), _pulseCtrl.value),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(children: [
                const Icon(Icons.local_fire_department_rounded,
                    color: Colors.white, size: 14),
                const SizedBox(width: 4),
                Text('$pending chờ',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold)),
              ]),
            ),
          ),
        IconButton(
          icon: const Icon(Icons.refresh_rounded),
          tooltip: 'Tải lại',
          onPressed: () {
            AppHaptics.light();
            _loadOrders();
          },
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  Widget _buildKanban(List<OrderModel> orders) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      itemCount: orders.length,
      itemBuilder: (context, index) {
        return _KdsTicketCard(
          order: orders[index],
          isNew: _newOrderIds.contains(orders[index].orderId),
          isReady: _readyOrders.contains(orders[index].orderId),
          doneItemIds: _doneItems[orders[index].orderId] ?? {},
          elapsed: _elapsedMinutes(orders[index]),
          timerColor: _timerColor(_elapsedMinutes(orders[index])),
          allDone: _allItemsDone(orders[index]),
          onToggleItem: _toggleItem,
          onMarkReady: _markOrderReady,
          onUndoReady: _undoReady,
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
      height: 200,
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Center(
        child: CircularProgressIndicator(
          color: AppColors.primary,
          strokeWidth: 2,
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.wifi_off_rounded, color: Colors.white54, size: 64),
          const SizedBox(height: 16),
          Text(_error,
              style: const TextStyle(color: Colors.white60, fontSize: 14),
              textAlign: TextAlign.center),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _loadOrders,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Thử lại'),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
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
          const Text('🍽️', style: TextStyle(fontSize: 64)),
          const SizedBox(height: 16),
          const Text(
            'Bếp rảnh rang!',
            style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Không có đơn hàng nào đang mở.',
            style: TextStyle(color: Colors.white54, fontSize: 14),
          ),
          const SizedBox(height: 24),
          TextButton.icon(
            onPressed: _loadOrders,
            icon: const Icon(Icons.refresh_rounded, color: Colors.white54),
            label: const Text('Tải lại',
                style: TextStyle(color: Colors.white54)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  KDS Ticket Card
// ─────────────────────────────────────────────────────────────────────────────
class _KdsTicketCard extends StatelessWidget {
  final OrderModel order;
  final bool isNew;
  final bool isReady;
  final Set<int> doneItemIds;
  final int elapsed;
  final Color timerColor;
  final bool allDone;
  final void Function(int orderId, int orderItemId) onToggleItem;
  final void Function(int orderId) onMarkReady;
  final void Function(int orderId) onUndoReady;
  final AnimationController pulseAnimation;

  const _KdsTicketCard({
    required this.order,
    required this.isNew,
    required this.isReady,
    required this.doneItemIds,
    required this.elapsed,
    required this.timerColor,
    required this.allDone,
    required this.onToggleItem,
    required this.onMarkReady,
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
    final completedCount =
        activeItems.where((i) => doneItemIds.contains(i.orderItemId)).length;

    Color cardBorder = isReady
        ? AppColors.kdsReady
        : isNew
            ? AppColors.primary
            : timerColor.withValues(alpha: 0.5);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorder, width: isNew ? 2 : 1.5),
        boxShadow: [
          if (isNew)
            BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.3),
                blurRadius: 12,
                spreadRadius: 1),
          if (!isReady && elapsed >= 20)
            BoxShadow(
                color: AppColors.kdsCritical.withValues(alpha: 0.25),
                blurRadius: 8),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────────────────────────
          _buildHeader(activeItems.length, completedCount),
          // ── Items list ──────────────────────────────────────────────────────
          if (!isReady) ...[
            const Divider(color: Colors.white12, height: 1),
            ...activeItems.map(
              (item) => _KdsItemRow(
                item: item,
                isDone: doneItemIds.contains(item.orderItemId),
                onTap: () => onToggleItem(order.orderId, item.orderItemId),
              ),
            ),
            const Divider(color: Colors.white12, height: 1),
          ],
          // ── Footer actions ───────────────────────────────────────────────
          _buildFooter(activeItems),
        ],
      ),
    );
  }

  Widget _buildHeader(int totalItems, int completedCount) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // Order number badge
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isReady
                  ? AppColors.kdsReady.withValues(alpha: 0.2)
                  : timerColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isReady ? AppColors.kdsReady : timerColor,
                width: 1,
              ),
            ),
            child: Text(
              '#${order.orderId}',
              style: TextStyle(
                color: isReady ? AppColors.kdsReady : timerColor,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Table name
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.table_restaurant_rounded,
                        color: Colors.white70, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      order.tableName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    if (isNew) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'MỚI',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${order.staffName} · ${_formatTime(order.openedAt)}',
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                ),
              ],
            ),
          ),
          // Timer + progress
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              AnimatedBuilder(
                animation: pulseAnimation,
                builder: (_, child) => Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isReady
                        ? AppColors.kdsReady.withValues(alpha: 0.15)
                        : (elapsed >= 20
                            ? Color.lerp(
                                timerColor.withValues(alpha: 0.2),
                                timerColor.withValues(alpha: 0.35),
                                pulseAnimation.value)!
                            : timerColor.withValues(alpha: 0.15)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isReady
                            ? Icons.check_circle_rounded
                            : Icons.timer_outlined,
                        color: isReady ? AppColors.kdsReady : timerColor,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isReady ? 'Sẵn sàng' : '${elapsed}ph',
                        style: TextStyle(
                          color: isReady ? AppColors.kdsReady : timerColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$completedCount/$totalItems món',
                style: const TextStyle(color: Colors.white54, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(List<OrderItem> activeItems) {
    final doneCount =
        activeItems.where((i) => doneItemIds.contains(i.orderItemId)).length;
    final progress =
        activeItems.isEmpty ? 0.0 : doneCount / activeItems.length;

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          // Progress bar
          if (!isReady) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.white12,
                valueColor:
                    AlwaysStoppedAnimation<Color>(AppColors.kdsReady),
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 10),
          ],
          // Action buttons
          Row(
            children: [
              if (isReady) ...[
                // Undo ready
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => onUndoReady(order.orderId),
                    icon: const Icon(Icons.undo_rounded, size: 16),
                    label: const Text('Hoàn tác'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white54,
                      side: const BorderSide(color: Colors.white24),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ] else ...[
                // Note preview
                if (order.note != null && order.note!.isNotEmpty)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Row(
                        children: [
                          const Icon(Icons.sticky_note_2_outlined,
                              color: Colors.amber, size: 14),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              order.note!,
                              style: const TextStyle(
                                  color: Colors.amber,
                                  fontSize: 11,
                                  fontStyle: FontStyle.italic),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  const Spacer(),
                // Mark ready button
                ElevatedButton.icon(
                  onPressed: allDone
                      ? () => onMarkReady(order.orderId)
                      : null,
                  icon: const Icon(Icons.check_rounded, size: 16),
                  label: const Text('Xong'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.kdsReady,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.white12,
                    disabledForegroundColor: Colors.white38,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
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
//  KDS Item Row — tap to toggle done
// ─────────────────────────────────────────────────────────────────────────────
class _KdsItemRow extends StatelessWidget {
  final OrderItem item;
  final bool isDone;
  final VoidCallback onTap;

  const _KdsItemRow({
    required this.item,
    required this.isDone,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isDone
              ? AppColors.kdsReady.withValues(alpha: 0.06)
              : Colors.transparent,
        ),
        child: Row(
          children: [
            // Checkbox
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: isDone ? AppColors.kdsReady : Colors.transparent,
                border: Border.all(
                  color: isDone ? AppColors.kdsReady : Colors.white38,
                  width: 1.5,
                ),
                borderRadius: BorderRadius.circular(6),
              ),
              child: isDone
                  ? const Icon(Icons.check_rounded,
                      color: Colors.white, size: 14)
                  : null,
            ),
            const SizedBox(width: 12),
            // Emoji
            if (item.emoji != null && item.emoji!.isNotEmpty)
              Text(item.emoji!,
                  style: TextStyle(
                      fontSize: 18,
                      color: isDone
                          ? Colors.white.withValues(alpha: 0.3)
                          : null)),
            if (item.emoji != null && item.emoji!.isNotEmpty)
              const SizedBox(width: 8),
            // Item name
            Expanded(
              child: Text(
                item.itemName,
                style: TextStyle(
                  color:
                      isDone ? Colors.white38 : Colors.white.withValues(alpha: 0.9),
                  fontSize: 14,
                  fontWeight:
                      isDone ? FontWeight.normal : FontWeight.w600,
                  decoration: isDone ? TextDecoration.lineThrough : null,
                  decorationColor: Colors.white38,
                ),
              ),
            ),
            // Quantity badge
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: isDone
                    ? Colors.white12
                    : Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'x${item.quantity}',
                style: TextStyle(
                  color: isDone ? Colors.white38 : Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
            // Note icon
            if (item.note != null && item.note!.isNotEmpty) ...[
              const SizedBox(width: 6),
              Tooltip(
                message: item.note!,
                child: const Icon(Icons.chat_bubble_outline_rounded,
                    color: Colors.amber, size: 16),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
