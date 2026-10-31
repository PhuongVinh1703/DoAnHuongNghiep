import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:doanquanlyquananai_mobileapp/config/constants.dart';
import 'package:doanquanlyquananai_mobileapp/services/auth_service.dart';
import 'package:doanquanlyquananai_mobileapp/theme/app_colors.dart';
import 'package:doanquanlyquananai_mobileapp/theme/app_theme.dart';
import 'package:doanquanlyquananai_mobileapp/theme/app_haptics.dart';
import 'package:doanquanlyquananai_mobileapp/widgets/common/menu_item_image.dart';
import 'package:doanquanlyquananai_mobileapp/widgets/common/app_shimmer.dart';
import 'package:doanquanlyquananai_mobileapp/services/menu_provider.dart';
import 'package:doanquanlyquananai_mobileapp/services/order_provider.dart';
import 'package:doanquanlyquananai_mobileapp/models/menu/menu_item.dart';
import 'package:doanquanlyquananai_mobileapp/models/menu/menu_category.dart';
import 'package:doanquanlyquananai_mobileapp/l10n/app_localizations.dart';
import 'package:doanquanlyquananai_mobileapp/screens/staff/checkout_screen.dart';
import 'package:doanquanlyquananai_mobileapp/core/utils/ai_tracker.dart';

class MenuOrderScreen extends StatefulWidget {
  final String tableName;
  const MenuOrderScreen({super.key, required this.tableName});

  @override
  State<MenuOrderScreen> createState() => _MenuOrderScreenState();
}

