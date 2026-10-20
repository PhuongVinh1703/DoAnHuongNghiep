class AiTracker {
  DateTime? _orderStartTime;
  DateTime? _confirmTime;
  int _voidCount = 0;
  int _totalAdded = 0;
  int _totalRemoved = 0;
  int _removedAfterConfirm = 0;
  bool _hasConfirmed = false;

  double? _cancelRate;

  AiTracker();

  AiTracker.fromRaw({
    DateTime? startTime,
    DateTime? confirmTime,
    int voidCount = 0,
    int totalAdded = 0,
    int totalRemoved = 0,
    int removedAfterConfirm = 0,
    bool hasConfirmed = false,
    double? cancelRate,
  })  : _orderStartTime = startTime,
        _confirmTime = confirmTime,
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

  void onOrderConfirmed() {
    _hasConfirmed = true;
    _confirmTime ??= DateTime.now();
  }

  double get sessionDuration {
    if (_orderStartTime == null) return 0;
    return DateTime.now().difference(_orderStartTime!).inSeconds.toDouble();
  }

  double get checkoutTimeSec {
    if (_confirmTime != null) {
      final sec = DateTime.now().difference(_confirmTime!).inSeconds.toDouble();
      return sec > 0 ? sec : sessionDuration;
    }
    return sessionDuration;
  }

  double get addRemoveRatio =>
      _totalAdded == 0 ? 0.0 : _totalRemoved / _totalAdded;

  int get voidCount => _voidCount;
  int get itemsRemovedAfterConfirm => _removedAfterConfirm;
  double get cancelRate => _cancelRate ?? 0.0;

  void reset() {
    _orderStartTime = null;
    _confirmTime = null;
    _voidCount = 0;
    _totalAdded = 0;
    _totalRemoved = 0;
    _removedAfterConfirm = 0;
    _hasConfirmed = false;
    _cancelRate = null;
  }
}
