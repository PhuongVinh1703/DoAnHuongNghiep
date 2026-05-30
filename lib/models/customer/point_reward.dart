class PointReward {
  final int rewardId;
  final String name;
  final String description;
  final int pointCost;
  final double discountPercent;
  final double minOrderAmount;
  final int validDays;
  final bool isActive;
  final String emoji;

  PointReward({
    required this.rewardId,
    required this.name,
    required this.description,
    required this.pointCost,
    required this.discountPercent,
    required this.minOrderAmount,
    required this.validDays,
    required this.isActive,
    required this.emoji,
  });

  factory PointReward.fromJson(Map<String, dynamic> json) {
    return PointReward(
      rewardId:        json['rewardId']        ?? json['RewardId']        ?? 0,
      name:            json['name']            ?? json['Name']            ?? '',
      description:     json['description']     ?? json['Description']     ?? '',
      pointCost:       json['pointCost']       ?? json['PointCost']       ?? 0,
      discountPercent: (json['discountPercent'] ?? json['DiscountPercent'] ?? 0).toDouble(),
      minOrderAmount:  (json['minOrderAmount']  ?? json['MinOrderAmount']  ?? 0).toDouble(),
      validDays:       json['validDays']       ?? json['ValidDays']       ?? 7,
      isActive:        json['isActive']        ?? json['IsActive']        ?? true,
      emoji:           json['emoji']           ?? json['Emoji']           ?? '🎁',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'rewardId': rewardId,
      'name': name,
      'description': description,
      'pointCost': pointCost,
      'discountPercent': discountPercent,
      'minOrderAmount': minOrderAmount,
      'validDays': validDays,
      'isActive': isActive,
      'emoji': emoji,
    };
  }
}
