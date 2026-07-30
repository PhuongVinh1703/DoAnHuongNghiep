import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:doanquanlyquananai_mobileapp/config/constants.dart';
import 'package:doanquanlyquananai_mobileapp/theme/app_colors.dart';
import 'package:doanquanlyquananai_mobileapp/theme/app_theme.dart';
import 'package:doanquanlyquananai_mobileapp/services/auth_service.dart';
import 'package:doanquanlyquananai_mobileapp/services/customer_provider.dart';
import 'package:doanquanlyquananai_mobileapp/screens/customer/customer_booking_screen.dart';
import 'package:doanquanlyquananai_mobileapp/screens/customer/customer_invoice_history_screen.dart';
import 'package:doanquanlyquananai_mobileapp/screens/customer/customer_points_screen.dart';
import 'package:doanquanlyquananai_mobileapp/screens/customer/voucher_loyalty_screen.dart';
import 'package:doanquanlyquananai_mobileapp/screens/customer/qr_membership_screen.dart';
import 'package:doanquanlyquananai_mobileapp/screens/menu_screen.dart';
import 'package:doanquanlyquananai_mobileapp/screens/profile_screen.dart';

class CustomerHomeScreen extends StatefulWidget {
  const CustomerHomeScreen({super.key});

  @override
  State<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends State<CustomerHomeScreen> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthService>();
      if (auth.isLoggedIn && auth.currentUser?.role == AppConstants.roleCustomer) {
        context.read<CustomerProvider>().fetchCustomerProfileByIdentifier(auth.currentUser!.username);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: IndexedStack(
        index: _currentIndex,
        children: const [
          _HomeContent(),
          MenuScreen(),
          VoucherLoyaltyScreen(),
          ProfileScreen(),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBottomNav() {
    final items = [
      _NavItem(Icons.home_rounded, 'Home'),
      _NavItem(Icons.restaurant_menu_rounded, 'Menu'),
      _NavItem(Icons.card_giftcard_rounded, 'Vouchers'),
      _NavItem(Icons.person_rounded, 'Profile'),
    ];

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppColors.outlineVariant.withAlpha(60)),
        boxShadow: AppTheme.shadowLevel2,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(items.length, (i) {
          final active = _currentIndex == i;
          return GestureDetector(
            onTap: () => setState(() => _currentIndex = i),
            behavior: HitTestBehavior.opaque,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: active ? AppColors.primary.withAlpha(20) : Colors.transparent,
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              ),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(items[i].icon, color: active ? AppColors.primary : AppColors.onSurfaceVariant, size: 24),
                const SizedBox(height: 4),
                Text(items[i].label, style: TextStyle(fontSize: 11, fontWeight: active ? FontWeight.w600 : FontWeight.w400, color: active ? AppColors.primary : AppColors.onSurfaceVariant)),
              ]),
            ),
          );
        }),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  _NavItem(this.icon, this.label);
}

class _HomeContent extends StatelessWidget {
  const _HomeContent();

  String _getTierName(int tier) {
    switch (tier) {
      case 1: return 'Silver Member';
      case 2: return 'Gold Member';
      case 3: return 'Platinum Member';
      default: return 'Bronze Member';
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthService>().currentUser;
    final customer = context.watch<CustomerProvider>().currentCustomer;
    final userName = user?.fullName ?? 'Khách';
    
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: AppTheme.marginMobile),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SizedBox(height: 16),

          // Greeting
          Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Chào buổi tối,', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.onSurfaceVariant)),
              Text(userName, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700)),
            ])),
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(gradient: AppColors.aiGradient, shape: BoxShape.circle),
              child: const Icon(Icons.person_rounded, color: Colors.white, size: 24),
            ),
          ]),

          const SizedBox(height: 24),

          // Membership card mini
          GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const QrMembershipScreen())),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: AppColors.aiGradient,
                borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                boxShadow: [BoxShadow(color: AppColors.primary.withAlpha(50), blurRadius: 20, offset: const Offset(0, 8))],
              ),
              child: Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Thẻ Thành Viên', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                  Text(customer != null ? 'Hạng thẻ hiện tại' : 'Đăng nhập để xem hạng', style: TextStyle(color: Colors.white.withAlpha(180), fontSize: 12)),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: Colors.white.withAlpha(35), borderRadius: BorderRadius.circular(100)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.star_rounded, color: Colors.amber, size: 14),
                      const SizedBox(width: 4),
                      Text(customer != null ? _getTierName(customer.tier) : 'Hạng Đồng', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                    ]),
                  ),
                ])),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.white.withAlpha(30), borderRadius: BorderRadius.circular(14)),
                  child: const Icon(Icons.qr_code_2_rounded, color: Colors.white, size: 32),
                ),
              ]),
            ),
          ),

          const SizedBox(height: 20),

          // Scan at checkout
          GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CustomerPointsScreen())),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                border: Border.all(color: AppColors.primary.withAlpha(40)),
              ),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: AppColors.primary.withAlpha(18), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.qr_code_scanner_rounded, size: 20, color: AppColors.primary),
                ),
                const SizedBox(width: 12),
                const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Tích điểm & đổi điểm', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  Text('Nhập mã QR token sau thanh toán', style: TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant)),
                ])),
                const Icon(Icons.chevron_right_rounded, color: AppColors.onSurfaceVariant),
              ]),
            ),
          ),

          const SizedBox(height: 24),

          // Quick actions
          Text('Thao tác nhanh', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),

          Row(children: [
            _QuickAction(icon: Icons.event_rounded, label: 'Đặt bàn', color: const Color(0xFF1565C0), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CustomerBookingScreen()))),
            const SizedBox(width: 12),
            _QuickAction(icon: Icons.restaurant_menu_rounded, label: 'Thực đơn', color: AppColors.primary, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MenuScreen()))),
            const SizedBox(width: 12),
            _QuickAction(icon: Icons.local_offer_rounded, label: 'Ưu đãi', color: const Color(0xFF6F5900), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const VoucherLoyaltyScreen()))),
            const SizedBox(width: 12),
            _QuickAction(icon: Icons.history_rounded, label: 'Lịch sử', color: AppColors.tertiary, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CustomerInvoiceHistoryScreen()))),
          ]),

          const SizedBox(height: 28),

          // Seasonal promo
          Text('Thực đơn mùa hè', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFFFFF1EC), Color(0xFFFFE9E1)], begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: AppColors.secondaryContainer, borderRadius: BorderRadius.circular(100)),
                child: const Text('🔥 Giới hạn', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF6F5900))),
              ),
              const SizedBox(height: 12),
              const Text('Lễ hội Hải sản Mùa hè', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text('Thưởng thức những món hải sản tươi ngon nhất được chế biến bởi đầu bếp 5 sao.', style: TextStyle(fontSize: 13, color: AppColors.onSurfaceVariant, height: 1.5)),
              const SizedBox(height: 14),
              ElevatedButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const MenuScreen(initialCategoryId: 3),
                  ),
                ),
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12)),
                child: const Text('Xem Thực Đơn'),
              ),
            ]),
          ),

          const SizedBox(height: 32),
        ]),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _QuickAction({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Column(children: [
          Container(
            width: 56, height: 56,
            decoration: BoxDecoration(color: color.withAlpha(20), borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500), textAlign: TextAlign.center),
        ]),
      ),
    );
  }
}
