import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:doanquanlyquananai_mobileapp/theme/app_colors.dart';
import 'package:doanquanlyquananai_mobileapp/theme/app_theme.dart';
import 'package:doanquanlyquananai_mobileapp/services/auth_service.dart';
import 'package:doanquanlyquananai_mobileapp/screens/login_screen.dart';
import 'package:doanquanlyquananai_mobileapp/screens/edit_profile_screen.dart';
import 'package:doanquanlyquananai_mobileapp/screens/change_password_screen.dart';
import 'package:doanquanlyquananai_mobileapp/screens/notifications_screen.dart';
import 'package:doanquanlyquananai_mobileapp/screens/activity_log_screen.dart';
import 'package:doanquanlyquananai_mobileapp/config/constants.dart';
import 'package:doanquanlyquananai_mobileapp/screens/manager/manager_dashboard_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();
    final user = authService.currentUser;
    final roleName = switch (user?.role) {
      0 => 'Owner',
      1 => 'Staff',
      2 => 'Manager',
      3 => 'Customer',
      _ => 'Guest',
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
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    gradient: AppColors.aiGradient,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.person_rounded,
                    size: 40,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  user?.fullName ?? 'Guest',
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
                    style: TextStyle(
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
              'Manager Dashboard',
              'Go to Admin Console',
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
          _tile(Icons.edit_rounded, 'Edit Profile', 'Update your info', () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const EditProfileScreen()),
            );
          }),
          _tile(
            Icons.lock_outline_rounded,
            'Change Password',
            'Update credentials',
            () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ChangePasswordScreen()),
              );
            },
          ),
          _tile(
            Icons.notifications_none_rounded,
            'Notifications',
            'Manage preferences',
            () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NotificationsScreen()),
              );
            },
          ),
          _tile(Icons.history_rounded, 'Activity Log', 'Recent activities', () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ActivityLogScreen()),
            );
          }),
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
              label: const Text(
                'Log Out',
                style: TextStyle(color: AppColors.error),
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
                          style: TextStyle(
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
