import '../core/constants/api_constants.dart';

class ApiConfig {
  // Thay đổi baseUrl theo môi trường (sử dụng cấu hình chung từ ApiConstants)
  static const String baseUrl = ApiConstants.baseUrl;

  // Auth endpoints
  static const String login = '$baseUrl/Auth/login';
  static const String changePassword = '$baseUrl/Auth/change-password';

  // Menu endpoints
  static const String menu = '$baseUrl/Menu';
  static const String menuCategories = '$baseUrl/Menu/categories';

  // Order endpoints
  static const String orders = '$baseUrl/Orders';

  // Table endpoints
  static const String tables = '$baseUrl/Tables';

  // Invoice endpoints
  static const String invoices = '$baseUrl/Invoices';

  // Dashboard endpoints
  static const String dashboard = '$baseUrl/Dashboard';

  // Alerts endpoints
  static const String alerts = '$baseUrl/Alerts';

  // Customers endpoints
  static const String customers = '$baseUrl/Customers';

  // Reservations endpoints
  static const String reservations = '$baseUrl/Reservations';

  // Branches endpoints
  static const String branches = '$baseUrl/Branches';
}
