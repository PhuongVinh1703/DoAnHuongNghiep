import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:doanquanlyquananai_mobileapp/theme/app_colors.dart';
import 'package:doanquanlyquananai_mobileapp/theme/app_theme.dart';
import 'package:doanquanlyquananai_mobileapp/theme/app_haptics.dart';
import 'package:doanquanlyquananai_mobileapp/widgets/status_chip.dart';
import 'package:doanquanlyquananai_mobileapp/widgets/common/app_shimmer.dart';
import 'package:doanquanlyquananai_mobileapp/services/table_provider.dart';
import 'package:doanquanlyquananai_mobileapp/models/table/dining_table.dart';
import 'package:doanquanlyquananai_mobileapp/l10n/app_localizations.dart';
import 'package:doanquanlyquananai_mobileapp/services/order_provider.dart';
import 'package:doanquanlyquananai_mobileapp/services/auth_service.dart';
import 'package:doanquanlyquananai_mobileapp/screens/staff/menu_order_screen.dart';
import 'package:doanquanlyquananai_mobileapp/services/branch_service.dart';
import 'package:doanquanlyquananai_mobileapp/models/branch/branch.dart';
import 'package:doanquanlyquananai_mobileapp/config/constants.dart';

// ─── Enum trạng thái bộ lọc ──────────────────────────────────────
enum _TableFilter { all, available, occupied, reserved }

class StaffTablesScreen extends StatefulWidget {
  const StaffTablesScreen({super.key});

  @override
  State<StaffTablesScreen> createState() => _StaffTablesScreenState();
}

