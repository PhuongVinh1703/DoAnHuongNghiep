import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:doanquanlyquananai_mobileapp/config/constants.dart';
import 'package:doanquanlyquananai_mobileapp/theme/app_colors.dart';
import 'package:doanquanlyquananai_mobileapp/theme/app_theme.dart';
import 'package:doanquanlyquananai_mobileapp/services/auth_service.dart';
import 'package:doanquanlyquananai_mobileapp/services/customer_provider.dart';
import 'package:doanquanlyquananai_mobileapp/widgets/common/app_snackbar.dart';

class CustomerPointsScreen extends StatefulWidget {
  const CustomerPointsScreen({super.key});

  @override
  State<CustomerPointsScreen> createState() => _CustomerPointsScreenState();
}

class _CustomerPointsScreenState extends State<CustomerPointsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _tokenController = TextEditingController();
  bool _isRedeeming = false;

  // Tier thresholds
  static const tierThresholds = [0, 50, 200, 500, 1000];
  static const tierNames = ['Đồng', 'Bạc', 'Vàng', 'VIP', 'Kim Cương'];
  static const tierEmojis = ['🥉', '🥈', '🥇', '💎', '👑'];
  static const tierColors = [
    Color(0xFFCD7F32), Color(0xFFC0C0C0), Color(0xFFFFD700),
    Color(0xFF9B59B6), Color(0xFF00BCD4),
  ];

  static const tierBenefits = [
    ['Tích điểm mọi hoá đơn', 'Nhận thông báo ưu đãi'],
    ['Tích điểm mọi hoá đơn', 'Giảm 5% khi đặt bàn trước', 'Ưu tiên xếp bàn'],
    ['Tích điểm x1.5', 'Giảm 10% mỗi hoá đơn', 'Ưu tiên xếp bàn', 'Tặng khai vị'],
    ['Tích điểm x2', 'Giảm 15% mọi hoá đơn', 'Bàn VIP ưu tiên', 'Tặng khai vị + tráng miệng'],
    ['Tích điểm x3', 'Giảm 20% mọi hoá đơn', 'Bàn riêng tư', 'Butler service', 'Ưu đãi sinh nhật đặc biệt'],
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final auth = context.read<AuthService>();
      final prov = context.read<CustomerProvider>();
      if (auth.isLoggedIn && auth.currentUser?.role == AppConstants.roleCustomer) {
        await prov.fetchCustomerProfileByIdentifier(auth.currentUser!.username);
        await prov.fetchTransactions();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _tokenController.dispose();
    super.dispose();
  }

  Future<void> _redeemQr() async {
    final token = _tokenController.text.trim().toUpperCase();
    if (token.isEmpty) {
      AppSnackbar.showError(context, 'Vui lòng nhập mã token');
      return;
    }

    setState(() => _isRedeeming = true);
    final prov = context.read<CustomerProvider>();
    await prov.redeemQrToken(token);
    if (mounted) {
      setState(() => _isRedeeming = false);
      if (prov.error.isEmpty) {
        _tokenController.clear();
        AppSnackbar.showSuccess(context, 'Tích điểm thành công! Điểm đã được cộng vào tài khoản của bạn.');
      } else {
        AppSnackbar.showError(context, prov.error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Điểm tích lũy'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [Tab(text: 'Tích điểm'), Tab(text: 'Lịch sử')],
        ),
      ),
      body: Consumer<CustomerProvider>(
        builder: (context, prov, child) {
          final cust = prov.currentCustomer;
          return Column(
            children: [
              // Points overview card
              if (cust != null) _buildPointsCard(cust.points, cust.tier),

              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildRedeemQrTab(),
                    _buildHistoryTab(prov),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPointsCard(int points, int tier) {
    final tierIdx = tier.clamp(0, 4);
    final tierColor = tierColors[tierIdx];
    final tierName  = tierNames[tierIdx];
    final tierEmoji = tierEmojis[tierIdx];

    // Progress to next tier
    final currentMin = tierIdx < 4 ? tierThresholds[tierIdx]     : tierThresholds[4];
    final nextMin    = tierIdx < 4 ? tierThresholds[tierIdx + 1]  : tierThresholds[4];
    final progress   = tierIdx >= 4 ? 1.0
        : ((points - currentMin) / (nextMin - currentMin)).clamp(0.0, 1.0);
    final remaining  = tierIdx >= 4 ? 0 : (nextMin - points).clamp(0, nextMin);
    final nextName   = tierIdx < 4 ? tierNames[tierIdx + 1] : '';

    return Container(
      margin: const EdgeInsets.all(AppTheme.marginMobile),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [tierColor.withAlpha(200), tierColor.withAlpha(180)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        boxShadow: [BoxShadow(color: tierColor.withAlpha(80), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Điểm tích lũy', style: TextStyle(color: Colors.white.withAlpha(200), fontSize: 13)),
            const SizedBox(height: 4),
            Text('$points', style: const TextStyle(color: Colors.white, fontSize: 38, fontWeight: FontWeight.w800, letterSpacing: -1)),
          ]),
          const Spacer(),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(tierEmoji, style: const TextStyle(fontSize: 32)),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(color: Colors.white.withAlpha(50), borderRadius: BorderRadius.circular(100)),
              child: Text('Hạng $tierName', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
            ),
          ]),
        ]),

        const SizedBox(height: 18),

        // Progress bar
        ClipRRect(
          borderRadius: BorderRadius.circular(100),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.white.withAlpha(50),
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            minHeight: 6,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          tierIdx >= 4
              ? '💎 Bạn đã đạt hạng cao nhất!'
              : 'Còn $remaining điểm để lên hạng $nextName',
          style: TextStyle(color: Colors.white.withAlpha(220), fontSize: 12, fontWeight: FontWeight.w500),
        ),

        const SizedBox(height: 16),

        // Benefits
        Wrap(
          spacing: 6, runSpacing: 6,
          children: tierBenefits[tierIdx].map((b) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: Colors.white.withAlpha(40), borderRadius: BorderRadius.circular(100)),
            child: Text(b, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w500)),
          )).toList(),
        ),
      ]),
    );
  }

  // ─── TAB 1: QR REDEEM ────────────────────────────────────────────────────
  Widget _buildRedeemQrTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.marginMobile),
      child: Column(children: [
        // Info card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.primary.withAlpha(15),
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            border: Border.all(color: AppColors.primary.withAlpha(50)),
          ),
          child: const Row(children: [
            Icon(Icons.info_outline_rounded, color: AppColors.primary, size: 20),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Nhân viên sẽ cung cấp mã QR Token sau khi thanh toán. Nhập mã để tích điểm vào tài khoản của bạn.',
                style: TextStyle(fontSize: 13, color: AppColors.primary, height: 1.5),
              ),
            ),
          ]),
        ),

        const SizedBox(height: 24),

        // Large icon
        Container(
          width: 100, height: 100,
          decoration: BoxDecoration(
            gradient: AppColors.aiGradient,
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: AppColors.primary.withAlpha(60), blurRadius: 20, offset: const Offset(0, 8))],
          ),
          child: const Icon(Icons.qr_code_scanner_rounded, color: Colors.white, size: 44),
        ),

        const SizedBox(height: 24),

        const Text('Nhập mã tích điểm', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        const Text('Mã được nhân viên cung cấp sau thanh toán', style: TextStyle(color: AppColors.onSurfaceVariant, fontSize: 13)),

        const SizedBox(height: 24),

        // Token input
        TextField(
          controller: _tokenController,
          textCapitalization: TextCapitalization.characters,
          decoration: InputDecoration(
            hintText: 'Nhập mã QR token (VD: ABC123)',
            prefixIcon: const Icon(Icons.tag_rounded),
            suffixIcon: IconButton(
              icon: const Icon(Icons.paste_rounded),
              onPressed: () async {
                final data = await Clipboard.getData('text/plain');
                if (data?.text != null) {
                  _tokenController.text = data!.text!.trim().toUpperCase();
                }
              },
            ),
            filled: true,
            fillColor: AppColors.surfaceContainerLowest,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              borderSide: BorderSide(color: AppColors.outlineVariant),
            ),
          ),
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: 2),
        ),

        const SizedBox(height: 20),

        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _isRedeeming ? null : _redeemQr,
            icon: _isRedeeming
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.add_circle_rounded),
            label: Text(_isRedeeming ? 'Đang xử lý...' : 'Tích điểm ngay',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
          ),
        ),

        const SizedBox(height: 32),

        // How it works
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            border: Border.all(color: AppColors.outlineVariant.withAlpha(60)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('🎯 Cách tích điểm', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            _HowItWorksStep(step: '1', text: 'Dùng bữa tại nhà hàng và yêu cầu tính điểm'),
            _HowItWorksStep(step: '2', text: 'Nhân viên cung cấp mã QR Token sau thanh toán'),
            _HowItWorksStep(step: '3', text: 'Nhập mã vào ô trên và nhấn "Tích điểm ngay"'),
            _HowItWorksStep(step: '4', text: 'Cứ 100.000đ sẽ tích được 1 điểm thành viên', isLast: true),
          ]),
        ),
      ]),
    );
  }

  // ─── TAB 2: HISTORY ──────────────────────────────────────────────────────
  Widget _buildHistoryTab(CustomerProvider prov) {
    if (prov.isLoading && prov.transactions.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (prov.transactions.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(color: AppColors.surfaceContainerHigh, shape: BoxShape.circle),
            child: const Icon(Icons.history_rounded, size: 32, color: AppColors.onSurfaceVariant),
          ),
          const SizedBox(height: 14),
          const Text('Chưa có lịch sử giao dịch', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        ]),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.marginMobile, vertical: 12),
      itemCount: prov.transactions.length,
      separatorBuilder: (_, i2) => const SizedBox(height: 8),
      itemBuilder: (ctx, i) {
        final tx = prov.transactions[i];
        final isEarned = tx.pointDelta > 0;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            border: Border.all(color: AppColors.outlineVariant.withAlpha(40)),
          ),
          child: Row(children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: isEarned ? AppColors.chipPaid.withAlpha(20) : AppColors.error.withAlpha(20),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isEarned ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                color: isEarned ? AppColors.chipPaid : AppColors.error,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(tx.note, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
              Text(DateFormat('HH:mm dd/MM/yyyy').format(tx.createdAt),
                  style: const TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant)),
            ])),
            Text(
              '${isEarned ? '+' : ''}${tx.pointDelta} điểm',
              style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w700,
                color: isEarned ? AppColors.chipPaid : AppColors.error,
              ),
            ),
          ]),
        );
      },
    );
  }
}

class _HowItWorksStep extends StatelessWidget {
  final String step, text;
  final bool isLast;
  const _HowItWorksStep({required this.step, required this.text, this.isLast = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 10),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 22, height: 22,
          decoration: BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
          child: Center(child: Text(step, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700))),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 13, height: 1.5, color: AppColors.onSurface))),
      ]),
    );
  }
}
