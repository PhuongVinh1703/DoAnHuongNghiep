import 'package:flutter/foundation.dart';
import 'package:doanquanlyquananai_mobileapp/models/order/order.dart';
import 'package:doanquanlyquananai_mobileapp/core/utils/ai_tracker.dart';
import 'package:doanquanlyquananai_mobileapp/services/order_service.dart';
import 'package:doanquanlyquananai_mobileapp/services/invoice_service.dart';
import 'package:doanquanlyquananai_mobileapp/core/utils/error_handler.dart';

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
  DateTime? _confirmTime;
  DateTime? _tableOpenedAt;

  OrderProvider();

  OrderModel? get currentOrder => _currentOrder;
  bool get isLoading => _isLoading;
  String get error => _error;

  void _resetCounters({bool keepVoidCount = false}) {
    _addCount = 0;
    _removeCount = 0;
    if (!keepVoidCount) {
      _voidCount = 0;
    }
    _itemsRemovedAfterConfirm = 0;
    _confirmClicked = false;
    _confirmTime = null;
    _tableOpenedAt = null;
  }

  /// Reset toàn bộ trạng thái đơn hàng sau khi thanh toán thành công
  void clearCurrentOrderAfterCheckout() {
    _currentOrder = null;
    _resetCounters(keepVoidCount: false);
    notifyListeners();
  }

  /// Gán đơn hàng hiện tại (dùng khi Thu ngân bấm "Tính tiền" trực tiếp từ danh sách)
  void setCurrentOrder(OrderModel order) {
    _currentOrder = order;
    _tableOpenedAt = order.openedAt;
    final merged = AiTracker.mergeFromOrderNote(
      order.note,
      getAiTracker(),
      openedAt: order.openedAt,
    );
    _voidCount = merged.voidCount;
    _addCount = merged.totalAdded;
    _removeCount = merged.totalRemoved;
    _itemsRemovedAfterConfirm = merged.itemsRemovedAfterConfirm;
    _confirmClicked = merged.hasConfirmed;
    _confirmTime = merged.confirmTime;
    notifyListeners();
  }

  /// Lấy order hiện tại của bàn (Status = 0)
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
          _tableOpenedAt ??= _currentOrder!.openedAt;
          final merged = AiTracker.mergeFromOrderNote(
            _currentOrder!.note,
            getAiTracker(),
            openedAt: _currentOrder!.openedAt,
          );
          _voidCount = merged.voidCount;
          _addCount = merged.totalAdded;
          _removeCount = merged.totalRemoved;
          _itemsRemovedAfterConfirm = merged.itemsRemovedAfterConfirm;
          _confirmClicked = merged.hasConfirmed;
          _confirmTime = merged.confirmTime;
        } else {
          _resetCounters(keepVoidCount: true);
        }
      } else {
        _error = result.error ?? 'Lỗi tải order';
      }
    } catch (e) {
      _error = ErrorHandler.formatError(e);
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Mở bàn / Tạo Order mới
  Future<bool> createOrder(int tableId, int accountId, {String? note}) async {
    try {
      final orderService = OrderService();
      final result = await orderService.createOrder(
        tableId: tableId,
        accountId: accountId,
        note: note,
      );

      if (result.isSuccess && result.data != null) {
        _resetCounters(keepVoidCount: true);
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
      _error = ErrorHandler.formatError(e);
      notifyListeners();
      return false;
    }
  }

  /// Đồng bộ chỉ số AI Tracker và trạng thái vào Orders.Note
  Future<void> _syncTrackerToOrderNote({
    bool? requestPayment,
    bool? kitchenReady,
  }) async {
    if (_currentOrder == null) return;
    try {
      final newNote = AiTracker.buildUpdatedNote(
        currentNote: _currentOrder!.note,
        requestPayment: requestPayment,
        kitchenReady: kitchenReady,
        tracker: getAiTracker(),
      );
      final res = await OrderService().updateOrderNote(
        _currentOrder!.orderId,
        newNote,
      );
      if (res.isSuccess && res.data != null) {
        _currentOrder = res.data;
      }
    } catch (_) {}
  }

  /// Thêm món
  Future<bool> addItem(int itemId, int quantity, {String? note}) async {
    if (_currentOrder == null) return false;
    try {
      final orderService = OrderService();
      final result = await orderService.addItem(
        _currentOrder!.orderId,
        itemId,
        quantity,
        note: note,
      );

      if (result.isSuccess && result.data != null) {
        _addCount += quantity;
        _currentOrder = result.data;
        await _syncTrackerToOrderNote();
        notifyListeners();
        return true;
      } else {
        _error = result.error ?? 'Lỗi thêm món';
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = ErrorHandler.formatError(e);
      notifyListeners();
      return false;
    }
  }

  /// Cập nhật số lượng món
  Future<bool> updateItemQty(int orderItemId, int quantity) async {
    if (_currentOrder == null) return false;

    try {
      final oldQty = _currentOrder!.items
          .firstWhere((i) => i.orderItemId == orderItemId)
          .quantity;
      final orderService = OrderService();
      final result = await orderService.updateItemQty(
        _currentOrder!.orderId,
        orderItemId,
        quantity,
      );

      if (result.isSuccess && result.data != null) {
        if (quantity < oldQty) {
          final diff = oldQty - quantity;
          _removeCount += diff;
          _voidCount++;
          if (_confirmClicked) _itemsRemovedAfterConfirm += diff;
        } else if (quantity > oldQty) {
          _addCount += (quantity - oldQty);
        }
        _currentOrder = result.data;

        // Tự động hủy order & giải phóng bàn nếu không còn món nào trong giỏ
        if (_currentOrder != null && _currentOrder!.items.isEmpty) {
          await cancelOrder();
        } else {
          await _syncTrackerToOrderNote();
        }

        notifyListeners();
        return true;
      } else {
        _error = result.error ?? 'Lỗi cập nhật';
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = ErrorHandler.formatError(e);
      notifyListeners();
      return false;
    }
  }

  /// Xóa món
  Future<bool> removeItem(int orderItemId) async {
    if (_currentOrder == null) return false;

    try {
      final item = _currentOrder!.items
          .firstWhere((i) => i.orderItemId == orderItemId);
      final orderService = OrderService();
      final result = await orderService.removeItem(
        _currentOrder!.orderId,
        orderItemId,
      );

      if (result.isSuccess && result.data != null) {
        _removeCount += item.quantity;
        _voidCount++;
        if (_confirmClicked) _itemsRemovedAfterConfirm += item.quantity;
        _currentOrder = result.data;

        // Tự động hủy order & giải phóng bàn nếu không còn món nào trong giỏ
        if (_currentOrder != null && _currentOrder!.items.isEmpty) {
          await cancelOrder();
        } else {
          await _syncTrackerToOrderNote();
        }

        notifyListeners();
        return true;
      } else {
        _error = result.error ?? 'Lỗi xóa món';
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = ErrorHandler.formatError(e);
      notifyListeners();
      return false;
    }
  }

  /// Hủy Order
  Future<bool> cancelOrder() async {
    if (_currentOrder == null) return false;

    try {
      final orderService = OrderService();
      final result = await orderService.cancelOrder(_currentOrder!.orderId);

      if (result.isSuccess) {
        _voidCount++;
        _currentOrder = null;
        _resetCounters(keepVoidCount: true);
        notifyListeners();
        return true;
      } else {
        _error = result.error ?? 'Không thể hủy order';
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = ErrorHandler.formatError(e);
      notifyListeners();
      return false;
    }
  }

  /// Đánh dấu người dùng đã bấm xác nhận gửi bếp / checkout
  void markConfirmClicked() {
    _confirmClicked = true;
    _confirmTime ??= DateTime.now();
    notifyListeners();
  }

  /// Nhân viên Phục vụ bấm báo Quầy Thu ngân tính tiền bàn này
  Future<bool> requestPaymentForCurrentOrder() async {
    if (_currentOrder == null) return false;
    markConfirmClicked();
    try {
      final newNote = AiTracker.buildUpdatedNote(
        currentNote: _currentOrder!.note,
        requestPayment: true,
        tracker: getAiTracker(),
      );
      final res = await OrderService().updateOrderNote(
        _currentOrder!.orderId,
        newNote,
      );
      if (res.isSuccess && res.data != null) {
        _currentOrder = res.data;
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      _error = ErrorHandler.formatError(e);
      notifyListeners();
      return false;
    }
  }

  /// Nhân viên Phục vụ bấm Xác nhận & Gửi Bếp
  Future<bool> sendToKitchen() async {
    if (_currentOrder == null) return false;
    markConfirmClicked();
    try {
      await _syncTrackerToOrderNote();
      notifyListeners();
      return true;
    } catch (e) {
      _error = ErrorHandler.formatError(e);
      notifyListeners();
      return false;
    }
  }

  AiTracker getAiTracker() {
    return AiTracker.fromRaw(
      startTime: _tableOpenedAt,
      confirmTime: _confirmTime,
      voidCount: _voidCount,
      totalAdded: _addCount,
      totalRemoved: _removeCount,
      removedAfterConfirm: _itemsRemovedAfterConfirm,
      hasConfirmed: _confirmClicked,
    );
  }

  /// Thanh toán hóa đơn tại quầy
  Future<Map<String, dynamic>?> checkout({
    required int accountId,
    int? customerId,
    required int paymentMethod,
    String? voucherCode,
    String? discountCampaignCode,
    double? appliedDiscountPercent,
    double vatPercent = 8.0,
  }) async {
    if (_currentOrder == null) return null;

    try {
      final invoiceService = InvoiceService();
      final result = await invoiceService.checkout(
        orderId: _currentOrder!.orderId,
        accountId: accountId,
        tableId: _currentOrder!.tableId,
        paymentMethod: paymentMethod,
        tracker: getAiTracker(),
        customerId: customerId,
        voucherCode: voucherCode,
        discountCampaignCode: discountCampaignCode,
        appliedDiscountPercent: appliedDiscountPercent,
        vatPercent: vatPercent,
      );

      if (result.isSuccess && result.data != null) {
        final resJson = result.data!.toJson();
        clearCurrentOrderAfterCheckout();
        return resJson;
      } else {
        _error = result.error ?? 'Thanh toán thất bại';
        notifyListeners();
        return null;
      }
    } catch (e) {
      _error = ErrorHandler.formatError(e);
      notifyListeners();
      return null;
    }
  }
}
