import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:doanquanlyquananai_mobileapp/theme/app_colors.dart';
import 'package:doanquanlyquananai_mobileapp/theme/app_theme.dart';
import 'package:doanquanlyquananai_mobileapp/l10n/app_localizations.dart';
import 'package:doanquanlyquananai_mobileapp/services/auth_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:doanquanlyquananai_mobileapp/services/branch_service.dart';
import 'package:doanquanlyquananai_mobileapp/models/branch/branch.dart';

class StaffManagementScreen extends StatefulWidget {
  const StaffManagementScreen({super.key});

  @override
  State<StaffManagementScreen> createState() => _StaffManagementScreenState();
}

class _StaffManagementScreenState extends State<StaffManagementScreen> {
  List<dynamic> _staff = [];
  bool _isLoading = true;
  String? _error;
  String _searchQuery = '';
  int? _roleFilter; // null = all, 2 = manager, 1 = staff
  final _searchCtrl = TextEditingController();

  List<Branch> _branches = [];
  int? _selectedBranchId;
  bool _isOwner = false;

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    await _loadBranches();
    await _loadStaff();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadBranches() async {
    final auth = context.read<AuthService>();
    final user = auth.currentUser;
    if (user?.role == 0) {
      final res = await BranchService().getBranches();
      if (res.isSuccess) {
        setState(() {
          _branches = res.data ?? [];
        });
      }
    }
  }

  Future<void> _loadStaff() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final db = Supabase.instance.client;
      var query = db.from('Accounts').select('*, Branches(Name)');
      if (_roleFilter != null) {
        query = query.eq('Role', _roleFilter!);
      } else {
        // Mặc định load các role 1 (Staff) và 2 (Manager) để quản lý
        query = query.inFilter('Role', [1, 2]);
      }
      
      final auth = context.read<AuthService>();
      final user = auth.currentUser;
      _isOwner = (user?.role == 0);

      if (_isOwner) {
        if (_selectedBranchId != null) {
          query = query.eq('BranchId', _selectedBranchId!);
        }
      } else {
        if (user?.branchId != null) {
          query = query.eq('BranchId', user!.branchId!);
        }
      }
      final res = await query.order('AccountId');
      
      final list = (res as List).map((acc) => {
        'accountId': acc['AccountId'] ?? acc['accountId'],
        'fullName': acc['FullName'] ?? acc['fullName'],
        'username': acc['Username'] ?? acc['username'],
        'role': acc['Role'] ?? acc['role'],
        'isActive': acc['IsActive'] ?? acc['isActive'] ?? true,
        'phone': acc['Phone'] ?? acc['phone'] ?? '',
        'email': acc['Email'] ?? acc['email'] ?? '',
        'branchId': acc['BranchId'] ?? acc['branchId'],
        'branchName': (acc['Branches'] as Map?)?['Name'] ?? '—',
      }).toList();

