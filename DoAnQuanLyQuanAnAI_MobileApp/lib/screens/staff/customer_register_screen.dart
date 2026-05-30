import 'package:flutter/material.dart';
import 'package:doanquanlyquananai_mobileapp/core/constants/app_colors.dart';
import 'package:doanquanlyquananai_mobileapp/models/customer/customer.dart';
import 'package:doanquanlyquananai_mobileapp/services/customer_service.dart';
import 'package:doanquanlyquananai_mobileapp/widgets/common/app_button.dart';
import 'package:doanquanlyquananai_mobileapp/widgets/common/app_snackbar.dart';

class CustomerRegisterScreen extends StatefulWidget {
  final String? prefillPhone;
  final void Function(Customer customer)? onRegistered;

  const CustomerRegisterScreen({super.key, this.prefillPhone, this.onRegistered});

  @override
  State<CustomerRegisterScreen> createState() => _CustomerRegisterScreenState();
}

class _CustomerRegisterScreenState extends State<CustomerRegisterScreen> {
  final _formKey   = GlobalKey<FormState>();
  final _nameCtrl  = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _svc = CustomerService();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.prefillPhone != null) {
      _phoneCtrl.text = widget.prefillPhone!;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final result = await _svc.createCustomer(
      fullName: _nameCtrl.text.trim(),
      phone:    _phoneCtrl.text.trim(),
      email:    _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
    );
    setState(() => _isLoading = false);

    result.fold(
      onSuccess: (c) {
        AppSnackbar.showSuccess(context, 'Đăng ký thành công! Chào ${c.fullName} 🎉');
        widget.onRegistered?.call(c);
        Navigator.pop(context, c);
      },
      onFailure: (e) => AppSnackbar.showError(context, e),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(
      title: const Text('Đăng Ký Khách Hàng Mới'),
      backgroundColor: Colors.white,
      foregroundColor: AppColors.textPrimary,
      elevation: 0,
    ),
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(children: [
          const SizedBox(height: 8),
          // Avatar preview
          CircleAvatar(
            radius: 36,
            backgroundColor: AppColors.primary.withValues(alpha: 0.1),
            child: const Icon(Icons.person_add, size: 36, color: AppColors.primary),
          ),
          const SizedBox(height: 24),

          _field(
            controller: _nameCtrl,
            label: 'Họ và tên *',
            icon: Icons.person_outline,
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Vui lòng nhập tên' : null,
          ),
          const SizedBox(height: 14),
          _field(
            controller: _phoneCtrl,
            label: 'Số điện thoại *',
            icon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Vui lòng nhập SĐT';
              if (v.trim().length < 9) return 'SĐT không hợp lệ';
              return null;
            },
          ),
          const SizedBox(height: 14),
          _field(
            controller: _emailCtrl,
            label: 'Email (tuỳ chọn)',
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 28),
          AppButtonWide(
            label: 'Đăng Ký Thành Viên',
            onPressed: _submit,
            isLoading: _isLoading,
            icon: Icons.card_membership,
          ),
        ]),
      ),
    ),
  );

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) => TextFormField(
    controller: controller,
    keyboardType: keyboardType,
    validator: validator,
    decoration: InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      filled: true,
      fillColor: Colors.white,
    ),
  );
}
