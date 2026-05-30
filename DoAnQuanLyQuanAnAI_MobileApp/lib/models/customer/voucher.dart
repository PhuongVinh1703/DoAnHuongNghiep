class Voucher {
  final String voucherCode;
  final int customerId;
  final String description;
  final double discountAmount;
  final double minSubtotal;
  final DateTime expiryDate;
  final bool isUsed;

  Voucher({
    required this.voucherCode,
    required this.customerId,
    required this.description,
    required this.discountAmount,
    required this.minSubtotal,
    required this.expiryDate,
    required this.isUsed,
  });

  factory Voucher.fromJson(Map<String, dynamic> json) {
    // Nếu có relation join từ PointRewards
    final rewardDesc = (json['PointRewards'] as Map?)?['Description'] ?? 
                       (json['PointRewards'] as Map?)?['Name'] ?? '';

    return Voucher(
      voucherCode: json['code']            ?? json['Code']            ?? 
                   json['voucherCode']     ?? json['VoucherCode']     ?? '',
      customerId:  json['customerId']      ?? json['CustomerId']      ?? 0,
      description: json['description']     ?? json['Description']     ?? rewardDesc ?? '',
      // Bản chất trong DB là phần trăm giảm giá (DiscountPercent)
      discountAmount: (json['discountPercent'] ?? json['DiscountPercent'] ?? 
                       json['discountAmount']  ?? json['DiscountAmount']  ?? 0).toDouble(),
      minSubtotal: (json['minOrderAmount'] ?? json['MinOrderAmount'] ?? 
                    json['minSubtotal']    ?? json['MinSubtotal']    ?? 0).toDouble(),
      expiryDate:  DateTime.parse(json['expiresAt'] ?? json['ExpiresAt'] ?? 
                                  json['expiryDate'] ?? json['ExpiryDate'] ?? DateTime.now().toIso8601String()),
      isUsed:      json['isUsed']          ?? json['IsUsed']          ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'voucherCode': voucherCode,
      'customerId': customerId,
      'description': description,
      'discountAmount': discountAmount,
      'minSubtotal': minSubtotal,
      'expiryDate': expiryDate.toIso8601String(),
      'isUsed': isUsed,
    };
  }
}
