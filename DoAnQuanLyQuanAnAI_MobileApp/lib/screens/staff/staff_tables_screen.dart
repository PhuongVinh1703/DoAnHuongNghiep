import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:doanquanlyquananai_mobileapp/theme/app_colors.dart';
import 'package:doanquanlyquananai_mobileapp/theme/app_theme.dart';
import 'package:doanquanlyquananai_mobileapp/theme/app_haptics.dart';
import 'package:doanquanlyquananai_mobileapp/widgets/status_chip.dart';
import 'package:doanquanlyquananai_mobileapp/widgets/common/app_shimmer.dart';
import 'package:doanquanlyquananai_mobileapp/services/table_provider.dart';
import 'package:doanquanlyquananai_mobileapp/services/table_service.dart';
import 'package:doanquanlyquananai_mobileapp/services/reservation_service.dart';
import 'package:doanquanlyquananai_mobileapp/models/table/dining_table.dart';
import 'package:doanquanlyquananai_mobileapp/models/reservation/reservation.dart';
import 'package:doanquanlyquananai_mobileapp/models/order/order.dart';
import 'package:doanquanlyquananai_mobileapp/l10n/app_localizations.dart';
import 'package:doanquanlyquananai_mobileapp/services/order_provider.dart';
import 'package:doanquanlyquananai_mobileapp/services/order_service.dart';
import 'package:doanquanlyquananai_mobileapp/services/auth_service.dart';
import 'package:doanquanlyquananai_mobileapp/screens/staff/menu_order_screen.dart';
import 'package:doanquanlyquananai_mobileapp/screens/staff/checkout_screen.dart';
import 'package:doanquanlyquananai_mobileapp/services/branch_service.dart';
import 'package:doanquanlyquananai_mobileapp/models/branch/branch.dart';
import 'package:doanquanlyquananai_mobileapp/config/constants.dart';
import 'package:doanquanlyquananai_mobileapp/core/utils/ai_tracker.dart';

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
  bool _isOwner = false;
  List<Branch> _branches = [];
  int? _selectedBranchId;

  static const List<String> _zoneLabels = ['Tất cả', 'Tầng 1', 'Tầng 2', 'Sân vườn', 'VIP'];
  int _selectedZoneIndex = 0;

  Timer? _clockTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initData());
    _clockTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      if (mounted) {
        context.read<TableProvider>().loadTables(
              branchId: _selectedBranchId,
              showLoading: false,
            );
      }
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
    _isOwner = (user?.role == AppConstants.roleOwner);

    if (_isOwner) {
      final res = await BranchService().getBranches();
      if (res.isSuccess && res.data != null && res.data!.isNotEmpty) {
        setState(() {
          _branches = res.data!;
          _selectedBranchId = _branches.first.branchId;
        });
      }
    } else {
      _selectedBranchId = user?.branchId;
    }

    if (mounted) {
      context.read<TableProvider>().loadTables(branchId: _selectedBranchId);
    }
  }

  bool _tableMatchesZone(DiningTable t) {
    if (_selectedZoneIndex == 0) return true;
    final name = t.tableName.toLowerCase();
    switch (_selectedZoneIndex) {
      case 1: return name.contains('t1') || name.contains('tầng 1') || name.contains('tang 1') || name.contains('f1');
      case 2: return name.contains('t2') || name.contains('tầng 2') || name.contains('tang 2') || name.contains('f2');
      case 3: return name.contains('sv') || name.contains('sân vườn') || name.contains('san vuon') || name.contains('garden');
      case 4: return name.contains('vip');
      default: return true;
    }
  }

  Widget _buildBranchFilter() {
    return Container(
      margin: const EdgeInsets.fromLTRB(AppTheme.marginMobile, 0, AppTheme.marginMobile, 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: AppTheme.cardDecoration(
        color: AppColors.surfaceContainerLowest,
        radius: AppTheme.radiusMd,
      ),
      child: Row(
        children: [
          const Icon(Icons.store_rounded, color: AppColors.primary, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int?>(
                value: _selectedBranchId,
                isExpanded: true,
                hint: const Text('Chọn chi nhánh'),
                items: _branches
                    .map((b) => DropdownMenuItem<int?>(
                          value: b.branchId,
                          child: Text(b.name, style: const TextStyle(fontSize: 14)),
                        ))
                    .toList(),
                onChanged: (val) {
                  AppHaptics.selection();
                  setState(() => _selectedBranchId = val);
                  context.read<TableProvider>().loadTables(branchId: val);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildZoneTabs() {
    return SizedBox(
      height: 36,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppTheme.marginMobile),
        itemCount: _zoneLabels.length,
        itemBuilder: (context, index) {
          final isSelected = _selectedZoneIndex == index;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () {
                AppHaptics.selection();
                setState(() => _selectedZoneIndex = index);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary : AppColors.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                  border: Border.all(
                    color: isSelected ? AppColors.primary : AppColors.outlineVariant,
                  ),
                  boxShadow: isSelected ? AppTheme.shadowLevel2 : [],
                ),
                child: Text(
                  _zoneLabels[index],
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? Colors.white : AppColors.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

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
        if (provider.isLoading && provider.tables.isEmpty) {
          return const TableGridShimmer();
        }

        final all = provider.tables;

        List<DiningTable> displayTables = all.where((t) {
          final zoneMatch = _tableMatchesZone(t);
          final statusMatch = switch (_selectedFilter) {
            _TableFilter.all => true,
            _TableFilter.available => t.status == 0,
            _TableFilter.occupied => t.status == 1,
            _TableFilter.reserved => t.status == 2,
          };
          return zoneMatch && statusMatch;
        }).toList();

        final availableCount = all.where((t) => t.status == 0).length;
        final occupiedCount  = all.where((t) => t.status == 1).length;
        final reservedCount  = all.where((t) => t.status == 2).length;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),

            if (_isOwner) ...[
              _buildBranchFilter(),
              const SizedBox(height: 8),
            ],

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

            _buildZoneTabs(),
            const SizedBox(height: 10),

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
                          Text(provider.errorMessage!, style: const TextStyle(color: AppColors.onSurfaceVariant)),
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
                              const Icon(Icons.table_restaurant_rounded, size: 52, color: AppColors.outlineVariant),
                              const SizedBox(height: 12),
                              const Text(
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
                              childAspectRatio: 0.88,
                              crossAxisSpacing: AppTheme.gutterCard,
                              mainAxisSpacing: AppTheme.gutterCard,
                            ),
                            itemCount: displayTables.length,
                            itemBuilder: (context, index) {
                              final t = displayTables[index];
                              return _SmartTableCard(
                                table: t,
                                reservation: provider.getReservationForTable(t.tableId),
                                branchId: _selectedBranchId,
                              );
                            },
                          ),
                        ),
            ),
          ],
        );
      },
    );
  }
}

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

// ─── Smart Table Card ────────────────────────────────────────────
class _SmartTableCard extends StatelessWidget {
  final DiningTable table;
  final Reservation? reservation;
  final int? branchId;

  const _SmartTableCard({
    required this.table,
    this.reservation,
    this.branchId,
  });

  Duration? _fakeSeatingDuration() {
    if (table.status != 1) return null;
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final status = table.status;

    final bgColor = AppColors.tableStatusBg(status);
    final fgColor = AppColors.tableStatusColor(status);
    final borderColor = AppColors.tableStatusBorder(status);

    IconData statusIcon;
    String statusStr;
    switch (status) {
      case 1:
        statusIcon = Icons.restaurant_rounded;
        statusStr = l10n.translate('occupied');
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
    final res = reservation;
    final int? minsUntilRes = res?.reservedAt.difference(DateTime.now()).inMinutes;
    final bool isOverdueRes = minsUntilRes != null && minsUntilRes < -15;
    final bool showUpcomingWarning = res != null && minsUntilRes != null && minsUntilRes <= 120;

    return GestureDetector(
      onTap: () async {
        AppHaptics.light();
        await _handleTableTap(context, l10n);
      },
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

              Row(
                children: [
                  const Icon(Icons.people_outline_rounded, size: 13, color: AppColors.onSurfaceVariant),
                  const SizedBox(width: 3),
                  Text(
                    '${table.capacity}',
                    style: const TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant),
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

              // Cảnh báo lịch đặt bàn sắp tới hoặc quá giờ giữ bàn (15 phút)
              if (showUpcomingWarning) ...[
                const SizedBox(height: 5),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: isOverdueRes
                        ? Colors.red.withAlpha(22)
                        : const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    isOverdueRes
                        ? '⚠️ Quá hẹn ${-minsUntilRes}p (${res.customerName})'
                        : '⏰ Đặt ${DateFormat('HH:mm').format(res.reservedAt)} (${res.guestCount} khách)',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: isOverdueRes ? Colors.red[800] : const Color(0xFFB45309),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ] else if (status == 1) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.receipt_long_rounded, size: 11, color: AppColors.primary.withAlpha(180)),
                    const SizedBox(width: 4),
                    Text(
                      'Chạm để xem món đã gọi',
                      style: TextStyle(
                        fontSize: 10,
                        color: AppColors.primary.withAlpha(180),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ] else if (status == 2) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.event_available_rounded, size: 11, color: Colors.amber[900]),
                    const SizedBox(width: 4),
                    Text(
                      'Chạm để đón khách / hủy giữ',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.amber[900],
                        fontWeight: FontWeight.w600,
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

  /// Luồng chuẩn nhà hàng:
  /// - Nếu bàn Đã đặt (Status = 2): Mở bảng "Thông tin khách đặt bàn trước" để Check-in mở bàn (tự gắn SĐT tích điểm) hoặc Giải phóng bàn (No-show).
  /// - Nếu bàn Trống (Status = 0): Mở bàn & chuyển thẳng vào màn hình Thực đơn chọn món (MenuOrderScreen).
  /// - Nếu bàn Đang có khách (Status = 1): Mở BottomSheet "Chi tiết các món bàn đang dùng" để xem tiến độ Bếp,
  ///   có nút [➕ Gọi thêm / Sửa món] và nút [💳 Báo quầy tính tiền] (hoặc [Thanh toán] nếu là Thu ngân).
  Future<void> _handleTableTap(BuildContext context, AppLocalizations l10n) async {
    final orderProvider = context.read<OrderProvider>();
    final authService   = context.read<AuthService>();
    final tableProvider = context.read<TableProvider>();

    final accountId = authService.currentUser?.accountId;
    final userRole  = authService.currentUser?.role ?? AppConstants.roleStaff;
    if (accountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng đăng nhập lại')),
      );
      return;
    }

    // 1. Nếu bàn đang ở trạng thái ĐÃ ĐẶT (Status = 2) -> Mở bảng Check-in / Giải phóng bàn
    if (table.status == 2) {
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (sheetCtx) => _ReservedTableActionSheet(
          table: table,
          reservation: reservation,
          onReleaseTable: () async {
            Navigator.pop(sheetCtx);
            await TableService().updateStatus(table.tableId, 0);
            if (reservation != null) {
              await ReservationService().cancelReservation(reservation!.reservationId);
            }
            if (context.mounted) {
              tableProvider.updateTableStatus(table.tableId, 0);
              tableProvider.loadTables(branchId: branchId, showLoading: false);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Đã giải phóng ${table.tableName} về trạng thái Trống!'),
                  backgroundColor: AppColors.primary,
                ),
              );
            }
          },
          onCheckInAndOpenTable: () async {
            Navigator.pop(sheetCtx);
            await _openTableAndNavigateToMenu(
              context: context,
              orderProvider: orderProvider,
              tableProvider: tableProvider,
              accountId: accountId,
              reservationToCheckIn: reservation,
            );
          },
        ),
      );
      return;
    }

    // 2. Nếu bàn Trống (0) nhưng có lịch đặt sắp diễn ra trong vòng 90 phút tới -> Cảnh báo xác nhận trước khi xếp khách vãng lai
    if (table.status == 0 && reservation != null) {
      final minsUntil = reservation!.reservedAt.difference(DateTime.now()).inMinutes;
      if (minsUntil > 0 && minsUntil <= 90) {
        final proceed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('⚠️ Cảnh báo bàn sắp có khách đặt'),
            content: Text(
              '${table.tableName} có lịch đặt của khách "${reservation!.customerName}" (${reservation!.guestCount} người) lúc ${DateFormat('HH:mm').format(reservation!.reservedAt)} (còn $minsUntil phút nữa).\n\nBạn muốn mở bàn cho chính khách đặt này đến sớm hay xếp khách vãng lai?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, null),
                child: const Text('Đóng'),
              ),
              OutlinedButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Khách vãng lai'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Khách đặt đến sớm'),
              ),
            ],
          ),
        );
        if (proceed == null || !context.mounted) return;
        await _openTableAndNavigateToMenu(
          context: context,
          orderProvider: orderProvider,
          tableProvider: tableProvider,
          accountId: accountId,
          reservationToCheckIn: proceed ? reservation : null,
        );
        return;
      }
    }

    // 3. Luồng mở bàn trống bình thường hoặc xem bàn đang ăn (Status = 1)
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
    );

    try {
      await orderProvider.fetchOpenOrderForTable(table.tableId);
      if (orderProvider.currentOrder == null) {
        await orderProvider.createOrder(table.tableId, accountId);
      }
    } finally {
      if (context.mounted) Navigator.pop(context);
    }

    if (!context.mounted) return;

    final currentOrder = orderProvider.currentOrder;
    if (currentOrder != null) {
      if (table.status == 0) {
        tableProvider.updateTableStatus(table.tableId, 1);
      }

      if (table.status == 1 && currentOrder.items.isNotEmpty) {
        await showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (sheetCtx) => _TableOrderSummarySheet(
            table: table,
            order: currentOrder,
            userRole: userRole,
            onAddMoreItems: () async {
              Navigator.pop(sheetCtx);
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => MenuOrderScreen(tableName: table.tableName),
                ),
              );
              if (context.mounted) {
                tableProvider.loadTables(branchId: branchId);
              }
            },
            onRequestBillOrCheckout: () async {
              Navigator.pop(sheetCtx);
              if (userRole == AppConstants.roleStaff) {
                await orderProvider.requestPaymentForCurrentOrder();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('💳 Đã báo Quầy Thu ngân tính tiền cho ${table.tableName}!'),
                      backgroundColor: AppColors.primary,
                    ),
                  );
                }
              } else {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CheckoutScreen(order: currentOrder),
                  ),
                );
                if (context.mounted) {
                  tableProvider.loadTables(branchId: branchId);
                }
              }
            },
          ),
        );
      } else {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MenuOrderScreen(tableName: table.tableName),
          ),
        );
        if (context.mounted) {
          tableProvider.loadTables(branchId: branchId);
        }
      }
    } else {
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

  Future<void> _openTableAndNavigateToMenu({
    required BuildContext context,
    required OrderProvider orderProvider,
    required TableProvider tableProvider,
    required int accountId,
    Reservation? reservationToCheckIn,
  }) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
    );

    final String? initialNote = (reservationToCheckIn != null &&
            reservationToCheckIn.customerPhone.trim().isNotEmpty)
        ? AiTracker.formatCustomerPhoneTag(reservationToCheckIn.customerPhone)
        : null;

    try {
      // Đánh dấu phiếu đặt bàn đã nhận bàn ([SEATED])
      if (reservationToCheckIn != null) {
        await ReservationService().updateStatus(
          reservationToCheckIn.reservationId,
          1,
          managerNote: reservationToCheckIn.markSeatedManagerNote(),
        );
      }

      await orderProvider.fetchOpenOrderForTable(table.tableId);
      if (orderProvider.currentOrder == null) {
        await orderProvider.createOrder(
          table.tableId,
          accountId,
          note: initialNote,
        );
      } else if (initialNote != null && initialNote.isNotEmpty) {
        // Nếu bàn đã có order nháp, gắn thêm SĐT khách vào note
        final updatedNote = AiTracker.buildUpdatedNote(
          currentNote: orderProvider.currentOrder!.note,
          customerPhone: reservationToCheckIn!.customerPhone,
          tracker: orderProvider.getAiTracker(),
        );
        await OrderService().updateOrderNote(
          orderProvider.currentOrder!.orderId,
          updatedNote,
        );
        await orderProvider.fetchOpenOrderForTable(table.tableId);
      }
    } finally {
      if (context.mounted) Navigator.pop(context);
    }

    if (!context.mounted) return;
    if (orderProvider.currentOrder != null) {
      tableProvider.updateTableStatus(table.tableId, 1);
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MenuOrderScreen(tableName: table.tableName),
        ),
      );
      if (context.mounted) {
        tableProvider.loadTables(branchId: branchId);
      }
    }
  }
}

