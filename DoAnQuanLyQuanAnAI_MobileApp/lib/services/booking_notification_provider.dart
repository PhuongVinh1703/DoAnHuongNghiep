import 'package:flutter/material.dart';
import 'package:doanquanlyquananai_mobileapp/models/reservation/reservation.dart';
import 'package:doanquanlyquananai_mobileapp/services/reservation_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BookingNotificationProvider extends ChangeNotifier {
  final ReservationService _reservationSvc = ReservationService();

  int _unreadCount = 0;
  List<Reservation> _pendingReservations = [];
  List<Reservation> _assignedTasks = [];
  bool _isLoading = false;

  int? _currentBranchId;
  String? _currentStaffName;
  RealtimeChannel? _realtimeChannel;

  int get unreadCount => _unreadCount;
  List<Reservation> get pendingReservations => _pendingReservations;
  List<Reservation> get assignedTasks => _assignedTasks;
  bool get isLoading => _isLoading;

  void _subscribeRealtime() {
    if (_realtimeChannel != null) return;
    _realtimeChannel = Supabase.instance.client
        .channel('reservations-realtime-channel')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'Reservations',
          callback: (payload) {
            if (_currentBranchId != null) {
              fetchPendingReservations(_currentBranchId!);
            }
            if (_currentStaffName != null && _currentBranchId != null) {
              fetchStaffTasks(_currentStaffName!, _currentBranchId!);
            }
          },
        );
    _realtimeChannel!.subscribe();
  }

  @override
  void dispose() {
    if (_realtimeChannel != null) {
      Supabase.instance.client.removeChannel(_realtimeChannel!);
    }
    super.dispose();
  }

  /// Tải số lượng đặt bàn chờ duyệt từ API
  Future<void> fetchPendingReservations(int branchId) async {
    _currentBranchId = branchId;
    _subscribeRealtime();

    _isLoading = true;
    notifyListeners();

    final result = await _reservationSvc.getReservations(status: 0, branchId: branchId);
    result.fold(
      onSuccess: (data) {
        _pendingReservations = data;
        _unreadCount = data.length;
      },
      onFailure: (_) {},
    );

    _isLoading = false;
    notifyListeners();
  }

  /// Khi khách hàng đặt bàn trong cùng phiên app, tăng nhanh chỉ số thông báo
  void addNewBookingNotification(Reservation reservation) {
    if (!_pendingReservations.any((r) => r.reservationId == reservation.reservationId)) {
      _pendingReservations.insert(0, reservation);
      _unreadCount++;
      notifyListeners();
    }
  }

  /// Xoá số lượng chưa đọc
  void clearUnread() {
    _unreadCount = 0;
    notifyListeners();
  }

  /// Lấy danh sách nhiệm vụ được giao cho Nhân viên Phục vụ trong ca
  Future<void> fetchStaffTasks(String staffName, int branchId) async {
    _currentStaffName = staffName;
    _currentBranchId = branchId;
    _subscribeRealtime();

    _isLoading = true;
    notifyListeners();

    final result = await _reservationSvc.getReservations(status: 1, branchId: branchId);
    result.fold(
      onSuccess: (data) {
        final target = staffName.trim().toLowerCase();
        _assignedTasks = data.where((r) {
          if (r.isSeated) return false;
          final note = (r.managerNote ?? '').toLowerCase();
          if (note.isEmpty) return false;
          // Hỗ trợ cả định dạng mới "[INTERNAL:Phụ trách: Tên NV...]" lẫn định dạng cũ "Giao việc: Tên NV"
          return note.contains('phụ trách: $target') ||
              note.contains('giao việc: $target') ||
              note.contains('nhân viên ca trực');
        }).toList();
      },
      onFailure: (_) {},
    );

    _isLoading = false;
    notifyListeners();
  }
}
