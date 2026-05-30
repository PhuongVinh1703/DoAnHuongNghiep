import 'package:flutter/material.dart';
import 'package:doanquanlyquananai_mobileapp/theme/app_colors.dart';
import 'package:doanquanlyquananai_mobileapp/theme/app_theme.dart';
import 'package:provider/provider.dart';
import 'package:doanquanlyquananai_mobileapp/services/auth_service.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  final _otpController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  
  bool _isOtpSent = false;
  bool _isSuccess = false;
  bool _obscurePassword = true;
  int _countdown = 0;

  @override
  void dispose() {
    _emailController.dispose();
    _otpController.dispose();
    _newPasswordController.dispose();
    super.dispose();
  }

  void _startCountdown() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      setState(() {
        if (_countdown > 0) _countdown--;
      });
      return _countdown > 0;
    });
  }

  Future<void> _handleSendOtp() async {
    if (_emailController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập Email!')),
      );
      return;
    }

    final authService = context.read<AuthService>();
    final success = await authService.sendOtp(_emailController.text.trim());
    
    if (!mounted) return;
    
    if (success) {
      setState(() {
        _isOtpSent = true;
        _countdown = 60;
      });
      _startCountdown();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mã OTP đã được gửi đến email.'), backgroundColor: AppColors.success),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(authService.errorMessage ?? 'Gửi OTP lỗi'), backgroundColor: AppColors.error),
      );
    }
  }

  Future<void> _handleReset() async {
    if (!_formKey.currentState!.validate()) return;
    
    final authService = context.read<AuthService>();
    final success = await authService.resetPassword(
      email: _emailController.text.trim(),
      newPassword: _newPasswordController.text,
      otp: _otpController.text.trim(),
    );

    if (!mounted) return;

    if (success) {
      setState(() => _isSuccess = true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(authService.errorMessage ?? 'Đổi mật khẩu thất bại'), backgroundColor: AppColors.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.marginMobile),
          child: _isSuccess ? _buildSuccess() : _buildForm(),
        ),
      ),
    );
  }

  Widget _buildForm() {
    final authService = context.watch<AuthService>();

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 20),
          Text(
            'Quên mật khẩu?',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 12),
          Text(
            'Vui lòng nhập email đã đăng ký để nhận mã OTP khôi phục mật khẩu.',
            style: TextStyle(color: AppColors.onSurfaceVariant),
          ),
          const SizedBox(height: 40),
          
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _emailController,
                  validator: (v) => (v == null || v.isEmpty) ? 'Vui lòng nhập Email' : null,
                  decoration: const InputDecoration(
                    hintText: 'Email của bạn',
                    prefixIcon: Icon(Icons.mail_outline_rounded),
                  ),
                  enabled: !_isSuccess,
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  minimumSize: const Size(0, 56),
                  backgroundColor: AppColors.secondary,
                  foregroundColor: Colors.white,
                ),
                onPressed: (_countdown > 0 || authService.isLoading) ? null : _handleSendOtp,
                child: Text(_countdown > 0 ? '$_countdown s' : 'Gửi mã'),
              ),
            ],
          ),

          if (_isOtpSent) ...[
            const SizedBox(height: 24),
            TextFormField(
              controller: _otpController,
              keyboardType: TextInputType.number,
              validator: (v) => (v == null || v.isEmpty) ? 'Vui lòng nhập mã OTP' : null,
              decoration: const InputDecoration(
                hintText: 'Mã OTP (6 số)',
                prefixIcon: Icon(Icons.security_rounded),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _newPasswordController,
              obscureText: _obscurePassword,
              validator: (v) => (v == null || v.length < 6) ? 'Mật khẩu tối thiểu 6 ký tự' : null,
              decoration: InputDecoration(
                hintText: 'Mật khẩu mới',
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    color: AppColors.onSurfaceVariant,
                  ),
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
            ),
          ],

          const SizedBox(height: 32),
          
          SizedBox(
            height: 56,
            child: ElevatedButton(
              onPressed: (!authService.isLoading && _isOtpSent) ? _handleReset : null,
              child: authService.isLoading 
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                  : const Text('Đặt lại mật khẩu'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccess() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(height: 60),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.success.withAlpha(20),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check_circle_rounded, size: 80, color: AppColors.success),
        ),
        const SizedBox(height: 24),
        const Text(
          'Đổi mật khẩu thành công!',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Text(
          'Mật khẩu của bạn đã được cập nhật thành công. Vui lòng đăng nhập lại.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.onSurfaceVariant),
        ),
        const SizedBox(height: 40),
        SizedBox(
          width: double.infinity,
          height: 56,
          child: OutlinedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Quay lại đăng nhập'),
          ),
        ),
      ],
    );
  }
}
