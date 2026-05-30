import 'package:flutter/material.dart';
import 'package:doanquanlyquananai_mobileapp/theme/app_colors.dart';
import 'package:doanquanlyquananai_mobileapp/theme/app_theme.dart';
import 'package:doanquanlyquananai_mobileapp/widgets/status_chip.dart';
import 'package:doanquanlyquananai_mobileapp/services/reservation_service.dart';
import 'package:doanquanlyquananai_mobileapp/models/reservation/reservation.dart';
import 'package:intl/intl.dart';
import 'package:doanquanlyquananai_mobileapp/widgets/common/app_snackbar.dart';

class ReservationScreen extends StatefulWidget {
  const ReservationScreen({super.key});

  @override
  State<ReservationScreen> createState() => _ReservationScreenState();
}

class _ReservationScreenState extends State<ReservationScreen> {
  final ReservationService _reservationSvc = ReservationService();
  List<Reservation> _reservations = [];
  bool _isLoading = false;
  int? _selectedStatus; // null = All, 0 = Pending, 1 = Confirmed, 2 = Seated, 3 = Cancelled

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final result = await _reservationSvc.getReservations(status: _selectedStatus);
    if (mounted) {
      if (result.isSuccess) {
        setState(() => _reservations = result.data ?? []);
      } else {
        AppSnackbar.showError(context, result.error ?? 'Failed to load reservations');
      }
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateStatus(int id, int status) async {
    final result = await _reservationSvc.updateStatus(id, status);
    if (mounted) {
      if (result.isSuccess) {
        _loadData();
        AppSnackbar.showSuccess(context, 'Cập nhật trạng thái thành công');
      } else {
        AppSnackbar.showError(context, result.error ?? 'Update failed');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final confirmedToday = _reservations.where((r) => r.status == 1).length;
    final pendingToday = _reservations.where((r) => r.status == 0).length;
    final totalGuests = _reservations.fold<int>(0, (sum, r) => sum + r.guestCount);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: const Text('Quản lý Đặt bàn')),
      body: Column(
        children: [
          // Stats row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.marginMobile, vertical: 8),
            child: Row(children: [
              _StatPill(label: 'Đã xác nhận', value: '$confirmedToday', color: AppColors.chipPaid),
              const SizedBox(width: 8),
              _StatPill(label: 'Chờ xử lý', value: '$pendingToday', color: AppColors.warning),
              const SizedBox(width: 8),
              _StatPill(label: 'Tổng khách', value: '$totalGuests', color: AppColors.tertiary),
            ]),
          ),

          // Status filter
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppTheme.marginMobile),
              children: [
                _StatusFilterChip(label: 'Tất cả', selected: _selectedStatus == null, onSelected: () => setState(() { _selectedStatus = null; _loadData(); })),
                _StatusFilterChip(label: 'Chờ duyệt', selected: _selectedStatus == 0, onSelected: () => setState(() { _selectedStatus = 0; _loadData(); })),
                _StatusFilterChip(label: 'Đã xác nhận', selected: _selectedStatus == 1, onSelected: () => setState(() { _selectedStatus = 1; _loadData(); })),
                _StatusFilterChip(label: 'Đã nhận bàn', selected: _selectedStatus == 2, onSelected: () => setState(() { _selectedStatus = 2; _loadData(); })),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Reservation list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _reservations.isEmpty
                    ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.event_busy_rounded, size: 48, color: AppColors.onSurfaceVariant.withAlpha(100)),
                        const SizedBox(height: 12),
                        const Text('Không có lịch đặt bàn nào', style: TextStyle(color: AppColors.onSurfaceVariant)),
                      ]))
                    : RefreshIndicator(
                        onRefresh: _loadData,
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: AppTheme.marginMobile),
                          itemCount: _reservations.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 16),
                          itemBuilder: (ctx, i) => _ReservationCard(
                            reservation: _reservations[i],
                            onStatusUpdate: (status) => _updateStatus(_reservations[i].reservationId, status),
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

class _StatusFilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onSelected;

  const _StatusFilterChip({required this.label, required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onSelected(),
        selectedColor: AppColors.primary,
        labelStyle: TextStyle(
          color: selected ? Colors.white : AppColors.onSurfaceVariant,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          fontSize: 13,
        ),
        side: BorderSide(color: selected ? AppColors.primary : AppColors.outlineVariant),
        shape: const StadiumBorder(),
        showCheckmark: false,
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  final String label, value;
  final Color color;
  const _StatPill({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        decoration: BoxDecoration(color: color.withAlpha(18), borderRadius: BorderRadius.circular(AppTheme.radiusMd), border: Border.all(color: color.withAlpha(35))),
        child: Row(children: [
          Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: color)),
          const SizedBox(width: 6),
          Expanded(child: Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis)),
        ]),
      ),
    );
  }
}

