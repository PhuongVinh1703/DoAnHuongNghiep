import 'package:flutter/material.dart';

class AppLocalizations {
  final Locale locale;
  AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  static const List<Locale> supportedLocales = [
    Locale('vi'),
    Locale('en'),
  ];

  bool get isVietnamese => locale.languageCode == 'vi';

  // ── Translations Map ──────────────────────────────────
  static final Map<String, Map<String, String>> _localizedValues = {
    // ── Common ──────────────────────────────────────────
    'app_name': {'vi': 'Reserve & Relish', 'en': 'Reserve & Relish'},
    'app_tagline': {'vi': 'Quản lý nhà hàng thông minh', 'en': 'Smart Restaurant Management'},
    'cancel': {'vi': 'Hủy', 'en': 'Cancel'},
    'confirm': {'vi': 'Xác nhận', 'en': 'Confirm'},
    'save': {'vi': 'Lưu', 'en': 'Save'},
    'delete': {'vi': 'Xóa', 'en': 'Delete'},
    'search': {'vi': 'Tìm kiếm', 'en': 'Search'},
    'search_menu': {'vi': 'Tìm kiếm', 'en': 'Search menu'},
    'loading': {'vi': 'Đang tải...', 'en': 'Loading...'},
    'error': {'vi': 'Lỗi', 'en': 'Error'},
    'success': {'vi': 'Thành công', 'en': 'Success'},
    'or': {'vi': 'hoặc', 'en': 'or'},

    // ── Auth / Login ────────────────────────────────────
    'system_auth': {'vi': 'Xác thực hệ thống', 'en': 'System Authentication'},
    'username': {'vi': 'Tên đăng nhập', 'en': 'Username'},
    'password': {'vi': 'Mật khẩu', 'en': 'Password'},
    'sign_in': {'vi': 'Đăng nhập', 'en': 'Sign In'},
    'forgot': {'vi': 'Quên mật khẩu?', 'en': 'Forgot?'},
    'ai_face_login': {'vi': 'Đăng nhập bằng khuôn mặt AI', 'en': 'AI Face Login'},
    'new_to_app': {'vi': 'Chưa có tài khoản? ', 'en': 'New to Reserve & Relish? '},
    'register_here': {'vi': 'Đăng ký tại đây', 'en': 'Register here'},
    'login_failed': {'vi': 'Đăng nhập thất bại', 'en': 'Login failed'},
    'username_required': {'vi': 'Vui lòng nhập tên đăng nhập', 'en': 'Please enter username'},
    'password_required': {'vi': 'Vui lòng nhập mật khẩu', 'en': 'Please enter password'},
    'connection_error': {'vi': 'Không thể kết nối đến máy chủ. Vui lòng kiểm tra kết nối.', 'en': 'Cannot connect to server. Please check your connection.'},

    // ── Register ────────────────────────────────────────
    'create_account': {'vi': 'Tạo tài khoản', 'en': 'Create Account'},
    'create_guest_account': {'vi': 'Tạo tài khoản khách', 'en': 'Create your guest account'},
    'full_name': {'vi': 'Họ và tên', 'en': 'Full name'},
    'email_optional': {'vi': 'Email (không bắt buộc)', 'en': 'Email (optional)'},
    'phone_number': {'vi': 'Số điện thoại', 'en': 'Phone number'},
    'confirm_password': {'vi': 'Xác nhận mật khẩu', 'en': 'Confirm password'},
    'name_required': {'vi': 'Vui lòng nhập họ tên', 'en': 'Please enter your name'},
    'password_min': {'vi': 'Mật khẩu tối thiểu 6 ký tự', 'en': 'Password must be at least 6 characters'},
    'password_mismatch': {'vi': 'Mật khẩu không khớp', 'en': 'Passwords do not match'},
    'already_guest': {'vi': 'Đã có tài khoản? ', 'en': 'Already a guest? '},
    'log_in': {'vi': 'Đăng nhập', 'en': 'Log In'},
    'register_developing': {'vi': 'Chức năng đăng ký đang phát triển', 'en': 'Registration is under development'},

    // ── Staff / Tables ──────────────────────────────────
    'floor_plan': {'vi': 'Sơ đồ tầng', 'en': 'Floor Plan'},
    'tables': {'vi': 'Bàn', 'en': 'Tables'},
    'orders': {'vi': 'Đơn hàng', 'en': 'Orders'},
    'insights': {'vi': 'Thống kê', 'en': 'Insights'},
    'profile': {'vi': 'Hồ sơ', 'en': 'Profile'},
    'all': {'vi': 'Tất cả', 'en': 'All'},
    'available': {'vi': 'Trống', 'en': 'Available'},
    'occupied': {'vi': 'Đang sử dụng', 'en': 'Occupied'},
    'reserved': {'vi': 'Đã đặt', 'en': 'Reserved'},
    'seats': {'vi': 'chỗ', 'en': 'seats'},

    // ── Orders ──────────────────────────────────────────
    'search_orders': {'vi': 'Tìm đơn hàng...', 'en': 'Search orders...'},
    'items': {'vi': 'món', 'en': 'items'},
    'paid': {'vi': 'Đã thanh toán', 'en': 'Paid'},
    'pending': {'vi': 'Chờ xử lý', 'en': 'Pending'},
    'draft': {'vi': 'Nháp', 'en': 'Draft'},

    // ── Menu ────────────────────────────────────────────
    'menu': {'vi': 'Thực đơn', 'en': 'Menu'},
    'main_course': {'vi': 'Món chính', 'en': 'Main Course'},
    'seafood': {'vi': 'Hải sản', 'en': 'Seafood'},
    'appetizer': {'vi': 'Khai vị', 'en': 'Appetizer'},
    'dessert': {'vi': 'Tráng miệng', 'en': 'Dessert'},
    'drinks': {'vi': 'Đồ uống', 'en': 'Drinks'},
    'popular': {'vi': 'Phổ biến', 'en': 'Popular'},

    // ── Profile ─────────────────────────────────────────
    'edit_profile': {'vi': 'Chỉnh sửa hồ sơ', 'en': 'Edit Profile'},
    'update_info': {'vi': 'Cập nhật thông tin cá nhân', 'en': 'Update your personal information'},
    'change_password': {'vi': 'Đổi mật khẩu', 'en': 'Change Password'},
    'update_credentials': {'vi': 'Cập nhật thông tin bảo mật', 'en': 'Update security credentials'},
    'notifications': {'vi': 'Thông báo', 'en': 'Notifications'},
    'manage_preferences': {'vi': 'Quản lý tùy chọn thông báo', 'en': 'Manage notification preferences'},
    'activity_log': {'vi': 'Nhật ký hoạt động', 'en': 'Activity Log'},
    'recent_activities': {'vi': 'Xem hoạt động gần đây', 'en': 'View recent activities'},
    'language': {'vi': 'Ngôn ngữ', 'en': 'Language'},
    'language_subtitle': {'vi': 'Tiếng Việt / English', 'en': 'Vietnamese / English'},
    'log_out': {'vi': 'Đăng xuất', 'en': 'Log Out'},
    'logout_confirm': {'vi': 'Bạn có chắc chắn muốn đăng xuất?', 'en': 'Are you sure you want to log out?'},
    'owner': {'vi': 'Chủ sở hữu', 'en': 'Owner'},
    'manager': {'vi': 'Quản lý', 'en': 'Manager'},
    'staff': {'vi': 'Nhân viên', 'en': 'Staff'},
    'guest': {'vi': 'Khách', 'en': 'Guest'},

    // ── Manager Dashboard ───────────────────────────────
    'admin_console': {'vi': 'Bảng điều khiển', 'en': 'Admin Console'},
    'dashboard_overview': {'vi': 'Tổng quan Dashboard', 'en': 'Dashboard Overview'},
    'realtime_metrics': {'vi': 'Số liệu thời gian thực cho ca hiện tại.', 'en': 'Real-time metrics for current shift.'},
    'menu_editor': {'vi': 'Quản lý thực đơn', 'en': 'Menu Editor'},
    'staff_registry': {'vi': 'Quản lý nhân viên', 'en': 'Staff Registry'},
    'fraud_alerts': {'vi': 'Cảnh báo gian lận', 'en': 'Fraud Alerts'},
    'inventory': {'vi': 'Kho hàng', 'en': 'Inventory'},
    'revenue': {'vi': 'Doanh thu', 'en': 'Revenue'},
    'avg_order': {'vi': 'TB đơn hàng', 'en': 'Avg. Order'},
    'cancels': {'vi': 'Hủy đơn', 'en': 'Cancels'},
    'action_required': {'vi': 'Cần xử lý', 'en': 'Action Required'},
    'inventory_anomaly': {'vi': 'Phát hiện bất thường kho rượu cao cấp. Xem đề xuất nhập hàng.', 'en': 'Inventory anomalies detected in premium wines. Review suggested restock.'},
    'top_selling': {'vi': 'Món bán chạy', 'en': 'Top Selling Items'},

    // ── AI Alerts ───────────────────────────────────────
    'ai_fraud_alerts': {'vi': 'Cảnh báo gian lận AI', 'en': 'AI Fraud Alerts'},
    'high_risk': {'vi': 'Rủi ro cao', 'en': 'High Risk'},
    'medium': {'vi': 'Trung bình', 'en': 'Medium'},
    'low': {'vi': 'Thấp', 'en': 'Low'},
    'ai_score': {'vi': 'Điểm AI', 'en': 'AI Score'},
    'ai_confidence': {'vi': 'Độ tin cậy AI', 'en': 'AI Confidence'},
    'new_alerts': {'vi': 'mới', 'en': 'new'},

    // ── Reservations ────────────────────────────────────
    'reservations': {'vi': 'Đặt bàn', 'en': 'Reservations'},
    'new_booking': {'vi': 'Đặt mới', 'en': 'New Booking'},
    'confirmed': {'vi': 'Đã xác nhận', 'en': 'Confirmed'},
    'guests': {'vi': 'khách', 'en': 'guests'},
    'today': {'vi': 'Hôm nay', 'en': 'Today'},
    'tomorrow': {'vi': 'Ngày mai', 'en': 'Tomorrow'},
    'call': {'vi': 'Gọi', 'en': 'Call'},
    'seat': {'vi': 'Xếp chỗ', 'en': 'Seat'},
    'no_reservations': {'vi': 'Không có đặt bàn', 'en': 'No reservations'},

    // ── Customer Home ───────────────────────────────────
    'good_evening': {'vi': 'Chào buổi tối', 'en': 'Good Evening'},
    'good_morning': {'vi': 'Chào buổi sáng', 'en': 'Good Morning'},
    'good_afternoon': {'vi': 'Chào buổi chiều', 'en': 'Good Afternoon'},
    'membership': {'vi': 'Thành viên', 'en': 'Membership'},
    'gold_member': {'vi': 'Thành viên Vàng', 'en': 'Gold Member'},
    'scan_checkout': {'vi': 'Quét tại quầy', 'en': 'Scan at Checkout'},
    'show_member_code': {'vi': 'Nhấn để hiện mã thành viên', 'en': 'Tap to show your member code'},
    'quick_actions': {'vi': 'Thao tác nhanh', 'en': 'Quick Actions'},
    'reserve': {'vi': 'Đặt bàn', 'en': 'Reserve'},
    'vouchers': {'vi': 'Ưu đãi', 'en': 'Vouchers'},
    'home': {'vi': 'Trang chủ', 'en': 'Home'},
    'new_seasonal_menu': {'vi': 'Thực đơn mùa mới', 'en': 'New Seasonal Menu'},

    // ── Voucher & Loyalty ───────────────────────────────
    'vouchers_loyalty': {'vi': 'Ưu đãi & Tích điểm', 'en': 'Vouchers & Loyalty'},
    'your_points': {'vi': 'Điểm của bạn', 'en': 'Your Points'},
    'rewards': {'vi': 'Phần thưởng', 'en': 'Rewards'},
    'redeem': {'vi': 'Đổi thưởng', 'en': 'Redeem'},
    'used': {'vi': 'Đã dùng', 'en': 'Used'},
    'expires': {'vi': 'Hết hạn', 'en': 'Expires'},
    'min_order': {'vi': 'Đơn tối thiểu', 'en': 'Min. order'},

    // ── QR Membership ───────────────────────────────────
    'membership_card': {'vi': 'Thẻ thành viên', 'en': 'Membership Card'},
    'member_since': {'vi': 'Thành viên từ', 'en': 'Member since'},
    'earn_points': {'vi': 'Tích điểm mỗi lần dùng bữa', 'en': 'Earn points every time you dine'},
    'progress_platinum': {'vi': 'Tiến tới Bạch Kim', 'en': 'Progress to Platinum'},
    'member_benefits': {'vi': 'Quyền lợi thành viên', 'en': 'Member Benefits'},
    'all_orders': {'vi': 'Tất cả đơn', 'en': 'All orders'},
    'birthday_gift': {'vi': 'Quà sinh nhật', 'en': 'Birthday Gift'},
    'free_dessert': {'vi': 'Tráng miệng miễn phí', 'en': 'Free dessert'},
    'priority_seating': {'vi': 'Ưu tiên chỗ ngồi', 'en': 'Priority Seating'},
    'skip_queue': {'vi': 'Không cần xếp hàng', 'en': 'Skip the queue'},
    'exclusive_deals': {'vi': 'Ưu đãi độc quyền', 'en': 'Exclusive Deals'},
    'members_only': {'vi': 'Chỉ dành cho thành viên', 'en': 'Members only'},

    // ── Settings ────────────────────────────────────────
    'settings': {'vi': 'Cài đặt', 'en': 'Settings'},
    'select_language': {'vi': 'Chọn ngôn ngữ', 'en': 'Select Language'},
    'vietnamese': {'vi': 'Tiếng Việt', 'en': 'Vietnamese'},
    'english': {'vi': 'Tiếng Anh', 'en': 'English'},
  };

  String translate(String key) {
    return _localizedValues[key]?[locale.languageCode] ?? _localizedValues[key]?['en'] ?? key;
  }
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => ['vi', 'en'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async => AppLocalizations(locale);

  @override
  bool shouldReload(covariant LocalizationsDelegate<AppLocalizations> old) => false;
}
