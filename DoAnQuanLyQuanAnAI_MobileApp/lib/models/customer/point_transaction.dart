class PointTransaction {
  final int txId;
  final int customerId;
  final int pointDelta;
  final String note;
  final DateTime createdAt;
  final int? invoiceId;

  PointTransaction({
    required this.txId,
    required this.customerId,
    required this.pointDelta,
    required this.note,
    required this.createdAt,
    this.invoiceId,
  });

  factory PointTransaction.fromJson(Map<String, dynamic> json) {
    return PointTransaction(
      txId:       json['txId']        ?? json['TxId']        ?? 0,
      customerId: json['customerId']  ?? json['CustomerId']  ?? 0,
      pointDelta: json['pointDelta']  ?? json['PointDelta']  ?? 0,
      note:       json['note']        ?? json['Note']        ?? '',
      createdAt:  DateTime.parse(json['createdAt'] ?? json['CreatedAt'] ?? DateTime.now().toIso8601String()),
      invoiceId:  json['invoiceId']   ?? json['InvoiceId'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'txId': txId,
      'customerId': customerId,
      'pointDelta': pointDelta,
      'note': note,
      'createdAt': createdAt.toIso8601String(),
      'invoiceId': invoiceId,
    };
  }
}
