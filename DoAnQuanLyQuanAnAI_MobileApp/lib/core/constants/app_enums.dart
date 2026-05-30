// Role (trong JWT claims)
class Role {
  static const int owner   = 0;
  static const int manager = 1;
  static const int staff   = 2;
  // LƯU Ý: Customer là entity riêng, KHÔNG có tài khoản đăng nhập qua JWT
}

// Table Status
class TableStatus {
  static const int available = 0;
  static const int occupied  = 1;
  static const int reserved  = 2;
}

// Order Status
class OrderStatus {
  static const int open      = 0;
  static const int paid      = 1;
  static const int cancelled = 2;
}

// Payment Method
class PaymentMethod {
  static const int cash = 0;
  static const int card = 1;
  static const int qr   = 2;
}

// Reservation Status
class ReservationStatus {
  static const int pending   = 0;
  static const int confirmed = 1;
  static const int rejected  = 2;
  static const int cancelled = 3;
}

// Alert Type (theo code thực tế)
class AlertType {
  static const int anomalyTransaction = 1;
  static const int highDiscount       = 2;
  static const int voidAbuse          = 3;
  static const int suspiciousPattern  = 4;
}

// Alert Severity
class AlertSeverity {
  static const int low    = 0;
  static const int medium = 1;
  static const int high   = 2;
}

// Customer Tier
class CustomerTier {
  static const int bronze = 0;
  static const int silver = 1;  // >= 100 điểm
  static const int gold   = 2;  // >= 500 điểm
}

// AI Anomaly Types (từ label_encoder Python)
const anomalyTypes = [
  'CancelAfterPayment',   // Hủy sau khi khách trả tiền
  'ExcessiveDiscount',    // Lạm dụng giảm giá (> 25%)
  'SpeedAnomaly',         // Thanh toán siêu tốc
  'UnusualHours',         // Giao dịch ngoài giờ (0-7h, 23h)
  'FrequentCancellation', // Hủy bill liên tục
  'AddRemoveAnomaly',     // Thêm/xóa món bất thường
];
