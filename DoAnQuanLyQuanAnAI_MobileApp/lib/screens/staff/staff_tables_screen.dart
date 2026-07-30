import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:doanquanlyquananai_mobileapp/theme/app_colors.dart';
import 'package:doanquanlyquananai_mobileapp/theme/app_theme.dart';
import 'package:doanquanlyquananai_mobileapp/widgets/status_chip.dart';
import 'package:doanquanlyquananai_mobileapp/services/table_provider.dart';
import 'package:doanquanlyquananai_mobileapp/models/table/dining_table.dart';
import 'package:doanquanlyquananai_mobileapp/l10n/app_localizations.dart';
import 'package:doanquanlyquananai_mobileapp/services/order_provider.dart';
import 'package:doanquanlyquananai_mobileapp/services/auth_service.dart';
import 'package:doanquanlyquananai_mobileapp/screens/staff/menu_order_screen.dart';
import 'package:doanquanlyquananai_mobileapp/services/branch_service.dart';
import 'package:doanquanlyquananai_mobileapp/models/branch/branch.dart';
import 'package:doanquanlyquananai_mobileapp/config/constants.dart';

class StaffTablesScreen extends StatefulWidget {
  const StaffTablesScreen({super.key});

  @override
  State<StaffTablesScreen> createState() => _StaffTablesScreenState();
}

class _StaffTablesScreenState extends State<StaffTablesScreen> {
  String _selectedFilter = 'All';
  bool _isOwner = false;
  List<Branch> _branches = [];
  int? _selectedBranchId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initData();
    });
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

  Widget _buildBranchFilter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.marginMobile, vertical: 8),
      color: Colors.white,
      child: Row(
        children: [
          const Icon(Icons.store_rounded, color: AppColors.primary, size: 20),
          const SizedBox(width: 8),
          const Text('Chi nhánh:', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButton<int?>(
              value: _selectedBranchId,
              isExpanded: true,
              underline: const SizedBox(),
              items: _branches.map((b) => DropdownMenuItem<int?>(
                    value: b.branchId,
                    child: Text(b.name),
                  )).toList(),
              onChanged: (val) {
                setState(() {
                  _selectedBranchId = val;
                });
                context.read<TableProvider>().loadTables(branchId: val);
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    
    return Consumer<TableProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading && provider.tables.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        final tables = provider.tables;
        final availableCount = tables.where((t) => t.status == 0).length;
        final occupiedCount = tables.where((t) => t.status == 1).length;
        final reservedCount = tables.where((t) => t.status == 2).length;

        List<DiningTable> filteredTables = tables;
        if (_selectedFilter != 'All') {
          final filterStatus = _selectedFilter == 'Available' ? 0 : (_selectedFilter == 'Occupied' ? 1 : 2);
          filteredTables = tables.where((t) => t.status == filterStatus).toList();
        }

        return Column(
      children: [
        if (_isOwner) _buildBranchFilter(),
        // ─── Header Stats ──────────────────────────────
        Container(
          padding: const EdgeInsets.fromLTRB(AppTheme.marginMobile, 8, AppTheme.marginMobile, 16),
          child: Row(
            children: [
              _StatBadge(count: availableCount, label: l10n.translate('available'), color: AppColors.chipPaid),
              const SizedBox(width: 10),
              _StatBadge(count: occupiedCount, label: l10n.translate('occupied'), color: const Color(0xFFE65100)),
              const SizedBox(width: 10),
              _StatBadge(count: reservedCount, label: l10n.translate('reserved'), color: const Color(0xFF1565C0)),
            ],
          ),
        ),

        // ─── Filter Chips ──────────────────────────────
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.marginMobile),
            children: ['All', 'Available', 'Occupied', 'Reserved'].map((filter) {
              String localizedFilter = filter;
              if (filter == 'All') localizedFilter = l10n.translate('all');
              if (filter == 'Available') localizedFilter = l10n.translate('available');
              if (filter == 'Occupied') localizedFilter = l10n.translate('occupied');
              if (filter == 'Reserved') localizedFilter = l10n.translate('reserved');

              final isSelected = _selectedFilter == filter;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(localizedFilter),
                  selected: isSelected,
                  onSelected: (selected) => setState(() => _selectedFilter = filter),
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
                ),
              );
            }).toList(),
          ),
        ),

        const SizedBox(height: 16),

        // ─── Table Grid ────────────────────────────────
        Expanded(
          child: provider.errorMessage != null 
            ? Center(child: Text(provider.errorMessage!))
            : GridView.builder(
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.marginMobile),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 1.1,
              crossAxisSpacing: AppTheme.gutterCard,
              mainAxisSpacing: AppTheme.gutterCard,
            ),
            itemCount: filteredTables.length,
            itemBuilder: (context, index) {
              return _TableCard(table: filteredTables[index]);
            },
          ),
        ),
      ],
    );
    });
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
          border: Border.all(color: color.withAlpha(40)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$count',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: color,
              ),
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

