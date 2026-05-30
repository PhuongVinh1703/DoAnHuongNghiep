import 'package:flutter/foundation.dart';
import 'package:doanquanlyquananai_mobileapp/core/utils/ai_tracker.dart';
import 'package:doanquanlyquananai_mobileapp/models/menu/menu_item.dart';

class CartItem {
  final MenuItemModel menuItem;
  int quantity;
  String? note;

  CartItem({required this.menuItem, this.quantity = 1, this.note});

  double get lineTotal => menuItem.price * quantity;
  int get itemId => menuItem.itemId;
}

class CartProvider with ChangeNotifier {
  final AiTracker aiTracker = AiTracker();

  final List<CartItem> _items = [];
  bool _confirmed = false;

  List<CartItem> get items => List.unmodifiable(_items);
  bool get isEmpty => _items.isEmpty;
  int get itemCount => _items.fold(0, (sum, i) => sum + i.quantity);
  bool get isConfirmed => _confirmed;

  double get subtotal => _items.fold(0, (sum, i) => sum + i.lineTotal);

  // ── Thêm món ─────────────────────────────────────────────────
  void addItem(MenuItemModel item, {int qty = 1, String? note}) {
    final idx = _items.indexWhere((c) => c.itemId == item.itemId);
    if (idx >= 0) {
      _items[idx].quantity += qty;
    } else {
      _items.add(CartItem(menuItem: item, quantity: qty, note: note));
    }
    aiTracker.onItemAdded(qty);
    notifyListeners();
  }

  // ── Giảm số lượng ────────────────────────────────────────────
  void decreaseItem(int itemId, {int qty = 1}) {
    final idx = _items.indexWhere((c) => c.itemId == itemId);
    if (idx < 0) return;
    if (_items[idx].quantity <= qty) {
      aiTracker.onItemRemoved(_items[idx].quantity);
      _items.removeAt(idx);
    } else {
      _items[idx].quantity -= qty;
      aiTracker.onItemRemoved(qty);
    }
    notifyListeners();
  }

  // ── Xóa hẳn ──────────────────────────────────────────────────
  void removeItem(int itemId) {
    final idx = _items.indexWhere((c) => c.itemId == itemId);
    if (idx < 0) return;
    aiTracker.onItemRemoved(_items[idx].quantity);
    _items.removeAt(idx);
    notifyListeners();
  }

  // ── Đặt số lượng trực tiếp ───────────────────────────────────
  void setQuantity(int itemId, int qty) {
    final idx = _items.indexWhere((c) => c.itemId == itemId);
    if (idx < 0) return;
    final old = _items[idx].quantity;
    if (qty <= 0) {
      aiTracker.onItemRemoved(old);
      _items.removeAt(idx);
    } else {
      final delta = qty - old;
      if (delta > 0) aiTracker.onItemAdded(delta);
      if (delta < 0) aiTracker.onItemRemoved(-delta);
      _items[idx].quantity = qty;
    }
    notifyListeners();
  }

  // ── Xác nhận (trước checkout) ─────────────────────────────────
  void confirm() {
    _confirmed = true;
    aiTracker.onOrderConfirmed();
    notifyListeners();
  }

  // ── Bắt đầu order mới ────────────────────────────────────────
  void startOrder() {
    _items.clear();
    _confirmed = false;
    aiTracker.startOrder();
    notifyListeners();
  }

  // ── Xóa giỏ hàng sau checkout ────────────────────────────────
  void clear() {
    _items.clear();
    _confirmed = false;
    aiTracker.reset();
    notifyListeners();
  }

  int quantityOf(int itemId) {
    final idx = _items.indexWhere((c) => c.itemId == itemId);
    return idx >= 0 ? _items[idx].quantity : 0;
  }
}