class _StaffTablesScreenState extends State<StaffTablesScreen>
    with SingleTickerProviderStateMixin {
  _TableFilter _selectedFilter = _TableFilter.all;
  List<Branch> _branches = [];
  int? _selectedBranchId;

  // Timer tích để cập nhật đồng hồ thời gian ngồi
  Timer? _clockTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initData());
    // Cập nhật UI mỗi 60 giây cho timer ngồi
    _clockTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    super.dispose();
  }

  Future<void> _initData() async {
    final auth = context.read<AuthService>();
    final user = auth.currentUser;

    // Luôn tải danh sách chi nhánh để hiển thị cho mọi vai trò
    final res = await BranchService().getBranches();
    if (res.isSuccess && res.data != null && res.data!.isNotEmpty) {
      if (mounted) {
        setState(() {
          _branches = res.data!;
        });
      }
    }

    if (user?.branchId != null) {
      _selectedBranchId = user!.branchId;
    } else if (_branches.isNotEmpty) {
      _selectedBranchId = _branches.first.branchId;
    }

    if (mounted) {
      context.read<TableProvider>().loadTables(branchId: _selectedBranchId);
    }
  }

  // ── Branch filter (Hiển thị cho tất cả các role, phân quyền chuyển chi nhánh) ──────────────────
  Widget _buildBranchFilter() {
    final user = context.read<AuthService>().currentUser;
    final canSwitch = user?.role == AppConstants.roleOwner ||
        user?.role == AppConstants.roleManager ||
        user?.role == AppConstants.roleCashier ||
        user?.branchId == null;

    final branchName = _branches
        .firstWhere(
          (b) => b.branchId == _selectedBranchId,
          orElse: () => _branches.isNotEmpty
              ? _branches.first
              : Branch(branchId: 1, name: 'Chi nhánh 1', address: '', phone: '', isActive: true),
        )
        .name;

    return Container(
      margin: const EdgeInsets.fromLTRB(AppTheme.marginMobile, 0, AppTheme.marginMobile, 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: AppTheme.cardDecoration(
        color: AppColors.surfaceContainerLowest,
        radius: AppTheme.radiusMd,
      ),
      child: Row(
        children: [
          const Icon(Icons.store_rounded, color: AppColors.primary, size: 20),
          const SizedBox(width: 8),
          const Text(
            'Chi nhánh:',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: canSwitch
                ? DropdownButtonHideUnderline(
                    child: DropdownButton<int?>(
                      value: _selectedBranchId,
                      isExpanded: true,
                      hint: const Text('Chọn chi nhánh'),
                      items: [
                        ..._branches.map((b) => DropdownMenuItem<int?>(
                              value: b.branchId,
                              child: Text(
                                b.name,
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                overflow: TextOverflow.ellipsis,
                              ),
                            )),
                        const DropdownMenuItem<int?>(
                          value: null,
                          child: Text(
                            'Tất cả chi nhánh',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                      onChanged: (val) {
                        AppHaptics.selection();
                        setState(() => _selectedBranchId = val);
                        context.read<TableProvider>().loadTables(branchId: val);
                      },
                    ),
                  )
                : Text(
                    branchName,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
          ),
        ],
      ),
    );
  }

  // ── Status Filter Chips ────────────────────────
  Widget _buildFilterChips(AppLocalizations l10n) {
    final filters = <_TableFilter, String>{
      _TableFilter.all: l10n.translate('all'),
      _TableFilter.available: l10n.translate('available'),
      _TableFilter.occupied: l10n.translate('occupied'),
      _TableFilter.reserved: l10n.translate('reserved'),
    };
    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppTheme.marginMobile),
        children: filters.entries.map((entry) {
          final isSelected = _selectedFilter == entry.key;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(entry.value),
              selected: isSelected,
              onSelected: (_) {
                AppHaptics.selection();
                setState(() => _selectedFilter = entry.key);
              },
              selectedColor: AppColors.primary.withAlpha(25),
              checkmarkColor: AppColors.primary,
              labelStyle: TextStyle(
                color: isSelected ? AppColors.primary : AppColors.onSurfaceVariant,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                fontSize: 13,
              ),
              backgroundColor: AppColors.surfaceContainerLowest,
              side: BorderSide(
                color: isSelected ? AppColors.primary : AppColors.outlineVariant,
              ),
              shape: const StadiumBorder(),
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
            ),
          );
        }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Consumer<TableProvider>(
      builder: (context, provider, child) {
        // ── Loading state với Skeleton ──
        if (provider.isLoading && provider.tables.isEmpty) {
          return const TableGridShimmer();
        }

        final all = provider.tables;

        // ── Filter by status ──
        List<DiningTable> displayTables = all.where((t) {
          return switch (_selectedFilter) {
            _TableFilter.all => true,
            _TableFilter.available => t.status == 0,
            _TableFilter.occupied => t.status == 1,
            _TableFilter.reserved => t.status == 2,
          };
        }).toList();

        // ── Counts ──
        final availableCount = all.where((t) => t.status == 0).length;
        final occupiedCount  = all.where((t) => t.status == 1).length;
        final reservedCount  = all.where((t) => t.status == 2).length;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),

            // ─── Branch Filter & Indicator ──────────────────
            _buildBranchFilter(),
            const SizedBox(height: 8),

            // ─── Header Stats ────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppTheme.marginMobile),
              child: Row(
                children: [
                  _StatBadge(
                    count: availableCount,
                    label: l10n.translate('available'),
                    color: AppColors.tableAvailableFg,
                  ),
                  const SizedBox(width: 8),
                  _StatBadge(
                    count: occupiedCount,
                    label: l10n.translate('occupied'),
                    color: AppColors.tableOccupiedFg,
                  ),
                  const SizedBox(width: 8),
                  _StatBadge(
                    count: reservedCount,
                    label: l10n.translate('reserved'),
                    color: AppColors.tableReservedFg,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // ─── Status Filter Chips ─────────────────────────
            _buildFilterChips(l10n),
            const SizedBox(height: 14),

            // ─── Table Grid ──────────────────────────────────
            Expanded(
              child: provider.errorMessage != null
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.wifi_off_rounded, size: 48, color: AppColors.onSurfaceVariant.withAlpha(100)),
                          const SizedBox(height: 12),
                          Text(provider.errorMessage!, style: TextStyle(color: AppColors.onSurfaceVariant)),
                          const SizedBox(height: 16),
                          TextButton.icon(
                            onPressed: () => context.read<TableProvider>().loadTables(branchId: _selectedBranchId),
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text('Thử lại'),
                          ),
                        ],
                      ),
                    )
                  : displayTables.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.table_restaurant_rounded, size: 52, color: AppColors.outlineVariant),
                              const SizedBox(height: 12),
                              Text(
                                'Không có bàn nào',
                                style: TextStyle(color: AppColors.onSurfaceVariant, fontSize: 15),
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          color: AppColors.primary,
                          onRefresh: () => context
                              .read<TableProvider>()
                              .loadTables(branchId: _selectedBranchId),
                          child: GridView.builder(
                            padding: const EdgeInsets.fromLTRB(
                              AppTheme.marginMobile,
                              0,
                              AppTheme.marginMobile,
                              AppTheme.marginMobile,
                            ),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              childAspectRatio: 0.9,
                              crossAxisSpacing: AppTheme.gutterCard,
                              mainAxisSpacing: AppTheme.gutterCard,
                            ),
                            itemCount: displayTables.length,
                            itemBuilder: (context, index) => _SmartTableCard(
                              table: displayTables[index],
                              branchId: _selectedBranchId,
                            ),
                          ),
                        ),
            ),
          ],
        );
      },
    );
  }
}

