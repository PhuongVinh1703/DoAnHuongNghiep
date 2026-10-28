import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:doanquanlyquananai_mobileapp/theme/app_colors.dart';
import 'package:doanquanlyquananai_mobileapp/theme/app_theme.dart';
import 'package:doanquanlyquananai_mobileapp/services/auth_service.dart';
import 'package:doanquanlyquananai_mobileapp/services/customer_provider.dart';
import 'package:doanquanlyquananai_mobileapp/services/reservation_service.dart';
import 'package:doanquanlyquananai_mobileapp/models/reservation/reservation.dart';
import 'package:doanquanlyquananai_mobileapp/widgets/common/app_snackbar.dart';
import 'package:doanquanlyquananai_mobileapp/services/branch_service.dart';
import 'package:doanquanlyquananai_mobileapp/models/branch/branch.dart';
import 'package:doanquanlyquananai_mobileapp/services/booking_notification_provider.dart';

class CustomerBookingScreen extends StatefulWidget {
  const CustomerBookingScreen({super.key});

  @override
  State<CustomerBookingScreen> createState() => _CustomerBookingScreenState();
}

class _CustomerBookingScreenState extends State<CustomerBookingScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ReservationService _reservationSvc = ReservationService();
  final BranchService _branchSvc = BranchService();

  List<Reservation> _myReservations = [];
  List<Branch> _branches = [];
  bool _isLoadingHistory = false;
  bool _isSubmitting = false;

  // Form fields
  Branch? _selectedBranch;
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _selectedTime = const TimeOfDay(hour: 12, minute: 0);
  int _guestCount = 2;
  final _noteController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadInitialData());
  }

  @override
  void dispose() {
    _tabController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    final branchResult = await _branchSvc.getBranches();
    if (mounted && branchResult.isSuccess) {
      setState(() {
        _branches = branchResult.data ?? [];
        if (_branches.isNotEmpty) _selectedBranch = _branches.first;
      });
    }
    await _loadHistory();
  }

  Future<void> _loadHistory() async {
    final prov = context.read<CustomerProvider>();
    final cust = prov.currentCustomer;
    if (cust == null) return;

    setState(() => _isLoadingHistory = true);
    final result = await _reservationSvc.getMyReservations(cust.customerId);
    if (mounted) {
      if (result.isSuccess) setState(() => _myReservations = result.data ?? []);
      setState(() => _isLoadingHistory = false);
    }
  }

  // Date and Time generation
  List<DateTime> _getAvailableDates() {
    final now = DateTime.now();
    return List.generate(14, (i) => now.add(Duration(days: i)));
  }

  List<TimeOfDay> _getAvailableTimeSlots(DateTime date) {
    final slots = <TimeOfDay>[];
    final now = DateTime.now();
    final isToday = date.year == now.year && date.month == now.month && date.day == now.day;
    
    for (int hour = 8; hour <= 21; hour++) {
      for (int minute in [0, 30]) {
        // Skip past times if today
        if (isToday) {
          if (hour < now.hour || (hour == now.hour && minute <= now.minute)) {
            continue;
          }
        }
        slots.add(TimeOfDay(hour: hour, minute: minute));
      }
    }
    return slots;
  }

  Future<void> _submitBooking() async {
    final auth = context.read<AuthService>();
    final prov = context.read<CustomerProvider>();

    if (_selectedBranch == null) {
      AppSnackbar.showError(context, 'Vui lòng chọn chi nhánh');
      return;
    }

    final reservedAt = DateTime(
      _selectedDate.year, _selectedDate.month, _selectedDate.day,
      _selectedTime.hour, _selectedTime.minute,
    );

    if (reservedAt.isBefore(DateTime.now().add(const Duration(minutes: 30)))) {
      AppSnackbar.showError(context, 'Thời gian đặt bàn phải ít nhất 30 phút từ bây giờ');
      return;
    }

    final cust = prov.currentCustomer;
    final user = auth.currentUser;

    setState(() => _isSubmitting = true);

    final String noteStr = _noteController.text.trim();

    final result = await _reservationSvc.createReservation(
      customerName:  cust?.fullName ?? user?.fullName ?? 'Khách',
      customerPhone: cust?.phone ?? user?.username ?? '',
      branchId:      _selectedBranch!.branchId,
      guestCount:    _guestCount,
      reservedAt:    reservedAt,
      note:          noteStr.isEmpty ? null : noteStr,
      customerId:    cust?.customerId,
    );

    if (mounted) {
      setState(() => _isSubmitting = false);
      if (result.isSuccess) {
        if (result.data != null) {
          context.read<BookingNotificationProvider>().addNewBookingNotification(result.data!);
        }
        AppSnackbar.showSuccess(context, 'Đặt bàn thành công! Vui lòng chờ chi nhánh xác nhận.');
        _noteController.clear();
        _tabController.animateTo(1);
        _loadHistory();
      } else {
        AppSnackbar.showError(context, result.error ?? 'Đặt bàn thất bại');
      }
    }
  }

  Future<void> _cancelReservation(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Xác nhận hủy'),
        content: const Text('Bạn có chắc muốn hủy đặt bàn này không?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Không')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Hủy bàn')),
        ],
      ),
    );
    if (confirm != true) return;

    final result = await _reservationSvc.cancelReservation(id);
    if (mounted) {
      if (result.isSuccess) {
        AppSnackbar.showSuccess(context, 'Đã hủy đặt bàn');
        _loadHistory();
      } else {
        AppSnackbar.showError(context, result.error ?? 'Hủy thất bại');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Đặt bàn'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [Tab(text: 'Đặt bàn mới'), Tab(text: 'Lịch sử đặt bàn')],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildBookingForm(), _buildHistory()],
      ),
    );
  }

  // ─── FORM ───────────────────────────────────────────────────────────────────
  Widget _buildBookingForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.marginMobile),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SizedBox(height: 4),

        // Branch selector
        _SectionLabel(label: '📍 Chi nhánh'),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            border: Border.all(color: AppColors.outlineVariant),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<Branch>(
              value: _selectedBranch,
              isExpanded: true,
              hint: const Text('Chọn chi nhánh'),
              items: _branches.map((b) => DropdownMenuItem(value: b, child: Text(b.name))).toList(),
              onChanged: (v) => setState(() => _selectedBranch = v),
            ),
          ),
        ),

        const SizedBox(height: 20),

        // Date & Time
        _SectionLabel(label: '📅 Chọn Ngày'),
        const SizedBox(height: 8),
        _buildDateSelector(),
        const SizedBox(height: 20),
        
        _SectionLabel(label: '⏰ Chọn Giờ'),
        const SizedBox(height: 8),
        _buildTimeSelector(),

        const SizedBox(height: 20),

        // Guest count
        _SectionLabel(label: '👥 Số người'),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            border: Border.all(color: AppColors.outlineVariant),
          ),
          child: Row(children: [
            IconButton(
              icon: const Icon(Icons.remove_rounded),
              onPressed: _guestCount > 1 ? () => setState(() => _guestCount--) : null,
            ),
            Expanded(
              child: Text('$_guestCount người', textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
            IconButton(
              icon: const Icon(Icons.add_rounded),
              onPressed: _guestCount < 20 ? () => setState(() => _guestCount++) : null,
            ),
          ]),
        ),

        const SizedBox(height: 20),

        // Note
        _SectionLabel(label: '📝 Ghi chú (tùy chọn)'),
        const SizedBox(height: 8),
        TextField(
          controller: _noteController,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'Yêu cầu đặc biệt, dị ứng thực phẩm...',
            filled: true,
            fillColor: AppColors.surfaceContainerLowest,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              borderSide: BorderSide(color: AppColors.outlineVariant),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              borderSide: BorderSide(color: AppColors.outlineVariant),
            ),
          ),
        ),

        const SizedBox(height: 28),

        // Submit
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _isSubmitting ? null : _submitBooking,
            icon: _isSubmitting
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.event_available_rounded),
            label: Text(_isSubmitting ? 'Đang xử lý...' : 'Xác nhận đặt bàn',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
          ),
        ),

        const SizedBox(height: 8),
        const Text(
          '* Nhà hàng sẽ xác nhận đặt bàn trong vòng 30 phút.',
          style: TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant, fontStyle: FontStyle.italic),
          textAlign: TextAlign.center,
        ),
      ]),
    );
  }

  Widget _buildDateSelector() {
    final dates = _getAvailableDates();
    return SizedBox(
      height: 70,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: dates.length,
        separatorBuilder: (context, index) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final date = dates[i];
          final isSelected = date.year == _selectedDate.year && date.month == _selectedDate.month && date.day == _selectedDate.day;
          
          String dayName = DateFormat('EEE', 'vi').format(date);
          if (i == 0) {
            dayName = 'Hôm nay';
          } else if (i == 1) {
            dayName = 'Ngày mai';
          }

          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedDate = date;
                final slots = _getAvailableTimeSlots(date);
                if (slots.isNotEmpty && !slots.contains(_selectedTime)) {
                  _selectedTime = slots.first;
                }
              });
            },
            child: Container(
              width: 75,
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : AppColors.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                border: Border.all(color: isSelected ? AppColors.primary : AppColors.outlineVariant),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(dayName, style: TextStyle(
                    fontSize: 12, 
                    color: isSelected ? Colors.white : AppColors.onSurfaceVariant,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal
                  )),
                  const SizedBox(height: 4),
                  Text(DateFormat('dd/MM').format(date), style: TextStyle(
                    fontSize: 15, 
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.white : AppColors.onSurface
                  )),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTimeSelector() {
    final slots = _getAvailableTimeSlots(_selectedDate);
    if (slots.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(child: Text('Đã hết giờ nhận khách trong ngày hôm nay.', style: TextStyle(color: AppColors.error))),
      );
    }

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: slots.map((time) {
        final isSelected = time.hour == _selectedTime.hour && time.minute == _selectedTime.minute;
        return InkWell(
          onTap: () => setState(() => _selectedTime = time),
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primaryContainer : AppColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              border: Border.all(color: isSelected ? AppColors.primary : AppColors.outlineVariant),
            ),
            child: Text(
              '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? AppColors.primary : AppColors.onSurface,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ─── HISTORY ────────────────────────────────────────────────────────────────
  Widget _buildHistory() {
    if (_isLoadingHistory) return const Center(child: CircularProgressIndicator());
    if (_myReservations.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(color: AppColors.surfaceContainerHigh, shape: BoxShape.circle),
            child: const Icon(Icons.event_busy_rounded, size: 36, color: AppColors.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          const Text('Chưa có lịch sử đặt bàn', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          TextButton(onPressed: () => _tabController.animateTo(0), child: const Text('Đặt bàn ngay')),
        ]),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadHistory,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: AppTheme.marginMobile, vertical: 12),
        itemCount: _myReservations.length,
        separatorBuilder: (_, i2) => const SizedBox(height: 12),
        itemBuilder: (ctx, i) => _HistoryCard(
          reservation: _myReservations[i],
          onCancel: () => _cancelReservation(_myReservations[i].reservationId),
        ),
      ),
    );
  }
}

// ─── WIDGETS ──────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) => Text(label,
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.onSurfaceVariant));
}

