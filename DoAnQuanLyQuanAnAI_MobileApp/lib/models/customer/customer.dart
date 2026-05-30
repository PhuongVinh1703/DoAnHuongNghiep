class Customer {
  final int customerId;
  final String fullName;
  final String phone;
  final String? email;
  final String? serialCode;
  final int points;
  final int tier; // 0=Bronze, 1=Silver, 2=Gold
  final bool isActive;

  int get totalPoints => points;  // alias

  String get tierDisplay {
    if (tier == 1) return 'Silver';
    if (tier == 2) return 'Gold';
    return 'Bronze';
  }

  String get tierColor {
    if (tier == 1) return '#C0C0C0';
    if (tier == 2) return '#FFD700';
    return '#CD7F32';
  }

  Customer({
    required this.customerId,
    required this.fullName,
    required this.phone,
    this.email,
    this.serialCode,
    required this.points,
    required this.tier,
    this.isActive = true,
  });

  factory Customer.fromJson(Map<String, dynamic> json) {
    return Customer(
      customerId: json['customerId'] ?? json['CustomerId'] ?? 0,
      fullName:   json['fullName']   ?? json['FullName']   ?? '',
      phone:      json['phone']      ?? json['Phone']      ?? '',
      email:      json['email']      ?? json['Email'],
      serialCode: json['serialCode'] ?? json['SerialCode'],
      points:     json['loyaltyPoints'] ?? json['LoyaltyPoints'] ?? 
                  json['points']        ?? json['Points']        ?? 
                  json['totalPoints']   ?? 0,
      tier:       json['tier']       ?? json['Tier']       ?? 0,
      isActive:   json['isActive']   ?? json['IsActive']   ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'customerId': customerId,
      'fullName': fullName,
      'phone': phone,
      'serialCode': serialCode,
      'points': points,
      'tier': tier,
      'isActive': isActive,
    };
  }
}
