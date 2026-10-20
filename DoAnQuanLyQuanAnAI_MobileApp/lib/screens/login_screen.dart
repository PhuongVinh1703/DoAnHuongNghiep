import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:doanquanlyquananai_mobileapp/theme/app_colors.dart';
import 'package:doanquanlyquananai_mobileapp/theme/app_theme.dart';
import 'package:doanquanlyquananai_mobileapp/config/constants.dart';
import 'package:doanquanlyquananai_mobileapp/l10n/app_localizations.dart';
import 'package:doanquanlyquananai_mobileapp/services/auth_service.dart';
import 'package:doanquanlyquananai_mobileapp/screens/customer/customer_home_screen.dart';
import 'package:doanquanlyquananai_mobileapp/screens/register_screen.dart';
import 'package:doanquanlyquananai_mobileapp/screens/staff/staff_main_screen.dart';
import 'package:doanquanlyquananai_mobileapp/screens/manager/manager_dashboard_screen.dart';
import 'package:doanquanlyquananai_mobileapp/screens/forgot_password_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _obscurePassword = true;
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _animController.dispose();
    super.dispose();
  }

  void _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    final authService = context.read<AuthService>();
    final success = await authService.login(
      _usernameController.text.trim(),
      _passwordController.text,
    );

    if (!mounted) return;

    if (success) {
      _navigateByRole(authService.currentUser!.role);
    } else {
      // Hiển thị lỗi bằng SnackBar
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(authService.errorMessage ?? 'Đăng nhập thất bại'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  void _navigateByRole(int role) {
    Widget targetScreen;
    switch (role) {
      case AppConstants.roleOwner:
      case AppConstants.roleManager:
        targetScreen = const ManagerDashboardScreen();
        break;
      case AppConstants.roleStaff:
        targetScreen = const StaffMainScreen();
        break;
      case AppConstants.roleCustomer:
        targetScreen = const CustomerHomeScreen();
        break;
      default:
        targetScreen = const LoginScreen(); // Fallback
        break;
    }

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, anim, secondaryAnim) => targetScreen,
        transitionsBuilder: (context, anim, secondaryAnim, child) {
          return FadeTransition(opacity: anim, child: child);
        },
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.marginMobile),
          child: FadeTransition(
            opacity: _fadeAnim,
            child: SlideTransition(
              position: _slideAnim,
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 60),

                    // ─── Logo ────────────────────────────────────
                    Center(
                      child: Container(
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                          gradient: AppColors.aiGradient,
                          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withAlpha(50),
                              blurRadius: 24,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.restaurant_menu,
                          size: 48,
                          color: Colors.white,
                        ),
                      ),
                    ),

                    const SizedBox(height: 28),

                    // ─── App Name ────────────────────────────────
                    Text(
                      AppConstants.appName,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),

                    const SizedBox(height: 6),

                    // ─── Subtitle ────────────────────────────────
                    Text(
                      l10n.translate('system_auth'),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: AppColors.onSurfaceVariant,
                          ),
                    ),

                    const SizedBox(height: 48),

                    // ─── Username Field ──────────────────────────
                    TextFormField(
                      controller: _usernameController,
                      textInputAction: TextInputAction.next,
                      validator: (v) => (v == null || v.trim().isEmpty) ? l10n.translate('username_required') : null,
                      decoration: InputDecoration(
                        hintText: l10n.translate('username'),
                        prefixIcon: const Icon(Icons.person_outline_rounded),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ─── Password Field ──────────────────────────
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _handleLogin(),
                      validator: (v) => (v == null || v.isEmpty) ? l10n.translate('password_required') : null,
                      decoration: InputDecoration(
                        hintText: l10n.translate('password'),
                        prefixIcon: const Icon(Icons.lock_outline_rounded),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: AppColors.onSurfaceVariant,
                          ),
                          onPressed: () {
                            setState(() => _obscurePassword = !_obscurePassword);
                          },
                        ),
                      ),
                    ),

                    // ─── Forgot Password ─────────────────────────
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const ForgotPasswordScreen()),
                          );
                        },
                        child: Text(
                          l10n.translate('forgot'),
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // ─── Login Button ─────────────────────────────
                    SizedBox(
                      height: 56,
                      child: ElevatedButton(
                        onPressed: authService.isLoading ? null : _handleLogin,
                        child: authService.isLoading
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.5,
                                ),
                              )
                            : Text(l10n.translate('sign_in')),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ─── Register Link ───────────────────────────
                    Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            l10n.translate('new_to_app'),
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: AppColors.onSurfaceVariant,
                                ),
                          ),
                          GestureDetector(
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => const RegisterScreen()),
                              );
                            },
                            child: Text(
                              l10n.translate('register_here'),
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w600,
                                    decoration: TextDecoration.underline,
                                    decorationColor: AppColors.primary,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
