class CheckoutRequest {
  final int orderId;
  final int accountId;
  final int tableId;
  final int paymentMethod;
  final int? customerId;
  final String? voucherCode;
  final String? discountCampaignCode;
  final double vatPercent;
  
  // AI tracking data
  final double checkoutTimeSec;
  final int voidCount;
  final double addRemoveRatio;
  final int itemsRemovedAfterConfirm;

  CheckoutRequest({
    required this.orderId,
    required this.accountId,
    required this.tableId,
    required this.paymentMethod,
    this.customerId,
    this.voucherCode,
    this.discountCampaignCode,
    this.vatPercent = 8.0,
    required this.checkoutTimeSec,
    required this.voidCount,
    required this.addRemoveRatio,
    required this.itemsRemovedAfterConfirm,
  });

  Map<String, dynamic> toJson() {
    return {
      'orderId': orderId,
      'accountId': accountId,
      'tableId': tableId,
      'paymentMethod': paymentMethod,
      'customerId': customerId,
      'voucherCode': voucherCode,
      'discountCampaignCode': discountCampaignCode,
      'vatPercent': vatPercent,
      'checkoutTimeSec': checkoutTimeSec,
      'voidCount': voidCount,
      'addRemoveRatio': addRemoveRatio,
      'itemsRemovedAfterConfirm': itemsRemovedAfterConfirm,
    };
  }
}
