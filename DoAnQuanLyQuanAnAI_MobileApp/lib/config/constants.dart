class AppConstants {
  static const String appName = 'Reserve & Relish';
  static const String appTagline = 'Smart Restaurant Management';
  static const String appVersion = 'v2.4.0-AI';

  // Role constants (matching API: 0=Owner, 1=Staff, 2=Manager, 3=Customer, 4=Cashier, 5=Kitchen)
  static const int roleOwner = 0;
  static const int roleStaff = 1;
  static const int roleManager = 2;
  static const int roleCustomer = 3;
  static const int roleCashier = 4; // Nhân viên Thu ngân tại quầy
  static const int roleKitchen = 5; // Nhân viên Bếp (KDS)

  // Storage keys
  static const String tokenKey = 'auth_token';
  static const String userIdKey = 'user_id';
  static const String userRoleKey = 'user_role';
  static const String userNameKey = 'user_name';
  static const String fullNameKey = 'full_name';
  static const String branchIdKey = 'branch_id';
}
