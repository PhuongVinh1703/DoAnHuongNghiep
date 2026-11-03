class Reservation {
  final int reservationId;
  final String customerName;
  final String customerPhone;
  final int branchId;
  final String? branchName;
  final int guestCount;
  final DateTime reservedAt;
  final DateTime createdAt;
  final int status; // 0=Pending, 1=Confirmed, 2=Rejected, 3=Cancelled
  final String? note;
  final String? managerNote;
  final int? customerId;

  Reservation({
    required this.reservationId,
    required this.customerName,
    required this.customerPhone,
    required this.branchId,
    this.branchName,
    required this.guestCount,
    required this.reservedAt,
    required this.createdAt,
    required this.status,
    this.note,
    this.managerNote,
    this.customerId,
  });

  /// ID bàn được xếp cho phiếu đặt chỗ này (trích xuất từ tag [TABLE:id|name])
  int? get assignedTableId {
    final raw = managerNote;
    if (raw == null || raw.isEmpty) return null;
    final match = RegExp(r'\[TABLE:(\d+)\|([^\]]+)\]').firstMatch(raw);
    if (match != null) {
      return int.tryParse(match.group(1) ?? '');
    }
    return null;
  }

  /// Tên bàn được xếp cho phiếu đặt chỗ này (ví dụ: "Bàn 04")
  String? get assignedTableName {
    final raw = managerNote;
    if (raw == null || raw.isEmpty) return null;
    final match = RegExp(r'\[TABLE:(\d+)\|([^\]]+)\]').firstMatch(raw);
    if (match != null) {
      return match.group(2)?.trim();
    }
    return null;
  }

  /// Khách đã đến nhận bàn (Check-in / Seated) hay chưa
  bool get isSeated {
    final raw = managerNote;
    if (raw == null || raw.isEmpty) return false;
    return raw.contains('[SEATED]');
  }

  /// Chỉ dẫn nội bộ của Quản lý giao cho Nhân viên (tuyệt đối ẩn khỏi màn hình Khách hàng)
  String? get internalStaffTask {
    final raw = managerNote;
    if (raw == null || raw.isEmpty) return null;

    final internalMatch = RegExp(r'\[INTERNAL:([^\]]+)\]').firstMatch(raw);
    if (internalMatch != null) {
      final text = internalMatch.group(1)?.trim();
      return (text != null && text.isNotEmpty) ? text : null;
    }

    // Tương thích ngược với các bản ghi cũ lưu trực tiếp "[Giao việc: ...]"
    if (raw.contains('[Giao việc:')) {
      return raw
          .replaceAll(RegExp(r'\[TABLE:[^\]]+\]'), '')
          .replaceAll('[SEATED]', '')
          .trim();
    }
    return null;
  }

  /// Lời nhắn lịch sự hiển thị cho Khách hàng (đã lọc bỏ hoàn toàn kịch bản Upsell nội bộ)
  String? get customerFacingNote {
    final raw = managerNote;
    if (raw == null || raw.isEmpty) return null;

    // Nếu là bản ghi cũ chứa "[Giao việc: ...]" mà chưa tách tag [INTERNAL:...]
    if (raw.contains('[Giao việc:') && !raw.contains('[INTERNAL:')) {
      return status == 1
          ? 'Nhà hàng đã xác nhận giữ chỗ và chuẩn bị bàn đón tiếp quý khách.'
          : null;
    }

    final cleaned = raw
        .replaceAll(RegExp(r'\[TABLE:[^\]]+\]'), '')
        .replaceAll(RegExp(r'\[INTERNAL:[^\]]+\]'), '')
        .replaceAll('[SEATED]', '')
        .trim();

    if (cleaned.isNotEmpty) return cleaned;
    if (status == 1 && assignedTableName != null) {
      return 'Nhà hàng đã sắp xếp $assignedTableName đón tiếp quý khách.';
    }
    return null;
  }

  /// Đóng gói metadata chuẩn cho cột ManagerNote mà không cần đổi cấu trúc bảng Supabase
  static String buildManagerMetadata({
    int? tableId,
    String? tableName,
    String? internalTask,
    String? customerMessage,
    bool isSeated = false,
  }) {
    final parts = <String>[];
    if (tableId != null && tableName != null && tableName.trim().isNotEmpty) {
      parts.add('[TABLE:$tableId|${tableName.trim()}]');
    }
    if (isSeated) {
      parts.add('[SEATED]');
    }
    if (internalTask != null && internalTask.trim().isNotEmpty) {
      final cleanInternal = internalTask.trim().replaceAll('[', '(').replaceAll(']', ')');
      parts.add('[INTERNAL:$cleanInternal]');
    }
    if (customerMessage != null && customerMessage.trim().isNotEmpty) {
      parts.add(customerMessage.trim());
    }
    return parts.join(' ').trim();
  }

  /// Đánh dấu phiếu đặt bàn đã Check-in nhận bàn ([SEATED])
  String markSeatedManagerNote() {
    final current = managerNote ?? '';
    if (current.contains('[SEATED]')) return current;
    return '$current [SEATED]'.trim();
  }

  factory Reservation.fromJson(Map<String, dynamic> json) {
    return Reservation(
      reservationId: json['reservationId'] ?? json['ReservationId'] ?? 0,
      customerName:  json['customerName'] ?? json['CustomerName'] ??
                     (json['Customers'] as Map?)?['FullName'] ?? '',
      customerPhone: json['customerPhone'] ?? json['CustomerPhone'] ??
                     (json['Customers'] as Map?)?['Phone'] ?? '',
      branchId:      json['branchId'] ?? json['BranchId'] ?? 0,
      branchName:    json['branchName'] ?? json['BranchName'] ??
                     (json['Branches'] as Map?)?['Name'],
      guestCount:    json['guestCount'] ?? json['GuestCount'] ?? 0,
      reservedAt:    DateTime.parse(json['reservedAt'] ?? json['ReservedAt']),
      createdAt:     json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : json['CreatedAt'] != null
              ? DateTime.parse(json['CreatedAt'])
              : DateTime.now(),
      status:        json['status'] ?? json['Status'] ?? 0,
      note:          json['note'] ?? json['Note'],
      managerNote:   json['managerNote'] ?? json['ManagerNote'],
      customerId:    json['customerId'] ?? json['CustomerId'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'reservationId': reservationId,
      'customerName': customerName,
      'customerPhone': customerPhone,
      'branchId': branchId,
      'guestCount': guestCount,
      'reservedAt': reservedAt.toIso8601String(),
      'status': status,
      'note': note,
      'createdAt': createdAt.toIso8601String(),
      'managerNote': managerNote,
      'customerId': customerId,
    };
  }
}