class _TableCard extends StatelessWidget {
  final DiningTable table;

  const _TableCard({required this.table});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final status = table.status; // 0: available, 1: occupied, 2: reserved

    Color bgColor;
    StatusType statusType;
    IconData statusIcon;
    String statusStr;

    switch (status) {
      case 1:
        bgColor = AppColors.tableOccupied;
        statusType = StatusType.occupied;
        statusIcon = Icons.restaurant_rounded;
        statusStr = l10n.translate('occupied');
        break;
      case 2:
        bgColor = AppColors.tableReserved;
        statusType = StatusType.reserved;
        statusIcon = Icons.event_rounded;
        statusStr = l10n.translate('reserved');
        break;
      default:
        bgColor = AppColors.tableAvailable;
        statusType = StatusType.available;
        statusIcon = Icons.check_circle_outline_rounded;
        statusStr = l10n.translate('available');
    }

    return GestureDetector(
      onTap: () async {
        final orderProvider = context.read<OrderProvider>();
        final authService = context.read<AuthService>();
        final tableProvider = context.read<TableProvider>();
        
        final accountId = authService.currentUser?.accountId;
        if (accountId == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Vui lòng đăng nhập lại')),
          );
          return;
        }

        // Hiển thị vòng xoay loading để ngăn chặn click đúp / xung đột trạng thái
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          ),
        );

        try {
          if (status == 1) { // Occupied
            await orderProvider.fetchOpenOrderForTable(table.tableId);
          } else if (status == 0) { // Available
            await orderProvider.createOrder(table.tableId, accountId);
          }
        } finally {
          if (context.mounted) {
            Navigator.pop(context); // Tắt loading dialog
          }
        }
        
        if (!context.mounted) return;
        
        if (orderProvider.currentOrder != null) {
          // Cập nhật trạng thái bàn cục bộ trước để giao diện lập tức phản ánh
          if (status == 0) {
            tableProvider.updateTableStatus(table.tableId, 1);
          }

          // Điều hướng đến màn hình chọn món và đợi kết quả
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => MenuOrderScreen(tableName: table.tableName),
            ),
          );
          
          // Khi quay trở lại (từ việc đóng màn hình hoặc thanh toán), tải lại danh sách bàn thực tế từ server
          if (context.mounted) {
            tableProvider.loadTables(branchId: table.branchId);
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                orderProvider.error.isNotEmpty 
                    ? orderProvider.error 
                    : 'Không thể mở bàn. Vui lòng thử lại.'
              ),
            ),
          );
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          border: Border.all(
            color: status == 1 ? const Color(0xFFE65100).withAlpha(50) : AppColors.outlineVariant.withAlpha(60),
            width: status == 1 ? 1.5 : 1,
          ),
          boxShadow: AppTheme.shadowLevel1,
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: bgColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(statusIcon, size: 18, color: statusType == StatusType.available
                        ? AppColors.chipPaid
                        : statusType == StatusType.occupied
                            ? const Color(0xFFE65100)
                            : const Color(0xFF1565C0)),
                  ),
                  StatusChip(label: statusStr, type: statusType),
                ],
              ),
              const Spacer(),
              Text(
                table.tableName,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 2),
              Text(
                '${table.capacity} ${l10n.translate('seats')}',
                style: TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
