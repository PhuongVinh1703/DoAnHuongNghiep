class Reservation {
  final int reservationId;
  final String customerName;
  final String customerPhone;
  final int branchId;
  final String? branchName;
  final int guestCount;
  final DateTime reservedAt;
  final DateTime createdAt;
  final int status; // 0=Pending, 1=Confirmed, 2=Rejected, 3=Cancelled
  final String? note;
  final String? managerNote;
  final int? customerId;

  Reservation({
    required this.reservationId,
    required this.customerName,
    required this.customerPhone,
    required this.branchId,
    this.branchName,
    required this.guestCount,
    required this.reservedAt,
    required this.createdAt,
    required this.status,
    this.note,
    this.managerNote,
    this.customerId,
  });

  factory Reservation.fromJson(Map<String, dynamic> json) {
    return Reservation(
      reservationId: json['reservationId'] ?? json['ReservationId'] ?? 0,
      customerName:  json['customerName'] ?? json['CustomerName'] ?? 
                     (json['Customers'] as Map?)?['FullName'] ?? '',
      customerPhone: json['customerPhone'] ?? json['CustomerPhone'] ?? 
                     (json['Customers'] as Map?)?['Phone'] ?? '',
      branchId:      json['branchId'] ?? json['BranchId'] ?? 0,
      branchName:    json['branchName'] ?? json['BranchName'] ?? 
                     (json['Branches'] as Map?)?['Name'],
      guestCount:    json['guestCount'] ?? json['GuestCount'] ?? 0,
      reservedAt:    DateTime.parse(json['reservedAt'] ?? json['ReservedAt']),
      createdAt:     json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : json['CreatedAt'] != null
              ? DateTime.parse(json['CreatedAt'])
              : DateTime.now(),
      status:        json['status'] ?? json['Status'] ?? 0,
      note:          json['note'] ?? json['Note'],
      managerNote:   json['managerNote'] ?? json['ManagerNote'],
      customerId:    json['customerId'] ?? json['CustomerId'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'reservationId': reservationId,
      'customerName': customerName,
      'customerPhone': customerPhone,
      'branchId': branchId,
      'guestCount': guestCount,
      'reservedAt': reservedAt.toIso8601String(),
      'status': status,
      'note': note,
      'createdAt': createdAt.toIso8601String(),
      'managerNote': managerNote,
      'customerId': customerId,
    };
  }
}
