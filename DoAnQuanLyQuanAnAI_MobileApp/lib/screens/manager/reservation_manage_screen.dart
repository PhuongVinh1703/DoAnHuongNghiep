import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:doanquanlyquananai_mobileapp/core/constants/app_colors.dart';
import 'package:doanquanlyquananai_mobileapp/models/reservation/reservation.dart';
import 'package:doanquanlyquananai_mobileapp/models/table/dining_table.dart';
import 'package:doanquanlyquananai_mobileapp/services/reservation_service.dart';
import 'package:doanquanlyquananai_mobileapp/services/table_service.dart';
import 'package:doanquanlyquananai_mobileapp/core/constants/app_enums.dart';
import 'package:doanquanlyquananai_mobileapp/core/utils/date_utils.dart';
import 'package:doanquanlyquananai_mobileapp/widgets/common/app_snackbar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:doanquanlyquananai_mobileapp/services/auth_service.dart';
import 'package:doanquanlyquananai_mobileapp/services/branch_service.dart';
import 'package:doanquanlyquananai_mobileapp/models/branch/branch.dart';
import 'package:doanquanlyquananai_mobileapp/config/constants.dart';

class ReservationManageScreen extends StatefulWidget {
  const ReservationManageScreen({super.key});

  @override
  State<ReservationManageScreen> createState() => _ReservationManageScreenState();
}

