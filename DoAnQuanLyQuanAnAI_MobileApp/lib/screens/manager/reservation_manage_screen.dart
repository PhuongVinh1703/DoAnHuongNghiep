import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:doanquanlyquananai_mobileapp/core/constants/app_colors.dart';
import 'package:doanquanlyquananai_mobileapp/models/reservation/reservation.dart';
import 'package:doanquanlyquananai_mobileapp/services/reservation_service.dart';
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
    setState(() {
      _isLoading = false;
      _pending   = r1.data ?? [];
      _confirmed = r2.data ?? [];
    });
  }

  Future<void> _updateStatus(Reservation r, int newStatus, {String? note}) async {
    final result = await _svc.updateStatus(r.reservationId, newStatus, managerNote: note);
    result.fold(
      onSuccess: (_) { AppSnackbar.showSuccess(context, 'Đã cập nhật!'); _loadData(); },
      onFailure: (e) => AppSnackbar.showError(context, e),
    );
  }

  Future<List<dynamic>> _fetchStaff(int branchId) async {
    try {
      final db = Supabase.instance.client;
      final res = await db
          .from('Accounts')
          .select()
          .eq('Role', AppConstants.roleStaff)
          .eq('BranchId', branchId)
          .eq('IsActive', true);

      return (res as List).map((acc) => {
        'accountId': acc['AccountId'] ?? acc['accountId'],
        'fullName': acc['FullName'] ?? acc['fullName'],
        'username': acc['Username'] ?? acc['username'] ?? '',
        'role': acc['Role'] ?? acc['role'],
        'branchId': acc['BranchId'] ?? acc['branchId'],
      }).toList();
    } catch (e) {
      debugPrint('Error fetching staff: $e');
    }
    return [];
  }

  void _showAssignStaffBottomSheet(Reservation r) {
    final isMorning = r.reservedAt.hour < 15;
    final shiftLabel = isMorning ? 'Ca Sáng (08:00 - 15:00)' : 'Ca Tối (15:00 - 22:00)';

    // States for bottom sheet
    dynamic selectedStaffAcc;
    bool opt1 = false; // Upsell đặc sản kèm rượu vang
    bool opt2 = false; // Combo tráng miệng cao cấp
    bool opt3 = false; // Hướng dẫn cài App tích điểm
    bool exp1 = false; // Set up bàn sạch trước 15 phút
    bool exp2 = false; // Chào đón nồng nhiệt chuẩn VIP
    bool exp3 = false; // Ưu tiên ra món pre-order nhanh
    final customNoteCtrl = TextEditingController();

    // Check if there is an existing assignment to populate fields
    if (r.managerNote != null && r.managerNote!.isNotEmpty) {
      final note = r.managerNote!;
      if (note.contains('Ghi chú thêm: ')) {
        final rawCustom = note.split('Ghi chú thêm: ').last;
        customNoteCtrl.text = rawCustom.endsWith(']')
            ? rawCustom.substring(0, rawCustom.length - 1).trim()
            : rawCustom.trim();
      } else if (!note.startsWith('[Giao việc:')) {
        customNoteCtrl.text = note;
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.85,
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
                      const Text(
                        'Phân Công Ca Trực & Tối Ưu',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withAlpha(20),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.primary.withAlpha(50)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.access_time_filled_rounded, color: AppColors.primary, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'Ca làm việc: $shiftLabel',
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '1. Chọn Nhân viên hỗ trợ bàn',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          const SizedBox(height: 8),
                          FutureBuilder<List<dynamic>>(
                            future: _fetchStaff(r.branchId),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState == ConnectionState.waiting) {
                                return const SizedBox(
                                  height: 100,
                                  child: Center(child: CircularProgressIndicator()),
                                );
                              }
                              final staffList = snapshot.data ?? [];
                              if (staffList.isEmpty) {
                                return const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 12),
                                  child: Text(
                                    'Không tìm thấy nhân viên chi nhánh.',
                                    style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
                                  ),
                                );
                              }

                              return SizedBox(
                                height: 110,
                                child: ListView.builder(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: staffList.length,
                                  itemBuilder: (context, idx) {
                                    final st = staffList[idx];
                                    final stName = st['fullName'] ?? 'Staff';
                                    final stUser = st['username'] ?? '';
                                    final isSelected = selectedStaffAcc != null && selectedStaffAcc['accountId'] == st['accountId'];
                                    
                                    // Simulated shift: even morning, odd evening
                                    final isOnShift = isMorning ? (idx % 2 == 0) : (idx % 2 != 0);

                                    return GestureDetector(
                                      onTap: () {
                                        setModalState(() {
                                          selectedStaffAcc = st;
                                        });
                                      },
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
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withValues(alpha: 0.05),
                                              blurRadius: 4,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
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
                              );
                            },
                          ),
                          const SizedBox(height: 16),

                          const Text(
                            '2. Chỉ dẫn Tối ưu doanh thu (Lợi nhuận)',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          CheckboxListTile(
                            title: const Text('Upsell đặc sản (Lẩu cua, Bào ngư) kèm Rượu vang', style: TextStyle(fontSize: 13)),
                            value: opt1,
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            activeColor: AppColors.primary,
                            onChanged: (val) => setModalState(() => opt1 = val ?? false),
                          ),
                          CheckboxListTile(
                            title: const Text('Gợi ý combo tráng miệng cao cấp sau bữa ăn', style: TextStyle(fontSize: 13)),
                            value: opt2,
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            activeColor: AppColors.primary,
                            onChanged: (val) => setModalState(() => opt2 = val ?? false),
                          ),
                          CheckboxListTile(
                            title: const Text('Hướng dẫn khách đăng ký thành viên VIP tích điểm', style: TextStyle(fontSize: 13)),
                            value: opt3,
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            activeColor: AppColors.primary,
                            onChanged: (val) => setModalState(() => opt3 = val ?? false),
                          ),
                          const SizedBox(height: 12),

                          const Text(
                            '3. Chỉ dẫn Tối ưu trải nghiệm (Giữ chân khách)',
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
                            title: const Text('Đón tiếp nồng nhiệt theo chuẩn khách VIP', style: TextStyle(fontSize: 13)),
                            value: exp2,
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            activeColor: AppColors.primary,
                            onChanged: (val) => setModalState(() => exp2 = val ?? false),
                          ),
                          CheckboxListTile(
                            title: const Text('Ưu tiên ra món pre-order ngay khi khách ngồi bàn', style: TextStyle(fontSize: 13)),
                            value: exp3,
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            activeColor: AppColors.primary,
                            onChanged: (val) => setModalState(() => exp3 = val ?? false),
                          ),
                          const SizedBox(height: 12),

                          const Text(
                            '4. Ghi chú thêm từ Quản lý',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: customNoteCtrl,
                            decoration: const InputDecoration(
                              hintText: 'Nhập hướng dẫn tuỳ chỉnh khác cho nhân viên...',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                            maxLines: 2,
                            style: const TextStyle(fontSize: 13),
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () {
                        if (selectedStaffAcc == null) {
                          AppSnackbar.showError(context, 'Vui lòng chọn nhân viên để giao việc!');
                          return;
                        }

                        final selectedName = selectedStaffAcc['fullName'] ?? 'Nhân viên';
                        
                        final tasks = <String>[];
                        if (opt1) tasks.add('Upsell đặc sản');
                        if (opt2) tasks.add('Gợi ý tráng miệng');
                        if (opt3) tasks.add('Tư vấn VIP');
                        if (exp1) tasks.add('Set up bàn sạch');
                        if (exp2) tasks.add('Đón chuẩn VIP');
                        if (exp3) tasks.add('Ra món pre-order');

                        final customNote = customNoteCtrl.text.trim();
                        
                        final formattedNote = '[Giao việc: $selectedName | $shiftLabel] '
                            'Nhiệm vụ: ${tasks.isEmpty ? 'Hỗ trợ phục vụ bàn.' : tasks.join(', ')}.'
                            '${customNote.isNotEmpty ? ' Ghi chú thêm: $customNote' : ''}';

                        Navigator.pop(context);
                        _updateStatus(r, ReservationStatus.confirmed, note: formattedNote);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text(
                        'Xác nhận & Giao nhiệm vụ',
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
          Text(AppDateUtils.timeAgo(r.createdAt), style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        ]),
        const SizedBox(height: 6),
        _row(Icons.store_rounded, 'Chi nhánh: ${r.branchName ?? '—'}'),
        _row(Icons.phone, r.customerPhone),
        _row(Icons.access_time, '${AppDateUtils.formatDateTime(r.reservedAt)} ($shiftText)'),
        _row(Icons.people, '${r.guestCount} khách'),
        if (r.note != null && r.note!.isNotEmpty) _row(Icons.note, 'Ghi chú khách: ${r.note!}'),
        if (r.managerNote != null && r.managerNote!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(children: [
              const Icon(Icons.assignment_ind, size: 14, color: AppColors.primary),
              const SizedBox(width: 6),
              Expanded(child: Text('Phân công QL: ${r.managerNote!}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primary))),
            ]),
          ),
        if (showActions) ...[
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: OutlinedButton.icon(
              onPressed: () => _updateStatus(r, ReservationStatus.rejected),
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
              icon: const Icon(Icons.assignment_ind_outlined, size: 16, color: Colors.white),
              label: const Text('Xác nhận & Giao việc', style: TextStyle(color: Colors.white, fontSize: 12)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            )),
          ]),
        ] else if (r.status == ReservationStatus.confirmed) ...[
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: OutlinedButton.icon(
              onPressed: () => _showAssignStaffBottomSheet(r),
              icon: const Icon(Icons.assignment_ind_rounded, size: 16),
              label: const Text('Cập nhật phân công ca trực'),
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
