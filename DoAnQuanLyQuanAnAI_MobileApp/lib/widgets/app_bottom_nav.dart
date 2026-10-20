import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:doanquanlyquananai_mobileapp/l10n/app_localizations.dart';
import 'package:doanquanlyquananai_mobileapp/theme/app_colors.dart';
import 'package:doanquanlyquananai_mobileapp/theme/app_theme.dart';

class AppBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const AppBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final items = [
      _NavItem(icon: Icons.grid_view_rounded, label: l10n.translate('tables'), index: 0),
      _NavItem(icon: Icons.receipt_long_rounded, label: l10n.translate('orders'), index: 1),
      _NavItem(icon: Icons.restaurant_menu_rounded, label: l10n.translate('menu'), index: 2),
      _NavItem(icon: Icons.person_rounded, label: l10n.translate('profile'), index: 3),
    ];

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(AppTheme.radiusLg),
          topRight: Radius.circular(AppTheme.radiusLg),
          bottomLeft: Radius.circular(AppTheme.radiusMd),
          bottomRight: Radius.circular(AppTheme.radiusMd),
        ),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.glassBackground,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(AppTheme.radiusLg),
                topRight: Radius.circular(AppTheme.radiusLg),
                bottomLeft: Radius.circular(AppTheme.radiusMd),
                bottomRight: Radius.circular(AppTheme.radiusMd),
              ),
              border: Border.all(color: AppColors.outlineVariant.withAlpha(80)),
              boxShadow: AppTheme.shadowLevel2,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: items.map((item) {
                final isActive = currentIndex == item.index;
                return _buildNavItem(context, item, isActive);
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(BuildContext context, _NavItem item, bool isActive) {
    return GestureDetector(
      onTap: () => onTap(item.index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primary.withAlpha(20) : Colors.transparent,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              item.icon,
              color: isActive ? AppColors.primary : AppColors.onSurfaceVariant,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              item.label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                color: isActive ? AppColors.primary : AppColors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  final int index;

  _NavItem({required this.icon, required this.label, required this.index});
}
