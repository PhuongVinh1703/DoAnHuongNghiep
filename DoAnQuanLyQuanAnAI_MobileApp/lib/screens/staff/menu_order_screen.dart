import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:doanquanlyquananai_mobileapp/theme/app_colors.dart';
import 'package:doanquanlyquananai_mobileapp/theme/app_theme.dart';
import 'package:doanquanlyquananai_mobileapp/services/menu_provider.dart';
import 'package:doanquanlyquananai_mobileapp/services/order_provider.dart';
import 'package:doanquanlyquananai_mobileapp/models/menu/menu_item.dart';
import 'package:doanquanlyquananai_mobileapp/models/menu/menu_category.dart';
import 'package:doanquanlyquananai_mobileapp/l10n/app_localizations.dart';
import 'package:doanquanlyquananai_mobileapp/screens/staff/checkout_screen.dart';

class MenuOrderScreen extends StatefulWidget {
  final String tableName;
  const MenuOrderScreen({super.key, required this.tableName});

  @override
  State<MenuOrderScreen> createState() => _MenuOrderScreenState();
}

class _MenuOrderScreenState extends State<MenuOrderScreen> {
  int _selectedCategoryId = 0;
  final TextEditingController _searchController = TextEditingController();
  String _searchKeyword = '';

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
      (Match m) => '${m[1]}.',
    );
    return '$formatted' 'đ';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final orderProvider = context.watch<OrderProvider>();
    final menuProvider = context.watch<MenuProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.translate('menu')),
            Text(
              '${l10n.translate('table')}: ${widget.tableName}',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
            ),
          ],
        ),
        actions: [
          if (orderProvider.currentOrder != null && orderProvider.currentOrder!.items.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_rounded, color: AppColors.error),
              onPressed: () => _showCancelConfirm(context),
              tooltip: 'Hủy đơn hàng',
            ),
        ],
      ),
      body: Column(
        children: [
          // ─── Search Bar ──────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(AppTheme.marginMobile, 8, AppTheme.marginMobile, 12),
            child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _searchKeyword = value),
              decoration: InputDecoration(
                hintText: l10n.translate('search_menu'),
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _searchKeyword.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 20),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchKeyword = '');
                        },
                      )
                    : null,
              ),
            ),
          ),

          // ─── Categories ──────────────────────────────
          SizedBox(
            height: 44,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppTheme.marginMobile),
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

                final isSelected = _selectedCategoryId == category.categoryId;

                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text('${category.icon} ${category.name}'),
                    selected: isSelected,
                    onSelected: (_) => setState(() => _selectedCategoryId = category.categoryId),
                    selectedColor: AppColors.primary,
                    backgroundColor: AppColors.surfaceContainerLowest,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : AppColors.onSurfaceVariant,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                      fontSize: 13,
                    ),
                    side: BorderSide(
                      color: isSelected ? AppColors.primary : AppColors.outlineVariant,
                    ),
                    shape: const StadiumBorder(),
                    showCheckmark: false,
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 12),

          // ─── Menu Grid ───────────────────────────────
          Expanded(
            child: menuProvider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildMenuGrid(menuProvider, orderProvider),
          ),

          // ─── Bottom Order Panel ─────────────────────
          if (orderProvider.currentOrder != null && orderProvider.currentOrder!.items.isNotEmpty)
            _buildBottomOrderPanel(orderProvider),
        ],
      ),
    );
  }

  Widget _buildMenuGrid(MenuProvider menuProvider, OrderProvider orderProvider) {
    var items = menuProvider.getItemsByCategory(_selectedCategoryId);
    if (_searchKeyword.isNotEmpty) {
      items = items
          .where((i) => i.name.toLowerCase().contains(_searchKeyword.toLowerCase()))
          .toList();
    }

    if (items.isEmpty) {
      return const Center(child: Text('Không tìm thấy món nào'));
    }

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(AppTheme.marginMobile, 0, AppTheme.marginMobile, 16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.75,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final orderItem = orderProvider.currentOrder?.items.where((oi) => oi.itemId == item.itemId).firstOrNull;

        return _MenuItemCard(
          item: item,
          quantity: orderItem?.quantity ?? 0,
          onAdd: () => orderProvider.addItem(item.itemId, 1),
          onRemove: orderItem != null
              ? () async {
                  final success = await orderProvider.updateItemQty(orderItem.orderItemId, orderItem.quantity - 1);
                  if (success && orderProvider.currentOrder == null) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Đơn hàng trống, bàn đã được giải phóng.')),
                      );
                      Navigator.pop(context);
                    }
                  }
                }
              : null,
        );
      },
    );
  }

  Widget _buildBottomOrderPanel(OrderProvider orderProvider) {
    final order = orderProvider.currentOrder!;
    final itemCount = order.items.fold(0, (sum, i) => sum + i.quantity);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(20),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$itemCount items',
                      style: const TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant),
                    ),
                    Text(
                      _formatCurrency(order.subtotal),
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.primary),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CheckoutScreen(order: order),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Row(
                  children: [
                    Text('Tiếp tục', style: TextStyle(fontWeight: FontWeight.w600)),
                    SizedBox(width: 8),
                    Icon(Icons.arrow_forward_rounded, size: 18),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCancelConfirm(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hủy đơn hàng?'),
        content: const Text('Tất cả món đã chọn sẽ bị xóa và bàn sẽ được giải phóng.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Bỏ qua'),
          ),
          TextButton(
            onPressed: () async {
              final orderProvider = context.read<OrderProvider>();
              final success = await orderProvider.cancelOrder();
              if (!context.mounted) return;
              Navigator.pop(context);
              if (success) {
                Navigator.pop(context); // Go back to tables screen
              }
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Đồng ý hủy'),
          ),
        ],
      ),
    );
  }
}

class _MenuItemCard extends StatelessWidget {
  final MenuItemModel item;
  final int quantity;
  final VoidCallback onAdd;
  final VoidCallback? onRemove;

  const _MenuItemCard({
    required this.item,
    required this.quantity,
    required this.onAdd,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(
          color: quantity > 0 ? AppColors.primary.withAlpha(100) : AppColors.outlineVariant.withAlpha(60),
          width: quantity > 0 ? 1.5 : 1,
        ),
        boxShadow: AppTheme.shadowLevel1,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── Image ─────────────────────────────
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.surfaceContainer,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(AppTheme.radiusLg - 1)),
              ),
              child: Center(
                child: Text(
                  item.emoji.isNotEmpty ? item.emoji : '🍽️',
                  style: const TextStyle(fontSize: 48),
                ),
              ),
            ),
          ),

          // ─── Info ──────────────────────────────
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '${item.price.toInt()}đ',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primary),
                ),
                const SizedBox(height: 8),
                
                // ─── Controls ──────────────────────────
                if (quantity == 0)
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: onAdd,
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.zero,
                        side: const BorderSide(color: AppColors.primary),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('Thêm', style: TextStyle(fontSize: 12)),
                    ),
                  )
                else
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _QtyButton(icon: Icons.remove_rounded, onTap: onRemove),
                      Text(
                        '$quantity',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                      ),
                      _QtyButton(icon: Icons.add_rounded, onTap: onAdd),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

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
        child: Icon(icon, size: 18, color: AppColors.primary),
      ),
    );
  }
}
