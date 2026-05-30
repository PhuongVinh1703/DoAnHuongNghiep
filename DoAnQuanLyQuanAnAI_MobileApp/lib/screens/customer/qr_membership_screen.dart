import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:doanquanlyquananai_mobileapp/theme/app_colors.dart';
import 'package:doanquanlyquananai_mobileapp/theme/app_theme.dart';
import 'package:doanquanlyquananai_mobileapp/services/customer_provider.dart';
import 'package:doanquanlyquananai_mobileapp/services/auth_service.dart';

class QrMembershipScreen extends StatefulWidget {
  const QrMembershipScreen({super.key});

  @override
  State<QrMembershipScreen> createState() => _QrMembershipScreenState();
}

class _QrMembershipScreenState extends State<QrMembershipScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  void _loadData() {
    final auth = context.read<AuthService>();
    final customerProvider = context.read<CustomerProvider>();
    if (auth.isLoggedIn && auth.currentUser?.role == 3) { // 3 is roleCustomer
      customerProvider.fetchCustomerProfileByIdentifier(auth.currentUser!.username);
    }
  }



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
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: const Text('Membership Card')),
      body: Consumer<CustomerProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading && provider.currentCustomer == null) {
            return const Center(child: CircularProgressIndicator());
          }

          final customer = provider.currentCustomer;
          if (customer == null) {
            return const Center(child: Text('Vui lòng đăng nhập bằng tài khoản Khách hàng'));
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.marginMobile),
            child: Column(
              children: [
                const SizedBox(height: 16),

                // Membership card
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: AppColors.aiGradient,
                    borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                    boxShadow: [BoxShadow(color: AppColors.primary.withAlpha(60), blurRadius: 24, offset: const Offset(0, 10))],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        // Header
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              const Text('Reserve & Relish', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                              Text('Membership', style: TextStyle(color: Colors.white.withAlpha(180), fontSize: 13)),
                            ]),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                              decoration: BoxDecoration(color: Colors.white.withAlpha(40), borderRadius: BorderRadius.circular(100)),
                              child: Row(mainAxisSize: MainAxisSize.min, children: [
                                const Icon(Icons.star_rounded, color: Colors.amber, size: 16),
                                const SizedBox(width: 4),
                                Text(_getTierName(customer.tier), style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                              ]),
                            ),
                          ],
                        ),

                        const SizedBox(height: 28),

                        // QR Code display
                        Container(
                          width: 200, height: 200,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: QrImageView(
                              data: customer.serialCode ?? 'MEMBER-${customer.customerId}',
                              version: QrVersions.auto,
                              size: 180.0,
                              eyeStyle: const QrEyeStyle(
                                eyeShape: QrEyeShape.square,
                                color: AppColors.onSurface,
                              ),
                              dataModuleStyle: const QrDataModuleStyle(
                                dataModuleShape: QrDataModuleShape.square,
                                color: AppColors.onSurface,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Scan instruction
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(color: Colors.white.withAlpha(25), borderRadius: BorderRadius.circular(12)),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.touch_app_rounded, color: Colors.white.withAlpha(200), size: 18),
                            const SizedBox(width: 8),
                            Text(customer.serialCode ?? 'MEMBER-${customer.customerId}', style: TextStyle(color: Colors.white.withAlpha(200), fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 1)),
                          ]),
                        ),

                        const SizedBox(height: 16),

                        // Member name
                        Text(customer.fullName, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        Text('Member since 2024', style: TextStyle(color: Colors.white.withAlpha(160), fontSize: 12)),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 28),

                // Scan at Checkout section
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                    border: Border.all(color: AppColors.outlineVariant.withAlpha(60)),
                    boxShadow: AppTheme.shadowLevel1,
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: AppColors.primary.withAlpha(18), borderRadius: BorderRadius.circular(12)),
                        child: const Icon(Icons.qr_code_scanner_rounded, size: 22, color: AppColors.primary),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Scan at Checkout', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                        Text('Earn points every time you dine', style: TextStyle(fontSize: 13, color: AppColors.onSurfaceVariant)),
                      ])),
                    ]),
                    const SizedBox(height: 16),
                    // Progress to next tier
                    Row(children: [
                      Text('Loyalty Points', style: TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant)),
                      const Spacer(),
                      Text('${customer.points} points', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary)),
                    ]),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: (customer.points % 1000) / 1000,
                        backgroundColor: AppColors.surfaceContainerHigh,
                        valueColor: const AlwaysStoppedAnimation(AppColors.primary),
                        minHeight: 8,
                      ),
                    ),
                  ]),
                ),

                const SizedBox(height: 16),

                // Benefits grid
                Text('Member Benefits', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),

                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.4,
                  children: [
                    _BenefitCard(icon: Icons.percent_rounded, title: '15% Off', subtitle: 'All orders'),
                    _BenefitCard(icon: Icons.cake_rounded, title: 'Birthday Gift', subtitle: 'Free dessert'),
                    _BenefitCard(icon: Icons.event_seat_rounded, title: 'Priority Seating', subtitle: 'Skip the queue'),
                    _BenefitCard(icon: Icons.local_offer_rounded, title: 'Exclusive Deals', subtitle: 'Members only'),
                  ],
                ),

                const SizedBox(height: 32),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _BenefitCard extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  const _BenefitCard({required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppColors.outlineVariant.withAlpha(50)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, size: 24, color: AppColors.primary),
        const SizedBox(height: 10),
        Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        Text(subtitle, style: TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant)),
      ]),
    );
  }
}
