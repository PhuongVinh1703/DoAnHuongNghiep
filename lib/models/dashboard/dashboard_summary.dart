class DashboardSummary {
  final double totalRevenue;
  final int totalInvoices;
  final double totalDiscount;
  final double avgOrderValue;
  final int openOrders;
  final int unresolvedAlerts;

  DashboardSummary({
    required this.totalRevenue,
    required this.totalInvoices,
    required this.totalDiscount,
    required this.avgOrderValue,
    required this.openOrders,
    required this.unresolvedAlerts,
  });

  factory DashboardSummary.fromJson(Map<String, dynamic> json) {
    return DashboardSummary(
      totalRevenue: (json['totalRevenue'] ?? 0).toDouble(),
      totalInvoices: json['totalInvoices'] ?? 0,
      totalDiscount: (json['totalDiscount'] ?? 0).toDouble(),
      avgOrderValue: (json['avgOrderValue'] ?? 0).toDouble(),
      openOrders: json['openOrders'] ?? 0,
      unresolvedAlerts: json['unresolvedAlerts'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'totalRevenue': totalRevenue,
      'totalInvoices': totalInvoices,
      'totalDiscount': totalDiscount,
      'avgOrderValue': avgOrderValue,
      'openOrders': openOrders,
      'unresolvedAlerts': unresolvedAlerts,
    };
  }
}
