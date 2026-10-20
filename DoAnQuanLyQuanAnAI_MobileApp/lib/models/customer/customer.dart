class Customer {
  final int customerId;
  final String fullName;
  final String phone;
  final String? email;
  final String? serialCode;
  final int points;
  final int tier; // 0=Bronze, 1=Silver, 2=Gold, 3=Platinum/VIP, 4=Diamond
  final bool isActive;

  int get totalPoints => points; // alias

  /// Tính hạng thành viên tự động dựa trên tổng điểm tích lũy
  static int calculateTier(int points) {
    if (points >= 2000) return 4; // Kim Cương / Diamond
    if (points >= 1000) return 3; // Bạch Kim / VIP
    if (points >= 500) return 2;  // Vàng / Gold
    if (points >= 100) return 1;  // Bạc / Silver
    return 0;                     // Đồng / Bronze
  }

  String get tierDisplay {
    switch (tier) {
      case 1:
        return 'Silver';
      case 2:
        return 'Gold';
      case 3:
        return 'Platinum';
      case 4:
        return 'Diamond';
      default:
        return 'Bronze';
    }
  }

  String get tierColor {
    switch (tier) {
      case 1:
        return '#C0C0C0';
      case 2:
        return '#FFD700';
      case 3:
        return '#00BCD4';
      case 4:
        return '#7C4DFF';
      default:
        return '#CD7F32';
    }
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
    final parsedPoints = json['loyaltyPoints'] ??
        json['LoyaltyPoints'] ??
        json['points'] ??
        json['Points'] ??
        json['totalPoints'] ??
        0;
    final rawTier = json['tier'] ?? json['Tier'];
    return Customer(
      customerId: json['customerId'] ?? json['CustomerId'] ?? 0,
      fullName: json['fullName'] ?? json['FullName'] ?? '',
      phone: json['phone'] ?? json['Phone'] ?? '',
      email: json['email'] ?? json['Email'],
      serialCode: json['serialCode'] ?? json['SerialCode'],
      points: parsedPoints,
      tier: rawTier ?? calculateTier(parsedPoints as int),
      isActive: json['isActive'] ?? json['IsActive'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'customerId': customerId,
      'fullName': fullName,
      'phone': phone,
      'email': email,
      'serialCode': serialCode,
      'points': points,
      'tier': tier,
      'isActive': isActive,
    };
  }
}
