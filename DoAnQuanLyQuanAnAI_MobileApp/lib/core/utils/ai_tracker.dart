import 'dart:math' as math;

class AiTracker {
  static const String billReqTag = '[BILL_REQ]';
  static const String kdsReadyTag = '[KDS_READY]';
  static const String itemDoneTag = '[DONE]';

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
  int get totalAdded => _totalAdded;
  int get totalRemoved => _totalRemoved;
  int get itemsRemovedAfterConfirm => _removedAfterConfirm;
  bool get hasConfirmed => _hasConfirmed;
  DateTime? get confirmTime => _confirmTime;
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

  /// Mã hóa các chỉ số hành vi AI vào chuỗi tag ẩn để lưu vào Orders.Note
  String encodeToNoteTag() {
    final ct = _confirmTime?.millisecondsSinceEpoch ?? 0;
    return '[AI:v=$_voidCount,a=$_totalAdded,r=$_totalRemoved,rac=$_removedAfterConfirm,ct=$ct]';
  }

  /// Khôi phục và gộp dữ liệu AiTracker từ Orders.Note và localTracker
  static AiTracker mergeFromOrderNote(
    String? note,
    AiTracker localTracker, {
    DateTime? openedAt,
  }) {
    int remoteVoid = 0;
    int remoteAdded = 0;
    int remoteRemoved = 0;
    int remoteRac = 0;
    int remoteCtEpoch = 0;

    if (note != null && note.isNotEmpty) {
      final match = RegExp(
        r'\[AI:v=(\d+),a=(\d+),r=(\d+),rac=(\d+),ct=(\d+)\]',
      ).firstMatch(note);

      if (match != null) {
        remoteVoid = int.tryParse(match.group(1) ?? '0') ?? 0;
        remoteAdded = int.tryParse(match.group(2) ?? '0') ?? 0;
        remoteRemoved = int.tryParse(match.group(3) ?? '0') ?? 0;
        remoteRac = int.tryParse(match.group(4) ?? '0') ?? 0;
        remoteCtEpoch = int.tryParse(match.group(5) ?? '0') ?? 0;
      }
    }

    final mergedVoid = math.max(remoteVoid, localTracker.voidCount);
    final mergedAdded = math.max(remoteAdded, localTracker.totalAdded);
    final mergedRemoved = math.max(remoteRemoved, localTracker.totalRemoved);
    final mergedRac = math.max(remoteRac, localTracker.itemsRemovedAfterConfirm);

    DateTime? mergedConfirm;
    if (remoteCtEpoch > 0) {
      mergedConfirm = DateTime.fromMillisecondsSinceEpoch(remoteCtEpoch);
    } else {
      mergedConfirm = localTracker.confirmTime;
    }

    final hasConfirmed =
        (remoteCtEpoch > 0) || localTracker.hasConfirmed || (mergedRac > 0);

    return AiTracker.fromRaw(
      startTime: openedAt ?? localTracker._orderStartTime,
      confirmTime: mergedConfirm,
      voidCount: mergedVoid,
      totalAdded: mergedAdded,
      totalRemoved: mergedRemoved,
      removedAfterConfirm: mergedRac,
      hasConfirmed: hasConfirmed,
      cancelRate: localTracker.cancelRate,
    );
  }

  /// Kiểm tra bàn có đang yêu cầu tính tiền hay không
  static bool isPaymentRequested(String? note) {
    if (note == null || note.isEmpty) return false;
    return note.contains(billReqTag);
  }

  /// Kiểm tra bếp đã báo chế biến xong toàn bộ đơn hay chưa
  static bool isKitchenReady(String? note) {
    if (note == null || note.isEmpty) return false;
    return note.contains(kdsReadyTag);
  }

  /// Kiểm tra từng món ăn riêng lẻ đã được bếp chế biến xong chưa
  static bool isItemDone(String? note) {
    if (note == null || note.isEmpty) return false;
    return note.contains(itemDoneTag);
  }

  /// Gán hoặc gỡ tag [DONE] cho ghi chú của món ăn
  static String setItemDone(String? currentNote, bool isDone) {
    final clean = cleanDisplayNote(currentNote);
    if (isDone) {
      return clean.isEmpty ? itemDoneTag : '$clean $itemDoneTag';
    } else {
      return clean;
    }
  }

  /// Xóa sạch các tag kỹ thuật để hiển thị ghi chú món sạch đẹp cho khách và nhân viên
  static String cleanDisplayNote(String? note) {
    if (note == null || note.isEmpty) return '';
    return note
        .replaceAll(RegExp(r'\[AI:[^\]]*\]'), '')
        .replaceAll(billReqTag, '')
        .replaceAll(kdsReadyTag, '')
        .replaceAll(itemDoneTag, '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Ghép lại ghi chú của khách với các tag trạng thái và chỉ số AI
  static String buildUpdatedNote({
    String? currentNote,
    bool? requestPayment,
    bool? kitchenReady,
    AiTracker? tracker,
  }) {
    final cleanText = cleanDisplayNote(currentNote);
    final bool reqPay = requestPayment ?? isPaymentRequested(currentNote);
    final bool kdsDone = kitchenReady ?? isKitchenReady(currentNote);

    final tags = <String>[];
    if (reqPay) {
      tags.add(billReqTag);
    }
    if (kdsDone) {
      tags.add(kdsReadyTag);
    }

    if (tracker != null) {
      tags.add(tracker.encodeToNoteTag());
    } else if (currentNote != null) {
      final aiMatch = RegExp(r'\[AI:[^\]]*\]').firstMatch(currentNote);
      if (aiMatch != null) {
        tags.add(aiMatch.group(0)!);
      }
    }

    final tagString = tags.join(' ');
    if (cleanText.isEmpty) {
      return tagString;
    }
    if (tagString.isEmpty) {
      return cleanText;
    }
    return '$cleanText $tagString';
  }
}
