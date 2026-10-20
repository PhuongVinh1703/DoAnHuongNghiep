class OrderItem {
  final int orderItemId;
  final int itemId;
  final String itemName;
  final String? emoji;
  final String? imagePath;
  int quantity;
  final double unitPrice;
  final double lineTotal;
  final String? note;
  final bool isDeleted;

  OrderItem({
    required this.orderItemId,
    required this.itemId,
    required this.itemName,
    this.emoji,
    this.imagePath,
    required this.quantity,
    required this.unitPrice,
    required this.lineTotal,
    this.note,
    this.isDeleted = false,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    final double uPrice =
        (json['unitPrice'] ?? json['UnitPrice'] ?? 0).toDouble();
    final int qty = json['quantity'] ?? json['Quantity'] ?? 1;
    final menuMap = json['MenuItems'] as Map?;
    return OrderItem(
      orderItemId: json['orderItemId'] ?? json['OrderItemId'] ?? 0,
      itemId: json['itemId'] ?? json['ItemId'] ?? 0,
      itemName: json['itemName'] ??
          json['ItemName'] ??
          menuMap?['Name'] ??
          menuMap?['name'] ??
          '',
      emoji: json['emoji'] ?? json['Emoji'] ?? menuMap?['Emoji'] ?? menuMap?['emoji'],
      imagePath: json['imagePath'] ??
          json['ImagePath'] ??
          menuMap?['ImagePath'] ??
          menuMap?['imagePath'],
      quantity: qty,
      unitPrice: uPrice,
      lineTotal:
          (json['lineTotal'] ?? json['LineTotal'] ?? uPrice * qty).toDouble(),
      note: json['note'] ?? json['Note'],
      isDeleted: json['isDeleted'] ?? json['IsDeleted'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'orderItemId': orderItemId,
      'itemId': itemId,
      'itemName': itemName,
      'emoji': emoji,
      'imagePath': imagePath,
      'quantity': quantity,
      'unitPrice': unitPrice,
      'lineTotal': lineTotal,
      'note': note,
      'isDeleted': isDeleted,
    };
  }
}
