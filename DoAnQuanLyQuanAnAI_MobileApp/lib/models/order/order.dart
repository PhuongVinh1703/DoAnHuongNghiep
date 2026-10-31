import 'order_item.dart';

class OrderModel {
  final int orderId;
  final int tableId;
  final String tableName;
  final int accountId;
  final String staffName;
  final int status; // 0=Open, 1=Paid, 2=Cancelled
  final DateTime openedAt;
  final DateTime? closedAt;
  final String? note;
  final double subtotal;
  final List<OrderItem> items;
  final int? branchId;

  OrderModel({
    required this.orderId,
    required this.tableId,
    required this.tableName,
    required this.accountId,
    required this.staffName,
    required this.status,
    required this.openedAt,
    this.closedAt,
    this.note,
    required this.subtotal,
    required this.items,
    this.branchId,
  });

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    final itemsList = (json['items'] ?? json['OrderItems'] ?? []) as List;
    final parsedItems = itemsList.map((i) => OrderItem.fromJson(i)).toList();
    
    // Tự động tính toán subtotal nếu không được trả về từ DB
    final double computedSubtotal = parsedItems
        .where((item) => !item.isDeleted)
        .fold(0.0, (sum, item) => sum + item.lineTotal);

    return OrderModel(
      orderId:   json['orderId']   ?? json['OrderId']   ?? 0,
      tableId:   json['tableId']   ?? json['TableId']   ?? 0,
      tableName: json['tableName'] ?? json['TableName'] ?? 
                 (json['DiningTables'] as Map?)?['TableName'] ?? '',
      accountId: json['accountId'] ?? json['AccountId'] ?? 0,
      staffName: json['staffName'] ?? json['StaffName'] ?? 
                 (json['Accounts'] as Map?)?['FullName']  ?? '',
      status:    json['status']    ?? json['Status']    ?? 0,
      openedAt:  DateTime.parse(json['openedAt'] ?? json['OpenedAt']),
      closedAt:  json['closedAt'] != null
          ? DateTime.parse(json['closedAt'])
          : json['ClosedAt'] != null
              ? DateTime.parse(json['ClosedAt'])
              : null,
      note:      json['note'] ?? json['Note'],
      subtotal:  (json['subtotal'] ?? json['Subtotal'] ?? computedSubtotal).toDouble(),
      items:     parsedItems,
      branchId:  json['branchId']  ?? json['BranchId']  ?? 
                 (json['DiningTables'] as Map?)?['BranchId'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'orderId': orderId,
      'tableId': tableId,
      'tableName': tableName,
      'accountId': accountId,
      'staffName': staffName,
      'status': status,
      'openedAt': openedAt.toIso8601String(),
      'closedAt': closedAt?.toIso8601String(),
      'note': note,
      'subtotal': subtotal,
      'items': items.map((i) => i.toJson()).toList(),
      'branchId': branchId,
    };
  }
}
