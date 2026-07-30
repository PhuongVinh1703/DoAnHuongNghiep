import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:doanquanlyquananai_mobileapp/theme/app_colors.dart';
import 'package:doanquanlyquananai_mobileapp/theme/app_theme.dart';
import 'package:doanquanlyquananai_mobileapp/services/menu_provider.dart';
import 'package:doanquanlyquananai_mobileapp/models/menu/menu_item.dart';
import 'package:doanquanlyquananai_mobileapp/models/menu/menu_category.dart';
import 'package:doanquanlyquananai_mobileapp/l10n/app_localizations.dart';

class MenuScreen extends StatefulWidget {
  final int initialCategoryId;
  const MenuScreen({super.key, this.initialCategoryId = 0});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  late int _selectedCategoryId;

  @override
  void initState() {
    super.initState();
    _selectedCategoryId = widget.initialCategoryId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MenuProvider>().loadMenuData();
    });
  }

  String _formatCurrency(int amount) {
    final formatted = amount.toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    );
    return '$formatted' 'đ';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Consumer<MenuProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading && provider.categories.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        final filteredItems = provider.getItemsByCategory(_selectedCategoryId);
        
        // Add 'All' category manually
        final displayCategories = [
          MenuCategoryModel(categoryId: 0, name: l10n.translate('all'), icon: '🍽️', displayOrder: 0, isActive: true),
          ...provider.categories
        ];

        return Scaffold(
          backgroundColor: AppColors.surface,
          appBar: Navigator.canPop(context)
              ? AppBar(
                  title: const Text('Thực đơn'),
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                )
              : null,
          body: SafeArea(
            child: Column(
            children: [
              // ─── Category Filter ─────────────────────────
              SizedBox(
                height: 44,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: AppTheme.marginMobile),
                  itemCount: displayCategories.length,
                  itemBuilder: (context, index) {
                    final category = displayCategories[index];
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

              const SizedBox(height: 16),

              // ─── Menu Items ──────────────────────────────
              Expanded(
                child: provider.errorMessage != null 
                  ? Center(child: Text(provider.errorMessage!))
                  : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: AppTheme.marginMobile),
                  itemCount: filteredItems.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final item = filteredItems[index];
                    return _MenuItemCard(
                      item: item,
                      formattedPrice: _formatCurrency(item.price.toInt()),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );
    },
    );
  }
}

class _MenuItemCard extends StatelessWidget {
  final MenuItemModel item;
  final String formattedPrice;

  const _MenuItemCard({required this.item, required this.formattedPrice});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppColors.outlineVariant.withAlpha(60)),
        boxShadow: AppTheme.shadowLevel1,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── Image placeholder ───────────────────
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.surfaceContainer,
                    AppColors.surfaceContainerHigh,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              ),
              child: Center(
                child: Text(
                  item.emoji.isNotEmpty ? item.emoji : '🍽️',
                  style: const TextStyle(fontSize: 36),
                ),
              ),
            ),

            const SizedBox(width: 14),

            // ─── Content ─────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.name,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      if (item.categoryId == 1) // Fake popular for testing
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.secondaryContainer,
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: const Text(
                            '★ Popular',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF6F5900)),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  if (item.description != null && item.description!.isNotEmpty)
                    Text(
                      item.description!,
                      style: Theme.of(context).textTheme.bodySmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        formattedPrice,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.add_rounded,
                          size: 18,
                          color: Colors.white,
                        ),
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
}
