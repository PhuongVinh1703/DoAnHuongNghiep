class Alert {
  final int alertId;
  final int alertType;
  final int severity;
  final String description;
  final DateTime createdAt;
  final bool isResolved;
  final int? resolvedBy;
  final DateTime? resolvedAt;
  final String? resolutionNote;
  final int branchId;
  final String? branchName;      // tên chi nhánh
  final String? staffName;       // tên nhân viên
  final double? anomalyScore;    // điểm bất thường từ AI
  final int? accountId;          // accountId của nhân viên

  // Computed getter
  String get alertTypeName {
    switch (alertType) {
      case 0: return 'Hủy sau khi trả tiền';
      case 1: return 'Giao dịch bất thường';
      case 2: return 'Lạm dụng giảm giá';
      case 3: return 'Giao dịch ngoài giờ';
      case 4: return 'Hành vi đáng ngờ';
      case 5: return 'Thanh toán siêu tốc';
      case 6: return 'Thêm/xóa món bất thường';
      default: return 'Cảnh báo #$alertType';
    }
  }

  Alert({
    required this.alertId,
    required this.alertType,
    required this.severity,
    required this.description,
    required this.createdAt,
    required this.isResolved,
    this.resolvedBy,
    this.resolvedAt,
    this.resolutionNote,
    required this.branchId,
    this.branchName,
    this.staffName,
    this.anomalyScore,
    this.accountId,
  });

  factory Alert.fromJson(Map<String, dynamic> json) {
    // Phân giải branchName và branchId từ join Orders -> DiningTables -> Branches
    final order = json['Orders'] as Map?;
    final table = order != null ? order['DiningTables'] as Map? : null;
    final branch = table != null ? table['Branches'] as Map? : null;
    
    final branchName = branch != null 
        ? branch['Name'] as String? 
        : (json['branchName'] ?? json['BranchName']);
        
    final int? parsedBranchId = branch != null 
        ? branch['BranchId'] as int? 
        : (json['branchId'] ?? json['BranchId'] ?? table?['BranchId']);

    return Alert(
      alertId:        json['alertId']      ?? json['AlertId']      ?? 0,
      alertType:      json['alertType']    ?? json['AlertType']    ?? 0,
      severity:       json['severity']     ?? json['Severity']     ?? 0,
      description:    json['description']  ?? json['Message']      ?? json['message'] ?? '',
      createdAt:      DateTime.parse(json['createdAt'] ?? json['CreatedAt'] ?? DateTime.now().toIso8601String()),
      isResolved:     json['isResolved']   ?? json['IsResolved']   ?? false,
      resolvedBy:     json['resolvedBy']   ?? json['ResolvedBy'],
      resolvedAt:     json['resolvedAt'] != null
          ? DateTime.parse(json['resolvedAt'])
          : json['ResolvedAt'] != null
              ? DateTime.parse(json['ResolvedAt'])
              : null,
      resolutionNote: json['resolutionNote'] ?? json['ResolvedNote'],
      branchId:       parsedBranchId ?? 1,
      branchName:     branchName,
      staffName:      json['staffName']    ?? json['StaffName']    ?? 
                      json['accountName']  ?? json['AccountName']  ??
                      (json['Accounts'] as Map?)?['FullName'],
      anomalyScore:   json['anomalyScore'] != null
          ? (json['anomalyScore']).toDouble()
          : json['AnomalyScore'] != null
              ? (json['AnomalyScore']).toDouble()
              : null,
      accountId:      json['accountId']    ?? json['AccountId'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'alertId': alertId,
      'alertType': alertType,
      'severity': severity,
      'description': description,
      'createdAt': createdAt.toIso8601String(),
      'isResolved': isResolved,
      'resolvedBy': resolvedBy,
      'resolvedAt': resolvedAt?.toIso8601String(),
      'resolutionNote': resolutionNote,
      'branchId': branchId,
    };
  }
}
