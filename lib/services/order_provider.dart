import 'package:flutter/foundation.dart';
import 'package:doanquanlyquananai_mobileapp/models/order/order.dart';
import 'package:doanquanlyquananai_mobileapp/core/utils/ai_tracker.dart';
import 'package:doanquanlyquananai_mobileapp/services/order_service.dart';
import 'package:doanquanlyquananai_mobileapp/services/invoice_service.dart';

class OrderProvider with ChangeNotifier {

  OrderModel? _currentOrder;
  bool _isLoading = false;
  String _error = '';

  // Biến theo dõi hành vi AI
  int _addCount = 0;
  int _removeCount = 0;
  int _voidCount = 0;
  int _itemsRemovedAfterConfirm = 0;
  bool _confirmClicked = false;
  DateTime? _tableOpenedAt;

  OrderProvider();

  OrderModel? get currentOrder => _currentOrder;
  bool get isLoading => _isLoading;
  String get error => _error;

  void _resetCounters() {
    _addCount = 0;
    _removeCount = 0;
    _voidCount = 0;
    _itemsRemovedAfterConfirm = 0;
    _confirmClicked = false;
    _tableOpenedAt = null;
  }

  // Lấy order hiện tại của bàn (Status = 0)
  Future<void> fetchOpenOrderForTable(int tableId) async {
    _isLoading = true;
    _error = '';
    notifyListeners();

    try {
      final orderService = OrderService();
      final result = await orderService.getOpenOrderByTable(tableId);
      
      if (result.isSuccess) {
        _currentOrder = result.data;
        if (_currentOrder != null) {
          _tableOpenedAt ??= _currentOrder!.openedAt; // Lưu lại thời gian mở bàn cho AI
        } else {
          _resetCounters();
        }
      } else {
        _error = result.error ?? 'Lỗi tải order';
      }
    } catch (e) {
      _error = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  // Mở bàn / Tạo Order mới
  Future<bool> createOrder(int tableId, int accountId) async {
    try {
      final orderService = OrderService();
      final result = await orderService.createOrder(tableId: tableId, accountId: accountId);
      
      if (result.isSuccess && result.data != null) {
        _resetCounters();
        _tableOpenedAt = DateTime.now();
        _currentOrder = result.data;
        notifyListeners();
        return true;
      } else {
        _error = result.error ?? 'Không thể tạo order';
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  // Thêm món
  Future<bool> addItem(int itemId, int quantity) async {
    if (_currentOrder == null) return false;
    try {
      final orderService = OrderService();
      final result = await orderService.addItem(_currentOrder!.orderId, itemId, quantity);
      
      if (result.isSuccess && result.data != null) {
        _addCount++;
        _currentOrder = result.data;
        notifyListeners();
        return true;
      } else {
        _error = result.error ?? 'Lỗi thêm món';
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  // Cập nhật số lượng
  Future<bool> updateItemQty(int orderItemId, int quantity) async {
    if (_currentOrder == null) return false;

    try {
      final oldQty = _currentOrder!.items.firstWhere((i) => i.orderItemId == orderItemId).quantity;
      final orderService = OrderService();
      final result = await orderService.updateItemQty(_currentOrder!.orderId, orderItemId, quantity);

      if (result.isSuccess && result.data != null) {
        if (quantity < oldQty) {
          _removeCount++;
          if (_confirmClicked) _itemsRemovedAfterConfirm++;
        } else {
          _addCount++;
        }
        _currentOrder = result.data;

        // Tự động hủy order & giải phóng bàn nếu không còn món nào trong giỏ
        if (_currentOrder != null && _currentOrder!.items.isEmpty) {
          await cancelOrder();
        }

        notifyListeners();
        return true;
      } else {
        _error = result.error ?? 'Lỗi cập nhật';
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  // Xóa món
  Future<bool> removeItem(int orderItemId) async {
    if (_currentOrder == null) return false;

    try {
      final item = _currentOrder!.items.firstWhere((i) => i.orderItemId == orderItemId);
      final orderService = OrderService();
      final result = await orderService.removeItem(_currentOrder!.orderId, orderItemId);

      if (result.isSuccess && result.data != null) {
        _removeCount++;
        if (_confirmClicked) _itemsRemovedAfterConfirm += item.quantity;
        _currentOrder = result.data;

        // Tự động hủy order & giải phóng bàn nếu không còn món nào trong giỏ
        if (_currentOrder != null && _currentOrder!.items.isEmpty) {
          await cancelOrder();
        }

        notifyListeners();
        return true;
      } else {
        _error = result.error ?? 'Lỗi xóa món';
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  // Hủy Order
  Future<bool> cancelOrder() async {
    if (_currentOrder == null) return false;

    try {
      final orderService = OrderService();
      final result = await orderService.cancelOrder(_currentOrder!.orderId);
      
      if (result.isSuccess) {
        _voidCount++;
        _currentOrder = null;
        _resetCounters();
        notifyListeners();
        return true;
      } else {
        _error = result.error ?? 'Không thể hủy order';
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  // Đánh dấu người dùng đã bấm Checkout
  void markConfirmClicked() {
    _confirmClicked = true;
    notifyListeners();
  }

  AiTracker getAiTracker() {
    return AiTracker.fromRaw(
      startTime: _tableOpenedAt,
      voidCount: _voidCount,
      totalAdded: _addCount,
      totalRemoved: _removeCount,
      removedAfterConfirm: _itemsRemovedAfterConfirm,
      hasConfirmed: _confirmClicked,
    );
  }

  // Thanh toán
  Future<Map<String, dynamic>?> checkout({
    required int accountId,
    int? customerId,
    required int paymentMethod,
    String? voucherCode,
    String? discountCampaignCode,
    double vatPercent = 8.0,
  }) async {
    if (_currentOrder == null) return null;

    try {
      final invoiceService = InvoiceService();
      final result = await invoiceService.checkout(
        orderId:              _currentOrder!.orderId,
        accountId:            accountId,
        tableId:              _currentOrder!.tableId,
        paymentMethod:        paymentMethod,
        tracker:              getAiTracker(),
        customerId:           customerId,
        voucherCode:          voucherCode,
        discountCampaignCode: discountCampaignCode,
        vatPercent:           vatPercent,
      );

      if (result.isSuccess && result.data != null) {
        final resJson = result.data!.toJson();
        _currentOrder = null;
        _resetCounters();
        notifyListeners();
        return resJson;
      } else {
        _error = result.error ?? 'Thanh toán thất bại';
        notifyListeners();
        return null;
      }
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }
}
