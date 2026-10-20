import 'package:dio/dio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ErrorHandler {
  /// Chuyển đổi mọi loại Exception sang thông báo tiếng Việt thân thiện với người dùng
  static String formatError(Object? error) {
    if (error == null) return 'Đã xảy ra lỗi không xác định.';
    if (error is String) return error;

    if (error is PostgrestException) {
      final msg = error.message;
      if (error.code == '23505') {
        return 'Dữ liệu đã tồn tại (trùng mã hoặc số điện thoại).';
      }
      if (error.code == '23503') {
        return 'Không thể xóa hoặc cập nhật do dữ liệu đang được tham chiếu.';
      }
      return msg.isNotEmpty ? msg : 'Lỗi truy vấn cơ sở dữ liệu (${error.code}).';
    }

    if (error is AuthException) {
      return error.message.isNotEmpty ? error.message : 'Lỗi xác thực tài khoản.';
    }

    if (error is DioException) {
      switch (error.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          return 'Kết nối tới máy chủ quá thời gian chờ. Vui lòng thử lại.';
        case DioExceptionType.connectionError:
          return 'Không thể kết nối mạng tới máy chủ.';
        case DioExceptionType.badResponse:
          final statusCode = error.response?.statusCode;
          final data = error.response?.data;
          if (data is Map && data['message'] != null) {
            return data['message'].toString();
          }
          return 'Máy chủ phản hồi lỗi (Mã: $statusCode).';
        default:
          return error.message ?? 'Lỗi kết nối mạng.';
      }
    }

    if (error is FormatException) {
      return 'Định dạng dữ liệu không hợp lệ: ${error.message}';
    }

    final raw = error.toString();
    if (raw.startsWith('Exception: ')) {
      return raw.substring('Exception: '.length);
    }
    return raw;
  }
}
