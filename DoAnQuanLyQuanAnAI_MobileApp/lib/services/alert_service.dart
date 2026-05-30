import 'package:doanquanlyquananai_mobileapp/core/network/api_response.dart';
import 'package:doanquanlyquananai_mobileapp/models/alert/alert.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dio/dio.dart';

class AlertService {
  final _db = Supabase.instance.client;
  final _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 4),
    receiveTimeout: const Duration(seconds: 4),
  ));

  String get _aiBaseUrl {
    return 'https://module-ai-myproject.onrender.com';
  }

  Future<ApiResult<List<Alert>>> getAlerts({
    bool? resolved,
    int? severity,
    int? alertType,
    int? accountId,
    int page = 1,
  }) async {
    try {
      var query = _db.from('Alerts').select('*, Accounts(FullName), Orders(TableId, DiningTables(BranchId, TableName, Branches(BranchId, Name)))');
      
      if (resolved != null) {
        query = query.eq('IsResolved', resolved);
      }
      if (severity != null) {
        query = query.eq('Severity', severity);
      }
      if (alertType != null) {
        query = query.eq('AlertType', alertType);
      }
      if (accountId != null) {
        query = query.eq('AccountId', accountId);
      }

      final pageSize = 20;
      final from = (page - 1) * pageSize;
      final to = from + pageSize - 1;
      
      final res = await query.order('CreatedAt', ascending: false).range(from, to);
      final list = (res as List).map((e) => Alert.fromJson(e)).toList();
      return ApiResult.success(list);
    } catch (e) {
      return ApiResult.failure('Lỗi lấy danh sách cảnh báo: $e');
    }
  }

  Future<ApiResult<Alert>> getById(int id) async {
    try {
      final res = await _db
          .from('Alerts')
          .select('*, Accounts(FullName), Orders(TableId, DiningTables(BranchId, TableName, Branches(BranchId, Name)))')
          .eq('AlertId', id)
          .single();
      return ApiResult.success(Alert.fromJson(res));
    } catch (e) {
      return ApiResult.failure('Không tìm thấy cảnh báo: $e');
    }
  }

  Future<ApiResult<void>> resolveAlert(int id, {String? note}) async {
    try {
      await _db.from('Alerts').update({
        'IsResolved': true,
        'ResolvedNote': note,
        'ResolvedAt': DateTime.now().toIso8601String(),
      }).eq('AlertId', id);
      return ApiResult.success(null);
    } catch (e) {
      return ApiResult.failure('Lỗi xử lý cảnh báo: $e');
    }
  }

  Future<ApiResult<void>> sendFeedback({
    required int alertId,
    required bool isFalsePositive,
    String? note,
  }) async {
    try {
      // 1. Cập nhật note vào hóa đơn/cảnh báo nếu cần
      if (note != null && note.isNotEmpty) {
        await _db.from('Alerts').update({
          'ResolvedNote': note,
        }).eq('AlertId', alertId);
      }

      // 2. Gửi phản hồi sang Flask AI microservice
      final alertRes = await _db.from('Alerts').select('AnomalyScore, AlertType').eq('AlertId', alertId).single();
      final anomalyScore = (alertRes['AnomalyScore'] as num).toDouble();
      final alertType = alertRes['AlertType'] as int;

      final payload = {
        'features': {
          'anomaly_score': anomalyScore,
          'alert_type': alertType.toDouble(),
        },
        'actual_label': isFalsePositive ? 0 : 1, // 0 = False positive (bình thường), 1 = True positive (gian lận thật)
        'actual_type': isFalsePositive ? 'Normal' : 'Anomaly',
      };

      final res = await _dio.post('$_aiBaseUrl/feedback', data: payload);
      if (res.statusCode == 200) {
        return ApiResult.success(null);
      } else {
        return ApiResult.failure('AI service trả về mã lỗi: ${res.statusCode}');
      }
    } catch (e) {
      return ApiResult.failure('Không thể gửi phản hồi cho AI: $e');
    }
  }

  Future<ApiResult<void>> triggerRetrain() async {
    try {
      final res = await _dio.post('$_aiBaseUrl/retrain');
      if (res.statusCode == 200) {
        return ApiResult.success(null);
      } else {
        return ApiResult.failure('Không thể huấn luyện lại: ${res.statusCode}');
      }
    } catch (e) {
      return ApiResult.failure('Lỗi kết nối AI service: $e');
    }
  }

  Future<ApiResult<Map<String, dynamic>>> getRetrainStatus() async {
    try {
      final res = await _dio.get('$_aiBaseUrl/retrain/status');
      if (res.statusCode == 200) {
        return ApiResult.success(res.data as Map<String, dynamic>);
      } else {
        return ApiResult.failure('Lỗi lấy trạng thái AI: ${res.statusCode}');
      }
    } catch (e) {
      return ApiResult.failure('Lỗi kết nối AI service: $e');
    }
  }

  Future<ApiResult<bool>> checkAiHealth() async {
    try {
      final res = await _dio.get('$_aiBaseUrl/health');
      final ok = res.statusCode == 200;
      return ApiResult.success(ok);
    } catch (e) {
      return ApiResult.success(false); // Offline
    }
  }
}
