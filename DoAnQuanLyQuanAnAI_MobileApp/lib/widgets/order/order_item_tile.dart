import 'package:flutter/material.dart';
import 'package:doanquanlyquananai_mobileapp/core/constants/app_colors.dart';
import 'package:doanquanlyquananai_mobileapp/core/utils/money_formatter.dart';
import 'package:doanquanlyquananai_mobileapp/services/cart_provider.dart';
import 'package:doanquanlyquananai_mobileapp/widgets/common/menu_item_image.dart';

class OrderItemTile extends StatelessWidget {
  final CartItem item;
  final VoidCallback? onIncrease;
  final VoidCallback? onDecrease;
  final VoidCallback? onRemove;
  final bool isEditable;

  const OrderItemTile({
    super.key,
    required this.item,
    this.onIncrease,
    this.onDecrease,
    this.onRemove,
    this.isEditable = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          // Hình ảnh món ăn thực tế
          MenuItemImage(
            imagePath: item.menuItem.imagePath,
            itemName: item.menuItem.name,
            emoji: item.menuItem.emoji,
            width: 48,
            height: 48,
            borderRadius: BorderRadius.circular(10),
            emojiSize: 22,
          ),
          const SizedBox(width: 12),

          // Name + price
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.menuItem.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  MoneyFormatter.format(item.menuItem.price),
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          // Qty controls or read-only qty
          if (isEditable) ...[
            _SmallIconBtn(icon: Icons.remove, onTap: onDecrease, color: AppColors.error),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text(
                '${item.quantity}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            _SmallIconBtn(icon: Icons.add, onTap: onIncrease, color: AppColors.primary),
            const SizedBox(width: 8),
            _SmallIconBtn(
              icon: Icons.delete_outline,
              onTap: onRemove,
              color: AppColors.error.withValues(alpha: 0.7),
            ),
          ] else ...[
            Text(
              'x${item.quantity}',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
          ],

          const SizedBox(width: 8),

          // Line total
          Text(
            MoneyFormatter.format(item.lineTotal),
            style: TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _SmallIconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final Color color;

  const _SmallIconBtn({required this.icon, this.onTap, required this.color});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 16, color: color),
    ),
  );
}
