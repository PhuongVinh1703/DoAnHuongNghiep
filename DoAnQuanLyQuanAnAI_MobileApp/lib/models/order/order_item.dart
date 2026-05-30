class OrderItem {
  final int orderItemId;
  final int itemId;
  final String itemName;
  final String? emoji;
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
    required this.quantity,
    required this.unitPrice,
    required this.lineTotal,
    this.note,
    this.isDeleted = false,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    final double uPrice = (json['unitPrice'] ?? json['UnitPrice'] ?? 0).toDouble();
    final int qty = json['quantity'] ?? json['Quantity'] ?? 1;
    return OrderItem(
      orderItemId: json['orderItemId'] ?? json['OrderItemId'] ?? 0,
      itemId:      json['itemId']      ?? json['ItemId']      ?? 0,
      itemName:    json['itemName']    ?? json['ItemName']    ?? 
                   (json['MenuItems'] as Map?)?['Name']       ?? '',
      emoji:       json['emoji']       ?? json['Emoji']       ?? 
                   (json['MenuItems'] as Map?)?['Emoji'],
      quantity:    qty,
      unitPrice:   uPrice,
      lineTotal:   (json['lineTotal'] ?? json['LineTotal'] ?? uPrice * qty).toDouble(),
      note:        json['note']        ?? json['Note'],
      isDeleted:   json['isDeleted']   ?? json['IsDeleted']   ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'orderItemId': orderItemId,
      'itemId': itemId,
      'itemName': itemName,
      'emoji': emoji,
      'quantity': quantity,
      'unitPrice': unitPrice,
      'lineTotal': lineTotal,
      'note': note,
      'isDeleted': isDeleted,
    };
  }
}