class _MenuOrderScreenState extends State<MenuOrderScreen>
    with SingleTickerProviderStateMixin {
  int _selectedCategoryId = 0;
  final TextEditingController _searchController = TextEditingController();
  String _searchKeyword = '';

  // Mini cart panel toggle
  bool _cartExpanded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MenuProvider>().loadMenuData();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _formatCurrency(double amount) {
    final formatted = amount.toInt().toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]}.',
    );
    return '${formatted}đ';
  }

  // ─── Thêm món với haptics & Modifier Sheet ──────────────────
  Future<void> _handleAddItem(BuildContext context, MenuItemModel item,
      OrderProvider orderProvider) async {
    // Nếu món có ghi chú đặc biệt (description), có thể mở modifier
    // Hiện tại: thêm thẳng + haptic
    AppHaptics.medium();
    await orderProvider.addItem(item.itemId, 1);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final orderProvider = context.watch<OrderProvider>();
    final menuProvider  = context.watch<MenuProvider>();
    final userRole = context.watch<AuthService>().currentUser?.role ?? AppConstants.roleStaff;

    final order = orderProvider.currentOrder;
    final itemCount  = order?.items.fold(0, (s, i) => s + i.quantity) ?? 0;
    final subtotal   = order?.subtotal ?? 0.0;
    final hasItems   = order != null && order.items.isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () {
            AppHaptics.light();
            Navigator.pop(context);
          },
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.translate('menu'),
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            Row(
              children: [
                const Icon(Icons.table_restaurant_rounded,
                    size: 12, color: AppColors.primary),
                const SizedBox(width: 4),
                Text(
                  widget.tableName,
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.primary),
                ),
              ],
            ),
          ],
        ),
        actions: [
          if (hasItems)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: IconButton(
                icon: const Icon(Icons.delete_sweep_rounded,
                    color: AppColors.error),
                onPressed: () {
                  AppHaptics.error();
                  _showCancelConfirm(context);
                },
                tooltip: 'Hủy đơn hàng',
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // ─── Search Bar ──────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppTheme.marginMobile, 10, AppTheme.marginMobile, 0),
            child: TextField(
              controller: _searchController,
              onChanged: (v) {
                AppHaptics.selection();
                setState(() => _searchKeyword = v);
              },
              decoration: InputDecoration(
                hintText: l10n.translate('search_menu'),
                prefixIcon:
                    const Icon(Icons.search_rounded, size: 20),
                suffixIcon: _searchKeyword.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchKeyword = '');
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                filled: true,
                fillColor: AppColors.surfaceContainerHigh.withAlpha(80),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          const SizedBox(height: 10),

          // ─── Category Chips ──────────────────────────────
          SizedBox(
            height: 40,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.marginMobile),
              itemCount: menuProvider.categories.length + 1,
              itemBuilder: (context, index) {
                final category = index == 0
                    ? MenuCategoryModel(
                        categoryId: 0,
                        name: l10n.translate('all'),
                        icon: '🍽️',
                        displayOrder: 0,
                        isActive: true)
                    : menuProvider.categories[index - 1];
                final isSelected =
                    _selectedCategoryId == category.categoryId;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () {
                      AppHaptics.selection();
                      setState(
                          () => _selectedCategoryId = category.categoryId);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.surfaceContainerLowest,
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusFull),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.outlineVariant,
                        ),
                      ),
                      child: Text(
                        '${category.icon} ${category.name}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isSelected
                              ? Colors.white
                              : AppColors.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 12),

          // ─── Menu Grid ───────────────────────────────────
          Expanded(
            child: menuProvider.isLoading
                ? const CardListShimmer(count: 6, cardHeight: 200)
                : _buildMenuGrid(menuProvider, orderProvider, l10n),
          ),

          // ─── Floating Mini Cart Bar ──────────────────────
          if (hasItems)
            _FloatingCartBar(
              itemCount: itemCount,
              subtotal: subtotal,
              formatCurrency: _formatCurrency,
              expanded: _cartExpanded,
              onToggle: () {
                AppHaptics.light();
                setState(() => _cartExpanded = !_cartExpanded);
              },
              order: order,
              orderProvider: orderProvider,
              userRole: userRole,
              tableName: widget.tableName,
              onCheckout: () {
                AppHaptics.heavy();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CheckoutScreen(order: order),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  // ─── Menu Grid builder ────────────────────────────────────
  Widget _buildMenuGrid(MenuProvider menuProvider,
      OrderProvider orderProvider, AppLocalizations l10n) {
    var items = menuProvider.getItemsByCategory(_selectedCategoryId);
    if (_searchKeyword.isNotEmpty) {
      final q = _searchKeyword.toLowerCase();
      items = items
          .where((i) =>
              i.name.toLowerCase().contains(q) ||
              (i.description?.toLowerCase().contains(q) ?? false))
          .toList();
    }

    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🔍',
                style: TextStyle(fontSize: 40)),
            const SizedBox(height: 12),
            Text(
              'Không tìm thấy món nào',
              style: TextStyle(
                  color: AppColors.onSurfaceVariant, fontSize: 15),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(
          AppTheme.marginMobile, 0, AppTheme.marginMobile, 100),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.73,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final orderItem = orderProvider.currentOrder?.items
            .where((oi) => oi.itemId == item.itemId)
            .firstOrNull;
        return _MenuItemCard(
          item: item,
          quantity: orderItem?.quantity ?? 0,
          onAdd: () => _handleAddItem(context, item, orderProvider),
          onRemove: orderItem != null
              ? () async {
                  AppHaptics.light();
                  final success = await orderProvider.updateItemQty(
                      orderItem.orderItemId, orderItem.quantity - 1);
                  if (success &&
                      orderProvider.currentOrder == null &&
                      context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text(
                              'Đơn hàng trống, bàn đã được giải phóng.')),
                    );
                    Navigator.pop(context);
                  }
                }
              : null,
          onLongPress: () => _showItemNoteSheet(context, item, orderProvider),
        );
      },
    );
  }

  // ─── Item Note / Modifier Bottom Sheet ───────────────────
  void _showItemNoteSheet(BuildContext context, MenuItemModel item,
      OrderProvider orderProvider) {
    AppHaptics.medium();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) =>
          _ItemModifierSheet(item: item, orderProvider: orderProvider),
    );
  }

  // ─── Cancel Confirm Dialog ────────────────────────────────
  void _showCancelConfirm(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusLg)),
        title: const Text('Hủy đơn hàng?'),
        content: const Text(
            'Tất cả món đã chọn sẽ bị xóa và bàn sẽ được giải phóng.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Bỏ qua'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            onPressed: () async {
              final op = context.read<OrderProvider>();
              final success = await op.cancelOrder();
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
              if (success && context.mounted) Navigator.pop(context);
            },
            child: const Text('Đồng ý hủy'),
          ),
        ],
      ),
    );
  }
}

// ─── Smart Menu Item Card ─────────────────────────────────────────
class _MenuItemCard extends StatelessWidget {
  final MenuItemModel item;
  final int quantity;
  final VoidCallback onAdd;
  final VoidCallback? onRemove;
  final VoidCallback? onLongPress;

