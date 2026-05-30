import 'package:flutter/material.dart';
import 'package:doanquanlyquananai_mobileapp/core/constants/app_colors.dart';
import 'package:doanquanlyquananai_mobileapp/core/storage/secure_storage.dart';
import 'package:doanquanlyquananai_mobileapp/services/auth_service.dart';
import 'package:doanquanlyquananai_mobileapp/widgets/common/app_button.dart';
import 'package:doanquanlyquananai_mobileapp/widgets/common/app_snackbar.dart';
import 'package:provider/provider.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey   = GlobalKey<FormState>();
  final _oldCtrl   = TextEditingController();
  final _newCtrl   = TextEditingController();
  final _cfmCtrl   = TextEditingController();

  bool _isLoading  = false;
  bool _showOld    = false;
  bool _showNew    = false;
  bool _showCfm    = false;

  @override
  void dispose() {
    _oldCtrl.dispose();
    _newCtrl.dispose();
    _cfmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    
    final auth = context.read<AuthService>();

    final accountIdStr = await SecureStorage.getUserId();
    if (accountIdStr == null) return;

    setState(() => _isLoading = true);
    final ok = await auth.changePassword(
      accountId: int.parse(accountIdStr),
      oldPassword: _oldCtrl.text.trim(),
      newPassword: _newCtrl.text.trim(),
    );
    setState(() => _isLoading = false);

    if (!mounted) return;
    if (ok) {
      AppSnackbar.showSuccess(context, 'Đổi mật khẩu thành công!');
      Navigator.pop(context);
    } else {
      AppSnackbar.showError(context, 'Mật khẩu cũ không đúng. Vui lòng thử lại.');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(
      title: const Text('Đổi Mật Khẩu'),
      backgroundColor: Colors.white,
      foregroundColor: AppColors.textPrimary,
      elevation: 0,
    ),
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(children: [
          const SizedBox(height: 16),
          // Icon header
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.lock_outline, size: 36, color: AppColors.primary),
          ),
          const SizedBox(height: 24),

          _passField(
            controller: _oldCtrl,
            label: 'Mật khẩu hiện tại',
            show: _showOld,
            onToggle: () => setState(() => _showOld = !_showOld),
            validator: (v) => (v == null || v.isEmpty) ? 'Vui lòng nhập mật khẩu cũ' : null,
          ),
          const SizedBox(height: 14),
          _passField(
            controller: _newCtrl,
            label: 'Mật khẩu mới',
            show: _showNew,
            onToggle: () => setState(() => _showNew = !_showNew),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Vui lòng nhập mật khẩu mới';
              if (v.length < 6) return 'Mật khẩu tối thiểu 6 ký tự';
              return null;
            },
          ),
          const SizedBox(height: 14),
          _passField(
            controller: _cfmCtrl,
            label: 'Xác nhận mật khẩu mới',
            show: _showCfm,
            onToggle: () => setState(() => _showCfm = !_showCfm),
            validator: (v) {
              if (v != _newCtrl.text) return 'Mật khẩu không khớp';
              return null;
            },
          ),
          const SizedBox(height: 28),
          AppButtonWide(
            label: 'Đổi Mật Khẩu',
            onPressed: _submit,
            isLoading: _isLoading,
            icon: Icons.save_outlined,
          ),
        ]),
      ),
    ),
  );

  Widget _passField({
    required TextEditingController controller,
    required String label,
    required bool show,
    required VoidCallback onToggle,
    String? Function(String?)? validator,
  }) => TextFormField(
    controller: controller,
    obscureText: !show,
    validator: validator,
    decoration: InputDecoration(
      labelText: label,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      filled: true,
      fillColor: Colors.white,
      prefixIcon: const Icon(Icons.lock_outline),
      suffixIcon: IconButton(
        icon: Icon(show ? Icons.visibility_off : Icons.visibility),
        onPressed: onToggle,
      ),
    ),
  );
}