      setState(() {
        _staff = list;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Lỗi kết nối CSDL: $e';
        _isLoading = false;
      });
    }
  }

  List<dynamic> get _filtered {
    final q = _searchQuery.toLowerCase();
    if (q.isEmpty) return _staff;
    return _staff.where((s) {
      return (s['fullName'] as String? ?? '').toLowerCase().contains(q) ||
             (s['username'] as String? ?? '').toLowerCase().contains(q) ||
             (s['phone'] as String? ?? '').toLowerCase().contains(q);
    }).toList();
  }

  Future<void> _toggleActive(dynamic staff) async {
    final id = staff['accountId'];
    final name = staff['fullName'] ?? '';
    final isActive = staff['isActive'] as bool? ?? true;
    final action = isActive ? 'khoá' : 'mở khoá';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Xác nhận $action'),
        content: Text('Bạn có chắc muốn $action tài khoản [$name]?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Huỷ')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: isActive ? AppColors.error : AppColors.success),
            child: Text(action),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final db = Supabase.instance.client;
      await db.from('Accounts').update({'IsActive': !isActive}).eq('AccountId', id);
      _loadStaff();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lỗi khi thực hiện thao tác')),
        );
      }
    }
  }

  Future<void> _resetPassword(dynamic staff) async {
    final id = staff['accountId'];
    final name = staff['fullName'] ?? '';
    final pwCtrl = TextEditingController();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Đặt lại mật khẩu cho $name'),
        content: TextField(
          controller: pwCtrl,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'Mật khẩu mới',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.lock_outline_rounded),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Huỷ')),
          FilledButton(
            onPressed: () {
              if (pwCtrl.text.length < 6) return;
              Navigator.pop(context, true);
            },
            child: const Text('Đặt lại'),
          ),
        ],
      ),
    );

    if (confirm != true || pwCtrl.text.isEmpty) return;

    try {
      final db = Supabase.instance.client;
      await db.rpc('reset_staff_password', params: {
        'p_staff_id': id,
        'p_new_password': pwCtrl.text,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Đã đặt lại mật khẩu')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lỗi khi đặt lại mật khẩu')),
        );
      }
    }
  }

  void _showAddStaffDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddStaffSheet(
        branchId: _isOwner ? null : context.read<AuthService>().currentUser?.branchId,
        isAdmin: _isOwner,
        branches: _branches,
        onSuccess: _loadStaff,
      ),
    );
  }

  void _showStaffDetailsSheet(BuildContext context, dynamic staff) {
    final role = staff['role'] as int? ?? 1;
    final isActive = staff['isActive'] as bool? ?? true;
    final fullName = staff['fullName'] as String? ?? '';
    final username = staff['username'] as String? ?? '';
    final phone = staff['phone'] as String? ?? 'Chưa cập nhật';
    final email = staff['email'] as String? ?? 'Chưa cập nhật';
    final branchName = staff['branchName'] as String? ?? 'Chưa gán';
    final accountId = staff['accountId'];

    final roleLabel = role == 0 ? '👑 Admin / Chủ nhà hàng' : role == 2 ? '🏢 Quản lý chi nhánh' : '👤 Nhân viên phục vụ';
    final roleColor = role == 0 ? const Color(0xFF7C3AED) : role == 2 ? AppColors.primary : AppColors.onSurfaceVariant;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(24),
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
              const SizedBox(height: 24),
              Row(
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [
                        roleColor.withAlpha(60),
                        roleColor.withAlpha(30),
                      ]),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      fullName.isNotEmpty ? fullName[0].toUpperCase() : '?',
                      style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: roleColor),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          fullName,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '@$username',
                          style: TextStyle(color: Colors.grey[600], fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),
              _detailRow(Icons.badge_outlined, 'Vai trò', roleLabel, roleColor),
              _detailRow(
                isActive ? Icons.check_circle_outline_rounded : Icons.block_flipped,
                'Trạng thái tài khoản',
                isActive ? 'Đang hoạt động' : 'Bị khóa / Tạm ngưng',
                isActive ? Colors.green : Colors.red,
              ),
              _detailRow(Icons.store_outlined, 'Chi nhánh làm việc', branchName, Colors.black87),
              _detailRow(Icons.phone_outlined, 'Số điện thoại', phone, Colors.black87),
              _detailRow(Icons.email_outlined, 'Email liên hệ', email, Colors.black87),
              _detailRow(Icons.fingerprint_rounded, 'Mã tài khoản (ID)', 'ACC-$accountId', Colors.black54),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Đóng', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _detailRow(IconData icon, String title, String val, Color valColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                const SizedBox(height: 2),
                Text(val, style: TextStyle(color: valColor, fontSize: 14, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBranchFilter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      margin: const EdgeInsets.only(bottom: 8),
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
              items: [
                const DropdownMenuItem<int?>(
                  value: null,
                  child: Text('Tất cả chi nhánh'),
                ),
                ..._branches.map((b) => DropdownMenuItem<int?>(
                      value: b.branchId,
                      child: Text(b.name),
                    )),
              ],
              onChanged: (val) {
                setState(() {
                  _selectedBranchId = val;
                });
                _loadStaff();
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
    final filtered = _filtered;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: Text(l10n.translate('staff_registry'),
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadStaff,
            tooltip: 'Làm mới',
          ),
          IconButton(
            icon: const Icon(Icons.person_add_rounded),
            color: AppColors.primary,
            onPressed: _showAddStaffDialog,
            tooltip: 'Thêm nhân viên',
          ),
        ],
      ),
      body: Column(
        children: [
          if (_isOwner) _buildBranchFilter(),
          // Search + filter bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Column(
              children: [
                TextField(
                  controller: _searchCtrl,
                  onChanged: (v) => setState(() => _searchQuery = v),
                  decoration: InputDecoration(
                    hintText: 'Tìm theo tên, username, SĐT...',
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    filled: true,
                    fillColor: AppColors.surfaceContainerLowest,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.outlineVariant),
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _FilterChip(label: 'Tất cả', selected: _roleFilter == null,
                      onTap: () => setState(() { _roleFilter = null; _loadStaff(); })),
                    const SizedBox(width: 8),
                    if (_isOwner)
                    _FilterChip(label: '🏢 Quản lý', selected: _roleFilter == 2,
                      onTap: () => setState(() { _roleFilter = 2; _loadStaff(); })),
                    if (_isOwner) const SizedBox(width: 8),
                    _FilterChip(label: '👤 Nhân viên', selected: _roleFilter == 1,
                      onTap: () => setState(() { _roleFilter = 1; _loadStaff(); })),
                    const Spacer(),
                    Text('${filtered.length} người',
                      style: TextStyle(fontSize: 13, color: AppColors.onSurfaceVariant)),
                  ],
                ),
              ],
            ),
          ),

          // List
          Expanded(
            child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                ? Center(child: Text(_error!, style: TextStyle(color: AppColors.error)))
                : filtered.isEmpty
                  ? _EmptyState()
                  : RefreshIndicator(
                      onRefresh: _loadStaff,
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                        itemCount: filtered.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 10),
                        itemBuilder: (_, i) => GestureDetector(
                          onTap: () => _showStaffDetailsSheet(context, filtered[i]),
                          child: _StaffCard(
                            staff: filtered[i],
                            onToggle: () => _toggleActive(filtered[i]),
                            onResetPw: () => _resetPassword(filtered[i]),
                          ),
                        ),
                      ),
                    ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary.withAlpha(25) : AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.outlineVariant,
          ),
        ),
        child: Text(label, style: TextStyle(
          fontSize: 13,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          color: selected ? AppColors.primary : AppColors.onSurfaceVariant,
        )),
      ),
    );
  }
}