class _ReservationCard extends StatelessWidget {
  final Reservation reservation;
  final Function(int) onStatusUpdate;

  const _ReservationCard({required this.reservation, required this.onStatusUpdate});

  String _getStatusLabel(int status) {
    switch (status) {
      case 0: return 'Chờ duyệt';
      case 1: return 'Đã xác nhận';
      case 2: return 'Đã nhận bàn';
      case 3: return 'Đã hủy';
      default: return 'Unknown';
    }
  }

  StatusType _getStatusType(int status) {
    switch (status) {
      case 1: return StatusType.paid;
      case 2: return StatusType.reserved;
      case 3: return StatusType.cancelled;
      default: return StatusType.pending;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isConfirmed = reservation.status == 1;
    final isPending = reservation.status == 0;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppColors.outlineVariant.withAlpha(60)),
        boxShadow: AppTheme.shadowLevel1,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Header
          Row(children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: isConfirmed ? AppColors.chipPaid.withAlpha(25) : AppColors.warning.withAlpha(30),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                isConfirmed ? Icons.event_available_rounded : Icons.schedule_rounded,
                color: isConfirmed ? AppColors.chipPaid : AppColors.warning,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(reservation.customerName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              Text(reservation.customerPhone, style: TextStyle(fontSize: 13, color: AppColors.onSurfaceVariant)),
            ])),
            StatusChip(label: _getStatusLabel(reservation.status), type: _getStatusType(reservation.status)),
          ]),

          const SizedBox(height: 14),

          // Details row
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppColors.surfaceContainerLow, borderRadius: BorderRadius.circular(12)),
            child: Row(children: [
              _InfoChip(icon: Icons.access_time_rounded, text: DateFormat('HH:mm').format(reservation.reservedAt)),
              const SizedBox(width: 16),
              _InfoChip(icon: Icons.people_rounded, text: '${reservation.guestCount} khách'),
              const SizedBox(width: 16),
              _InfoChip(icon: Icons.calendar_today_rounded, text: DateFormat('dd/MM').format(reservation.reservedAt)),
            ]),
          ),

          if (reservation.note != null && reservation.note!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(children: [
              Icon(Icons.sticky_note_2_outlined, size: 14, color: AppColors.onSurfaceVariant),
              const SizedBox(width: 6),
              Expanded(child: Text(reservation.note!, style: TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant, fontStyle: FontStyle.italic))),
            ]),
          ],

          const SizedBox(height: 12),

          // Actions
          if (reservation.status < 2)
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => onStatusUpdate(3), // Cancel
                  icon: const Icon(Icons.close_rounded, size: 16),
                  label: const Text('Hủy'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    side: BorderSide(color: AppColors.error.withAlpha(100)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => onStatusUpdate(isPending ? 1 : 2), // Confirm or Seat
                  icon: Icon(isPending ? Icons.check_rounded : Icons.event_seat_rounded, size: 16),
                  label: Text(isPending ? 'Xác nhận' : 'Nhận bàn'),
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 10)),
                ),
              ),
            ]),
        ]),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoChip({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 15, color: AppColors.onSurfaceVariant),
      const SizedBox(width: 4),
      Text(text, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.onSurface)),
    ]);
  }
}
