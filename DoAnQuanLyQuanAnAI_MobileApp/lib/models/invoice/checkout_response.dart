class AiAlertSummary {
  final bool isAnomaly;
  final double anomalyScore;
  final String riskLevel;

  AiAlertSummary({
    required this.isAnomaly,
    required this.anomalyScore,
    required this.riskLevel,
  });

  factory AiAlertSummary.fromJson(Map<String, dynamic> json) {
    return AiAlertSummary(
      isAnomaly:    json['isAnomaly']    ?? json['IsAnomaly']    ?? false,
      anomalyScore: (json['anomalyScore'] ?? json['AnomalyScore'] ?? 0).toDouble(),
      riskLevel:    json['riskLevel']    ?? json['RiskLevel']    ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'isAnomaly': isAnomaly,
      'anomalyScore': anomalyScore,
      'riskLevel': riskLevel,
    };
  }
}

class CheckoutResponse {
  final int invoiceId;
  final String invoiceNo;
  final double totalAmount;
  final int earnedPoints;
  final AiAlertSummary? aiAlert;

  CheckoutResponse({
    required this.invoiceId,
    required this.invoiceNo,
    required this.totalAmount,
    required this.earnedPoints,
    this.aiAlert,
  });

  factory CheckoutResponse.fromJson(Map<String, dynamic> json) {
    return CheckoutResponse(
      invoiceId:    json['invoiceId']    ?? json['InvoiceId']    ?? 0,
      invoiceNo:    json['invoiceNo']    ?? json['InvoiceNo']    ?? '',
      totalAmount:  (json['totalAmount']  ?? json['TotalAmount']  ?? 0).toDouble(),
      earnedPoints: json['earnedPoints'] ?? json['EarnedPoints'] ?? 0,
      aiAlert:      (json['aiAlert'] ?? json['AiAlert']) != null 
          ? AiAlertSummary.fromJson(json['aiAlert'] ?? json['AiAlert']) 
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'invoiceId': invoiceId,
      'invoiceNo': invoiceNo,
      'totalAmount': totalAmount,
      'earnedPoints': earnedPoints,
      'aiAlert': aiAlert?.toJson(),
    };
  }
}
