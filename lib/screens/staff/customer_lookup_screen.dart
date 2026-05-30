import 'package:flutter/material.dart';
import 'package:doanquanlyquananai_mobileapp/core/constants/app_colors.dart';
import 'package:doanquanlyquananai_mobileapp/models/customer/customer.dart';
import 'package:doanquanlyquananai_mobileapp/services/customer_service.dart';
import 'package:doanquanlyquananai_mobileapp/widgets/common/app_button.dart';
import 'package:doanquanlyquananai_mobileapp/widgets/common/app_snackbar.dart';

class CustomerLookupScreen extends StatefulWidget {
  final void Function(Customer customer)? onCustomerSelected;

  const CustomerLookupScreen({super.key, this.onCustomerSelected});

  @override
  State<CustomerLookupScreen> createState() => _CustomerLookupScreenState();
}

class _CustomerLookupScreenState extends State<CustomerLookupScreen> {
  final _searchCtrl = TextEditingController();
  final _svc = CustomerService();

  Customer? _found;
  bool _isLoading = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _searchCtrl.text.trim();
    if (query.isEmpty) return;

    setState(() { _isLoading = true; _found = null; });

    final result = await _svc.findByPhone(query);
    setState(() => _isLoading = false);

    result.fold(
      onSuccess: (c) {
        if (c == null) {
          AppSnackbar.showWarning(context, 'Không tìm thấy. Thử đăng ký mới.');
        }
        setState(() => _found = c);
      },
      onFailure: (e) => AppSnackbar.showError(context, e),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Tìm Khách Hàng'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Search bar
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _search(),
                    decoration: InputDecoration(
                      hintText: 'Nhập số điện thoại...',
                      prefixIcon: const Icon(Icons.phone),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                AppButton(
                  label: 'Tìm',
                  onPressed: _search,
                  isLoading: _isLoading,
                  icon: Icons.search,
                  height: 54,
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Result
            if (_found != null) _buildCustomerCard(_found!),

            if (_found == null && !_isLoading)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.person_search, size: 64, color: Colors.grey[300]),
                      const SizedBox(height: 12),
                      Text(
                        'Nhập SĐT để tìm khách hàng',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomerCard(Customer c) {
    final tierColors = [AppColors.tierBronze, AppColors.tierSilver, AppColors.tierGold];
    final tierLabels = ['Bronze', 'Silver', 'Gold'];
    final tierColor = tierColors[c.tier.clamp(0, 2)];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: tierColor.withValues(alpha: 0.15),
                radius: 28,
                child: Text(
                  c.fullName.isNotEmpty ? c.fullName[0].toUpperCase() : '?',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: tierColor),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(c.fullName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    Text(c.phone, style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                    Row(
                      children: [
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: tierColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '⭐ ${tierLabels[c.tier.clamp(0, 2)]} · ${c.totalPoints} điểm',
                            style: TextStyle(fontSize: 11, color: tierColor, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          AppButtonWide(
            label: 'Chọn khách này',
            onPressed: () {
              widget.onCustomerSelected?.call(c);
              Navigator.pop(context, c);
            },
            icon: Icons.check,
            color: AppColors.success,
          ),
        ],
      ),
    );
  }
}