class _ReservationManageScreenState extends State<ReservationManageScreen>
    with SingleTickerProviderStateMixin {
  final _svc = ReservationService();
  final _tableSvc = TableService();
  late TabController _tabs;

  List<Reservation> _pending = [];
  List<Reservation> _confirmed = [];
  bool _isLoading = true;

  List<Branch> _branches = [];
  int? _selectedBranchId;
  bool _isOwner = false;

  RealtimeChannel? _realtimeChannel;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _initData();
  }

  Future<void> _initData() async {
    _subscribeRealtime();
    await _loadBranches();
    await _loadData();
  }

  Future<void> _loadBranches() async {
    final auth = context.read<AuthService>();
    final user = auth.currentUser;
    _isOwner = (user?.role == AppConstants.roleOwner);
    if (_isOwner) {
      final res = await BranchService().getBranches();
      if (res.isSuccess) {
        setState(() {
          _branches = res.data ?? [];
        });
      }
    }
  }

  @override
  void dispose() {
    _tabs.dispose();
    if (_realtimeChannel != null) {
      Supabase.instance.client.removeChannel(_realtimeChannel!);
    }
    super.dispose();
  }

  void _subscribeRealtime() {
    if (_realtimeChannel != null) return;
    _realtimeChannel = Supabase.instance.client
        .channel('reservation-screen-channel')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'Reservations',
          callback: (payload) {
            if (mounted) _loadData();
          },
        );
    _realtimeChannel!.subscribe();
  }

  Widget _buildBranchFilter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                _loadData();
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý đặt bàn', style: TextStyle(fontWeight: FontWeight.bold)),
        bottom: TabBar(
          controller: _tabs,
          tabs: [
            Tab(text: 'Chờ duyệt (${_pending.length})'),
            Tab(text: 'Đã xác nhận (${_confirmed.length})'),
          ],
        ),
      ),
      body: Column(
        children: [
          if (_isOwner) _buildBranchFilter(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabs,
                    children: [
                      _pending.isEmpty
                          ? const Center(child: Text('Không có đặt bàn chờ duyệt'))
                          : ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: _pending.length,
                              itemBuilder: (context, idx) => _buildCard(_pending[idx], showActions: true),
                            ),
                      _confirmed.isEmpty
                          ? const Center(child: Text('Không có đặt bàn đã xác nhận'))
                          : ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: _confirmed.length,
                              itemBuilder: (context, idx) => _buildCard(_confirmed[idx], showActions: false),
                            ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    int? filterBranchId;
    if (_isOwner) {
      filterBranchId = _selectedBranchId;
    } else {
      final user = context.read<AuthService>().currentUser;
      filterBranchId = user?.branchId;
    }

    final r1 = await _svc.getReservations(status: ReservationStatus.pending, branchId: filterBranchId);
    final r2 = await _svc.getReservations(status: ReservationStatus.confirmed, branchId: filterBranchId);
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _pending   = r1.data ?? [];
      _confirmed = r2.data ?? [];
    });
  }

  Future<void> _updateStatus(Reservation r, int newStatus, {String? note, String? customSuccessMsg}) async {
    final result = await _svc.updateStatus(r.reservationId, newStatus, managerNote: note);
    if (!mounted) return;
    result.fold(
      onSuccess: (_) {
        AppSnackbar.showSuccess(context, customSuccessMsg ?? 'Đã cập nhật trạng thái đặt bàn!');
        _loadData();
      },
      onFailure: (e) => AppSnackbar.showError(context, e),
    );
  }

  Future<Map<String, dynamic>> _fetchTablesAndStaff(Reservation r) async {
    final staffList = <Map<String, dynamic>>[];
    List<DiningTable> tables = [];
    final Set<int> conflictingTableIds = {};

    try {
      final db = Supabase.instance.client;
      final resStaff = await db
          .from('Accounts')
          .select()
          .eq('Role', AppConstants.roleStaff)
          .eq('BranchId', r.branchId)
          .eq('IsActive', true);

      for (final acc in (resStaff as List)) {
        staffList.add({
          'accountId': acc['AccountId'] ?? acc['accountId'],
          'fullName': acc['FullName'] ?? acc['fullName'],
          'username': acc['Username'] ?? acc['username'] ?? '',
          'role': acc['Role'] ?? acc['role'],
          'branchId': acc['BranchId'] ?? acc['branchId'],
        });
      }

      final tblRes = await _tableSvc.getTables(branchId: r.branchId);
      if (tblRes.isSuccess && tblRes.data != null) {
        tables = tblRes.data!;
      }

      // Kiểm tra các bàn đã bị gán cho đơn đặt bàn khác trong khung giờ ±90 phút
      final branchConfirmed = await _svc.getReservations(
        status: ReservationStatus.confirmed,
        branchId: r.branchId,
      );
      if (branchConfirmed.isSuccess && branchConfirmed.data != null) {
        for (final other in branchConfirmed.data!) {
          if (other.reservationId == r.reservationId) continue;
          if (other.isSeated) continue;
          final assignedId = other.assignedTableId;
          if (assignedId == null) continue;
          final diffMins = other.reservedAt.difference(r.reservedAt).inMinutes.abs();
          if (diffMins < 90) {
            conflictingTableIds.add(assignedId);
          }
        }
      }
    } catch (e) {
      debugPrint('Error fetching tables and staff: $e');
    }

    return {
      'staff': staffList,
      'tables': tables,
      'conflicts': conflictingTableIds,
    };
  }

  void _showAssignStaffBottomSheet(Reservation r) {
    final isMorning = r.reservedAt.hour < 15;
    final shiftLabel = isMorning ? 'Ca Sáng (08:00 - 15:00)' : 'Ca Tối (15:00 - 22:00)';

    DiningTable? selectedTable;
    dynamic selectedStaffAcc;
    bool opt1 = false;
    bool opt2 = false;
    bool opt3 = false;
    bool exp1 = true; // Mặc định nhắc set up bàn trước 15 phút
    bool exp2 = false;
    final customerMsgCtrl = TextEditingController(
      text: r.customerFacingNote ?? 'Hẹn đón tiếp quý khách tại nhà hàng!',
    );
    final internalNoteCtrl = TextEditingController();

    final futureData = _fetchTablesAndStaff(r);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.88,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                top: 16,
                left: 16,
                right: 16,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Expanded(
                        child: Text(
                          'Xếp Bàn Giữ Chỗ & Phân Công Ca Trực',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withAlpha(20),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.primary.withAlpha(50)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.event_seat_rounded, color: AppColors.primary, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Khách: ${r.customerName} (${r.guestCount} người) · ${AppDateUtils.formatDateTime(r.reservedAt)}',
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  Expanded(
                    child: FutureBuilder<Map<String, dynamic>>(
                      future: futureData,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        final data = snapshot.data ?? {};
                        final tables = (data['tables'] as List<DiningTable>?) ?? [];
                        final staffList = (data['staff'] as List<Map<String, dynamic>>?) ?? [];
                        final conflicts = (data['conflicts'] as Set<int>?) ?? <int>{};

                        // Tự động chọn bàn đã gán trước đó hoặc bàn trống phù hợp đầu tiên
                        if (selectedTable == null && tables.isNotEmpty) {
                          if (r.assignedTableId != null) {
                            final found = tables.where((t) => t.tableId == r.assignedTableId);
                            if (found.isNotEmpty) selectedTable = found.first;
                          }
                          selectedTable ??= tables
                              .where((t) => !conflicts.contains(t.tableId) && t.capacity >= r.guestCount)
                              .firstOrNull;
                        }

                        return SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // ── 1. Chọn bàn giữ chỗ (Chống trùng giờ & Kiểm tra sức chứa) ──
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    '1. Chọn Bàn giữ chỗ (Chống trùng khung giờ)',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                  Text(
                                    'Cần >= ${r.guestCount} ghế',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                '💡 Bàn chỉ tự động chuyển màu Vàng (Đã đặt) trong vòng 60 phút trước giờ hẹn để không khóa bàn cả ngày.',
                                style: TextStyle(fontSize: 11, color: Colors.grey, fontStyle: FontStyle.italic),
                              ),
                              const SizedBox(height: 8),
                              if (tables.isEmpty)
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 8),
                                  child: Text('Chi nhánh chưa có bàn nào.', style: TextStyle(color: Colors.grey)),
                                )
                              else
                                SizedBox(
                                  height: 96,
                                  child: ListView.builder(
                                    scrollDirection: Axis.horizontal,
                                    itemCount: tables.length,
                                    itemBuilder: (context, idx) {
                                      final t = tables[idx];
                                      final isConflict = conflicts.contains(t.tableId);
                                      final isEnoughCap = t.capacity >= r.guestCount;
                                      final isSelected = selectedTable?.tableId == t.tableId;

                                      return GestureDetector(
                                        onTap: isConflict
                                            ? null
                                            : () => setModalState(() => selectedTable = t),
                                        child: Container(
                                          width: 135,
                                          margin: const EdgeInsets.only(right: 10, bottom: 4),
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            color: isConflict
                                                ? Colors.grey[100]
                                                : isSelected
                                                    ? AppColors.primary.withAlpha(22)
                                                    : Colors.white,
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(
                                              color: isConflict
                                                  ? Colors.grey[300]!
                                                  : isSelected
                                                      ? AppColors.primary
                                                      : (isEnoughCap ? const Color(0xFF16A34A) : Colors.orange),
                                              width: isSelected ? 2 : 1,
                                            ),
                                          ),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      t.tableName,
                                                      style: TextStyle(
                                                        fontWeight: FontWeight.bold,
                                                        fontSize: 13,
                                                        color: isConflict ? Colors.grey : Colors.black87,
                                                      ),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                  if (isSelected)
                                                    const Icon(Icons.check_circle, size: 16, color: AppColors.primary),
                                                ],
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                'Sức chứa: ${t.capacity} ghế',
                                                style: TextStyle(fontSize: 11, color: Colors.grey[700]),
                                              ),
                                              const SizedBox(height: 4),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: isConflict
                                                      ? Colors.red[50]
                                                      : isEnoughCap
                                                          ? const Color(0xFFDCFCE7)
                                                          : const Color(0xFFFEF3C7),
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  isConflict
                                                      ? 'Đã trùng lịch đặt'
                                                      : isEnoughCap
                                                          ? 'Phù hợp'
                                                          : 'Hơi nhỏ (<${r.guestCount})',
                                                  style: TextStyle(
                                                    fontSize: 9,
                                                    fontWeight: FontWeight.bold,
                                                    color: isConflict
                                                        ? Colors.red[700]
                                                        : isEnoughCap
                                                            ? const Color(0xFF15803D)
                                                            : const Color(0xFFB45309),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),

                              const SizedBox(height: 16),

                              // ── 2. Chọn Nhân viên hỗ trợ bàn ──
                              Text(
                                '2. Chọn Nhân viên phụ trách ($shiftLabel)',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              const SizedBox(height: 8),
                              if (staffList.isEmpty)
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 8),
                                  child: Text(
                                    'Chưa có nhân viên phục vụ tại chi nhánh này (có thể duyệt không cần gán NV).',
                                    style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic, fontSize: 12),
                                  ),
                                )
                              else
                                SizedBox(
                                  height: 100,
                                  child: ListView.builder(
                                    scrollDirection: Axis.horizontal,
                                    itemCount: staffList.length,
                                    itemBuilder: (context, idx) {
                                      final st = staffList[idx];
                                      final stName = st['fullName'] ?? 'Staff';
                                      final stUser = st['username'] ?? '';
                                      final isSelected = selectedStaffAcc != null &&
                                          selectedStaffAcc['accountId'] == st['accountId'];
                                      final isOnShift = isMorning ? (idx % 2 == 0) : (idx % 2 != 0);

                                      return GestureDetector(
                                        onTap: () => setModalState(() => selectedStaffAcc = st),
                                        child: Container(
                                          width: 140,
                                          margin: const EdgeInsets.only(right: 10, bottom: 4),
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            color: isSelected
                                                ? AppColors.primary.withAlpha(20)
                                                : Colors.white,
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(
                                              color: isSelected ? AppColors.primary : Colors.grey[300]!,
                                              width: isSelected ? 2 : 1,
                                            ),
                                          ),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Text(
                                                stName,
                                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              Text(
                                                '@$stUser',
                                                style: TextStyle(color: Colors.grey[600], fontSize: 11),
                                                maxLines: 1,
                                              ),
                                              const SizedBox(height: 6),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: isOnShift ? const Color(0xFFDCFCE7) : Colors.grey[200],
                                                  borderRadius: BorderRadius.circular(100),
                                                ),
                                                child: Text(
                                                  isOnShift ? 'Trong ca trực' : 'Ngoại ca',
                                                  style: TextStyle(
                                                    fontSize: 9,
                                                    fontWeight: FontWeight.w600,
                                                    color: isOnShift ? const Color(0xFF16A34A) : Colors.grey[600],
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),

                              const SizedBox(height: 14),

                              // ── 3. Chỉ dẫn nội bộ cho Nhân viên (Ẩn hoàn toàn với Khách hàng) ──
                              const Text(
                                '3. Chỉ dẫn nội bộ cho Nhân viên (Khách hàng không nhìn thấy)',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              CheckboxListTile(
                                title: const Text('Set up bàn sạch đẹp trước giờ đón khách 15 phút', style: TextStyle(fontSize: 13)),
                                value: exp1,
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                activeColor: AppColors.primary,
                                onChanged: (val) => setModalState(() => exp1 = val ?? false),
                              ),
                              CheckboxListTile(
                                title: const Text('Đón tiếp nồng nhiệt & kiểm tra yêu cầu ghi chú của khách', style: TextStyle(fontSize: 13)),
                                value: exp2,
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                activeColor: AppColors.primary,
                                onChanged: (val) => setModalState(() => exp2 = val ?? false),
                              ),
                              CheckboxListTile(
                                title: const Text('Giới thiệu món đặc sản / Combo Lẩu & Nướng của quán', style: TextStyle(fontSize: 13)),
                                value: opt1,
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                activeColor: AppColors.primary,
                                onChanged: (val) => setModalState(() => opt1 = val ?? false),
                              ),
                              CheckboxListTile(
                                title: const Text('Gợi ý tráng miệng & Nước uống sau bữa ăn', style: TextStyle(fontSize: 13)),
                                value: opt2,
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                activeColor: AppColors.primary,
                                onChanged: (val) => setModalState(() => opt2 = val ?? false),
                              ),
                              CheckboxListTile(
                                title: const Text('Nhắc Thu ngân tích điểm thành viên cho khách khi thanh toán', style: TextStyle(fontSize: 13)),
                                value: opt3,
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                activeColor: AppColors.primary,
                                onChanged: (val) => setModalState(() => opt3 = val ?? false),
                              ),
                              const SizedBox(height: 6),
                              TextField(
                                controller: internalNoteCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'Dặn dò nội bộ thêm cho Phục vụ (tùy chọn)',
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                ),
                                style: const TextStyle(fontSize: 13),
                              ),

                              const SizedBox(height: 14),

                              // ── 4. Lời nhắn lịch sự gửi Khách hàng ──
                              const Text(
                                '4. Lời nhắn hiển thị cho Khách hàng trên App',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              const SizedBox(height: 6),
                              TextField(
                                controller: customerMsgCtrl,
                                decoration: const InputDecoration(
                                  hintText: 'Ví dụ: Nhà hàng đã giữ bàn cho quý khách, hẹn gặp quý khách!',
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                ),
                                style: const TextStyle(fontSize: 13),
                              ),
                              const SizedBox(height: 16),
                            ],
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () async {
                        if (selectedTable == null) {
                          AppSnackbar.showError(context, 'Vui lòng chọn 1 bàn để xếp giữ chỗ cho khách!');
                          return;
                        }

                        final selectedName = selectedStaffAcc != null
                            ? (selectedStaffAcc['fullName'] ?? 'Nhân viên ca trực')
                            : 'Nhân viên ca trực';

                        final tasks = <String>[];
                        if (exp1) tasks.add('Set up bàn trước 15p');
                        if (exp2) tasks.add('Đón khách & kiểm tra ghi chú');
                        if (opt1) tasks.add('Giới thiệu món đặc sản');
                        if (opt2) tasks.add('Gợi ý tráng miệng');
                        if (opt3) tasks.add('Nhắc tích điểm thành viên');

                        final extraInternal = internalNoteCtrl.text.trim();
                        final internalTaskStr = 'Phụ trách: $selectedName ($shiftLabel) | '
                            'Nhiệm vụ: ${tasks.isEmpty ? 'Đón tiếp và phục vụ bàn.' : tasks.join(', ')}.'
                            '${extraInternal.isNotEmpty ? ' Ghi chú QL: $extraInternal' : ''}';

                        final metadataNote = Reservation.buildManagerMetadata(
                          tableId: selectedTable!.tableId,
                          tableName: selectedTable!.tableName,
                          internalTask: internalTaskStr,
                          customerMessage: customerMsgCtrl.text.trim(),
                          isSeated: r.isSeated,
                        );

                        // Nếu đổi sang bàn khác, giải phóng bàn cũ nếu bàn cũ đang ở trạng thái Đã đặt (2)
                        if (r.assignedTableId != null && r.assignedTableId != selectedTable!.tableId) {
                          try {
                            await _tableSvc.updateStatus(r.assignedTableId!, 0);
                          } catch (_) {}
                        }

                        // Chỉ đổi trạng thái bàn sang Đã đặt (2) ngay lập tức nếu giờ hẹn cách hiện tại <= 60 phút
                        final minsUntil = r.reservedAt.difference(DateTime.now()).inMinutes;
                        final shouldLockNow = minsUntil <= 60 && minsUntil >= -45 && !r.isSeated;
                        if (shouldLockNow && selectedTable!.status == 0) {
                          try {
                            await _tableSvc.updateStatus(selectedTable!.tableId, 2);
                          } catch (_) {}
                        }

                        if (!context.mounted) return;
                        Navigator.pop(context);

                        final msg = shouldLockNow
                            ? 'Đã xác nhận & khóa giữ chỗ ${selectedTable!.tableName}!'
                            : 'Đã xếp ${selectedTable!.tableName}! Bàn sẽ tự động chuyển sang Giữ chỗ (Màu vàng) trước giờ hẹn 60 phút.';

                        await _updateStatus(
                          r,
                          ReservationStatus.confirmed,
                          note: metadataNote,
                          customSuccessMsg: msg,
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text(
                        'Xác nhận Giữ bàn & Giao nhiệm vụ',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildCard(Reservation r, {required bool showActions}) {
    final isMorning = r.reservedAt.hour < 15;
    final shiftText = isMorning ? 'Ca Sáng (08:00-15:00)' : 'Ca Tối (15:00-22:00)';
    final tableName = r.assignedTableName;
    final internalTask = r.internalStaffTask;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8)],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.person, size: 18, color: AppColors.primary),
          const SizedBox(width: 6),
          Expanded(child: Text(r.customerName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15))),
          if (r.isSeated)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFDCFCE7),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                '🍽️ Đã nhận bàn',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF15803D)),
              ),
            )
          else
            Text(AppDateUtils.timeAgo(r.createdAt), style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        ]),
        const SizedBox(height: 6),
        _row(Icons.store_rounded, 'Chi nhánh: ${r.branchName ?? '—'}'),
        _row(Icons.phone, r.customerPhone),
        _row(Icons.access_time, '${AppDateUtils.formatDateTime(r.reservedAt)} ($shiftText)'),
        _row(Icons.people, '${r.guestCount} khách'),
        if (tableName != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(children: [
              const Icon(Icons.table_restaurant_rounded, size: 14, color: Color(0xFF15803D)),
              const SizedBox(width: 6),
              Text(
                'Bàn được xếp: $tableName',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF15803D)),
              ),
            ]),
          ),
        if (r.note != null && r.note!.isNotEmpty) _row(Icons.note, 'Ghi chú khách: ${r.note!}'),
        if (internalTask != null && internalTask.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withAlpha(14),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.assignment_ind, size: 14, color: AppColors.primary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Nội bộ: $internalTask',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary),
                  ),
                ),
              ]),
            ),
          ),
        if (showActions) ...[
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: OutlinedButton.icon(
              onPressed: () => _updateStatus(
                r,
                ReservationStatus.rejected,
                note: 'Rất tiếc nhà hàng đã kín bàn trong khung giờ này. Mong quý khách thông cảm!',
              ),
              icon: const Icon(Icons.close, size: 16),
              label: const Text('Từ chối'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.error,
                side: const BorderSide(color: AppColors.error),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            )),
            const SizedBox(width: 10),
            Expanded(child: ElevatedButton.icon(
              onPressed: () => _showAssignStaffBottomSheet(r),
              icon: const Icon(Icons.event_seat_rounded, size: 16, color: Colors.white),
              label: const Text('Duyệt & Xếp bàn', style: TextStyle(color: Colors.white, fontSize: 12)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            )),
          ]),
        ] else if (r.status == ReservationStatus.confirmed && !r.isSeated) ...[
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: OutlinedButton.icon(
              onPressed: () => _showAssignStaffBottomSheet(r),
              icon: const Icon(Icons.edit_calendar_rounded, size: 16),
              label: const Text('Đổi bàn giữ chỗ / Cập nhật ca trực'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            )),
          ]),
        ],
      ]),
    );
  }

  Widget _row(IconData icon, String text) => Padding(
    padding: const EdgeInsets.only(top: 4),
    child: Row(children: [
      Icon(icon, size: 14, color: AppColors.textSecondary),
      const SizedBox(width: 6),
      Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
    ]),
  );
}
