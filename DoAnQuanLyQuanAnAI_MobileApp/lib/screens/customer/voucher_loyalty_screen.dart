import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:doanquanlyquananai_mobileapp/config/constants.dart';
import 'package:doanquanlyquananai_mobileapp/theme/app_colors.dart';
import 'package:doanquanlyquananai_mobileapp/theme/app_theme.dart';
import 'package:doanquanlyquananai_mobileapp/services/customer_provider.dart';
import 'package:doanquanlyquananai_mobileapp/services/auth_service.dart';
import 'package:doanquanlyquananai_mobileapp/widgets/common/app_snackbar.dart';

class VoucherLoyaltyScreen extends StatefulWidget {
  const VoucherLoyaltyScreen({super.key});

  @override
  State<VoucherLoyaltyScreen> createState() => _VoucherLoyaltyScreenState();
}

class _VoucherLoyaltyScreenState extends State<VoucherLoyaltyScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  void _loadData() {
    final auth = context.read<AuthService>();
    final provider = context.read<CustomerProvider>();
    if (auth.isLoggedIn && auth.currentUser?.role == AppConstants.roleCustomer) {
      provider.fetchCustomerProfileByIdentifier(auth.currentUser!.username);
      provider.fetchRewards();
      provider.fetchActiveCampaigns();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _getTierName(int tier) {
    switch (tier) {
      case 1: return 'Hạng Bạc (Silver)';
      case 2: return 'Hạng Vàng (Gold)';
      case 3: return 'Hạng VIP (Platinum)';
      case 4: return 'Hạng Kim Cương (Diamond)';
      default: return 'Hạng Đồng (Bronze)';
    }
  }

  Future<void> _redeem(int rewardId) async {
    final provider = context.read<CustomerProvider>();
    await provider.redeemReward(rewardId);
    if (mounted) {
      if (provider.error.isNotEmpty) {
        AppSnackbar.showError(context, provider.error);
      } else {
        AppSnackbar.showSuccess(context, 'Đổi ưu đãi thành công! Voucher đã được thêm vào kho của bạn.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: const Text('Vouchers & Loyalty')),
      body: Consumer<CustomerProvider>(
        builder: (context, provider, child) {
          final customer = provider.currentCustomer;

          if (provider.isLoading && customer == null) {
            return const Center(child: CircularProgressIndicator());
          }

          if (customer == null) {
            return const Center(child: Text('Vui lòng đăng nhập để xem ưu đãi'));
          }

          return Column(
            children: [
              // Points card
              Container(
                margin: const EdgeInsets.symmetric(horizontal: AppTheme.marginMobile, vertical: 8),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: AppColors.aiGradient,
                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                  boxShadow: [BoxShadow(color: AppColors.primary.withAlpha(60), blurRadius: 20, offset: const Offset(0, 8))],
                ),
                child: Row(children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Điểm tích lũy', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 4),
                    Text(customer.points.toString(), style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w700, letterSpacing: -1)),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: Colors.white.withAlpha(40), borderRadius: BorderRadius.circular(100)),
                      child: Text(_getTierName(customer.tier), style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                    ),
                  ])),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: Colors.white.withAlpha(30), borderRadius: BorderRadius.circular(16)),
                    child: const Icon(Icons.emoji_events_rounded, color: Colors.white, size: 32),
                  ),
                ]),
              ),

