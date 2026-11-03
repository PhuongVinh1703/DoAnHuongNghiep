import 'package:flutter/material.dart';
import 'package:doanquanlyquananai_mobileapp/models/table/dining_table.dart';
import 'package:doanquanlyquananai_mobileapp/models/reservation/reservation.dart';
import 'package:doanquanlyquananai_mobileapp/services/table_service.dart';
import 'package:doanquanlyquananai_mobileapp/services/order_service.dart';
import 'package:doanquanlyquananai_mobileapp/services/reservation_service.dart';
import 'package:doanquanlyquananai_mobileapp/core/utils/error_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TableProvider extends ChangeNotifier {
  List<DiningTable> _tables = [];
  Map<int, Reservation> _reservationsByTable = {};
  bool _isLoading = false;
  String? _errorMessage;

  TableProvider();

  List<DiningTable> get tables => _tables;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// Lấy thông tin phiếu đặt bàn gần nhất của một bàn (nếu có)
  Reservation? getReservationForTable(int tableId) => _reservationsByTable[tableId];

  int? _currentBranchId;
  RealtimeChannel? _realtimeChannel;

  void _subscribeRealtime() {
    if (_realtimeChannel != null) return;
    _realtimeChannel = Supabase.instance.client
        .channel('diningtables-reservations-realtime')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'DiningTables',
          callback: (payload) {
            loadTables(branchId: _currentBranchId, showLoading: false);
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'Reservations',
          callback: (payload) {
            loadTables(branchId: _currentBranchId, showLoading: false);
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

  Future<void> loadTables({int? branchId, bool showLoading = true}) async {
    _currentBranchId = branchId;
    _subscribeRealtime();

    if (_isLoading) return;

    if (showLoading) {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();
    }

    try {
      final tableService = TableService();
      final tableResult = await tableService.getTables(branchId: branchId);

      if (tableResult.isSuccess && tableResult.data != null) {
        List<DiningTable> fetchedTables = tableResult.data!;
        final Map<int, Reservation> nextResMap = {};
        final Set<int> activeWindowReservedTableIds = {};
        final Set<int> farFutureReservedTableIds = {};

        // 1. Đối chiếu danh sách Đặt bàn đã xác nhận (Status = 1) theo khung giờ thông minh
        try {
          final resResult = await ReservationService().getReservations(
            status: 1,
            branchId: branchId,
          );
          if (resResult.isSuccess && resResult.data != null) {
            final now = DateTime.now();
            for (final r in resResult.data!) {
              if (r.isSeated) continue;
              final tId = r.assignedTableId;
              if (tId == null) continue;

              final diffMins = r.reservedAt.difference(now).inMinutes;
              // Lưu thông tin đặt bàn nếu nằm trong khoảng [-90 phút (quá giờ), +180 phút (sắp đến)]
              if (diffMins >= -90 && diffMins <= 180) {
                final existing = nextResMap[tId];
                if (existing == null ||
                    r.reservedAt.difference(now).inMinutes.abs() <
                        existing.reservedAt.difference(now).inMinutes.abs()) {
                  nextResMap[tId] = r;
                }
              }

              // Chỉ khóa bàn sang màu Vàng (Status = 2) khi còn cách giờ hẹn <= 60 phút (và chưa quá hẹn 45 phút)
              if (diffMins <= 60 && diffMins >= -45) {
                activeWindowReservedTableIds.add(tId);
              } else if (diffMins > 60) {
                farFutureReservedTableIds.add(tId);
              }
            }
          }
        } catch (_) {}

        // 2. Tự động đối chiếu trạng thái bàn với Order đang mở & Lịch đặt bàn trong khung giờ
        try {
          final orderService = OrderService();
          final ordersResult = await orderService.getOrders(status: 0);

          if (ordersResult.isSuccess && ordersResult.data != null) {
            final List<int> occupiedTableIds = ordersResult.data!
                .map((o) => o.tableId)
                .toList();

            for (int i = 0; i < fetchedTables.length; i++) {
              final table = fetchedTables[i];
              if (occupiedTableIds.contains(table.tableId)) {
                if (table.status != 1) {
                  fetchedTables[i] = DiningTable(
                    tableId: table.tableId,
                    tableName: table.tableName,
                    capacity: table.capacity,
                    status: 1,
                    isActive: table.isActive,
                    branchId: table.branchId,
                  );
                  () async {
                    try {
                      await tableService.updateStatus(table.tableId, 1);
                    } catch (_) {}
                  }();
                }
              } else if (activeWindowReservedTableIds.contains(table.tableId)) {
                // Tự động chuyển bàn sang Đã đặt (Status = 2) khi vào khung giờ 60 phút trước giờ hẹn
                if (table.status != 2) {
                  fetchedTables[i] = DiningTable(
                    tableId: table.tableId,
                    tableName: table.tableName,
                    capacity: table.capacity,
                    status: 2,
                    isActive: table.isActive,
                    branchId: table.branchId,
                  );
                  () async {
                    try {
                      await tableService.updateStatus(table.tableId, 2);
                    } catch (_) {}
                  }();
                }
              } else {
                // Nếu bàn đang bị treo Occupied (1) không có order, hoặc bị khóa sớm cho lịch đặt còn xa (> 60p)
                final shouldReleaseEarlyLock =
                    table.status == 2 && farFutureReservedTableIds.contains(table.tableId);
                if (table.status == 1 || shouldReleaseEarlyLock) {
                  fetchedTables[i] = DiningTable(
                    tableId: table.tableId,
                    tableName: table.tableName,
                    capacity: table.capacity,
                    status: 0,
                    isActive: table.isActive,
                    branchId: table.branchId,
                  );
                  () async {
                    try {
                      await tableService.updateStatus(table.tableId, 0);
                    } catch (_) {}
                  }();
                }
              }
            }
          }
        } catch (_) {}

        _reservationsByTable = nextResMap;
        _tables = fetchedTables;
      } else {
        _errorMessage = tableResult.error ?? 'Lỗi khi tải danh sách bàn';
      }
    } catch (e) {
      _errorMessage = ErrorHandler.formatError(e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Cập nhật trạng thái bàn cục bộ trước khi đồng bộ lại từ API
  void updateTableStatus(int tableId, int newStatus) {
    final index = _tables.indexWhere((t) => t.tableId == tableId);
    if (index != -1) {
      final oldTable = _tables[index];
      _tables[index] = DiningTable(
        tableId: oldTable.tableId,
        tableName: oldTable.tableName,
        capacity: oldTable.capacity,
        status: newStatus,
        isActive: oldTable.isActive,
        branchId: oldTable.branchId,
      );
      notifyListeners();
    }
  }
}
