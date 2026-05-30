import 'package:flutter/material.dart';
import 'package:doanquanlyquananai_mobileapp/core/constants/app_colors.dart';
import 'package:doanquanlyquananai_mobileapp/models/menu/menu_item.dart';
import 'package:doanquanlyquananai_mobileapp/models/menu/menu_category.dart';
import 'package:doanquanlyquananai_mobileapp/services/menu_service.dart';
import 'package:doanquanlyquananai_mobileapp/core/utils/money_formatter.dart';
import 'package:doanquanlyquananai_mobileapp/widgets/common/app_snackbar.dart';
import 'package:doanquanlyquananai_mobileapp/widgets/common/loading_overlay.dart';

class MenuAvailabilityScreen extends StatefulWidget {
  const MenuAvailabilityScreen({super.key});

  @override
  State<MenuAvailabilityScreen> createState() => _MenuAvailabilityScreenState();
}

class _MenuAvailabilityScreenState extends State<MenuAvailabilityScreen> {
  final _svc = MenuService();

  List<MenuCategoryModel> _categories = [];
  List<MenuItemModel> _items = [];
  int _selectedCategoryId = 0;
  bool _isLoading = true;
  final Map<int, bool> _toggling = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final catResult  = await _svc.getAllCategories();
    final itemResult = await _svc.getAllItems();
    setState(() {
      _isLoading = false;
      _categories = catResult.data ?? [];
      _items      = itemResult.data ?? [];
    });
  }

  List<MenuItemModel> get _filtered {
    if (_selectedCategoryId == 0) return _items;
    return _items.where((i) => i.categoryId == _selectedCategoryId).toList();
  }

  Future<void> _toggle(MenuItemModel item) async {
    setState(() => _toggling[item.itemId] = true);
    final result = await _svc.toggleAvailability(item.itemId, !item.isAvailable);
    setState(() {
      _toggling[item.itemId] = false;
      if (result.isSuccess) {
        final idx = _items.indexWhere((i) => i.itemId == item.itemId);
        if (idx >= 0) {
          _items[idx] = MenuItemModel(
            itemId: item.itemId,
            categoryId: item.categoryId,
            categoryName: item.categoryName,
            name: item.name,
            description: item.description,
            price: item.price,
            isAvailable: !item.isAvailable,
            imagePath: item.imagePath,
            emoji: item.emoji,
          );
        }
      }
    });
    result.fold(
      onSuccess: (_) => AppSnackbar.showSuccess(
        context, '${item.name}: ${!item.isAvailable ? "Đang bán" : "Tạm ngừng"}',
      ),
      onFailure: (e) => AppSnackbar.showError(context, e),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(
      title: const Text('Quản Lý Thực Đơn'),
      backgroundColor: Colors.white,
      foregroundColor: AppColors.textPrimary,
      elevation: 0,
      actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData)],
    ),
    floatingActionButton: FloatingActionButton(
      onPressed: () => _showMenuForm(null),
      backgroundColor: AppColors.primary,
      child: const Icon(Icons.add, color: Colors.white),
    ),
    body: LoadingOverlay(
      isLoading: _isLoading,
      child: Column(children: [
        // Category filter chips
        Container(
          height: 50,
          color: Colors.white,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            children: [
              _chip('Tất cả', 0),
              ..._categories.map((c) => _chip(c.name, c.categoryId)),
            ],
          ),
        ),
        // Items list
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadData,
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _filtered.length,
              itemBuilder: (_, i) => _itemTile(_filtered[i]),
            ),
          ),
        ),
      ]),
    ),
  );

  Widget _chip(String label, int id) => GestureDetector(
    onTap: () => setState(() => _selectedCategoryId = id),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: _selectedCategoryId == id ? AppColors.primary : Colors.grey[100],
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: _selectedCategoryId == id ? Colors.white : AppColors.textSecondary,
        ),
      ),
    ),
  );

  Widget _itemTile(MenuItemModel item) {
    final isToggling = _toggling[item.itemId] == true;
    return GestureDetector(
      onTap: () => _showMenuForm(item),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: item.isAvailable
                ? AppColors.success.withValues(alpha: 0.3)
                : AppColors.error.withValues(alpha: 0.2),
          ),
        ),
        child: ListTile(
          leading: Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                item.emoji.isNotEmpty ? item.emoji : '🍽️',
                style: const TextStyle(fontSize: 22),
              ),
            ),
          ),
          title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text(
            MoneyFormatter.format(item.price),
            style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
          ),
          trailing: isToggling
              ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
              : Switch.adaptive(
                  value: item.isAvailable,
                  onChanged: (_) => _toggle(item),
                ),
        ),
      ),
    );
  }

  void _showMenuForm(MenuItemModel? item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _MenuFormSheet(
        item: item,
        categories: _categories,
        onSaved: _loadData,
        menuService: _svc,
      ),
    );
  }
}