class _HistoryCard extends StatelessWidget {
  final Reservation reservation;
  final VoidCallback onCancel;
  const _HistoryCard({required this.reservation, required this.onCancel});

  Widget _buildReservationNote(String? note, BuildContext context) {
    if (note == null || note.isEmpty) return const SizedBox.shrink();

    final bool hasPreOrder = note.contains('[Pre-order:');
    final bool hasStatus = note.contains('[Trạng thái:');

    if (!hasPreOrder && !hasStatus) {
      return Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.sticky_note_2_outlined, size: 14, color: AppColors.onSurfaceVariant),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                note,
                style: const TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant, fontStyle: FontStyle.italic),
              ),
            ),
          ],
        ),
      );
    }

    String userNote = '';
    String preOrderDetails = '';
    String depositStatus = '';

    String workingNote = note;
    final int b2cStartIndex = workingNote.indexOf('[');
    if (b2cStartIndex > 0) {
      userNote = workingNote.substring(0, b2cStartIndex).trim();
      workingNote = workingNote.substring(b2cStartIndex);
    }

    final cleaned = workingNote.replaceAll('[', '').replaceAll(']', '');
    if (cleaned.contains('Pre-order:')) {
      final parts = cleaned.split('. Trạng thái:');
      preOrderDetails = parts[0].replaceAll('Pre-order:', '').trim();
      if (parts.length > 1) {
        depositStatus = parts[1].trim();
      }
    } else if (cleaned.contains('Trạng thái:')) {
      depositStatus = cleaned.replaceAll('Trạng thái:', '').trim();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (userNote.isNotEmpty) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.sticky_note_2_outlined, size: 14, color: AppColors.onSurfaceVariant),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    userNote,
                    style: const TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant, fontStyle: FontStyle.italic),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
          ],
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary.withAlpha(12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primary.withAlpha(40)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.shopping_bag_outlined, size: 16, color: AppColors.primary),
                    const SizedBox(width: 6),
                    const Text(
                      'Đặt trước món ăn',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primary),
                    ),
                    const Spacer(),
                    if (depositStatus.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: depositStatus.contains('Đã cọc') ? AppColors.chipPaid.withAlpha(30) : AppColors.outlineVariant.withAlpha(120),
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Text(
                          depositStatus,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: depositStatus.contains('Đã cọc') ? AppColors.chipPaid : AppColors.onSurfaceVariant,
                          ),
                        ),
                      ),
                  ],
                ),
                if (preOrderDetails.isNotEmpty) ...[
                  const Divider(height: 16),
                  const Text(
                    'Món ăn:',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.onSurfaceVariant),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    preOrderDetails,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, height: 1.4),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = reservation;
    final (icon, label, color) = switch (r.status) {
      1 => ('✅', 'Đã xác nhận', AppColors.chipPaid),
      2 => ('❌', 'Từ chối', AppColors.error),
      3 => ('🚫', 'Đã hủy', AppColors.onSurfaceVariant),
      _ => ('⏳', 'Chờ xác nhận', AppColors.warning),
    };

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: color.withAlpha(50)),
        boxShadow: AppTheme.shadowLevel1,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Header
          Row(children: [
            Text(icon, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(r.branchName ?? 'Chi nhánh', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                Text(DateFormat('HH:mm — dd/MM/yyyy').format(r.reservedAt),
                    style: const TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant)),
              ]),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: (color).withAlpha(25),
                borderRadius: BorderRadius.circular(100),
                border: Border.all(color: (color).withAlpha(80)),
              ),
              child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
            ),
          ]),

          const SizedBox(height: 10),

          // Info row
          Row(children: [
            Icon(Icons.people_rounded, size: 14, color: AppColors.onSurfaceVariant),
            const SizedBox(width: 4),
            Text('${r.guestCount} người', style: const TextStyle(fontSize: 13, color: AppColors.onSurfaceVariant)),
          ]),

          _buildReservationNote(r.note, context),

          // Manager note
          if (r.managerNote != null && r.managerNote!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withAlpha(15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: color.withAlpha(50)),
              ),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(Icons.comment_rounded, size: 14, color: color),
                const SizedBox(width: 8),
                Expanded(child: Text(r.managerNote!, style: TextStyle(fontSize: 12, color: color))),
              ]),
            ),
          ],

          // Cancel button for pending bookings
          if (r.status == 0) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onCancel,
                icon: const Icon(Icons.cancel_outlined, size: 16),
                label: const Text('Hủy đặt bàn'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: BorderSide(color: AppColors.error.withAlpha(100)),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ],
        ]),
      ),
    );
  }
}
