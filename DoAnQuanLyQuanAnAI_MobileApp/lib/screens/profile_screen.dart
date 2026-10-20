import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:doanquanlyquananai_mobileapp/l10n/app_localizations.dart';
import 'package:doanquanlyquananai_mobileapp/theme/app_colors.dart';
import 'package:doanquanlyquananai_mobileapp/theme/app_theme.dart';
import 'package:doanquanlyquananai_mobileapp/services/auth_service.dart';
import 'package:doanquanlyquananai_mobileapp/services/locale_service.dart';
import 'package:doanquanlyquananai_mobileapp/screens/login_screen.dart';
import 'package:doanquanlyquananai_mobileapp/screens/edit_profile_screen.dart';
import 'package:doanquanlyquananai_mobileapp/screens/change_password_screen.dart';
import 'package:doanquanlyquananai_mobileapp/screens/notifications_screen.dart';
import 'package:doanquanlyquananai_mobileapp/screens/activity_log_screen.dart';
import 'package:doanquanlyquananai_mobileapp/config/constants.dart';
import 'package:doanquanlyquananai_mobileapp/screens/manager/manager_dashboard_screen.dart';
import 'package:doanquanlyquananai_mobileapp/widgets/common/menu_item_image.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();
    final localeService = context.watch<LocaleService>();
    final l10n = AppLocalizations.of(context);
    final user = authService.currentUser;
    final roleName = switch (user?.role) {
      0 => l10n.translate('owner'),
      1 => l10n.translate('staff'),
      2 => l10n.translate('manager'),
      3 => l10n.translate('membership'),
      _ => l10n.translate('guest'),
    };

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.marginMobile),
      child: Column(
        children: [
          const SizedBox(height: 24),
          // Avatar card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFFF1EC), Color(0xFFFFE9E1)],
              ),
              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            ),
            child: Column(
              children: [
                UserAvatarImage(
                  avatarUrl: user?.avatar,
                  fullName: user?.fullName ?? 'Guest',
                  role: user?.role ?? 3,
                  size: 84,
                ),
                const SizedBox(height: 14),
                Text(
                  user?.fullName ?? l10n.translate('guest'),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withAlpha(20),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text(
                    roleName,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '@${user?.username ?? "guest"}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          if (user?.role == AppConstants.roleOwner ||
              user?.role == AppConstants.roleManager)
            _tile(
              Icons.dashboard_rounded,
              l10n.translate('admin_console'),
              l10n.translate('dashboard_overview'),
              () {
                if (Navigator.canPop(context)) {
                  Navigator.pop(context);
                } else {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ManagerDashboardScreen(),
                    ),
                  );
                }
              },
            ),
          _tile(
            Icons.edit_rounded,
            l10n.translate('edit_profile'),
            l10n.translate('update_info'),
            () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const EditProfileScreen()),
              );
            },
          ),
          _tile(
            Icons.lock_outline_rounded,
            l10n.translate('change_password'),
            l10n.translate('update_credentials'),
            () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ChangePasswordScreen()),
              );
            },
          ),
          _tile(
            Icons.notifications_none_rounded,
            l10n.translate('notifications'),
            l10n.translate('manage_preferences'),
            () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NotificationsScreen()),
              );
            },
          ),
          _tile(
            Icons.history_rounded,
            l10n.translate('activity_log'),
            l10n.translate('recent_activities'),
            () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ActivityLogScreen()),
              );
            },
          ),
          _tile(
            Icons.language_rounded,
            l10n.translate('language'),
            localeService.locale.languageCode == 'vi'
                ? 'Đang dùng: Tiếng Việt (Chạm để sang English)'
                : 'Current: English (Tap for Tiếng Việt)',
            () {
              localeService.toggleLocale();
            },
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: OutlinedButton.icon(
              onPressed: () async {
                await authService.logout();
                if (context.mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (r) => false,
                  );
                }
              },
              icon: const Icon(Icons.logout_rounded, color: AppColors.error),
              label: Text(
                l10n.translate('log_out'),
                style: const TextStyle(color: AppColors.error),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.error),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'v2.4.0-AI',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.onSurfaceVariant.withAlpha(120),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _tile(IconData icon, String title, String sub, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Builder(
        builder: (context) {
          return InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                border: Border.all(
                  color: AppColors.outlineVariant.withAlpha(50),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      icon,
                      size: 20,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          sub,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.onSurfaceVariant,
                    size: 20,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
