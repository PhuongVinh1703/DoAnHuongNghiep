import 'package:flutter/material.dart';
import 'package:doanquanlyquananai_mobileapp/theme/app_colors.dart';
import 'package:doanquanlyquananai_mobileapp/theme/app_theme.dart';
import 'package:doanquanlyquananai_mobileapp/services/customer_service.dart';
import 'package:doanquanlyquananai_mobileapp/models/customer/customer.dart';
import 'package:doanquanlyquananai_mobileapp/widgets/common/app_snackbar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CustomerManagementScreen extends StatefulWidget {
  const CustomerManagementScreen({super.key});

  @override
  State<CustomerManagementScreen> createState() =>
      _CustomerManagementScreenState();
}

class _CustomerManagementScreenState extends State<CustomerManagementScreen> {
  final CustomerService _customerService = CustomerService();
  bool _isLoading = true;
  List<Customer> _customers = [];
  String _searchQuery = '';
  final _searchCtrl = TextEditingController();

  RealtimeChannel? _realtimeChannel;

  @override
  void initState() {
    super.initState();
    _loadCustomers();
    _setupRealtime();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    if (_realtimeChannel != null) {
      Supabase.instance.client.removeChannel(_realtimeChannel!);
    }
    super.dispose();
  }

  void _setupRealtime() {
    _realtimeChannel = Supabase.instance.client
        .channel('customers-realtime-channel')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'Customers',
          callback: (payload) {
            if (mounted) {
              _loadCustomers(showLoading: false);
            }
          },
        );
    _realtimeChannel!.subscribe();
  }

  Future<void> _loadCustomers({bool showLoading = true}) async {
    if (showLoading) {
      setState(() => _isLoading = true);
    }
    final res = await _customerService.searchCustomers(search: _searchQuery);
    if (res.isSuccess) {
      setState(() {
        _customers = res.data ?? [];
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
      if (mounted) AppSnackbar.showError(context, res.error!);
    }
  }

  Future<void> _toggleStatus(Customer customer) async {
    final action = customer.isActive ? 'Khóa' : 'Mở khóa';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận'),
        content: Text(
          'Bạn có chắc muốn $action tài khoản khách hàng ${customer.fullName}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Đồng ý'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final res = await _customerService.toggleStatus(customer.customerId);
    if (res.isSuccess) {
      if (mounted) AppSnackbar.showSuccess(context, 'Đã cập nhật trạng thái');
      _loadCustomers();
    } else {
      if (mounted) AppSnackbar.showError(context, res.error!);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text(
          'Quản lý Khách hàng',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadCustomers,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppTheme.marginMobile),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Tìm theo tên hoặc SĐT...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _searchQuery = '');
                          _loadCustomers();
                        },
                      )
                    : null,
                filled: true,
                fillColor: AppColors.surfaceContainerLowest,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (val) {
                setState(() => _searchQuery = val);
              },
              onSubmitted: (_) => _loadCustomers(),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _customers.isEmpty
                ? const Center(child: Text('Không tìm thấy khách hàng nào'))
                : RefreshIndicator(
                    onRefresh: _loadCustomers,
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.marginMobile,
                      ),
                      itemCount: _customers.length,
                      itemBuilder: (context, index) {
                        final customer = _customers[index];
                        return _CustomerCard(
                          customer: customer,
                          onToggleStatus: () => _toggleStatus(customer),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _CustomerCard extends StatelessWidget {
  final Customer customer;
  final VoidCallback onToggleStatus;

  const _CustomerCard({required this.customer, required this.onToggleStatus});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppColors.outlineVariant.withAlpha(50)),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: AppColors.primaryContainer,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              customer.fullName.isNotEmpty
                  ? customer.fullName[0].toUpperCase()
                  : 'C',
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  customer.fullName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  customer.phone.isEmpty ? 'Không có SĐT' : customer.phone,
                  style: TextStyle(
                    color: AppColors.onSurfaceVariant,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Color(
                          int.parse(customer.tierColor.replaceAll('#', '0xff')),
                        ).withAlpha(30),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        customer.tierDisplay,
                        style: TextStyle(
                          color: Color(
                            int.parse(
                              customer.tierColor.replaceAll('#', '0xff'),
                            ),
                          ),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${customer.points} điểm',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: customer.isActive
                      ? AppColors.successContainer
                      : AppColors.errorContainer,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  customer.isActive ? 'Hoạt động' : 'Đã khóa',
                  style: TextStyle(
                    color: customer.isActive
                        ? AppColors.success
                        : AppColors.error,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              IconButton(
                icon: Icon(
                  customer.isActive
                      ? Icons.lock_outline_rounded
                      : Icons.lock_open_rounded,
                  color: customer.isActive
                      ? AppColors.error
                      : AppColors.success,
                ),
                onPressed: onToggleStatus,
                tooltip: customer.isActive
                    ? 'Khóa khách hàng'
                    : 'Mở khóa khách hàng',
              ),
            ],
          ),
        ],
      ),
    );
  }
}