              // Tabs
              Container(
                margin: const EdgeInsets.symmetric(horizontal: AppTheme.marginMobile),
                decoration: BoxDecoration(color: AppColors.surfaceContainerHigh, borderRadius: BorderRadius.circular(12)),
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(color: AppColors.surfaceContainerLowest, borderRadius: BorderRadius.circular(10), boxShadow: AppTheme.shadowLevel1),
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                  labelColor: AppColors.onSurface,
                  unselectedLabelColor: AppColors.onSurfaceVariant,
                  labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  unselectedLabelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w400),
                  padding: const EdgeInsets.all(4),
                  tabs: const [
                    Tab(text: 'Khuyến mãi'),
                    Tab(text: 'Kho Voucher'),
                    Tab(text: 'Đổi ưu đãi'),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Tab content
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // General promotions tab
                    provider.activeCampaigns.isEmpty
                        ? const Center(child: Text('Chưa có chương trình khuyến mãi nào'))
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(horizontal: AppTheme.marginMobile),
                            itemCount: provider.activeCampaigns.length,
                            separatorBuilder: (context, index) => const SizedBox(height: 10),
                            itemBuilder: (ctx, i) {
                              final c = provider.activeCampaigns[i];
                              return Container(
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceContainerLowest,
                                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                                  border: Border.all(color: AppColors.primary.withAlpha(40)),
                                  boxShadow: AppTheme.shadowLevel1,
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Row(children: [
                                    Container(
                                      width: 56, height: 56,
                                      decoration: BoxDecoration(
                                        color: AppColors.primary.withAlpha(18),
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: const Center(child: Icon(Icons.percent_rounded, color: AppColors.primary)),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                      Text(c.code, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                                      const SizedBox(height: 2),
                                      Text(c.description.isNotEmpty ? c.description : 'Chương trình khuyến mãi giảm giá', style: TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant)),
                                      const SizedBox(height: 2),
                                      Text('Giảm ${c.discountValue.toInt()}% (Yêu cầu từ: ${c.minOrderValue.toInt()}đ)', style: const TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600)),
                                      const SizedBox(height: 2),
                                      Text('Hạn dùng: ${DateFormat('dd/MM/yyyy').format(c.endDate)}', style: const TextStyle(fontSize: 11, color: AppColors.chipPaid, fontWeight: FontWeight.w500)),
                                    ])),
                                  ]),
                                ),
                              );
                            },
                          ),

                    // Active Vouchers tab
                    provider.activeVouchers.isEmpty
                        ? const Center(child: Text('Bạn chưa có voucher nào'))
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(horizontal: AppTheme.marginMobile),
                            itemCount: provider.activeVouchers.length,
                            separatorBuilder: (context, index) => const SizedBox(height: 10),
                            itemBuilder: (ctx, i) {
                              final v = provider.activeVouchers[i];
                              return Container(
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceContainerLowest,
                                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                                  border: Border.all(color: AppColors.primary.withAlpha(40)),
                                  boxShadow: AppTheme.shadowLevel1,
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Row(children: [
                                    Container(
                                      width: 56, height: 56,
                                      decoration: BoxDecoration(
                                        color: AppColors.primary.withAlpha(18),
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: const Center(child: Icon(Icons.local_offer_rounded, color: AppColors.primary)),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                      Text(v.voucherCode, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                                      const SizedBox(height: 2),
                                      Text('Giảm ${v.discountAmount.toInt()}%', style: TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant)),
                                      const SizedBox(height: 2),
                                      Text('Hạn dùng: ${DateFormat('dd/MM/yyyy').format(v.expiryDate)}', style: const TextStyle(fontSize: 11, color: AppColors.chipPaid, fontWeight: FontWeight.w500)),
                                    ])),
                                    Icon(Icons.qr_code_2_rounded, size: 28, color: AppColors.onSurfaceVariant.withAlpha(120)),
                                  ]),
                                ),
                              );
                            },
                          ),

                    // Rewards tab (Redeemable)
                    ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: AppTheme.marginMobile),
                      itemCount: provider.rewards.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 10),
                      itemBuilder: (ctx, i) {
                        final r = provider.rewards[i];
                        final canRedeem = customer.points >= r.pointCost;
                        return Container(
                          decoration: BoxDecoration(
                            color: AppColors.surfaceContainerLowest,
                            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                            border: Border.all(color: AppColors.outlineVariant.withAlpha(50)),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                            leading: Container(
                              width: 48, height: 48,
                              decoration: BoxDecoration(
                                color: canRedeem ? AppColors.secondaryContainer.withAlpha(80) : AppColors.surfaceContainer,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(Icons.card_giftcard_rounded, color: canRedeem ? const Color(0xFF6F5900) : AppColors.onSurfaceVariant, size: 24),
                            ),
                            title: Text(r.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                            subtitle: Text('${r.pointCost} points', style: TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant)),
                            trailing: canRedeem
                                ? ElevatedButton(
                                    onPressed: () => _redeem(r.rewardId),
                                    style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), minimumSize: Size.zero),
                                    child: const Text('Đổi', style: TextStyle(fontSize: 13)),
                                  )
                                : Icon(Icons.lock_outline_rounded, color: AppColors.onSurfaceVariant.withAlpha(100)),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
