class DiscountCampaign {
  final int campaignId;
  final String code;
  final int discountType; // 0: percentage, 1: fixed amount
  final double discountValue;
  final double? maxDiscountAmount;
  final double minOrderValue;
  final DateTime startDate;
  final DateTime endDate;
  final int usageLimit;
  final int usedCount;
  final bool isActive;
  final int? branchId;
  final String description;

  DiscountCampaign({
    required this.campaignId,
    required this.code,
    required this.discountType,
    required this.discountValue,
    this.maxDiscountAmount,
    required this.minOrderValue,
    required this.startDate,
    required this.endDate,
    required this.usageLimit,
    required this.usedCount,
    required this.isActive,
    this.branchId,
    required this.description,
  });

  factory DiscountCampaign.fromJson(Map<String, dynamic> json) {
    return DiscountCampaign(
      campaignId: json['campaignId'] ?? json['CampaignId'] ?? 0,
      code: json['code'] ?? json['Code'] ?? '',
      discountType: 0, // Backend chỉ hỗ trợ giảm giá theo %
      discountValue: (json['discountPercent'] ?? json['DiscountPercent'] ?? json['discountValue'] ?? json['DiscountValue'] ?? 0).toDouble(),
      maxDiscountAmount: (json['maxDiscountAmount'] ?? json['MaxDiscountAmount'])?.toDouble(),
      minOrderValue: (json['minOrderValue'] ?? json['MinOrderValue'] ?? 0).toDouble(),
      startDate: DateTime.tryParse(json['startDate']?.toString() ?? json['StartDate']?.toString() ?? '') ?? DateTime.now(),
      endDate: DateTime.tryParse(json['endDate']?.toString() ?? json['EndDate']?.toString() ?? '') ?? DateTime.now(),
      usageLimit: json['usageLimit'] ?? json['UsageLimit'] ?? 0,
      usedCount: json['usedCount'] ?? json['UsedCount'] ?? 0,
      isActive: json['isActive'] ?? json['IsActive'] ?? false,
      branchId: json['branchId'] ?? json['BranchId'],
      description: json['description'] ?? json['Description'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'campaignId': campaignId,
      'code': code,
      'discountType': discountType,
      'discountValue': discountValue,
      'maxDiscountAmount': maxDiscountAmount,
      'minOrderValue': minOrderValue,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'usageLimit': usageLimit,
      'usedCount': usedCount,
      'isActive': isActive,
      'branchId': branchId,
      'description': description,
    };
  }
}
