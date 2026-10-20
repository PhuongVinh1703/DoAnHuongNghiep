import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:doanquanlyquananai_mobileapp/theme/app_colors.dart';
import 'package:doanquanlyquananai_mobileapp/theme/app_theme.dart';
import 'package:doanquanlyquananai_mobileapp/widgets/common/menu_item_image.dart';
import 'package:doanquanlyquananai_mobileapp/services/menu_provider.dart';
import 'package:doanquanlyquananai_mobileapp/models/menu/menu_item.dart';
import 'package:doanquanlyquananai_mobileapp/core/utils/money_formatter.dart';
import 'package:doanquanlyquananai_mobileapp/widgets/customer/simulated_payment_sheet.dart';
import 'package:doanquanlyquananai_mobileapp/widgets/common/app_snackbar.dart';

class PreOrderScreen extends StatefulWidget {
  final String customerName;
  final String customerPhone;

  const PreOrderScreen({
    super.key,
    required this.customerName,
    required this.customerPhone,
  });

  @override
  State<PreOrderScreen> createState() => _PreOrderScreenState();
}

class _PreOrderScreenState extends State<PreOrderScreen> {
  final Map<MenuItemModel, int> _selectedItems = {};
  int _selectedCategoryId = 0; // 0 = All
  String _searchQuery = '';
  int _depositType = 1; // 0: No deposit, 1: Flat 100k, 2: 30% Order value
  String _paymentMethod = 'VietQR'; // 'VietQR', 'MoMo', 'ZaloPay', 'Apple Pay'

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MenuProvider>().loadMenuData();
    });
  }

  double get _orderSubtotal {
    double total = 0;
    _selectedItems.forEach((item, qty) {
      total += item.price * qty;
    });
    return total;
  }

  double get _depositAmount {
    if (_depositType == 0) return 0;
    if (_depositType == 1) return 100000;
    return _orderSubtotal * 0.3;
  }

  void _adjustQty(MenuItemModel item, int delta) {
    setState(() {
      final current = _selectedItems[item] ?? 0;
      final newQty = current + delta;
      if (newQty <= 0) {
        _selectedItems.remove(item);
      } else {
        _selectedItems[item] = newQty;
      }
      
      // Auto switch deposit type to 30% if items are selected and was on "no deposit"
      if (_selectedItems.isNotEmpty && _depositType == 0) {
        _depositType = 2; 
      } else if (_selectedItems.isEmpty && _depositType == 2) {
        _depositType = 1; // Default back to flat 100k
      }
    });
  }

  void _showCheckoutOptions() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          final double deposit = _depositAmount;

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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Thông tin đặt cọc & Thanh toán',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                const SizedBox(height: 16),

                // Selected items recap
                if (_selectedItems.isNotEmpty) ...[
                  const Text('Món ăn đã chọn:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  const SizedBox(height: 8),
                  Container(
                    constraints: const BoxConstraints(maxHeight: 120),
                    child: ListView(
                      shrinkWrap: true,
                      children: _selectedItems.entries.map((e) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Text('${e.key.emoji} ', style: const TextStyle(fontSize: 16)),
                              Expanded(child: Text(e.key.name, style: const TextStyle(fontSize: 13))),
                              Text('x${e.value}  ', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                              Text(MoneyFormatter.format(e.key.price * e.value), style: const TextStyle(fontSize: 13)),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const Divider(height: 20),
                ],

                // Deposit choices
                const Text('Lựa chọn đặt cọc giữ chỗ:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (_selectedItems.isEmpty)
                      Expanded(
                        child: _buildDepositOption(
                          label: 'Không đặt cọc',
                          subLabel: 'Chỉ đặt bàn',
                          value: 0,
                          currentValue: _depositType,
                          onTap: () => setSheetState(() => _depositType = 0),
                        ),
                      ),
                    Expanded(
                      child: _buildDepositOption(
                        label: 'Cọc 100k',
                        subLabel: 'Cố định giữ bàn',
                        value: 1,
                        currentValue: _depositType,
                        onTap: () => setSheetState(() => _depositType = 1),
                      ),
                    ),
                    if (_selectedItems.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildDepositOption(
                          label: 'Cọc 30%',
                          subLabel: 'Theo thực đơn',
                          value: 2,
                          currentValue: _depositType,
                          onTap: () => setSheetState(() => _depositType = 2),
                        ),
                      ),
                    ]
                  ],
                ),
                const SizedBox(height: 20),

                // Payment Method Selector
                const Text('Phương thức thanh toán cọc:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 10),
                _buildPaymentMethodTile(
                  title: 'Chuyển khoản VietQR (VietinBank)',
                  subtitle: 'TRAN PHUONG VINH - 108876927706',
                  value: 'VietQR',
                  icon: Icons.qr_code_2_rounded,
                  color: Colors.blue[800]!,
                  setSheetState: setSheetState,
                ),
                _buildPaymentMethodTile(
                  title: 'Ví điện tử MoMo',
                  subtitle: 'Ví MoMo điện thoại liên kết',
                  value: 'MoMo',
                  icon: Icons.wallet_rounded,
                  color: const Color(0xFFA50064),
                  setSheetState: setSheetState,
                ),
                _buildPaymentMethodTile(
                  title: 'Ví điện tử ZaloPay',
                  subtitle: 'ZaloPay quét mã QR/Ví',
                  value: 'ZaloPay',
                  icon: Icons.account_balance_wallet_rounded,
                  color: const Color(0xFF0068FF),
                  setSheetState: setSheetState,
                ),
                _buildPaymentMethodTile(
                  title: 'Apple Pay',
                  subtitle: 'Thanh toán bảo mật FaceID',
                  value: 'Apple Pay',
                  icon: Icons.apple_rounded,
                  color: Colors.black,
                  setSheetState: setSheetState,
                ),
                const SizedBox(height: 24),

                // Amount info and submit
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Số tiền cần đặt cọc', style: TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant)),
                        Text(
                          MoneyFormatter.format(deposit),
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.primary),
                        ),
                      ],
                    ),
                    FilledButton(
                      onPressed: () {
                        Navigator.pop(context); // Close sheet
                        _executePaymentFlow(deposit);
                      },
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      ),
                      child: Text(
                        deposit > 0 ? 'Thanh toán cọc' : 'Xác nhận đặt bàn',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDepositOption({
    required String label,
    required String subLabel,
    required int value,
    required int currentValue,
    required VoidCallback onTap,
  }) {
    final isSelected = value == currentValue;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withAlpha(15) : AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.outlineVariant,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Text(label, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isSelected ? AppColors.primary : AppColors.onSurface)),
            const SizedBox(height: 2),
            Text(subLabel, style: const TextStyle(fontSize: 10, color: AppColors.onSurfaceVariant), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentMethodTile({
    required String title,
    required String subtitle,
    required String value,
    required IconData icon,
    required Color color,
    required StateSetter setSheetState,
  }) {
    final isSelected = _paymentMethod == value;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        onTap: () => setSheetState(() => _paymentMethod = value),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.surfaceContainerHigh : AppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? AppColors.primary : AppColors.outlineVariant.withAlpha(80),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: color.withAlpha(20), shape: BoxShape.circle),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    Text(subtitle, style: const TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant)),
                  ],
                ),
              ),
              // ignore: deprecated_member_use
              Radio<String>(
                value: value,
                // ignore: deprecated_member_use
                groupValue: _paymentMethod,
                activeColor: AppColors.primary,
                // ignore: deprecated_member_use
                onChanged: (v) => setSheetState(() => _paymentMethod = v!),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _executePaymentFlow(double depositAmount) {
    if (depositAmount == 0) {
      // Just finish booking without deposit
      _finishPreOrderFlow(depositStatus: 'Không cọc');
      return;
    }

    final String info = 'RR PREORDER ${widget.customerPhone}';

    SimulatedPaymentSheet.show(
      context,
      amount: depositAmount,
      paymentMethod: _paymentMethod,
      addInfo: info,
      onSuccess: () {
        _finishPreOrderFlow(
          depositStatus: 'Đã cọc ${MoneyFormatter.format(depositAmount)} qua $_paymentMethod',
        );
      },
      onCancel: () {
        AppSnackbar.showWarning(context, 'Thanh toán cọc đã bị hủy');
      },
    );
  }

  void _finishPreOrderFlow({required String depositStatus}) {
    // Generate structured note string
    String finalNote = '';
    if (_selectedItems.isNotEmpty) {
      final itemsStr = _selectedItems.entries.map((e) => '${e.value}x ${e.key.name}').join(', ');
      finalNote = '[Pre-order: $itemsStr. Trạng thái: $depositStatus]';
    } else {
      finalNote = '[Trạng thái: $depositStatus]';
    }

    Navigator.pop(context, finalNote);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Thực đơn đặt trước'),
        actions: [
          TextButton(
            onPressed: () {
              // Just return empty pre-order, booking screen note will remain original
              Navigator.pop(context, '');
            },
            child: const Text('Bỏ qua', style: TextStyle(fontWeight: FontWeight.bold)),
          )
        ],
      ),
      body: Consumer<MenuProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.errorMessage != null) {
            return Center(child: Text(provider.errorMessage!));
          }

          // Filter categories
          final categories = [
            MenuItemModel(
              itemId: 0,
              categoryId: 0,
              name: 'Tất cả',
              price: 0,
              emoji: '🍽️',
              isAvailable: true,
              categoryName: 'Tất cả',
            ),
            ...provider.categories.map((c) => MenuItemModel(
                  itemId: 0,
                  categoryId: c.categoryId,
                  name: c.name,
                  price: 0,
                  emoji: c.icon.isNotEmpty ? c.icon : '🍔',
                  isAvailable: true,
                  categoryName: c.name,
                ))
          ];

          // Filter items
          var items = provider.items;
          if (_selectedCategoryId != 0) {
            items = items.where((i) => i.categoryId == _selectedCategoryId).toList();
          }
          if (_searchQuery.isNotEmpty) {
            items = items
                .where((i) => i.name.toLowerCase().contains(_searchQuery.toLowerCase()))
                .toList();
          }

          return Column(
            children: [
              // Search & Categories
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: TextField(
                  onChanged: (v) => setState(() => _searchQuery = v),
                  decoration: InputDecoration(
                    hintText: 'Tìm kiếm món ăn...',
                    prefixIcon: const Icon(Icons.search_rounded),
                    filled: true,
                    fillColor: AppColors.surfaceContainerLowest,
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.outlineVariant),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.outlineVariant),
                    ),
                  ),
                ),
              ),

              // Categories Row
              SizedBox(
                height: 44,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: categories.length,
                  itemBuilder: (context, index) {
                    final cat = categories[index];
                    final isSelected = _selectedCategoryId == cat.categoryId;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(cat.name),
                        selected: isSelected,
                        onSelected: (selected) {
                          setState(() {
                            _selectedCategoryId = cat.categoryId;
                          });
                        },
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),

              // Menu Items List
              Expanded(
                child: items.isEmpty
                    ? const Center(child: Text('Không tìm thấy món ăn nào.'))
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        itemCount: items.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final item = items[index];
                          final qty = _selectedItems[item] ?? 0;

                          return Container(
                            decoration: BoxDecoration(
                              color: AppColors.surfaceContainerLowest,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppColors.outlineVariant.withAlpha(50)),
                              boxShadow: AppTheme.shadowLevel1,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  // Hình ảnh món ăn thực tế
                                  MenuItemImage(
                                    imagePath: item.imagePath,
                                    itemName: item.name,
                                    emoji: item.emoji,
                                    width: 68,
                                    height: 68,
                                    borderRadius: BorderRadius.circular(10),
                                    emojiSize: 30,
                                  ),
                                  const SizedBox(width: 14),

                                  // Name & Details
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.name,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold, fontSize: 14),
                                        ),
                                        if (item.description != null &&
                                            item.description!.isNotEmpty) ...[
                                          const SizedBox(height: 2),
                                          Text(
                                            item.description!,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                                fontSize: 11, color: AppColors.onSurfaceVariant),
                                          ),
                                        ],
                                        const SizedBox(height: 6),
                                        Text(
                                          MoneyFormatter.format(item.price),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 13,
                                            color: AppColors.primary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Stepper to select quantity
                                  Row(
                                    children: [
                                      if (qty > 0) ...[
                                        IconButton(
                                          icon: const Icon(Icons.remove_circle_outline_rounded,
                                              color: AppColors.onSurfaceVariant),
                                          onPressed: () => _adjustQty(item, -1),
                                        ),
                                        Text(
                                          '$qty',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold, fontSize: 14),
                                        ),
                                      ],
                                      IconButton(
                                        icon: const Icon(Icons.add_circle_outline_rounded,
                                            color: AppColors.primary),
                                        onPressed: () => _adjustQty(item, 1),
                                      ),
                                    ],
                                  )
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),

              // Bottom Total Summary Bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLowest,
                  boxShadow: AppTheme.shadowLevel2,
                  border: const Border(top: BorderSide(color: AppColors.outlineVariant)),
                ),
                child: SafeArea(
                  child: Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _selectedItems.isEmpty
                                ? 'Chưa chọn món'
                                : 'Đã chọn ${_selectedItems.values.reduce((a, b) => a + b)} món',
                            style: const TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant),
                          ),
                          Text(
                            MoneyFormatter.format(_orderSubtotal),
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const Spacer(),
                      FilledButton(
                        onPressed: _showCheckoutOptions,
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                        ),
                        child: const Row(
                          children: [
                            Text('Tiếp tục ', style: TextStyle(fontWeight: FontWeight.bold)),
                            Icon(Icons.arrow_forward_rounded, size: 16),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
