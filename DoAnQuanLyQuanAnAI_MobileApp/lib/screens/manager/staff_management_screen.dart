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
  int? _roleFilter; // null = all, 2 = manager, 1 = staff, 4 = cashier, 5 = kitchen
  final _searchCtrl = TextEditingController();

  List<Branch> _branches = [];
  int? _selectedBranchId;
  bool _isOwner = false;
  String _managerBranchName = '';

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
    _isOwner = (user?.role == 0);

    final res = await BranchService().getBranches();
    if (res.isSuccess && mounted) {
      final allBranches = res.data ?? [];
      setState(() {
        _branches = allBranches;
        if (!_isOwner && user?.branchId != null) {
          _selectedBranchId = user!.branchId;
          final matched = allBranches.where((b) => b.branchId == user.branchId);
          if (matched.isNotEmpty) {
            _managerBranchName = matched.first.name;
          } else {
            _managerBranchName = 'Chi nhánh #${user.branchId}';
          }
        }
      });
    }
  }

  Future<void> _loadStaff() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final auth = context.read<AuthService>();
      final user = auth.currentUser;
      _isOwner = (user?.role == 0);

      final db = Supabase.instance.client;
      var query = db.from('Accounts').select('*, Branches(Name)');
      if (_roleFilter != null) {
        query = query.eq('Role', _roleFilter!);
      } else {
        // Mặc định load các role 1 (Phục vụ), 2 (Quản lý), 4 (Thu ngân), 5 (Bếp KDS)
        query = query.inFilter('Role', [1, 2, 4, 5]);
      }

      if (_isOwner) {
        if (_selectedBranchId != null) {
          query = query.eq('BranchId', _selectedBranchId!);
        }
      } else {
        // Quản lý chi nhánh (Role = 2) CHỈ được xem nhân sự thuộc đúng chi nhánh của mình
        if (user?.branchId != null) {
          query = query.eq('BranchId', user!.branchId!);
        }
      }
      final res = await query.order('AccountId');

      final list = (res as List).map((acc) => {
        'accountId': acc['AccountId'] ?? acc['accountId'],
        'fullName': acc['FullName'] ?? acc['fullName'] ?? '',
        'username': acc['Username'] ?? acc['username'] ?? '',
        'role': acc['Role'] ?? acc['role'] ?? 1,
        'gender': acc['Gender'] ?? acc['gender'] ?? 0,
        'isActive': acc['IsActive'] ?? acc['isActive'] ?? true,
        'phone': acc['Phone'] ?? acc['phone'] ?? '',
        'email': acc['Email'] ?? acc['email'] ?? '',
        'avatar': acc['Avatar'] ?? acc['avatar'] ?? '👤',
        'branchId': acc['BranchId'] ?? acc['branchId'],
        'branchName': (acc['Branches'] as Map?)?['Name'] ?? '—',
      }).toList();

      if (mounted) {
        setState(() {
          _staff = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Lỗi kết nối CSDL: $e';
          _isLoading = false;
        });
      }
    }
  }

  List<dynamic> get _filtered {
    final q = _searchQuery.toLowerCase();
    if (q.isEmpty) return _staff;
    return _staff.where((s) {
      return (s['fullName'] as String? ?? '').toLowerCase().contains(q) ||
          (s['username'] as String? ?? '').toLowerCase().contains(q) ||
          (s['phone'] as String? ?? '').toLowerCase().contains(q) ||
          (s['email'] as String? ?? '').toLowerCase().contains(q);
    }).toList();
  }

  /// Kiểm tra quyền Khóa / Xóa:
  /// - Không ai được tự khóa hoặc tự xóa chính mình (isSelf).
  /// - Quản lý chi nhánh (Role = 2) KHÔNG được khóa/xóa tài khoản Quản lý (Role = 2) hoặc Admin (Role = 0).
  /// - Chỉ có Admin (Role = 0) mới có quyền khóa/xóa tài khoản Quản lý.
  bool _canLockOrDelete(dynamic staff) {
    final currentUser = context.read<AuthService>().currentUser;
    final staffId = staff['accountId'] as int?;
    final targetRole = staff['role'] as int? ?? 1;

    if (currentUser == null) return false;
    // Không bao giờ được tự khóa/xóa chính mình
    if (staffId == currentUser.accountId) return false;
    // Nếu không phải Admin (Owner), không được khóa/xóa Quản lý hoặc Owner
    if (!_isOwner && (targetRole == 2 || targetRole == 0)) return false;

    return true;
  }

  Future<void> _toggleActive(dynamic staff) async {
    if (!_canLockOrDelete(staff)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Bạn không thể tự khóa tài khoản của chính mình. Chỉ Admin mới có quyền khóa tài khoản Quản lý!'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final id = staff['accountId'];
    final name = staff['fullName'] ?? '';
    final isActive = staff['isActive'] as bool? ?? true;
    final action = isActive ? 'khoá' : 'mở khoá';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Xác nhận $action tài khoản'),
        content: Text('Bạn có chắc muốn $action tài khoản [$name]?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Huỷ')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: isActive ? AppColors.error : AppColors.success,
            ),
            child: Text(isActive ? 'Khoá tài khoản' : 'Mở khoá'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final db = Supabase.instance.client;
      await db.from('Accounts').update({'IsActive': !isActive}).eq('AccountId', id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isActive ? '🔒 Đã khóa tài khoản [$name]' : '🔓 Đã mở khóa tài khoản [$name]'),
            backgroundColor: isActive ? AppColors.error : AppColors.success,
          ),
        );
      }
      _loadStaff();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi khi thực hiện thao tác: $e')),
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
            labelText: 'Mật khẩu mới (≥6 ký tự)',
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
          SnackBar(
            content: Text('✅ Đã đặt lại mật khẩu cho [$name] thành công'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi khi đặt lại mật khẩu: $e')),
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
        branchId: _isOwner ? _selectedBranchId : context.read<AuthService>().currentUser?.branchId,
        isAdmin: _isOwner,
        branches: _branches,
        onSuccess: _loadStaff,
      ),
    );
  }

  void _showEditStaffDialog(dynamic staff) {
    final currentUser = context.read<AuthService>().currentUser;
    final isSelf = (staff['accountId'] == currentUser?.accountId);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditStaffSheet(
        staff: staff,
        isAdmin: _isOwner,
        isSelf: isSelf,
        branches: _branches,
        onSuccess: () {
          _loadStaff();
          if (isSelf) {
            // Đồng bộ lại tên hiển thị trong cache nếu Quản lý tự sửa tên mình
            context.read<AuthService>().updateCachedFullName(
              staff['fullName']?.toString() ?? currentUser?.fullName ?? '',
            );
          }
        },
      ),
    );
  }

  Future<void> _deleteStaff(dynamic staff) async {
    if (!_canLockOrDelete(staff)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Bạn không thể tự xóa tài khoản của chính mình. Chỉ Admin mới có quyền xóa tài khoản Quản lý!'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final id = staff['accountId'];
    final name = staff['fullName'] ?? '';
    final username = staff['username'] ?? '';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.delete_forever_rounded, color: AppColors.error),
            SizedBox(width: 8),
            Text('Xóa tài khoản nhân viên', style: TextStyle(fontSize: 17)),
          ],
        ),
        content: Text(
          'Bạn có chắc chắn muốn xóa tài khoản của [$name] (@$username)?\n\n'
          '⚠️ Lưu ý: Nếu nhân viên chưa có dữ liệu giao dịch (đơn hàng, hóa đơn...), tài khoản sẽ bị xóa vĩnh viễn.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Xác nhận xóa'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final db = Supabase.instance.client;
      await db.from('Accounts').delete().eq('AccountId', id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Đã xóa tài khoản [$name] thành công'),
            backgroundColor: AppColors.success,
          ),
        );
        _loadStaff();
      }
    } catch (_) {
      if (!mounted) return;
      final shouldLock = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange),
              SizedBox(width: 8),
              Text('Không thể xóa vĩnh viễn', style: TextStyle(fontSize: 16)),
            ],
          ),
          content: Text(
            'Tài khoản [$name] đã có lịch sử gắn liền với hệ thống (đơn món, hóa đơn thanh toán...). Để đảm bảo dữ liệu kế toán không bị sai lệch, không thể xóa vật lý tài khoản này.\n\n'
            'Bạn có muốn chuyển sang "Khóa tài khoản" để nhân viên không thể đăng nhập nữa?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Đóng'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(backgroundColor: AppColors.error),
              child: const Text('Khóa tài khoản ngay'),
            ),
          ],
        ),
      );

      if (shouldLock == true) {
        try {
          final db = Supabase.instance.client;
          await db.from('Accounts').update({'IsActive': false}).eq('AccountId', id);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('🔒 Đã khóa tài khoản [$name] thành công'),
                backgroundColor: AppColors.primary,
              ),
            );
            _loadStaff();
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Lỗi khi khóa tài khoản: $e')),
            );
          }
        }
      }
    }
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
    final canLockOrDelete = _canLockOrDelete(staff);
    final currentUser = context.read<AuthService>().currentUser;
    final isSelf = (accountId == currentUser?.accountId);

    final roleLabel = switch (role) {
      0 => '👑 Admin / Chủ nhà hàng',
      2 => '🏢 Quản lý chi nhánh',
      1 => '🛎️ Nhân viên phục vụ bàn',
      4 => '💳 Nhân viên thu ngân tại quầy',
      5 => '🍲 Nhân viên bếp (KDS)',
      _ => '👤 Nhân viên',
    };
    final roleColor = switch (role) {
      0 => const Color(0xFF7C3AED),
      2 => AppColors.primary,
      4 => Colors.amber[800]!,
      5 => Colors.deepOrange,
      _ => AppColors.onSurfaceVariant,
    };

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
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
              const SizedBox(height: 20),
              Row(
                children: [
                  Container(
                    width: 68,
                    height: 68,
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
                      style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: roleColor),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                fullName,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 19),
                              ),
                            ),
                            if (isSelf) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withAlpha(20),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'Tài khoản của bạn',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                            ],
                          ],
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
              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 12),
              _detailRow(Icons.badge_outlined, 'Vai trò', roleLabel, roleColor),
              _detailRow(
                isActive ? Icons.check_circle_outline_rounded : Icons.block_flipped,
                'Trạng thái tài khoản',
                isActive ? 'Đang hoạt động' : 'Bị khóa / Tạm ngưng',
                isActive ? Colors.green : Colors.red,
              ),
              _detailRow(
                staff['gender'] == 1 ? Icons.female_rounded : Icons.male_rounded,
                'Giới tính',
                staff['gender'] == 1 ? 'Nữ' : 'Nam',
                Colors.black87,
              ),
              _detailRow(Icons.store_outlined, 'Chi nhánh làm việc', branchName, Colors.black87),
              _detailRow(Icons.phone_outlined, 'Số điện thoại', phone.isEmpty ? 'Chưa cập nhật' : phone, Colors.black87),
              _detailRow(Icons.email_outlined, 'Email liên hệ', email.isEmpty ? 'Chưa cập nhật' : email, Colors.black87),
              _detailRow(Icons.fingerprint_rounded, 'Mã tài khoản (ID)', 'ACC-$accountId', Colors.black54),
              const SizedBox(height: 16),

              // Hàng 1: Chỉnh sửa thông tin & Đổi mật khẩu (luôn cho phép với tài khoản của mình và nhân viên)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _showEditStaffDialog(staff);
                      },
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: const Text('Chỉnh sửa', style: TextStyle(fontWeight: FontWeight.w600)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _resetPassword(staff);
                      },
                      icon: const Icon(Icons.lock_reset_rounded, size: 18),
                      label: const Text('Đổi mật khẩu', style: TextStyle(fontWeight: FontWeight.w600)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),

              // Hàng 2: Khóa & Xóa (CHỈ hiển thị khi có quyền canLockOrDelete)
              if (canLockOrDelete) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _toggleActive(staff);
                        },
                        icon: Icon(isActive ? Icons.lock_rounded : Icons.lock_open_rounded, size: 18),
                        label: Text(isActive ? 'Khóa tài khoản' : 'Mở khóa tài khoản', style: const TextStyle(fontWeight: FontWeight.w600)),
                        style: FilledButton.styleFrom(
                          backgroundColor: isActive ? Colors.orange[800] : AppColors.success,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _deleteStaff(staff);
                        },
                        icon: const Icon(Icons.delete_outline_rounded, size: 18),
                        label: const Text('Xóa tài khoản', style: TextStyle(fontWeight: FontWeight.w600)),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.error,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
              ] else ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.amber.withAlpha(25),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.amber.withAlpha(100)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.shield_outlined, size: 18, color: Color(0xFFB45309)),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Bạn có thể cập nhật thông tin & mật khẩu, nhưng không thể tự khóa/xóa tài khoản Quản lý (Chỉ Admin mới có quyền khóa).',
                          style: TextStyle(fontSize: 12, color: Color(0xFF92400E), fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Đóng', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey)),
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
      padding: const EdgeInsets.only(bottom: 12),
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

  Widget _buildBranchHeader() {
    if (_isOwner) {
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

    // Nếu là Quản lý chi nhánh (Role = 2): Chỉ hiển thị cố định chi nhánh của mình
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      margin: const EdgeInsets.only(bottom: 8),
      color: Colors.white,
      child: Row(
        children: [
          const Icon(Icons.store_rounded, color: AppColors.primary, size: 20),
          const SizedBox(width: 8),
          const Text('Chi nhánh quản lý:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _managerBranchName.isNotEmpty ? _managerBranchName : 'Chi nhánh của bạn',
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: AppColors.primary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.primary.withAlpha(18),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text(
              'Cố định theo quyền QL',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.primary),
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
    final currentUserId = context.watch<AuthService>().currentUser?.accountId;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: Text(
          l10n.translate('staff_registry'),
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadStaff,
            tooltip: 'Làm mới danh sách',
          ),
          IconButton(
            icon: const Icon(Icons.person_add_rounded),
            color: AppColors.primary,
            onPressed: _showAddStaffDialog,
            tooltip: 'Thêm nhân viên mới',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildBranchHeader(),
          // Search + filter bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Column(
              children: [
                TextField(
                  controller: _searchCtrl,
                  onChanged: (v) => setState(() => _searchQuery = v),
                  decoration: InputDecoration(
                    hintText: 'Tìm theo tên, username, SĐT, email...',
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
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _FilterChip(
                        label: 'Tất cả',
                        selected: _roleFilter == null,
                        onTap: () => setState(() {
                          _roleFilter = null;
                          _loadStaff();
                        }),
                      ),
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: '🛎️ Phục vụ',
                        selected: _roleFilter == 1,
                        onTap: () => setState(() {
                          _roleFilter = 1;
                          _loadStaff();
                        }),
                      ),
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: '💳 Thu ngân',
                        selected: _roleFilter == 4,
                        onTap: () => setState(() {
                          _roleFilter = 4;
                          _loadStaff();
                        }),
                      ),
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: '🍲 Bếp (KDS)',
                        selected: _roleFilter == 5,
                        onTap: () => setState(() {
                          _roleFilter = 5;
                          _loadStaff();
                        }),
                      ),
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: '🏢 Quản lý',
                        selected: _roleFilter == 2,
                        onTap: () => setState(() {
                          _roleFilter = 2;
                          _loadStaff();
                        }),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '${filtered.length} người',
                        style: TextStyle(fontSize: 13, color: AppColors.onSurfaceVariant),
                      ),
                    ],
                  ),
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
                              separatorBuilder: (context, index) => const SizedBox(height: 12),
                              itemBuilder: (_, i) {
                                final item = filtered[i];
                                final isSelf = (item['accountId'] == currentUserId);
                                final canLock = _canLockOrDelete(item);
                                return GestureDetector(
                                  onTap: () => _showStaffDetailsSheet(context, item),
                                  child: _StaffCard(
                                    staff: item,
                                    isSelf: isSelf,
                                    canLockOrDelete: canLock,
                                    onEdit: () => _showEditStaffDialog(item),
                                    onToggle: () => _toggleActive(item),
                                    onResetPw: () => _resetPassword(item),
                                    onDelete: () => _deleteStaff(item),
                                  ),
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
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected ? AppColors.primary : AppColors.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _StaffCard extends StatelessWidget {
  final dynamic staff;
  final bool isSelf;
  final bool canLockOrDelete;
  final VoidCallback onEdit;
  final VoidCallback onToggle;
  final VoidCallback onResetPw;
  final VoidCallback onDelete;

  const _StaffCard({
    required this.staff,
    required this.isSelf,
    required this.canLockOrDelete,
    required this.onEdit,
    required this.onToggle,
    required this.onResetPw,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final role = staff['role'] as int? ?? 1;
    final isActive = staff['isActive'] as bool? ?? true;
    final fullName = staff['fullName'] as String? ?? '';
    final username = staff['username'] as String? ?? '';
    final phone = staff['phone'] as String? ?? '';
    final branchName = staff['branchName'] as String? ?? '—';

    final roleLabel = switch (role) {
      0 => '👑 Admin',
      2 => '🏢 Quản lý',
      1 => '🛎️ Phục vụ',
      4 => '💳 Thu ngân',
      5 => '🍲 Bếp (KDS)',
      _ => '👤 Nhân viên',
    };
    final roleColor = switch (role) {
      0 => const Color(0xFF7C3AED),
      2 => AppColors.primary,
      4 => Colors.amber[800]!,
      5 => Colors.deepOrange,
      _ => AppColors.onSurfaceVariant,
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(
          color: isSelf
              ? AppColors.primary.withAlpha(120)
              : AppColors.outlineVariant.withAlpha(60),
          width: isSelf ? 1.5 : 1.0,
        ),
        boxShadow: AppTheme.shadowLevel1,
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Avatar
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    roleColor.withAlpha(60),
                    roleColor.withAlpha(30),
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
                        Expanded(
                          child: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  fullName,
                                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (isSelf) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withAlpha(20),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    'Bạn',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                          decoration: BoxDecoration(
                            color: isActive ? const Color(0xFFDCFCE7) : AppColors.errorContainer,
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: Text(
                            isActive ? 'Hoạt động' : 'Đã khóa',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isActive ? const Color(0xFF16A34A) : AppColors.error,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '@$username',
                      style: TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant),
                    ),
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
              Text(
                roleLabel,
                style: TextStyle(fontSize: 12, color: roleColor, fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: 10),
              Icon(Icons.phone_outlined, size: 14, color: AppColors.onSurfaceVariant),
              const SizedBox(width: 4),
              Text(
                phone.isNotEmpty ? phone : '—',
                style: TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant),
              ),
              const SizedBox(width: 10),
              Icon(Icons.store_outlined, size: 14, color: AppColors.onSurfaceVariant),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  branchName,
                  style: TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Hàng nút thao tác CRUD
          Row(
            children: [
              // Nút Sửa
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 14),
                  label: const Text('Sửa', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              // Nút Đổi mật khẩu
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onResetPw,
                  icon: const Icon(Icons.lock_reset_rounded, size: 15),
                  label: const Text('Đổi MK', style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              if (canLockOrDelete) ...[
                const SizedBox(width: 6),
                // Nút Khóa / Mở (Chỉ hiển thị khi được phép)
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onToggle,
                    icon: Icon(isActive ? Icons.lock_outline_rounded : Icons.lock_open_rounded, size: 14),
                    label: Text(isActive ? 'Khóa' : 'Mở', style: const TextStyle(fontSize: 12)),
                    style: FilledButton.styleFrom(
                      backgroundColor: isActive ? Colors.orange[800] : AppColors.success,
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                // Nút Xóa
                IconButton(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                  color: AppColors.error,
                  tooltip: 'Xóa tài khoản',
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.error.withAlpha(20),
                    padding: const EdgeInsets.all(8),
                  ),
                ),
              ],
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
          Text(
            'Không tìm thấy nhân viên',
            style: TextStyle(fontSize: 16, color: AppColors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

/// Bottom Sheet: Thêm nhân viên mới (Đã fix triệt để lỗi null Avatar 23502 trên Supabase)
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
  final _emailCtrl = TextEditingController();
  int _role = 1; // default: 1 - Phục vụ
  int _gender = 0; // 0: Nam, 1: Nữ
  int? _selectedBranchId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _selectedBranchId = widget.branchId;
    if (widget.isAdmin && widget.branches.isNotEmpty && _selectedBranchId == null) {
      _selectedBranchId = widget.branches.first.branchId;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _userCtrl.dispose();
    _pwCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  String _avatarForRole(int role, [int gender = 0]) {
    switch (role) {
      case 0:
        return '👑';
      case 2:
        return '🏢';
      case 4:
        return '💳';
      case 5:
        return '🍲';
      default:
        return gender == 1 ? '👩‍💼' : '🛎️';
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final username = _userCtrl.text.trim();
    final email = _emailCtrl.text.trim();

    setState(() => _saving = true);
    try {
      final db = Supabase.instance.client;

      // 1. Kiểm tra trùng Username trong bảng Accounts
      final existing = await db
          .from('Accounts')
          .select('AccountId')
          .ilike('Username', username)
          .maybeSingle();

      if (existing != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('⚠️ Tên đăng nhập này đã tồn tại! Vui lòng chọn tên khác.'),
              backgroundColor: AppColors.error,
            ),
          );
        }
        setState(() => _saving = false);
        return;
      }

      // 2. Tạo bản ghi trực tiếp vào bảng Accounts với đầy đủ trường NOT NULL ("Avatar", "Role", "Gender", "BranchId")
      final nowIso = DateTime.now().toIso8601String();
      final inserted = await db
          .from('Accounts')
          .insert({
            'Username': username,
            'PasswordHash': r'$2a$11$tempPlaceholderHashBeforeRpcReset0000000000000000000',
            'Role': _role,
            'FullName': _nameCtrl.text.trim(),
            'Phone': _phoneCtrl.text.trim().isNotEmpty ? _phoneCtrl.text.trim() : null,
            'Email': email.isNotEmpty ? email : null,
            'Avatar': _avatarForRole(_role, _gender),
            'Gender': _gender,
            'BranchId': _selectedBranchId,
            'IsActive': true,
            'JoinDate': nowIso,
            'CreatedAt': nowIso,
          })
          .select('AccountId')
          .single();

      final newAccountId = inserted['AccountId'] as int;

      // 3. Gọi RPC reset_staff_password để mã hóa mật khẩu chuẩn BCrypt (pgcrypto) trên Supabase
      await db.rpc('reset_staff_password', params: {
        'p_staff_id': newAccountId,
        'p_new_password': _pwCtrl.text,
      });

      if (mounted) {
        Navigator.pop(context);
        widget.onSuccess();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Đã tạo tài khoản nhân viên [$username] thành công!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi khi tạo tài khoản: $e'),
            backgroundColor: AppColors.error,
          ),
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
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Thêm nhân viên mới',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 18),

              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Họ và tên *',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: (v) => v == null || v.trim().isEmpty ? 'Bắt buộc nhập họ tên' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _userCtrl,
                decoration: const InputDecoration(
                  labelText: 'Tên đăng nhập (Username) *',
                  prefixIcon: Icon(Icons.alternate_email_rounded),
                ),
                validator: (v) => v == null || v.trim().isEmpty ? 'Bắt buộc nhập tên đăng nhập' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _pwCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Mật khẩu * (≥6 ký tự)',
                  prefixIcon: Icon(Icons.lock_outline),
                ),
                validator: (v) => v == null || v.length < 6 ? 'Mật khẩu ít nhất 6 ký tự' : null,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _phoneCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Số điện thoại',
                        prefixIcon: Icon(Icons.phone_outlined),
                      ),
                      keyboardType: TextInputType.phone,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: _emailCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                      keyboardType: TextInputType.emailAddress,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              if (widget.isAdmin) ...[
                Text('Chi nhánh làm việc *', style: TextStyle(fontSize: 13, color: AppColors.onSurfaceVariant)),
                const SizedBox(height: 8),
                DropdownButtonFormField<int>(
                  initialValue: _selectedBranchId,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.store_outlined),
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: widget.branches
                      .map((b) => DropdownMenuItem<int>(
                            value: b.branchId,
                            child: Text(b.name),
                          ))
                      .toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedBranchId = val;
                    });
                  },
                  validator: (val) => val == null ? 'Vui lòng chọn chi nhánh' : null,
                ),
                const SizedBox(height: 14),
              ],

              Text('Giới tính', style: TextStyle(fontSize: 13, color: AppColors.onSurfaceVariant)),
              const SizedBox(height: 8),
              Row(
                children: [
                  _RoleOption(
                    label: '👨 Nam',
                    value: 0,
                    selected: _gender,
                    onTap: () => setState(() => _gender = 0),
                  ),
                  const SizedBox(width: 8),
                  _RoleOption(
                    label: '👩 Nữ',
                    value: 1,
                    selected: _gender,
                    onTap: () => setState(() => _gender = 1),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              Text('Vai trò vận hành', style: TextStyle(fontSize: 13, color: AppColors.onSurfaceVariant)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _RoleOption(
                    label: '🛎️ Phục vụ',
                    value: 1,
                    selected: _role,
                    onTap: () => setState(() => _role = 1),
                  ),
                  _RoleOption(
                    label: '💳 Thu ngân',
                    value: 4,
                    selected: _role,
                    onTap: () => setState(() => _role = 4),
                  ),
                  _RoleOption(
                    label: '🍲 Bếp (KDS)',
                    value: 5,
                    selected: _role,
                    onTap: () => setState(() => _role = 5),
                  ),
                  if (widget.isAdmin)
                    _RoleOption(
                      label: '🏢 Quản lý',
                      value: 2,
                      selected: _role,
                      onTap: () => setState(() => _role = 2),
                    ),
                ],
              ),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _saving ? null : _submit,
                  style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
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

/// Bottom Sheet: Sửa thông tin nhân viên
class _EditStaffSheet extends StatefulWidget {
  final dynamic staff;
  final bool isAdmin;
  final bool isSelf;
  final List<Branch> branches;
  final VoidCallback onSuccess;

  const _EditStaffSheet({
    required this.staff,
    required this.isAdmin,
    required this.isSelf,
    required this.branches,
    required this.onSuccess,
  });

  @override
  State<_EditStaffSheet> createState() => _EditStaffSheetState();
}

class _EditStaffSheetState extends State<_EditStaffSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _emailCtrl;
  late int _role;
  late int _gender;
  int? _selectedBranchId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.staff['fullName'] as String? ?? '');
    _phoneCtrl = TextEditingController(text: widget.staff['phone'] as String? ?? '');
    _emailCtrl = TextEditingController(text: widget.staff['email'] as String? ?? '');
    _role = widget.staff['role'] as int? ?? 1;
    _gender = widget.staff['gender'] as int? ?? 0;
    _selectedBranchId = widget.staff['branchId'] as int?;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  String _avatarForRole(int role, [int gender = 0]) {
    switch (role) {
      case 0:
        return '👑';
      case 2:
        return '🏢';
      case 4:
        return '💳';
      case 5:
        return '🍲';
      default:
        return gender == 1 ? '👩‍💼' : '🛎️';
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    try {
      final db = Supabase.instance.client;
      final accountId = widget.staff['accountId'];

      final phone = _phoneCtrl.text.trim();
      final email = _emailCtrl.text.trim();
      final updates = <String, dynamic>{
        'FullName': _nameCtrl.text.trim(),
        'Phone': phone.isNotEmpty ? phone : null,
        'Email': email.isNotEmpty ? email : null,
        'Role': _role,
        'Gender': _gender,
        'Avatar': _avatarForRole(_role, _gender),
      };

      if (widget.isAdmin && _selectedBranchId != null) {
        updates['BranchId'] = _selectedBranchId;
      }

      await db.from('Accounts').update(updates).eq('AccountId', accountId);

      if (mounted) {
        Navigator.pop(context);
        widget.onSuccess();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Đã cập nhật thông tin [${_nameCtrl.text.trim()}]'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi khi cập nhật thông tin: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final username = widget.staff['username'] as String? ?? '';
    final canChangeRole = widget.isAdmin || (!widget.isSelf && _role != 2 && _role != 0);

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
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.isSelf ? 'Cập nhật hồ sơ của bạn' : 'Chỉnh sửa thông tin nhân viên',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.outlineVariant),
                    ),
                    child: Text(
                      '@$username',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Họ và tên *',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: (v) => v == null || v.trim().isEmpty ? 'Bắt buộc nhập họ tên' : null,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _phoneCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Số điện thoại',
                        prefixIcon: Icon(Icons.phone_outlined),
                      ),
                      keyboardType: TextInputType.phone,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: _emailCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Email liên hệ',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                      keyboardType: TextInputType.emailAddress,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              if (widget.isAdmin) ...[
                Text('Chi nhánh làm việc *', style: TextStyle(fontSize: 13, color: AppColors.onSurfaceVariant)),
                const SizedBox(height: 8),
                DropdownButtonFormField<int>(
                  initialValue: _selectedBranchId,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.store_outlined),
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: widget.branches
                      .map((b) => DropdownMenuItem<int>(
                            value: b.branchId,
                            child: Text(b.name),
                          ))
                      .toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedBranchId = val;
                    });
                  },
                  validator: (val) => val == null ? 'Vui lòng chọn chi nhánh' : null,
                ),
                const SizedBox(height: 14),
              ],

              if (canChangeRole) ...[
                Text('Giới tính', style: TextStyle(fontSize: 13, color: AppColors.onSurfaceVariant)),
              const SizedBox(height: 8),
              Row(
                children: [
                  _RoleOption(
                    label: '👨 Nam',
                    value: 0,
                    selected: _gender,
                    onTap: () => setState(() => _gender = 0),
                  ),
                  const SizedBox(width: 8),
                  _RoleOption(
                    label: '👩 Nữ',
                    value: 1,
                    selected: _gender,
                    onTap: () => setState(() => _gender = 1),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              Text('Vai trò vận hành', style: TextStyle(fontSize: 13, color: AppColors.onSurfaceVariant)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _RoleOption(
                      label: '🛎️ Phục vụ',
                      value: 1,
                      selected: _role,
                      onTap: () => setState(() => _role = 1),
                    ),
                    _RoleOption(
                      label: '💳 Thu ngân',
                      value: 4,
                      selected: _role,
                      onTap: () => setState(() => _role = 4),
                    ),
                    _RoleOption(
                      label: '🍲 Bếp (KDS)',
                      value: 5,
                      selected: _role,
                      onTap: () => setState(() => _role = 5),
                    ),
                    if (widget.isAdmin)
                      _RoleOption(
                        label: '🏢 Quản lý',
                        value: 2,
                        selected: _role,
                        onTap: () => setState(() => _role = 2),
                      ),
                  ],
                ),
                const SizedBox(height: 24),
              ] else ...[
                const SizedBox(height: 8),
              ],

              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _saving ? null : _submit,
                  style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Lưu thay đổi', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
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

  const _RoleOption({
    required this.label,
    required this.value,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = selected == value;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withAlpha(25) : AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.outlineVariant,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? AppColors.primary : AppColors.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
