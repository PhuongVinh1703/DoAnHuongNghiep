class DiningTable {
  final int tableId;
  final String tableName;
  final int capacity;
  final int status; // 0: Available, 1: Occupied, 2: Reserved
  final bool isActive;
  final int? branchId;

  DiningTable({
    required this.tableId,
    required this.tableName,
    required this.capacity,
    required this.status,
    required this.isActive,
    this.branchId,
  });

  factory DiningTable.fromJson(Map<String, dynamic> json) {
    return DiningTable(
      tableId:   json['tableId']   ?? json['TableId']   ?? 0,
      tableName: json['tableName'] ?? json['TableName'] ?? '',
      capacity:  json['capacity']  ?? json['Capacity']  ?? 0,
      status:    json['status']    ?? json['Status']    ?? 0,
      isActive:  json['isActive']  ?? json['IsActive']  ?? true,
      branchId:  json['branchId']  ?? json['BranchId'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'tableId': tableId,
      'tableName': tableName,
      'capacity': capacity,
      'status': status,
      'isActive': isActive,
      'branchId': branchId,
    };
  }
}
