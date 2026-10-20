import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:doanquanlyquananai_mobileapp/theme/app_colors.dart';
import 'package:doanquanlyquananai_mobileapp/services/auth_service.dart';
import 'package:doanquanlyquananai_mobileapp/services/customer_provider.dart';
import 'package:doanquanlyquananai_mobileapp/services/customer_service.dart';
import 'package:doanquanlyquananai_mobileapp/services/storage_service.dart';
import 'package:doanquanlyquananai_mobileapp/widgets/common/menu_item_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:doanquanlyquananai_mobileapp/widgets/common/app_snackbar.dart';
import 'package:doanquanlyquananai_mobileapp/widgets/common/app_button.dart';
import 'package:doanquanlyquananai_mobileapp/models/auth/login_response.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _formKey = GlobalKey<FormState>();
  final _branchFormKey = GlobalKey<FormState>();

  // Profile Controllers
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  
  // Branch Controllers (for Owner/Manager)
  final _branchNameCtrl = TextEditingController();
  final _branchAddressCtrl = TextEditingController();
  final _branchPhoneCtrl = TextEditingController();

  final _storageSvc = StorageService();
  bool _isLoading = false;
  bool _isBranchLoading = false;
  bool _isUploadingAvatar = false;

  Future<void> _uploadAvatar() async {
    final auth = context.read<AuthService>();
    final user = auth.currentUser;
    if (user == null) return;

    setState(() => _isUploadingAvatar = true);
    final res = await _storageSvc.pickAndUploadImage(
      source: ImageSource.gallery,
      folder: 'avatars',
    );
    if (!mounted) return;

    await res.fold(
      onSuccess: (url) async {
        if (url != null && url.isNotEmpty) {
          try {
            await Supabase.instance.client
                .from('Accounts')
                .update({'Avatar': url})
                .eq('AccountId', user.accountId);
            await auth.updateCachedAvatar(url);
            if (mounted) {
              AppSnackbar.showSuccess(
                context,
                'Đã cập nhật ảnh đại diện lên Supabase Storage!',
              );
            }
          } catch (e) {
            if (mounted) {
              AppSnackbar.showError(context, 'Lỗi lưu ảnh đại diện: $e');
            }
          }
        }
      },
      onFailure: (err) async {
        if (mounted) AppSnackbar.showError(context, err);
      },
    );

    if (mounted) setState(() => _isUploadingAvatar = false);
  }

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthService>();
    final isBoss = auth.currentUser?.role == 0 || auth.currentUser?.role == 2;
    _tabController = TabController(length: isBoss ? 2 : 1, vsync: this);
    
    _loadInitialData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _branchNameCtrl.dispose();
    _branchAddressCtrl.dispose();
    _branchPhoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    final auth = context.read<AuthService>();
    final user = auth.currentUser;
    if (user == null) return;

    if (user.role == 3) {
      // Customer
      final customerProvider = context.read<CustomerProvider>();
      if (customerProvider.currentCustomer == null) {
        setState(() => _isLoading = true);
        await customerProvider.fetchCustomerProfileByIdentifier(user.username);
      }
      final customer = customerProvider.currentCustomer;
      if (customer != null) {
        _nameCtrl.text = customer.fullName;
        _phoneCtrl.text = customer.phone;
        _emailCtrl.text = customer.email ?? '';
      }
      setState(() => _isLoading = false);
    } else {
      // Staff / Manager / Owner
      setState(() => _isLoading = true);
      _nameCtrl.text = user.fullName;
      
      try {
        final db = Supabase.instance.client;
        
        // Fetch myself to get phone/email
        final myAcc = await db
            .from('Accounts')
            .select()
            .eq('AccountId', user.accountId)
            .single();
            
        _nameCtrl.text = myAcc['FullName'] ?? myAcc['fullName'] ?? user.fullName;
        _phoneCtrl.text = myAcc['Phone'] ?? myAcc['phone'] ?? '';
        _emailCtrl.text = myAcc['Email'] ?? myAcc['email'] ?? '';

        // If Manager/Owner, load branch info
        if ((user.role == 0 || user.role == 2) && user.branchId != null) {
          final myBranch = await db
              .from('Branches')
              .select()
              .eq('BranchId', user.branchId!)
              .single();
              
          _branchNameCtrl.text = myBranch['Name'] ?? myBranch['name'] ?? '';
          _branchAddressCtrl.text = myBranch['Address'] ?? myBranch['address'] ?? '';
          _branchPhoneCtrl.text = myBranch['Phone'] ?? myBranch['phone'] ?? '';
        }
      } catch (e) {
        debugPrint('Error fetching account details: $e');
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    final auth = context.read<AuthService>();
    final user = auth.currentUser;
    
    if (user == null) return;

    try {
      if (user.role == 3) {
        // Update Customer
        final customerProvider = context.read<CustomerProvider>();
        final cId = customerProvider.currentCustomer?.customerId;
        if (cId != null) {
          final result = await CustomerService().updateCustomer(
            cId,
            fullName: _nameCtrl.text.trim(),
            phone: _phoneCtrl.text.trim(),
            email: _emailCtrl.text.trim(),
          );
          if (result.isSuccess) {
            await customerProvider.fetchCustomerProfile(cId);
            await auth.updateCachedFullName(_nameCtrl.text.trim());
            if (mounted) AppSnackbar.showSuccess(context, 'Cập nhật thông tin thành công!');
          } else {
            if (mounted) AppSnackbar.showError(context, result.error ?? 'Cập nhật thất bại');
          }
        }
      } else {
        // Update Staff / Manager / Owner Account
        final db = Supabase.instance.client;
        await db.from('Accounts').update({
          'FullName': _nameCtrl.text.trim(),
          'Phone': _phoneCtrl.text.trim(),
          'Email': _emailCtrl.text.trim(),
        }).eq('AccountId', user.accountId);

        await auth.updateCachedFullName(_nameCtrl.text.trim());
        
        if (mounted) AppSnackbar.showSuccess(context, 'Cập nhật thông tin thành công!');
      }
    } catch (e) {
      if (mounted) AppSnackbar.showError(context, 'Lỗi hệ thống: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveBranch() async {
    if (!_branchFormKey.currentState!.validate()) return;
    
    setState(() => _isBranchLoading = true);
    final auth = context.read<AuthService>();
    final user = auth.currentUser;
    
    if (user == null || user.branchId == null) return;

    try {
      final db = Supabase.instance.client;
      await db.from('Branches').update({
        'Name': _branchNameCtrl.text.trim(),
        'Address': _branchAddressCtrl.text.trim(),
        'Phone': _branchPhoneCtrl.text.trim(),
      }).eq('BranchId', user.branchId!);

      if (mounted) AppSnackbar.showSuccess(context, 'Cập nhật thông tin chi nhánh thành công!');
    } catch (e) {
      if (mounted) AppSnackbar.showError(context, 'Lỗi khi cập nhật chi nhánh: $e');
    } finally {
      if (mounted) setState(() => _isBranchLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final user = auth.currentUser;
    final isBoss = user?.role == 0 || user?.role == 2;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Cập Nhật Hồ Sơ', style: TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.onSurface,
        elevation: 0,
        bottom: isBoss
            ? TabBar(
                controller: _tabController,
                indicatorColor: AppColors.primary,
                labelColor: AppColors.primary,
                unselectedLabelColor: AppColors.onSurfaceVariant,
                tabs: const [
                  Tab(icon: Icon(Icons.person_rounded), text: 'Cá nhân'),
                  Tab(icon: Icon(Icons.store_rounded), text: 'Chi nhánh'),
                ],
              )
            : null,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              physics: isBoss ? null : const NeverScrollableScrollPhysics(),
              children: [
                _buildPersonalTab(user),
                if (isBoss) _buildBranchTab(),
              ],
            ),
    );
  }

  Widget _buildPersonalTab(LoginResponse? user) {
    final customer = context.watch<CustomerProvider>().currentCustomer;
    final isCustomer = user?.role == 3;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            // User Avatar Card (Terracotta style)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFF1EC), Color(0xFFFFE9E1)],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.outlineVariant.withAlpha(50)),
              ),
              child: Column(
                children: [
                  Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      UserAvatarImage(
                        avatarUrl: user?.avatar,
                        fullName: user?.fullName ?? 'Hồ sơ',
                        role: user?.role ?? 3,
                        size: 80,
                      ),
                      if (_isUploadingAvatar)
                        Container(
                          width: 80,
                          height: 80,
                          decoration: const BoxDecoration(
                            color: Colors.black45,
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          ),
                        ),
                      GestureDetector(
                        onTap: _isUploadingAvatar ? null : _uploadAvatar,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(
                            Icons.camera_alt_rounded,
                            size: 16,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    user?.fullName ?? 'Hồ sơ',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '@${user?.username ?? "user"}',
                    style: TextStyle(color: AppColors.onSurfaceVariant.withAlpha(150), fontSize: 13),
                  ),
                  if (isCustomer && customer != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withAlpha(20),
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Text(
                        'Hạng ${customer.tierDisplay} • ${customer.points} Điểm',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Form Inputs
            TextFormField(
              controller: _nameCtrl,
              decoration: InputDecoration(
                labelText: 'Họ và tên',
                prefixIcon: const Icon(Icons.badge_outlined),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.white,
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Vui lòng nhập họ và tên' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: 'Số điện thoại',
                prefixIcon: const Icon(Icons.phone_outlined),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.white,
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Vui lòng nhập số điện thoại' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: 'Email',
                prefixIcon: const Icon(Icons.email_outlined),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
            const SizedBox(height: 28),

            AppButtonWide(
              label: 'Lưu thay đổi',
              onPressed: _saveProfile,
              isLoading: _isLoading,
              icon: Icons.check_circle_outline_rounded,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBranchTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _branchFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Info Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.secondaryContainer.withAlpha(20),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.secondary.withAlpha(50)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, color: AppColors.secondary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Bạn có quyền cập nhật thông tin vận hành của chi nhánh này.',
                      style: TextStyle(color: AppColors.secondary, fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            TextFormField(
              controller: _branchNameCtrl,
              decoration: InputDecoration(
                labelText: 'Tên nhà hàng / Chi nhánh',
                prefixIcon: const Icon(Icons.storefront_rounded),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.white,
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Vui lòng nhập tên chi nhánh' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _branchAddressCtrl,
              decoration: InputDecoration(
                labelText: 'Địa chỉ chi nhánh',
                prefixIcon: const Icon(Icons.location_on_outlined),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.white,
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Vui lòng nhập địa chỉ' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _branchPhoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: 'Hotline chi nhánh',
                prefixIcon: const Icon(Icons.phone_in_talk_outlined),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.white,
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Vui lòng nhập hotline' : null,
            ),
            const SizedBox(height: 28),

            AppButtonWide(
              label: 'Lưu thông tin chi nhánh',
              onPressed: _saveBranch,
              isLoading: _isBranchLoading,
              icon: Icons.store_rounded,
            ),
          ],
        ),
      ),
    );
  }
}
