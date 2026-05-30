import 'package:doanquanlyquananai_mobileapp/core/network/api_response.dart';
import 'package:doanquanlyquananai_mobileapp/models/order/order.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class OrderService {
  final _db = Supabase.instance.client;

  /// Lấy order mở của bàn
  Future<ApiResult<OrderModel?>> getOpenOrderByTable(int tableId) async {
    try {
      final res = await _db
          .from('Orders')
          .select('*, OrderItems(*, MenuItems(*)), DiningTables(TableName), Accounts(FullName)')
          .eq('TableId', tableId)
          .eq('Status', 0)
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
          .select('*, OrderItems(*, MenuItems(*)), DiningTables(TableName), Accounts(FullName)')
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
    int page = 1, 
    int pageSize = 50
  }) async {
    try {
      var query = _db
          .from('Orders')
          .select('*, OrderItems(*, MenuItems(*)), DiningTables(TableName), Accounts(FullName)');
          
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

      return ApiResult.success(list);
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

  /// Thêm món — cộng dồn số lượng nếu đã tồn tại
  Future<ApiResult<OrderModel>> addItem(
    int orderId,
    int itemId,
    int qty, {
    String? note,
  }) async {
    try {
      // 1. Kiểm tra xem món đó đã có trong OrderItems chưa
      final existing = await _db
          .from('OrderItems')
          .select()
          .eq('OrderId', orderId)
          .eq('ItemId', itemId)
          .eq('IsDeleted', false)
          .maybeSingle();

      if (existing != null) {
        // Món đã có -> Cộng dồn số lượng
        final newQty = (existing['Quantity'] as int) + qty;
        await _db
            .from('OrderItems')
            .update({'Quantity': newQty})
            .eq('OrderItemId', existing['OrderItemId']);
      } else {
        // Món chưa có -> Lấy đơn giá hiện tại từ thực đơn
        final menuItem = await _db
            .from('MenuItems')
            .select('Price')
            .eq('ItemId', itemId)
            .single();
        final double price = (menuItem['Price'] as num).toDouble();

        // Thêm mới vào OrderItems
        await _db.from('OrderItems').insert({
          'OrderId': orderId,
          'ItemId': itemId,
          'Quantity': qty,
          'UnitPrice': price,
          'AddedAt': DateTime.now().toIso8601String(),
          'IsDeleted': false,
          'Note': note,
        });
      }

      // Trả về order mới cập nhật
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