class _StaffCard extends StatelessWidget {
  final dynamic staff;
  final VoidCallback onToggle;
  final VoidCallback onResetPw;
  const _StaffCard({required this.staff, required this.onToggle, required this.onResetPw});

  @override
  Widget build(BuildContext context) {
    final role = staff['role'] as int? ?? 1;
    final isActive = staff['isActive'] as bool? ?? true;
    final fullName = staff['fullName'] as String? ?? '';
    final username = staff['username'] as String? ?? '';
    final phone = staff['phone'] as String? ?? '—';
    final branchName = staff['branchName'] as String? ?? '—';

    final roleLabel = role == 0 ? '👑 Admin' : role == 2 ? '🏢 Quản lý' : '👤 Nhân viên';
    final roleColor = role == 0 ? const Color(0xFF7C3AED) : role == 2 ? AppColors.primary : AppColors.onSurfaceVariant;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppColors.outlineVariant.withAlpha(60)),
        boxShadow: AppTheme.shadowLevel1,
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Avatar
              Container(
                width: 48, height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    roleColor.withAlpha(60), roleColor.withAlpha(30),
                  ]),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  fullName.isNotEmpty ? fullName[0].toUpperCase() : '?',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: roleColor),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(fullName,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15))),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: isActive ? const Color(0xFFDCFCE7) : AppColors.errorContainer,
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: Text(isActive ? 'Hoạt động' : 'Đã khoá',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                              color: isActive ? const Color(0xFF16A34A) : AppColors.error)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text('@$username', style: TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.badge_outlined, size: 14, color: roleColor),
              const SizedBox(width: 4),
              Text(roleLabel, style: TextStyle(fontSize: 12, color: roleColor, fontWeight: FontWeight.w600)),
              const SizedBox(width: 12),
              Icon(Icons.phone_outlined, size: 14, color: AppColors.onSurfaceVariant),
              const SizedBox(width: 4),
              Text(phone, style: TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant)),
              const SizedBox(width: 12),
              Icon(Icons.store_outlined, size: 14, color: AppColors.onSurfaceVariant),
              const SizedBox(width: 4),
              Expanded(child: Text(branchName, style: TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant),
                overflow: TextOverflow.ellipsis)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onResetPw,
                  icon: const Icon(Icons.lock_reset_rounded, size: 16),
                  label: const Text('Đặt lại mật khẩu', style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: onToggle,
                  icon: Icon(isActive ? Icons.lock_rounded : Icons.lock_open_rounded, size: 16),
                  label: Text(isActive ? 'Khoá TK' : 'Mở TK', style: const TextStyle(fontSize: 12)),
                  style: FilledButton.styleFrom(
                    backgroundColor: isActive ? AppColors.error : AppColors.success,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline_rounded, size: 64, color: AppColors.outlineVariant),
          const SizedBox(height: 16),
          Text('Không tìm thấy nhân viên',
            style: TextStyle(fontSize: 16, color: AppColors.onSurfaceVariant)),
        ],
      ),
    );
  }
}