class _MenuFormSheet extends StatefulWidget {
  final MenuItemModel? item;
  final List<MenuCategoryModel> categories;
  final VoidCallback onSaved;
  final MenuService menuService;

  const _MenuFormSheet({this.item, required this.categories, required this.onSaved, required this.menuService});

  @override
  State<_MenuFormSheet> createState() => _MenuFormSheetState();
}

class _MenuFormSheetState extends State<_MenuFormSheet> {
  final _nameCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _emojiCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  int? _catId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.item != null) {
      _nameCtrl.text = widget.item!.name;
      _priceCtrl.text = widget.item!.price.toString();
      _emojiCtrl.text = widget.item!.emoji;
      _descCtrl.text = widget.item!.description ?? '';
      _catId = widget.item!.categoryId;
    } else if (widget.categories.isNotEmpty) {
      _catId = widget.categories.first.categoryId;
    }
  }

  Future<void> _save() async {
    if (_nameCtrl.text.isEmpty || _priceCtrl.text.isEmpty || _catId == null) return;
    setState(() => _saving = true);
    
    final data = {
      'name': _nameCtrl.text,
      'price': double.tryParse(_priceCtrl.text) ?? 0,
      'emoji': _emojiCtrl.text,
      'description': _descCtrl.text,
      'categoryId': _catId,
      'isAvailable': widget.item?.isAvailable ?? true,
    };

    final isUpdate = widget.item != null;
    final res = isUpdate 
        ? await widget.menuService.updateMenuItem(widget.item!.itemId, data)
        : await widget.menuService.createMenuItem(data);

    setState(() => _saving = false);
    if (res.isSuccess) {
      if (mounted) Navigator.pop(context);
      widget.onSaved();
    } else {
      if (mounted) AppSnackbar.showError(context, res.error!);
    }
  }

  Future<void> _delete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: Text('Xóa món ${widget.item!.name}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Xóa')),
        ],
      )
    );
    if (confirm != true) return;

    setState(() => _saving = true);
    final res = await widget.menuService.deleteMenuItem(widget.item!.itemId);
    setState(() => _saving = false);
    
    if (res.isSuccess) {
      if (mounted) Navigator.pop(context);
      widget.onSaved();
    } else {
      if (mounted) AppSnackbar.showError(context, res.error!);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(widget.item == null ? 'Thêm Món Mới' : 'Sửa Món Ăn',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(labelText: 'Tên món', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _priceCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Giá (VNĐ)', border: OutlineInputBorder()),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 1,
                child: TextField(
                  controller: _emojiCtrl,
                  decoration: const InputDecoration(labelText: 'Emoji (vd: 🍕)', border: OutlineInputBorder()),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            initialValue: _catId,
            decoration: const InputDecoration(labelText: 'Danh mục', border: OutlineInputBorder()),
            items: widget.categories.map((c) => DropdownMenuItem(value: c.categoryId, child: Text(c.name))).toList(),
            onChanged: (val) => setState(() => _catId = val),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descCtrl,
            decoration: const InputDecoration(labelText: 'Mô tả', border: OutlineInputBorder()),
            maxLines: 2,
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              if (widget.item != null) ...[
                OutlinedButton(
                  onPressed: _saving ? null : _delete,
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                  child: const Icon(Icons.delete),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : Text(widget.item == null ? 'Thêm món' : 'Lưu'),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

}