  const _MenuItemCard({
    required this.item,
    required this.quantity,
    required this.onAdd,
    this.onRemove,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = quantity > 0;
    return GestureDetector(
      onLongPress: onLongPress,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          border: Border.all(
            color: isSelected
                ? AppColors.primary.withAlpha(120)
                : AppColors.outlineVariant.withAlpha(60),
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: isSelected
              ? AppTheme.shadowLevel2
              : AppTheme.shadowLevel1,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── Food Image ──────────────────────────
            Expanded(
              child: Stack(
                children: [
                  MenuItemImage(
                    imagePath: item.imagePath,
                    itemName: item.name,
                    emoji: item.emoji,
                    width: double.infinity,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(AppTheme.radiusLg - 1),
                    ),
                    emojiSize: 44,
                  ),
                  // Badge số lượng nổi trên ảnh
                  if (quantity > 0)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(
                              AppTheme.radiusFull),
                          boxShadow: AppTheme.shadowLevel2,
                        ),
                        child: Text(
                          'x$quantity',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  // Không có hàng badge
                  if (!item.isAvailable)
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withAlpha(100),
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(AppTheme.radiusLg - 1),
                        ),
                      ),
                      child: const Center(
                        child: Text(
                          'Hết hàng',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 13),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // ─── Info + Controls ──────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (item.description != null &&
                      item.description!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      item.description!,
                      style: TextStyle(
                          fontSize: 11,
                          color: AppColors.onSurfaceVariant),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _formatCurrency(item.price),
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary),
                      ),
                      // ── Qty Controls ───────────────
                      quantity == 0
                          ? _AddButton(
                              onTap: item.isAvailable ? onAdd : null)
                          : Row(
                              children: [
                                _QtyButton(
                                    icon: Icons.remove_rounded,
                                    onTap: onRemove),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8),
                                  child: Text('$quantity',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14)),
                                ),
                                _QtyButton(
                                    icon: Icons.add_rounded,
                                    onTap: item.isAvailable ? onAdd : null),
                              ],
                            ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatCurrency(double amount) {
    final formatted = amount.toInt().toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]}.',
    );
    return '${formatted}đ';
  }
}

// ─── Add Button ───────────────────────────────────────────────────
class _AddButton extends StatelessWidget {
  final VoidCallback? onTap;
  const _AddButton({this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: onTap != null ? AppColors.primary : AppColors.outlineVariant,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add_rounded, size: 14, color: Colors.white),
            SizedBox(width: 3),
            Text('Thêm',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white)),
          ],
        ),
      ),
    );
  }
}

// ─── Quantity Button ──────────────────────────────────────────────
class _QtyButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  const _QtyButton({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: AppColors.primary.withAlpha(20),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icon, size: 16, color: AppColors.primary),
      ),
    );
  }
}

// ─── Floating Cart Bar ────────────────────────────────────────────
class _FloatingCartBar extends StatelessWidget {
  final int itemCount;
  final double subtotal;
  final String Function(double) formatCurrency;
  final bool expanded;
  final VoidCallback onToggle;
  final dynamic order;
  final OrderProvider orderProvider;
  final VoidCallback onCheckout;
  final int userRole;
  final String tableName;

  const _FloatingCartBar({
    required this.itemCount,
    required this.subtotal,
    required this.formatCurrency,
    required this.expanded,
    required this.onToggle,
    required this.order,
    required this.orderProvider,
    required this.onCheckout,
    required this.userRole,
    required this.tableName,
  });

