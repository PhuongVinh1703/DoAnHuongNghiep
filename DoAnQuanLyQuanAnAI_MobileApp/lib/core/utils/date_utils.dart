import 'package:intl/intl.dart';

class AppDateUtils {
  static final DateFormat _dateFormat     = DateFormat('dd/MM/yyyy', 'vi_VN');
  static final DateFormat _timeFormat     = DateFormat('HH:mm', 'vi_VN');
  static final DateFormat _dateTimeFormat = DateFormat('dd/MM/yyyy HH:mm', 'vi_VN');
  static final DateFormat _apiFormat      = DateFormat("yyyy-MM-dd'T'HH:mm:ss");

  /// "dd/MM/yyyy"
  static String formatDate(DateTime dt) => _dateFormat.format(dt);

  /// "HH:mm"
  static String formatTime(DateTime dt) => _timeFormat.format(dt);

  /// "dd/MM/yyyy HH:mm"
  static String formatDateTime(DateTime dt) => _dateTimeFormat.format(dt);

  /// ISO 8601 cho API
  static String toApiString(DateTime dt) => _apiFormat.format(dt);

  /// Parse chuỗi ISO 8601 về DateTime, trả null nếu lỗi
  static DateTime? tryParse(String? s) {
    if (s == null || s.isEmpty) return null;
    try { return DateTime.parse(s); } catch (_) { return null; }
  }

  /// Thời gian tương đối: "5 phút trước", "2 giờ trước"...
  static String timeAgo(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inSeconds < 60)  return 'Vừa xong';
    if (diff.inMinutes < 60)  return '${diff.inMinutes} phút trước';
    if (diff.inHours < 24)    return '${diff.inHours} giờ trước';
    if (diff.inDays < 7)      return '${diff.inDays} ngày trước';
    return formatDate(dt);
  }

  /// Thời gian còn lại cho đặt bàn
  static String timeUntil(DateTime dt) {
    final now = DateTime.now();
    final diff = dt.difference(now);
    if (diff.isNegative) return 'Đã qua';
    if (diff.inMinutes < 60)  return 'Còn ${diff.inMinutes} phút';
    if (diff.inHours < 24)    return 'Còn ${diff.inHours} giờ';
    return 'Còn ${diff.inDays} ngày';
  }

  /// Kiểm tra đặt bàn hợp lệ (phải ≥ 30 phút từ bây giờ)
  static bool isValidReservationTime(DateTime dt) {
    return dt.isAfter(DateTime.now().add(const Duration(minutes: 30)));
  }

  /// Tính thời gian phiên làm việc (giây)
  static double sessionSeconds(DateTime start) =>
      DateTime.now().difference(start).inSeconds.toDouble();

  /// Start/end của ngày hôm nay cho query API
  static String todayStart() => '${DateFormat('yyyy-MM-dd').format(DateTime.now())}T00:00:00';
  static String todayEnd()   => '${DateFormat('yyyy-MM-dd').format(DateTime.now())}T23:59:59';

  /// Khoảng ngày tuần này
  static DateTime get weekStart {
    final now = DateTime.now();
    return now.subtract(Duration(days: now.weekday - 1));
  }

  /// Format khoảng thời gian cho label biểu đồ
  static String shortDate(DateTime dt) => DateFormat('dd/MM').format(dt);
}
