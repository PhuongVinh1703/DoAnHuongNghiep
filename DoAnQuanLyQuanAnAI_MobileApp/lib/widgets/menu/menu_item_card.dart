import 'package:flutter/material.dart';
import 'package:doanquanlyquananai_mobileapp/core/constants/app_colors.dart';
import 'package:doanquanlyquananai_mobileapp/core/utils/money_formatter.dart';
import 'package:doanquanlyquananai_mobileapp/models/menu/menu_item.dart';

class MenuItemCard extends StatelessWidget {
  final MenuItemModel item;
  final int cartQty;
  final VoidCallback onAdd;
  final VoidCallback? onDecrease;

  const MenuItemCard({
    super.key,
    required this.item,
    required this.cartQty,
    required this.onAdd,
    this.onDecrease,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: item.isAvailable ? 1.0 : 0.45,
      duration: const Duration(milliseconds: 200),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image / Emoji
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                child: item.imagePath != null
                    ? Image.network(
                        item.imagePath!,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        errorBuilder: (_, _, _) => _emojiPlaceholder(),
                      )
                    : _emojiPlaceholder(),
              ),
            ),

            // Info
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    MoneyFormatter.format(item.price),
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Qty control
                  if (!item.isAvailable)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'Hết hàng',
                        style: TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    )
                  else if (cartQty == 0)
                    SizedBox(
                      width: double.infinity,
                      height: 32,
                      child: ElevatedButton.icon(
                        onPressed: onAdd,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: EdgeInsets.zero,
                        ),
                        icon: const Icon(Icons.add, size: 16, color: Colors.white),
                        label: const Text(
                          'Thêm',
                          style: TextStyle(fontSize: 12, color: Colors.white),
                        ),
                      ),
                    )
                  else
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _CircleBtn(
                          icon: Icons.remove,
                          onTap: onDecrease,
                          color: AppColors.error,
                        ),
                        Text(
                          '$cartQty',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        _CircleBtn(
                          icon: Icons.add,
                          onTap: onAdd,
                          color: AppColors.primary,
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

  Widget _emojiPlaceholder() => Container(
    color: AppColors.primary.withValues(alpha: 0.08),
    child: Center(
      child: Text(
        item.emoji.isNotEmpty ? item.emoji : '🍽️',
        style: const TextStyle(fontSize: 40),
      ),
    ),
  );
}

class _CircleBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final Color color;

  const _CircleBtn({required this.icon, this.onTap, required this.color});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 16, color: color),
    ),
  );
}
