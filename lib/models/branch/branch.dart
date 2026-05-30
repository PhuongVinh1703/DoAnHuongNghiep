class Branch {
  final int branchId;
  final String name;
  final String? address;
  final String? phone;
  final bool isActive;

  Branch({
    required this.branchId,
    required this.name,
    this.address,
    this.phone,
    required this.isActive,
  });

  factory Branch.fromJson(Map<String, dynamic> json) {
    return Branch(
      branchId: json['branchId'] ?? json['BranchId'] ?? 0,
      name:     json['name']     ?? json['Name']     ?? '',
      address:  json['address']  ?? json['Address'],
      phone:    json['phone']    ?? json['Phone'],
      isActive: json['isActive'] ?? json['IsActive'] ?? true,
    );
  }
}
