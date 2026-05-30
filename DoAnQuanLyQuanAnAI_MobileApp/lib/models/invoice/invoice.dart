class InvoiceItem {
  final int invoiceItemId;
  final int? itemId;
  final String itemName;
  final int quantity;
  final double unitPrice;
  final double lineTotal;
  final String? note;

  InvoiceItem({
    required this.invoiceItemId,
    this.itemId,
    required this.itemName,
    required this.quantity,
    required this.unitPrice,
    required this.lineTotal,
    this.note,
  });

  factory InvoiceItem.fromJson(Map<String, dynamic> json) {
    final double price = (json['unitPrice'] ?? json['UnitPrice'] ?? 0).toDouble();
    final int qty = json['quantity'] ?? json['Quantity'] ?? 0;
    return InvoiceItem(
      invoiceItemId: json['invoiceItemId'] ?? json['InvoiceItemId'] ?? 0,
      itemId:        json['itemId']        ?? json['ItemId'],
      itemName:      json['itemName']      ?? json['ItemName']      ?? '',
      quantity:      qty,
      unitPrice:     price,
      lineTotal:     (json['lineTotal'] ?? json['LineTotal'] ?? price * qty).toDouble(),
      note:          json['note']          ?? json['Note'],
    );
  }
}

class Invoice {
  final int invoiceId;
  final String invoiceNo;
  final String? tableName;
  final String? staffName;
  final String? customerName;
  final int? customerId;
  final double subtotal;
  final double discountAmount;
  final double discountPercent;
  final double vatAmount;
  final double vatPercent;
  final double totalAmount;
  final int paymentMethod; // 0=Cash, 1=Card, 2=QR
  final DateTime paidAt;
  final List<InvoiceItem> items;

  Invoice({
    required this.invoiceId,
    required this.invoiceNo,
    this.tableName,
    this.staffName,
    this.customerName,
    this.customerId,
    required this.subtotal,
    required this.discountAmount,
    required this.discountPercent,
    required this.vatAmount,
    required this.vatPercent,
    required this.totalAmount,
    required this.paymentMethod,
    required this.paidAt,
    required this.items,
  });

  factory Invoice.fromJson(Map<String, dynamic> json) {
    final rawItems = (json['items'] ?? json['InvoiceItems'] ?? []) as List<dynamic>;
    return Invoice(
      invoiceId:       json['invoiceId']       ?? json['InvoiceId']       ?? 0,
      invoiceNo:       json['invoiceNo']       ?? json['InvoiceNo']       ?? '',
      tableName:       json['tableName']       ?? json['TableName']       ?? 
                       (json['DiningTables'] as Map?)?['TableName'],
      staffName:       json['staffName']       ?? json['StaffName']       ?? 
                       (json['Accounts'] as Map?)?['FullName'],
      customerName:    json['customerName']    ?? json['CustomerName']    ?? 
                       (json['Customers'] as Map?)?['FullName'],
      customerId:      json['customerId']      ?? json['CustomerId'],
      subtotal:        (json['subtotal']        ?? json['Subtotal']        ?? 0).toDouble(),
      discountAmount:  (json['discountAmount']  ?? json['DiscountAmount']  ?? 0).toDouble(),
      discountPercent: (json['discountPercent'] ?? json['DiscountPercent'] ?? 0).toDouble(),
      vatAmount:       (json['vatAmount']       ?? json['VatAmount']       ?? 0).toDouble(),
      vatPercent:      (json['vatPercent']      ?? json['VatPercent']      ?? 0).toDouble(),
      totalAmount:     (json['totalAmount']     ?? json['TotalAmount']     ?? 0).toDouble(),
      paymentMethod:   json['paymentMethod']   ?? json['PaymentMethod']   ?? 0,
      paidAt:          DateTime.parse(json['paidAt'] ?? json['PaidAt'] ?? DateTime.now().toIso8601String()),
      items:           rawItems.map((e) => InvoiceItem.fromJson(e)).toList(),
    );
  }

  String get paymentMethodLabel {
    switch (paymentMethod) {
      case 1: return 'Thẻ';
      case 2: return 'QR';
      default: return 'Tiền mặt';
    }
  }

  int get earnedPoints => (totalAmount / 100000).floor();
}
