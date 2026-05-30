class ApiConstants {
  // Development — Android emulator (Use HTTPS to avoid localhost redirect loop)
  static const String emulator  = 'https://10.0.2.2:7206/api';
  
  // Development — điện thoại thật (thay IP máy tính: 192.168.123.5)
  static const String device    = 'https://192.168.123.5:7206/api';
  
  // Production
  static const String prod      = 'https://your-domain.com/api';
  
  // CHÚ Ý: 
  // - Nếu dùng Android Emulator: chọn 'emulator' (10.0.2.2)
  // - Nếu dùng điện thoại thật: chọn 'device' (192.168.123.5)
  // - Nếu dùng Flutter Web / Windows Desktop: dùng 'https://localhost:7206/api'
  static const String baseUrl = emulator; 
  
  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 15);
}
