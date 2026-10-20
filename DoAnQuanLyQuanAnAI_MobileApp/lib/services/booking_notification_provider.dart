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
            // Tự động cập nhật thông báo và nhiệm vụ khi có đặt bàn mới/thay đổi
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
      onFailure: (e) {
        // Bỏ qua lỗi kết nối tạm thời
      },
    );
    
    _isLoading = false;
    notifyListeners();
  }

  /// Khi khách hàng đặt bàn trong cùng phiên app, tăng nhanh chỉ số thông báo
  void addNewBookingNotification(Reservation reservation) {
    // Tránh trùng lặp
    if (!_pendingReservations.any((r) => r.reservationId == reservation.reservationId)) {
      _pendingReservations.insert(0, reservation);
      _unreadCount++;
      notifyListeners();
    }
  }

  /// Xoá số lượng chưa đọc (ví dụ khi manager mở hộp thư/danh sách đặt bàn)
  void clearUnread() {
    _unreadCount = 0;
    notifyListeners();
  }

  /// Lấy danh sách nhiệm vụ được giao cho Nhân viên
  Future<void> fetchStaffTasks(String staffName, int branchId) async {
    _currentStaffName = staffName;
    _currentBranchId = branchId;
    _subscribeRealtime();

    _isLoading = true;
    notifyListeners();

    // Lấy đặt bàn đã xác nhận (status = 1) để tìm những bàn được phân công
    final result = await _reservationSvc.getReservations(status: 1, branchId: branchId);
    result.fold(
      onSuccess: (data) {
        // Tìm các đặt bàn có managerNote chứa tên nhân viên
        _assignedTasks = data.where((r) {
          final note = r.managerNote;
          if (note == null || note.isEmpty) return false;
          // Phù hợp cấu trúc: [Giao việc: Tên Nhân Viên]
          return note.contains('Giao việc: $staffName');
        }).toList();
      },
      onFailure: (_) {},
    );

    _isLoading = false;
    notifyListeners();
  }
}