// ─── Bảng Đón Khách Đặt Bàn Trước / Giải Phóng Bàn (Check-in / No-Show) ──
class _ReservedTableActionSheet extends StatelessWidget {
  final DiningTable table;
  final Reservation? reservation;
  final VoidCallback onReleaseTable;
  final VoidCallback onCheckInAndOpenTable;

  const _ReservedTableActionSheet({
    required this.table,
    this.reservation,
    required this.onReleaseTable,
    required this.onCheckInAndOpenTable,
  });

  @override
  Widget build(BuildContext context) {
    final r = reservation;
    final minsUntil = r?.reservedAt.difference(DateTime.now()).inMinutes;
    final isOverdue = minsUntil != null && minsUntil < -15;
    final internalTask = r?.internalStaffTask;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 22),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.event_seat_rounded,
                    color: Color(0xFFB45309),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${table.tableName} — Đang giữ chỗ',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                      ),
                      Text(
                        'Sức chứa tiêu chuẩn: ${table.capacity} khách',
                        style: const TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 14),

            if (r != null) ...[
              if (isOverdue)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.red[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: Colors.red[700], size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Đã quá giờ hẹn ${-minsUntil} phút (Quy định giữ bàn tối đa 15 phút). Bạn có thể liên hệ SĐT khách hoặc giải phóng bàn.',
                          style: TextStyle(fontSize: 12, color: Colors.red[800], fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),

              _infoRow(Icons.person_rounded, 'Khách đặt:', r.customerName),
              const SizedBox(height: 8),
              _infoRow(Icons.phone_rounded, 'Số điện thoại:', r.customerPhone),
              const SizedBox(height: 8),
              _infoRow(
                Icons.access_time_filled_rounded,
                'Giờ hẹn đến:',
                DateFormat('HH:mm — dd/MM/yyyy').format(r.reservedAt),
              ),
              const SizedBox(height: 8),
              _infoRow(Icons.groups_rounded, 'Số lượng khách:', '${r.guestCount} người'),
              if (r.note != null && r.note!.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                _infoRow(Icons.sticky_note_2_rounded, 'Yêu cầu của khách:', r.note!),
              ],
              if (internalTask != null && internalTask.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withAlpha(15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.primary.withAlpha(50)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.assignment_ind_rounded, size: 15, color: AppColors.primary),
                          SizedBox(width: 6),
                          Text(
                            'CHỈ DẪN NỘI BỘ TỪ QUẢN LÝ',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        internalTask,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 8),
              const Text(
                '💡 Khi bấm "Khách nhận bàn", hệ thống tự động gắn SĐT khách vào đơn hàng để tích điểm tại Quầy Thu ngân.',
                style: TextStyle(fontSize: 11, color: Colors.grey, fontStyle: FontStyle.italic),
              ),
            ] else ...[
              const Text(
                'Bàn này đang được đánh dấu Giữ chỗ trước. Bạn muốn mở bàn đón khách hay giải phóng bàn về trạng thái Trống?',
                style: TextStyle(fontSize: 13, color: AppColors.onSurfaceVariant),
              ),
            ],

            const SizedBox(height: 18),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onReleaseTable,
                    icon: const Icon(Icons.event_busy_rounded, size: 18),
                    label: const Text(
                      'Khách không đến\n(Giải phóng bàn)',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.error, width: 1.4),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onCheckInAndOpenTable,
                    icon: const Icon(Icons.how_to_reg_rounded, size: 18),
                    label: const Text(
                      'Khách nhận bàn\n(Mở bàn gọi món)',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppColors.primary),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(fontSize: 13, color: AppColors.onSurfaceVariant),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

// ─── Bảng Xem Chi Tiết Món Đã Gọi Của Bàn (Chuẩn POS Nhà Hàng) ──
class _TableOrderSummarySheet extends StatelessWidget {
  final DiningTable table;
  final OrderModel order;
  final int userRole;
  final VoidCallback onAddMoreItems;
  final VoidCallback onRequestBillOrCheckout;

  const _TableOrderSummarySheet({
    required this.table,
    required this.order,
    required this.userRole,
    required this.onAddMoreItems,
    required this.onRequestBillOrCheckout,
  });

  String _fmtCurrency(double amount) {
    final f = amount.toInt().toString().replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.');
    return '${f}đ';
  }

  @override
  Widget build(BuildContext context) {
    final isStaff = userRole == AppConstants.roleStaff;
    final isBillReq = AiTracker.isPaymentRequested(order.note);
    final linkedPhone = AiTracker.extractCustomerPhone(order.note);
    final totalQty = order.items.fold<int>(0, (s, i) => s + i.quantity);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.82,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ── Header thông tin bàn & đơn ──
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withAlpha(20),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.table_restaurant_rounded,
                          color: AppColors.primary, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              table.tableName,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceContainerHigh,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Đơn #${order.orderId}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Mở lúc ${order.openedAt.hour.toString().padLeft(2, '0')}:${order.openedAt.minute.toString().padLeft(2, '0')} · $totalQty phần${linkedPhone != null ? ' · KH: $linkedPhone' : ''}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                if (isBillReq)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.amber[700],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      '💳 Đã báo bill',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 10),

            const Text(
              'DANH SÁCH MÓN BÀN ĐÃ GỌI',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Colors.grey,
                letterSpacing: 0.6,
              ),
            ),
            const SizedBox(height: 8),

            // ── Danh sách món ăn & tiến độ Bếp ──
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: order.items.length,
                separatorBuilder: (_, _) => const Divider(height: 12),
                itemBuilder: (context, idx) {
                  final item = order.items[idx];
                  final isDone = AiTracker.isItemDone(item.note);
                  final cleanNote = AiTracker.cleanDisplayNote(item.note);

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withAlpha(18),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'x${item.quantity}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.itemName,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (cleanNote.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  'Ghi chú: $cleanNote',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.amber[900],
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: isDone
                                    ? const Color(0xFFDCFCE7)
                                    : const Color(0xFFFEF3C7),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                isDone ? '✅ Bếp đã lên món' : '⏳ Bếp đang chế biến',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: isDone
                                      ? const Color(0xFF15803D)
                                      : const Color(0xFFB45309),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        _fmtCurrency(item.unitPrice * item.quantity),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),

            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),

            // ── Tổng tạm tính ──
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Tạm tính (chưa VAT):',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                Text(
                  _fmtCurrency(order.subtotal),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── Hai nút hành động chính chuẩn nhà hàng ──
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onAddMoreItems,
                    icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
                    label: const Text(
                      'Gọi thêm / Sửa món',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary, width: 1.5),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onRequestBillOrCheckout,
                    icon: Icon(
                      isStaff
                          ? Icons.point_of_sale_rounded
                          : Icons.receipt_long_rounded,
                      size: 18,
                    ),
                    label: Text(
                      isStaff ? 'Báo quầy tính tiền' : 'Thanh toán ngay',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
