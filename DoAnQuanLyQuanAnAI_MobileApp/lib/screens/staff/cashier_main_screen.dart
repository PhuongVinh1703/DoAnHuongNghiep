import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:doanquanlyquananai_mobileapp/core/utils/ai_tracker.dart';
import 'package:doanquanlyquananai_mobileapp/theme/app_colors.dart';
import 'package:doanquanlyquananai_mobileapp/config/constants.dart';
import 'package:doanquanlyquananai_mobileapp/services/auth_service.dart';
import 'package:doanquanlyquananai_mobileapp/services/branch_service.dart';
import 'package:doanquanlyquananai_mobileapp/services/locale_service.dart';
import 'package:doanquanlyquananai_mobileapp/l10n/app_localizations.dart';
import 'package:doanquanlyquananai_mobileapp/widgets/app_bottom_nav.dart';
import 'package:doanquanlyquananai_mobileapp/screens/staff/staff_order_screen.dart';
import 'package:doanquanlyquananai_mobileapp/screens/staff/staff_tables_screen.dart';
import 'package:doanquanlyquananai_mobileapp/screens/profile_screen.dart';

class CashierMainScreen extends StatefulWidget {
  const CashierMainScreen({super.key});

  @override
  State<CashierMainScreen> createState() => _CashierMainScreenState();
}

class _CashierMainScreenState extends State<CashierMainScreen> {
  int _currentIndex = 0;
  String? _branchName;
  int _billReqCount = 0;
  RealtimeChannel? _ordersChannel;

  @override
  void initState() {
    super.initState();
    _loadBranchName();
    _fetchBillReqCount();
    _subscribeToOrderChanges();
  }

  @override
  void dispose() {
    _ordersChannel?.unsubscribe();
    super.dispose();
  }

  Future<void> _loadBranchName() async {
    final user = context.read<AuthService>().currentUser;
    if (user?.branchId != null) {
      try {
        final res = await BranchService().getBranches();
        if (res.isSuccess && res.data != null) {
          final branch = res.data!.firstWhere(
            (b) => b.branchId == user!.branchId,
          );
          if (mounted) setState(() => _branchName = branch.name);
        }
      } catch (_) {}
    }
  }

  Future<void> _fetchBillReqCount() async {
    try {
      final supabase = Supabase.instance.client;
      final res = await supabase
          .from('Orders')
          .select('OrderId, Note, TableId')
          .eq('Status', 0);

      final list = (res as List)
          .where((o) => AiTracker.isPaymentRequested(o['Note']?.toString()))
          .toList();

      if (mounted) {
        setState(() => _billReqCount = list.length);
      }
    } catch (_) {}
  }

  void _subscribeToOrderChanges() {
    try {
      final supabase = Supabase.instance.client;
      _ordersChannel = supabase.channel('public:cashier_orders_channel')
        ..onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'Orders',
          callback: (payload) {
            _fetchBillReqCount();

            // Nếu là UPDATE và có thêm cờ [BILL_REQ]
            if (payload.eventType == PostgresChangeEvent.update) {
              final newRecord = payload.newRecord;
              final oldRecord = payload.oldRecord;
              final status = newRecord['Status'];
              final note = newRecord['Note']?.toString() ?? '';
              final oldNote = oldRecord['Note']?.toString() ?? '';

              if (status == 0 &&
                  AiTracker.isPaymentRequested(note) &&
                  !AiTracker.isPaymentRequested(oldNote)) {
                final tableId = newRecord['TableId'];
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          const Icon(Icons.point_of_sale_rounded,
                              color: Colors.white),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '💳 Bàn $tableId vừa yêu cầu thanh toán!',
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      backgroundColor: Colors.amber[800],
                      behavior: SnackBarBehavior.floating,
                      duration: const Duration(seconds: 4),
                    ),
                  );
                }
              }
            }
          },
        )
        ..subscribe();
    } catch (_) {}
  }

  final _screens = const [
    StaffOrderScreen(isCashierMode: true),
    StaffTablesScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthService>().currentUser;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => Navigator.maybePop(context),
              )
            : null,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  AppConstants.appName,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.amber.withAlpha(40),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.amber.withAlpha(120)),
                  ),
                  child: Text(
                    '💳 Thu ngân',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.amber[900],
                    ),
                  ),
                ),
              ],
            ),
            if (user != null)
              Text(
                '${user.fullName}${_branchName != null ? ' - $_branchName' : (user.branchId != null ? ' - Chi nhánh ${user.branchId}' : '')}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.language_rounded),
            onPressed: () => context.read<LocaleService>().toggleLocale(),
            tooltip: AppLocalizations.of(context).translate('language'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _screens[_currentIndex],
      bottomNavigationBar: AppBottomNav(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        customItems: [
          AppBottomNavItem(
            icon: Icons.point_of_sale_rounded,
            label: 'Quầy thu ngân',
            badgeCount: _billReqCount,
          ),
          AppBottomNavItem(
            icon: Icons.grid_view_rounded,
            label: AppLocalizations.of(context).translate('tables'),
          ),
          AppBottomNavItem(
            icon: Icons.person_rounded,
            label: AppLocalizations.of(context).translate('profile'),
          ),
        ],
      ),
    );
  }
}
