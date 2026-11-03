import 'package:doanquanlyquananai_mobileapp/core/network/api_response.dart';
import 'package:doanquanlyquananai_mobileapp/models/order/order.dart';
import 'package:doanquanlyquananai_mobileapp/core/utils/ai_tracker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class OrderService {
  final _db = Supabase.instance.client;

  /// Lấy order mở của bàn (Dùng order + limit(1) để tránh lỗi PGRST116 nếu bàn bị kẹt >1 đơn mở)
  Future<ApiResult<OrderModel?>> getOpenOrderByTable(int tableId) async {
    try {
      final res = await _db
          .from('Orders')
          .select('*, OrderItems(*, MenuItems(*)), DiningTables(TableName, BranchId), Accounts(FullName)')
          .eq('TableId', tableId)
          .eq('Status', 0)
          .order('OpenedAt', ascending: false)
          .limit(1)
          .maybeSingle();

      if (res == null) return ApiResult.success(null);

      // Lọc các items chưa bị xóa
      final items = (res['OrderItems'] as List? ?? [])
          .where((i) => i['IsDeleted'] == false)
          .toList();
      res['OrderItems'] = items;

      return ApiResult.success(OrderModel.fromJson(res));
    } catch (e) {
      return ApiResult.failure('Lỗi lấy đơn hàng mở của bàn: $e');
    }
  }

  Future<ApiResult<OrderModel>> getOrderById(int orderId) async {
    try {
      final res = await _db
          .from('Orders')
          .select('*, OrderItems(*, MenuItems(*)), DiningTables(TableName, BranchId), Accounts(FullName)')
          .eq('OrderId', orderId)
          .single();

      // Lọc items chưa xóa
      final items = (res['OrderItems'] as List? ?? [])
          .where((i) => i['IsDeleted'] == false)
          .toList();
      res['OrderItems'] = items;

      return ApiResult.success(OrderModel.fromJson(res));
    } catch (e) {
      return ApiResult.failure('Không tìm thấy đơn hàng: $e');
    }
  }

  Future<ApiResult<List<OrderModel>>> getOrders({
    int? status,
    int? branchId,
    int page = 1,
    int pageSize = 50,
  }) async {
    try {
      var query = _db
          .from('Orders')
          .select('*, OrderItems(*, MenuItems(*)), DiningTables(TableName, BranchId), Accounts(FullName)');

      if (status != null) {
        query = query.eq('Status', status);
      }

      final from = (page - 1) * pageSize;
      final to = from + pageSize - 1;
      final res = await query.order('OpenedAt', ascending: false).range(from, to);

      final list = (res as List).map((e) {
        // Lọc các items hoạt động
        final items = (e['OrderItems'] as List? ?? [])
            .where((i) => i['IsDeleted'] == false)
            .toList();
        e['OrderItems'] = items;
        return OrderModel.fromJson(e);
      }).toList();

      final filtered = branchId != null
          ? list.where((o) => o.branchId == branchId).toList()
          : list;

      return ApiResult.success(filtered);
    } catch (e) {
      return ApiResult.failure('Lỗi tải danh sách đơn hàng: $e');
    }
  }

  Future<ApiResult<OrderModel>> createOrder({
    required int tableId,
    required int accountId,
    String? note,
  }) async {
    try {
      // 1. Tạo order mới
      final res = await _db.from('Orders').insert({
        'TableId': tableId,
        'AccountId': accountId,
        'Status': 0, // Open
        'OpenedAt': DateTime.now().toIso8601String(),
        'Note': note ?? '',
      }).select('OrderId').single();

      final newOrderId = res['OrderId'] as int;

      // 2. Đồng bộ cập nhật trạng thái bàn thành Occupied (1)
      await _db.from('DiningTables').update({'Status': 1}).eq('TableId', tableId);

      // 3. Trả về order đầy đủ thông tin
      final fullOrder = await getOrderById(newOrderId);
      return fullOrder;
    } catch (e) {
      return ApiResult.failure('Lỗi tạo đơn hàng: $e');
    }
  }

  /// Thêm món — chỉ cộng dồn nếu món đó chưa được Bếp nấu xong ([DONE]) và có cùng ghi chú
  Future<ApiResult<OrderModel>> addItem(
    int orderId,
    int itemId,
    int qty, {
    String? note,
  }) async {
    try {
      // 1. Lấy danh sách các dòng của món này trong OrderItems (dùng select list thay vì maybeSingle để không crash)
      final existingRows = await _db
          .from('OrderItems')
          .select()
          .eq('OrderId', orderId)
          .eq('ItemId', itemId)
          .eq('IsDeleted', false);

      final rows = existingRows as List? ?? [];
      final cleanNewNote = AiTracker.cleanDisplayNote(note);

      // Tìm dòng chưa lên món ([DONE]) và có cùng ghi chú để cộng dồn
      Map<String, dynamic>? matchingRow;
      for (final r in rows) {
        final rNote = r['Note']?.toString();
        if (!AiTracker.isItemDone(rNote) &&
            AiTracker.cleanDisplayNote(rNote) == cleanNewNote) {
          matchingRow = r as Map<String, dynamic>;
          break;
        }
      }

      if (matchingRow != null) {
        final newQty = (matchingRow['Quantity'] as int) + qty;
        await _db
            .from('OrderItems')
            .update({'Quantity': newQty})
            .eq('OrderItemId', matchingRow['OrderItemId']);
      } else {
        // Món chưa có hoặc đợt trước Bếp đã nấu xong -> Tạo dòng mới để Bếp nhận thông báo nấu tiếp
        final menuItem = await _db
            .from('MenuItems')
            .select('Price')
            .eq('ItemId', itemId)
            .single();
        final double price = (menuItem['Price'] as num).toDouble();

        await _db.from('OrderItems').insert({
          'OrderId': orderId,
          'ItemId': itemId,
          'Quantity': qty,
          'UnitPrice': price,
          'AddedAt': DateTime.now().toIso8601String(),
          'IsDeleted': false,
          'Note': cleanNewNote.isNotEmpty ? cleanNewNote : null,
        });
      }

      // Nếu đơn trước đó đã đánh dấu [KDS_READY], khi gọi thêm món mới thì gỡ [KDS_READY] để Bếp nấu món mới
      final currentOrderRes = await _db
          .from('Orders')
          .select('Note')
          .eq('OrderId', orderId)
          .maybeSingle();
      final currentOrderNote = currentOrderRes?['Note']?.toString();
      if (AiTracker.isKitchenReady(currentOrderNote)) {
        final updatedOrderNote = AiTracker.buildUpdatedNote(
          currentNote: currentOrderNote,
          kitchenReady: false,
        );
        await _db
            .from('Orders')
            .update({'Note': updatedOrderNote})
            .eq('OrderId', orderId);
      }

      return await getOrderById(orderId);
    } catch (e) {
      return ApiResult.failure('Lỗi thêm món: $e');
    }
  }

  /// Cập nhật số lượng — số lượng <= 0 sẽ xóa mềm (IsDeleted = true)
  Future<ApiResult<OrderModel>> updateItemQty(
    int orderId,
    int orderItemId,
    int qty,
  ) async {
    try {
      if (qty <= 0) {
        await _db
            .from('OrderItems')
            .update({'IsDeleted': true})
            .eq('OrderItemId', orderItemId);
      } else {
        await _db
            .from('OrderItems')
            .update({'Quantity': qty})
            .eq('OrderItemId', orderItemId);
      }
      return await getOrderById(orderId);
    } catch (e) {
      return ApiResult.failure('Lỗi cập nhật số lượng món: $e');
    }
  }

  Future<ApiResult<OrderModel>> removeItem(int orderId, int orderItemId) async {
    try {
      await _db
          .from('OrderItems')
          .update({'IsDeleted': true})
          .eq('OrderItemId', orderItemId);
      return await getOrderById(orderId);
    } catch (e) {
      return ApiResult.failure('Lỗi xóa món: $e');
    }
  }

  /// Cập nhật ghi chú từng món ăn (chứa tag [DONE] khi bếp làm xong món)
  Future<ApiResult<void>> updateOrderItemNote(int orderItemId, String? note) async {
    try {
      await _db
          .from('OrderItems')
          .update({'Note': note})
          .eq('OrderItemId', orderItemId);
      return ApiResult.success(null);
    } catch (e) {
      return ApiResult.failure('Lỗi cập nhật trạng thái món: $e');
    }
  }

  /// Cập nhật ghi chú đơn hàng (chứa các tag AI, BILL_REQ, KDS_READY)
  Future<ApiResult<OrderModel>> updateOrderNote(int orderId, String note) async {
    try {
      await _db.from('Orders').update({
        'Note': note,
      }).eq('OrderId', orderId);

      return await getOrderById(orderId);
    } catch (e) {
      return ApiResult.failure('Lỗi cập nhật ghi chú đơn hàng: $e');
    }
  }

  Future<ApiResult<void>> cancelOrder(int orderId) async {
    try {
      // 1. Lấy TableId trước khi hủy để giải phóng bàn
      final order = await _db
          .from('Orders')
          .select('TableId')
          .eq('OrderId', orderId)
          .single();
      final tableId = order['TableId'] as int;

      // 2. Cập nhật trạng thái đơn hàng thành Cancelled (2)
      await _db.from('Orders').update({
        'Status': 2,
        'ClosedAt': DateTime.now().toIso8601String(),
      }).eq('OrderId', orderId);

      // 3. Giải phóng trạng thái bàn ăn (Status = 0)
      await _db.from('DiningTables').update({'Status': 0}).eq('TableId', tableId);

      return ApiResult.success(null);
    } catch (e) {
      return ApiResult.failure('Lỗi hủy đơn hàng: $e');
    }
  }
}
