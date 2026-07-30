class AiTracker {
  DateTime? _orderStartTime;
  int _voidCount = 0;
  int _totalAdded = 0;
  int _totalRemoved = 0;
  int _removedAfterConfirm = 0;
  bool _hasConfirmed = false;

  double? _cancelRate;

  AiTracker();

  AiTracker.fromRaw({
    DateTime? startTime,
    int voidCount = 0,
    int totalAdded = 0,
    int totalRemoved = 0,
    int removedAfterConfirm = 0,
    bool hasConfirmed = false,
    double? cancelRate,
  })  : _orderStartTime = startTime,
        _voidCount = voidCount,
        _totalAdded = totalAdded,
        _totalRemoved = totalRemoved,
        _removedAfterConfirm = removedAfterConfirm,
        _hasConfirmed = hasConfirmed,
        _cancelRate = cancelRate;

  void startOrder() => _orderStartTime ??= DateTime.now();
  
  void onItemAdded(int qty) {
    if (qty > 0) {
      _totalAdded += qty;
    }
  }
  
  void onItemRemoved(int qty) {
    if (qty > 0) {
      _totalRemoved += qty;
      _voidCount++;
      if (_hasConfirmed) _removedAfterConfirm += qty;
    }
  }
  
  void onOrderConfirmed() => _hasConfirmed = true;
  
  double get sessionDuration {
    if (_orderStartTime == null) return 0;
    return DateTime.now().difference(_orderStartTime!).inSeconds.toDouble();
  }
  
  double get checkoutTimeSec {
    if (!_hasConfirmed || _orderStartTime == null) return sessionDuration;
    return DateTime.now().difference(_orderStartTime!).inSeconds.toDouble();
  }
  
  double get addRemoveRatio =>
    _totalAdded == 0 ? 0.0 : _totalRemoved / _totalAdded;
  
  int get voidCount => _voidCount;
  int get itemsRemovedAfterConfirm => _removedAfterConfirm;
  double get cancelRate => _cancelRate ?? 0.0;

  void reset() {
    _orderStartTime = null;
    _voidCount = 0;
    _totalAdded = 0;
    _totalRemoved = 0;
    _removedAfterConfirm = 0;
    _hasConfirmed = false;
    _cancelRate = null;
  }
}