// ─── Stat Badge ───────────────────────────────────────────────────
class _StatBadge extends StatelessWidget {
  final int count;
  final String label;
  final Color color;

  const _StatBadge({required this.count, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: color.withAlpha(20),
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(color: color.withAlpha(50)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$count',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: color),
            ),
            Text(
              label,
              style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Smart Table Card (Phase 2 upgrade) ──────────────────────────
class _SmartTableCard extends StatelessWidget {
  final DiningTable table;
  final int? branchId;

  const _SmartTableCard({required this.table, this.branchId});

  // Thời gian ngồi giả lập (dựa trên tableId seed — sẽ thay bằng API thực)
  // Trong thực tế sẽ lấy từ Order.createdAt
  Duration? _fakeSeatingDuration() {
    if (table.status != 1) return null;
    // Seed từ tableId để tạo thời gian ngồi giả lập khi chưa có field API
    final minutes = (table.tableId * 17 + 23) % 90;
    return Duration(minutes: minutes);
  }

  Color _timerColor(Duration d) {
    if (d.inMinutes < 30) return AppColors.kdsNormal;
    if (d.inMinutes < 60) return AppColors.kdsWarning;
    return AppColors.kdsCritical;
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    if (h > 0) return '${h}g${m.toString().padLeft(2, '0')}p';
    return '${m}p';
  }

  void _showQuickActions(BuildContext context, AppLocalizations l10n) {
    AppHaptics.medium();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _QuickActionSheet(table: table, branchId: branchId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final status = table.status;

    // Màu sắc theo trạng thái
    final bgColor = AppColors.tableStatusBg(status);
    final fgColor = AppColors.tableStatusColor(status);
    final borderColor = AppColors.tableStatusBorder(status);

    IconData statusIcon;
    String statusStr;
    switch (status) {
      case 1:
        statusIcon = Icons.restaurant_rounded;
        statusStr = l10n.translate('occupied');
        StatusType.occupied;
        break;
      case 2:
        statusIcon = Icons.event_rounded;
        statusStr = l10n.translate('reserved');
        break;
      default:
        statusIcon = Icons.check_circle_outline_rounded;
        statusStr = l10n.translate('available');
    }

    final statusType = status == 1
        ? StatusType.occupied
        : status == 2
            ? StatusType.reserved
            : StatusType.available;

    final seatingDuration = _fakeSeatingDuration();

    return GestureDetector(
      onTap: () async {
        AppHaptics.light();
        await _openTable(context, l10n);
      },
      onLongPress: () => _showQuickActions(context, l10n),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          border: Border.all(color: borderColor, width: status == 1 ? 1.5 : 1),
          boxShadow: status == 1 ? AppTheme.shadowLevel2 : AppTheme.shadowLevel1,
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Top Row: Icon khu vực + Chip trạng thái ──
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: bgColor,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Icon(statusIcon, size: 16, color: fgColor),
                  ),
                  StatusChip(label: statusStr, type: statusType),
                ],
              ),

              const Spacer(),

              // ── Tên bàn + Nhãn chi nhánh nếu xem tất cả ──
              Row(
                children: [
                  Expanded(
                    child: Text(
                      table.tableName,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (table.branchId != null && branchId == null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withAlpha(25),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'CN ${table.branchId}',
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 4),

              // ── Sức chứa + Timer ngồi ────────────────────
              Row(
                children: [
                  Icon(Icons.people_outline_rounded, size: 13, color: AppColors.onSurfaceVariant),
                  const SizedBox(width: 3),
                  Text(
                    '${table.capacity}',
                    style: TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant),
                  ),
                  if (seatingDuration != null) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _timerColor(seatingDuration).withAlpha(20),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.timer_outlined, size: 11, color: _timerColor(seatingDuration)),
                          const SizedBox(width: 3),
                          Text(
                            _formatDuration(seatingDuration),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: _timerColor(seatingDuration),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),

              // ── Gợi ý giữ lâu để mở menu nhanh ──────────
              if (status == 1) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.touch_app_outlined, size: 11, color: AppColors.onSurfaceVariant.withAlpha(120)),
                    const SizedBox(width: 3),
                    Text(
                      'Giữ để thao tác nhanh',
                      style: TextStyle(
                        fontSize: 10,
                        color: AppColors.onSurfaceVariant.withAlpha(120),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openTable(BuildContext context, AppLocalizations l10n) async {
    final orderProvider = context.read<OrderProvider>();
    final authService  = context.read<AuthService>();
    final tableProvider = context.read<TableProvider>();

    final accountId = authService.currentUser?.accountId;
    if (accountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng đăng nhập lại')),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
    );

    try {
      if (table.status == 1) {
        await orderProvider.fetchOpenOrderForTable(table.tableId);
      } else {
        await orderProvider.fetchOpenOrderForTable(table.tableId);
        if (orderProvider.currentOrder == null) {
          await orderProvider.createOrder(table.tableId, accountId);
        }
      }
    } finally {
      if (context.mounted) Navigator.pop(context);
    }

    if (!context.mounted) return;

    if (orderProvider.currentOrder != null) {
      if (table.status == 0 || table.status == 2) {
        tableProvider.updateTableStatus(table.tableId, 1);
      }
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => MenuOrderScreen(tableName: table.tableName),
        ),
      );
      if (context.mounted) {
        tableProvider.loadTables(branchId: table.branchId);
      }
    } else {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            orderProvider.error.isNotEmpty
                ? orderProvider.error
                : 'Không thể mở bàn. Vui lòng thử lại.',
          ),
        ),
      );
    }
  }
}

// ─── Quick Action Bottom Sheet ────────────────────────────────────
class _QuickActionSheet extends StatelessWidget {
  final DiningTable table;
  final int? branchId;

  const _QuickActionSheet({required this.table, this.branchId});

  @override
  Widget build(BuildContext context) {
    final isOccupied = table.status == 1;
    return Container(
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ──────────────────────────────────
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.tableStatusBg(table.status),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.table_restaurant_rounded,
                      color: AppColors.tableStatusColor(table.status),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        table.tableName,
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                      ),
                      Text(
                        '${table.capacity} chỗ ngồi',
                        style: TextStyle(fontSize: 13, color: AppColors.onSurfaceVariant),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 20),
              const Divider(height: 1),
              const SizedBox(height: 12),

              Text(
                'Thao tác nhanh',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.onSurfaceVariant,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 12),

              // ── Action tiles ────────────────────────────
              _ActionTile(
                icon: Icons.swap_horiz_rounded,
                iconColor: const Color(0xFF1565C0),
                iconBg: const Color(0xFFE3F2FD),
                label: 'Chuyển bàn',
                subtitle: 'Di chuyển order sang bàn khác',
                enabled: isOccupied,
                onTap: () {
                  AppHaptics.medium();
                  Navigator.pop(context);
                  _showTransferDialog(context);
                },
              ),
              const SizedBox(height: 10),
              _ActionTile(
                icon: Icons.call_merge_rounded,
                iconColor: const Color(0xFF7B1FA2),
                iconBg: const Color(0xFFF3E5F5),
                label: 'Gộp bàn',
                subtitle: 'Kết hợp 2 bàn thành một order',
                enabled: isOccupied,
                onTap: () {
                  AppHaptics.medium();
                  Navigator.pop(context);
                  _showMergeDialog(context);
                },
              ),
              const SizedBox(height: 10),
              _ActionTile(
                icon: Icons.receipt_long_rounded,
                iconColor: const Color(0xFF2E7D32),
                iconBg: const Color(0xFFE8F5E9),
                label: 'In phiếu tạm tính',
                subtitle: 'In bill tạm cho khách xem trước',
                enabled: isOccupied,
                onTap: () {
                  AppHaptics.medium();
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          const Icon(Icons.print_rounded, color: Colors.white, size: 18),
                          const SizedBox(width: 10),
                          Text('Đang gửi phiếu tạm tính ${table.tableName}...'),
                        ],
                      ),
                      backgroundColor: AppColors.success,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  );
                },
              ),
              const SizedBox(height: 10),
              _ActionTile(
                icon: Icons.call_split_rounded,
                iconColor: AppColors.splitBillBadge,
                iconBg: AppColors.splitBillBadge.withAlpha(20),
                label: 'Tách bill',
                subtitle: 'Chia hóa đơn theo món hoặc đều',
                enabled: isOccupied,
                onTap: () {
                  AppHaptics.medium();
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Tính năng tách bill — sắp ra mắt')),
                  );
                },
              ),

              const SizedBox(height: 16),

              // ── Cancel ──────────────────────────────────
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () {
                    AppHaptics.light();
                    Navigator.pop(context);
                  },
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      side: BorderSide(color: AppColors.outlineVariant),
                    ),
                  ),
                  child: const Text('Đóng', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showTransferDialog(BuildContext context) {
    final tableProvider = context.read<TableProvider>();
    final availableTables = tableProvider.tables
        .where((t) => t.tableId != table.tableId && t.status == 0)
        .toList();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusLg)),
        title: Row(
          children: [
            Icon(Icons.swap_horiz_rounded, color: const Color(0xFF1565C0), size: 22),
            const SizedBox(width: 10),
            const Text('Chuyển bàn'),
          ],
        ),
        content: availableTables.isEmpty
            ? const Text('Không có bàn trống nào để chuyển.')
            : SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Chọn bàn trống để chuyển order từ ${table.tableName}:',
                      style: TextStyle(fontSize: 13, color: AppColors.onSurfaceVariant),
                    ),
                    const SizedBox(height: 12),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 240),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: availableTables.length,
                        separatorBuilder: (context, index) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final t = availableTables[index];
                          return ListTile(
                            leading: const Icon(Icons.table_restaurant_rounded),
                            title: Text(t.tableName, style: const TextStyle(fontWeight: FontWeight.w600)),
                            subtitle: Text('${t.capacity} chỗ ngồi'),
                            trailing: const Icon(Icons.arrow_forward_rounded, size: 18),
                            onTap: () {
                              AppHaptics.medium();
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Đã chuyển order sang ${t.tableName}'),
                                  backgroundColor: AppColors.success,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
        ],
      ),
    );
  }

  void _showMergeDialog(BuildContext context) {
    final tableProvider = context.read<TableProvider>();
    final occupiedTables = tableProvider.tables
        .where((t) => t.tableId != table.tableId && t.status == 1)
        .toList();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusLg)),
        title: Row(
          children: [
            Icon(Icons.call_merge_rounded, color: const Color(0xFF7B1FA2), size: 22),
            const SizedBox(width: 10),
            const Text('Gộp bàn'),
          ],
        ),
        content: occupiedTables.isEmpty
            ? const Text('Không có bàn đang phục vụ nào để gộp.')
            : SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Chọn bàn để gộp vào ${table.tableName}:',
                      style: TextStyle(fontSize: 13, color: AppColors.onSurfaceVariant),
                    ),
                    const SizedBox(height: 12),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 240),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: occupiedTables.length,
                        separatorBuilder: (context, index) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final t = occupiedTables[index];
                          return ListTile(
                            leading: const Icon(Icons.restaurant_rounded, color: Color(0xFFE65100)),
                            title: Text(t.tableName, style: const TextStyle(fontWeight: FontWeight.w600)),
                            subtitle: Text('${t.capacity} chỗ ngồi · Đang phục vụ'),
                            trailing: const Icon(Icons.call_merge_rounded, size: 18),
                            onTap: () {
                              AppHaptics.medium();
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Đã gộp ${t.tableName} vào ${table.tableName}'),
                                  backgroundColor: const Color(0xFF7B1FA2),
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
        ],
      ),
    );
  }
}

// ─── Action Tile ──────────────────────────────────────────────────
class _ActionTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String label;
  final String subtitle;
  final bool enabled;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.label,
    required this.subtitle,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1.0 : 0.38,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            border: Border.all(color: AppColors.outlineVariant.withAlpha(60)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(9)),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: enabled ? AppColors.onSurfaceVariant : AppColors.outlineVariant,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
