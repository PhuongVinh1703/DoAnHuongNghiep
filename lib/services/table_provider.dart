import 'package:flutter/material.dart';
import 'package:doanquanlyquananai_mobileapp/models/table/dining_table.dart';
import 'package:doanquanlyquananai_mobileapp/services/table_service.dart';
import 'package:doanquanlyquananai_mobileapp/services/order_service.dart';

class TableProvider extends ChangeNotifier {
  
  List<DiningTable> _tables = [];
  bool _isLoading = false;
  String? _errorMessage;

  TableProvider();

  List<DiningTable> get tables => _tables;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> loadTables({int? branchId}) async {
    if (_isLoading) return;
    
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final tableService = TableService();
      final tableResult = await tableService.getTables(branchId: branchId);
      
      if (tableResult.isSuccess && tableResult.data != null) {
        List<DiningTable> fetchedTables = tableResult.data!;

        // Tự động đối chiếu trạng thái bàn với danh sách Order đang mở (Self-Healing) qua Supabase
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
                  // Ép trạng thái cục bộ thành Occupied (1)
                  fetchedTables[i] = DiningTable(
                    tableId: table.tableId,
                    tableName: table.tableName,
                    capacity: table.capacity,
                    status: 1,
                    isActive: table.isActive,
                    branchId: table.branchId,
                  );
                  // Vá trạng thái không nhất quán lên Supabase
                  () async {
                    try {
                      await tableService.updateStatus(table.tableId, 1);
                    } catch (_) {}
                  }();
                }
              } else {
                if (table.status == 1) {
                  // Ép trạng thái cục bộ thành Available (0) nếu không có order mở
                  fetchedTables[i] = DiningTable(
                    tableId: table.tableId,
                    tableName: table.tableName,
                    capacity: table.capacity,
                    status: 0,
                    isActive: table.isActive,
                    branchId: table.branchId,
                  );
                  // Vá trạng thái không nhất quán lên Supabase
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

        _tables = fetchedTables;
      } else {
        _errorMessage = tableResult.error ?? 'Lỗi khi tải danh sách bàn';
      }
    } catch (e) {
      _errorMessage = 'Đã có lỗi xảy ra: $e';
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
