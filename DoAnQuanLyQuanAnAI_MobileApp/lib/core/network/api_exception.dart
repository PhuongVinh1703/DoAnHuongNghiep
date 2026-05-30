import 'package:dio/dio.dart';

class ApiException implements Exception {
  final int statusCode;
  final String message;
  final dynamic data;

  const ApiException({
    required this.statusCode,
    required this.message,
    this.data,
  });

  factory ApiException.fromDioException(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const ApiException(
          statusCode: 408,
          message: 'Kết nối quá thời gian. Vui lòng thử lại.',
        );
      case DioExceptionType.connectionError:
        return const ApiException(
          statusCode: 503,
          message: 'Không thể kết nối máy chủ. Kiểm tra kết nối mạng.',
        );
      case DioExceptionType.badResponse:
        return ApiException._fromResponse(e.response);
      case DioExceptionType.cancel:
        return const ApiException(statusCode: 0, message: 'Yêu cầu đã bị huỷ.');
      default:
        return ApiException(
          statusCode: 0,
          message: e.message ?? 'Đã có lỗi không xác định.',
        );
    }
  }

  factory ApiException._fromResponse(Response? response) {
    final int code = response?.statusCode ?? 0;
    final data = response?.data;
    String message;

    if (data is Map && data.containsKey('message')) {
      message = data['message'].toString();
    } else {
      switch (code) {
        case 400: message = 'Dữ liệu không hợp lệ.'; break;
        case 401: message = 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.'; break;
        case 403: message = 'Bạn không có quyền thực hiện thao tác này.'; break;
        case 404: message = 'Không tìm thấy dữ liệu.'; break;
        case 409: message = 'Xung đột dữ liệu. Vui lòng thử lại.'; break;
        case 422: message = 'Dữ liệu không hợp lệ.'; break;
        case 500: message = 'Lỗi máy chủ nội bộ. Vui lòng thử lại sau.'; break;
        default:  message = 'Lỗi không xác định ($code).';
      }
    }

    return ApiException(statusCode: code, message: message, data: data);
  }

  bool get isUnauthorized   => statusCode == 401;
  bool get isForbidden      => statusCode == 403;
  bool get isNotFound       => statusCode == 404;
  bool get isServerError    => statusCode >= 500;
  bool get isNetworkError   => statusCode == 503 || statusCode == 408;

  @override
  String toString() => 'ApiException($statusCode): $message';
}