class _AddStaffSheet extends StatefulWidget {
  final int? branchId;
  final bool isAdmin;
  final List<Branch> branches;
  final VoidCallback onSuccess;
  const _AddStaffSheet({
    this.branchId,
    required this.isAdmin,
    required this.branches,
    required this.onSuccess,
  });

  @override
  State<_AddStaffSheet> createState() => _AddStaffSheetState();
}

class _AddStaffSheetState extends State<_AddStaffSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _userCtrl = TextEditingController();
  final _pwCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  int _role = 1; // default: Staff
  int? _selectedBranchId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _selectedBranchId = widget.branchId;
    if (widget.isAdmin && widget.branches.isNotEmpty) {
      _selectedBranchId = widget.branches.first.branchId;
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final db = Supabase.instance.client;
      await db.rpc('create_staff_account', params: {
        'p_username': _userCtrl.text.trim(),
        'p_password': _pwCtrl.text,
        'p_fullname': _nameCtrl.text.trim(),
        'p_phone': _phoneCtrl.text.trim(),
        'p_role': _role,
        'p_branch_id': _selectedBranchId,
      });
      if (mounted) {
        Navigator.pop(context);
        widget.onSuccess();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Đã thêm tài khoản mới')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi khi tạo tài khoản: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottom),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(color: AppColors.outlineVariant, borderRadius: BorderRadius.circular(2)),
              )),
              const SizedBox(height: 16),
              const Text('Thêm nhân viên mới',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 20),

              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: 'Họ và tên *', prefixIcon: Icon(Icons.person_outline)),
                validator: (v) => v == null || v.trim().isEmpty ? 'Bắt buộc nhập' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _userCtrl,
                decoration: const InputDecoration(labelText: 'Username *', prefixIcon: Icon(Icons.alternate_email_rounded)),
                validator: (v) => v == null || v.trim().isEmpty ? 'Bắt buộc nhập' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _pwCtrl,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Mật khẩu * (≥6 ký tự)', prefixIcon: Icon(Icons.lock_outline)),
                validator: (v) => v == null || v.length < 6 ? 'Mật khẩu ít nhất 6 ký tự' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phoneCtrl,
                decoration: const InputDecoration(labelText: 'Số điện thoại', prefixIcon: Icon(Icons.phone_outlined)),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),

              if (widget.isAdmin) ...[
                Text('Chi nhánh *', style: TextStyle(fontSize: 13, color: AppColors.onSurfaceVariant)),
                const SizedBox(height: 8),
                DropdownButtonFormField<int>(
                  initialValue: _selectedBranchId,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.store_outlined),
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: widget.branches.map((b) => DropdownMenuItem<int>(
                    value: b.branchId,
                    child: Text(b.name),
                  )).toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedBranchId = val;
                    });
                  },
                  validator: (val) => val == null ? 'Vui lòng chọn chi nhánh' : null,
                ),
                const SizedBox(height: 12),
              ],

              Text('Vai trò', style: TextStyle(fontSize: 13, color: AppColors.onSurfaceVariant)),
              const SizedBox(height: 8),
              Row(
                children: [
                  _RoleOption(label: '🏢 Quản lý', value: 2, selected: _role,
                    onTap: () => setState(() => _role = 2)),
                  const SizedBox(width: 10),
                  _RoleOption(label: '👤 Nhân viên', value: 1, selected: _role,
                    onTap: () => setState(() => _role = 1)),
                ],
              ),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _saving ? null : _submit,
                  style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                  child: _saving
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Tạo tài khoản', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleOption extends StatelessWidget {
  final String label;
  final int value;
  final int selected;
  final VoidCallback onTap;
  const _RoleOption({required this.label, required this.value, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isSelected = selected == value;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary.withAlpha(25) : AppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isSelected ? AppColors.primary : AppColors.outlineVariant),
          ),
          alignment: Alignment.center,
          child: Text(label, style: TextStyle(
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
            color: isSelected ? AppColors.primary : AppColors.onSurfaceVariant,
          )),
        ),
      ),
    );
  }
}