  @override
  Widget build(BuildContext context) {
    final isStaff = userRole == AppConstants.roleStaff;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: expanded
            ? const BorderRadius.vertical(
                top: Radius.circular(AppTheme.radiusXl))
            : BorderRadius.zero,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(30),
            blurRadius: 16,
            offset: const Offset(0, -4),
          )
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Drag handle ───────────────────────────
            if (expanded)
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 10, bottom: 4),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

            // ── Cart summary row ──────────────────────
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  // Cart icon + badge
                  GestureDetector(
                    onTap: onToggle,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withAlpha(15),
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusMd),
                          ),
                          child: const Icon(Icons.shopping_cart_rounded,
                              color: AppColors.primary, size: 22),
                        ),
                        Positioned(
                          top: -6,
                          right: -6,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              '$itemCount',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Subtotal info
                  Expanded(
                    child: GestureDetector(
                      onTap: onToggle,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$itemCount món',
                            style: TextStyle(
                                fontSize: 12,
                                color: AppColors.onSurfaceVariant),
                          ),
                          Text(
                            formatCurrency(subtotal),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Action buttons
                  if (isStaff) ...[
                    // Nút phụ: Báo tính tiền
                    OutlinedButton.icon(
                      onPressed: () async {
                        AppHaptics.medium();
                        await orderProvider.requestPaymentForCurrentOrder();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('💳 Đã báo quầy tính tiền cho $tableName'),
                              backgroundColor: AppColors.primary,
                              duration: const Duration(seconds: 2),
                            ),
                          );
                          Navigator.pop(context);
                        }
                      },
                      icon: const Icon(Icons.point_of_sale_rounded, size: 16),
                      label: const Text('Báo bill',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
                      ),
                    ),
                    const SizedBox(width: 6),
                    // Nút chính: Xác nhận & Gửi Bếp
                    ElevatedButton.icon(
                      onPressed: () async {
                        AppHaptics.heavy();
                        await orderProvider.sendToKitchen();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('✅ Đã gửi thực đơn $tableName xuống Bếp!'),
                              backgroundColor: AppColors.success,
                              duration: const Duration(seconds: 2),
                            ),
                          );
                          Navigator.pop(context);
                        }
                      },
                      icon: const Icon(Icons.soup_kitchen_rounded, size: 16),
                      label: const Text('Gửi Bếp',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
                        elevation: 0,
                      ),
                    ),
                  ] else ...[
                    // Nút chính cho Thu ngân / Quản lý: Thanh toán ngay
                    ElevatedButton.icon(
                      onPressed: onCheckout,
                      icon: const Icon(Icons.receipt_long_rounded, size: 18),
                      label: const Text('Thanh toán ngay',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusMd)),
                        elevation: 0,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // ── Expanded Cart Item List ───────────────
            if (expanded && order != null)
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 280),
                child: ListView.separated(
                  shrinkWrap: true,
                  padding:
                      const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  itemCount: order.items.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final item = order.items[index];
                    return Padding(
                      padding:
                          const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.itemName,
                                  style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500),
                                ),
                                if (AiTracker.isItemDone(item.note)) ...[
                                  const SizedBox(height: 2),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFDCFCE7),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      '✅ Bếp đã lên món',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF15803D),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          // Decrease
                          GestureDetector(
                            onTap: () {
                              AppHaptics.light();
                              orderProvider.updateItemQty(
                                  item.orderItemId, item.quantity - 1);
                            },
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceContainerHigh,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Icon(Icons.remove_rounded,
                                  size: 16,
                                  color: AppColors.onSurfaceVariant),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10),
                            child: Text(
                              '${item.quantity}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14),
                            ),
                          ),
                          // Increase
                          GestureDetector(
                            onTap: () {
                              AppHaptics.medium();
                              orderProvider.updateItemQty(
                                  item.orderItemId, item.quantity + 1);
                            },
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withAlpha(20),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Icon(Icons.add_rounded,
                                  size: 16, color: AppColors.primary),
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Line total
                          Text(
                            _fmtCurrency(item.price * item.quantity),
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _fmtCurrency(double amount) {
    final f = amount.toInt().toString().replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.');
    return '${f}đ';
  }
}

// ─── Item Modifier / Note Bottom Sheet ───────────────────────────
class _ItemModifierSheet extends StatefulWidget {
  final MenuItemModel item;
  final OrderProvider orderProvider;
  const _ItemModifierSheet(
      {required this.item, required this.orderProvider});

  @override
  State<_ItemModifierSheet> createState() => _ItemModifierSheetState();
}

class _ItemModifierSheetState extends State<_ItemModifierSheet> {
  int _qty = 1;
  int _spiceLevel = 0;    // 0=Bình thường, 1=Ít cay, 2=Cay vừa, 3=Cay nhiều
  int _iceLevel = 2;      // 0=Không đá, 1=Ít đá, 2=Đá thường, 3=Nhiều đá
  int _sugarLevel = 2;    // 0=Không đường, 1=Ít ngọt, 2=Bình thường, 3=Ngọt nhiều
  final _noteCtrl = TextEditingController();

  static const _spiceLabels = ['Bình thường', 'Ít cay', 'Cay vừa', 'Cay nhiều'];
  static const _iceLabels   = ['Không đá', 'Ít đá', 'Đá bình thường', 'Nhiều đá'];
  static const _sugarLabels = ['Không đường', 'Ít ngọt', 'Bình thường', 'Ngọt nhiều'];

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  bool get _isFood => !widget.item.name.toLowerCase().contains('nước')
      && !widget.item.name.toLowerCase().contains('cà phê')
      && !widget.item.name.toLowerCase().contains('trà')
      && !widget.item.name.toLowerCase().contains('sinh tố')
      && !widget.item.name.toLowerCase().contains('nha đam');

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
            20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ───────────────────────────────
            Row(
              children: [
                Text(widget.item.emoji,
                    style: const TextStyle(fontSize: 32)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.item.name,
                          style: const TextStyle(
                              fontSize: 17, fontWeight: FontWeight.w700)),
                      Text(
                        _fmtCurrency(widget.item.price * _qty),
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),
            const Divider(height: 1),
            const SizedBox(height: 16),

            // ── Quantity selector ─────────────────────
            _buildSectionTitle('Số lượng'),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _LargeQtyButton(
                  icon: Icons.remove_rounded,
                  onTap: _qty > 1
                      ? () {
                          AppHaptics.light();
                          setState(() => _qty--);
                        }
                      : null,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Text(
                    '$_qty',
                    style: const TextStyle(
                        fontSize: 26, fontWeight: FontWeight.w700),
                  ),
                ),
                _LargeQtyButton(
                  icon: Icons.add_rounded,
                  onTap: () {
                    AppHaptics.light();
                    setState(() => _qty++);
                  },
                ),
              ],
            ),

            // ── Modifiers (spice / ice / sugar) ──────
            if (_isFood) ...[
              const SizedBox(height: 20),
              _buildSectionTitle('Mức độ cay'),
              const SizedBox(height: 8),
              _buildSegmentControl(
                  _spiceLabels, _spiceLevel,
                  (i) => setState(() => _spiceLevel = i)),
            ] else ...[
              const SizedBox(height: 20),
              _buildSectionTitle('Lượng đá'),
              const SizedBox(height: 8),
              _buildSegmentControl(
                  _iceLabels, _iceLevel,
                  (i) => setState(() => _iceLevel = i)),
              const SizedBox(height: 14),
              _buildSectionTitle('Mức đường'),
              const SizedBox(height: 8),
              _buildSegmentControl(
                  _sugarLabels, _sugarLevel,
                  (i) => setState(() => _sugarLevel = i)),
            ],

            // ── Kitchen Note ──────────────────────────
            const SizedBox(height: 18),
            _buildSectionTitle('Ghi chú cho bếp (tùy chọn)'),
            const SizedBox(height: 8),
            TextField(
              controller: _noteCtrl,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'Vd: Không hành, dị ứng đậu phộng...',
                filled: true,
                fillColor: AppColors.surfaceContainerHigh.withAlpha(60),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),

            const SizedBox(height: 20),

            // ── Confirm button ────────────────────────
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  AppHaptics.heavy();
                  Navigator.pop(context);
                  String composedNote = '';
                  if (_isFood) {
                    composedNote = _spiceLabels[_spiceLevel];
                  } else {
                    composedNote = '${_iceLabels[_iceLevel]}, ${_sugarLabels[_sugarLevel]}';
                  }
                  if (_noteCtrl.text.trim().isNotEmpty) {
                    composedNote += (composedNote.isNotEmpty ? ' - ' : '') + _noteCtrl.text.trim();
                  }
                  await widget.orderProvider.addItem(
                    widget.item.itemId,
                    _qty,
                    note: composedNote.isNotEmpty ? composedNote : null,
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(AppTheme.radiusMd),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  'Thêm $_qty món — ${_fmtCurrency(widget.item.price * _qty)}',
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) => Text(
        title,
        style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.onSurfaceVariant),
      );

  Widget _buildSegmentControl(
      List<String> labels, int selected, ValueChanged<int> onSelect) {
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: List.generate(labels.length, (i) {
        final isSelected = selected == i;
        return GestureDetector(
          onTap: () {
            AppHaptics.selection();
            onSelect(i);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primary : AppColors.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(AppTheme.radiusFull),
              border: Border.all(
                  color: isSelected
                      ? AppColors.primary
                      : AppColors.outlineVariant),
            ),
            child: Text(
              labels[i],
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : AppColors.onSurfaceVariant,
              ),
            ),
          ),
        );
      }),
    );
  }

  String _fmtCurrency(double amount) {
    final f = amount.toInt().toString().replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.');
    return '${f}đ';
  }
}

// ─── Large Qty Button (used in modifier sheet) ────────────────────
class _LargeQtyButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  const _LargeQtyButton({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: onTap != null
              ? AppColors.primary.withAlpha(20)
              : AppColors.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(
              color: onTap != null
                  ? AppColors.primary.withAlpha(80)
                  : AppColors.outlineVariant),
        ),
        child: Icon(
          icon,
          size: 24,
          color: onTap != null
              ? AppColors.primary
              : AppColors.outlineVariant,
        ),
      ),
    );
  }
}
