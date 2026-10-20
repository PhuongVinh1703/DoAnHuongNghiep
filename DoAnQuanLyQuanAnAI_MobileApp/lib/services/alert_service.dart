import 'dart:convert';
import 'package:doanquanlyquananai_mobileapp/core/network/api_response.dart';
import 'package:doanquanlyquananai_mobileapp/core/storage/secure_storage.dart';
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

  static String _mapAlertTypeToClassName(int alertType) {
    switch (alertType) {
      case 0:
        return 'CancelAfterPayment';
      case 2:
        return 'ExcessiveDiscount';
      case 3:
        return 'UnusualHours';
      case 4:
        return 'FrequentCancellation';
      case 5:
        return 'SpeedAnomaly';
      case 6:
        return 'AddRemoveAnomaly';
      default:
        return 'SpeedAnomaly';
    }
  }

  Future<ApiResult<List<Alert>>> getAlerts({
    bool? resolved,
    int? severity,
    int? alertType,
    int? accountId,
    int page = 1,
  }) async {
    try {
      var query = _db.from('Alerts').select(
          '*, Accounts(FullName), Orders(TableId, DiningTables(BranchId, TableName, Branches(BranchId, Name)))');

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

      final res =
          await query.order('CreatedAt', ascending: false).range(from, to);
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
          .select(
              '*, Accounts(FullName), Orders(TableId, DiningTables(BranchId, TableName, Branches(BranchId, Name)))')
          .eq('AlertId', id)
          .single();
      return ApiResult.success(Alert.fromJson(res));
    } catch (e) {
      return ApiResult.failure('Không tìm thấy cảnh báo: $e');
    }
  }

  Future<ApiResult<void>> resolveAlert(int id, {String? note}) async {
    try {
      final userIdStr = await SecureStorage.getUserId();
      final resolvedBy = userIdStr != null ? int.tryParse(userIdStr) : null;
      final updateData = <String, dynamic>{
        'IsResolved': true,
        'ResolvedNote': note,
        'ResolvedAt': DateTime.now().toIso8601String(),
      };
      if (resolvedBy != null) {
        updateData['ResolvedBy'] = resolvedBy;
      }

      await _db.from('Alerts').update(updateData).eq('AlertId', id);
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
      // 1. Cập nhật note vào cảnh báo nếu có
      if (note != null && note.isNotEmpty) {
        await _db.from('Alerts').update({
          'ResolvedNote': note,
        }).eq('AlertId', alertId);
      }

      // 2. Lấy dữ liệu cảnh báo để gửi đúng 9 features và tên lớp chuẩn sang Flask AI
      final alertRes = await _db
          .from('Alerts')
          .select('AnomalyScore, AlertType, Detail, CreatedAt')
          .eq('AlertId', alertId)
          .single();

      final alertType = (alertRes['AlertType'] as num? ?? 1).toInt();
      final createdAt = DateTime.tryParse(alertRes['CreatedAt']?.toString() ?? '') ??
          DateTime.now();

      // Khởi tạo 9 features mặc định khớp với FEATURES trong predict_api.py
      Map<String, dynamic> features = {
        'session_duration': alertType == 5 ? 45.0 : 900.0,
        'num_items_ordered': 3,
        'cancel_rate': alertType == 4 ? 0.6 : 0.05,
        'transaction_hour': createdAt.hour.toDouble(),
        'checkout_time_sec': alertType == 5 ? 30.0 : 180.0,
        'void_count': alertType == 4 ? 6 : 0,
        'discount_percent': alertType == 2 ? 35.0 : 0.0,
        'add_remove_ratio': alertType == 6 ? 0.8 : 0.1,
        'items_removed_after_confirm': alertType == 0 ? 2 : 0,
      };

      // Nếu Detail có lưu JSON features lúc checkout thì khôi phục chính xác 9 features gốc
      final detailStr = alertRes['Detail']?.toString();
      if (detailStr != null && detailStr.trim().startsWith('{')) {
        try {
          final parsed = jsonDecode(detailStr) as Map<String, dynamic>;
          if (parsed['features'] is Map<String, dynamic>) {
            final savedFeatures = parsed['features'] as Map<String, dynamic>;
            for (final key in features.keys) {
              if (savedFeatures.containsKey(key)) {
                features[key] = savedFeatures[key];
              }
            }
          }
        } catch (_) {}
      }

      final payload = {
        'features': features,
        'actual_label': isFalsePositive ? 0 : 1,
        'actual_type':
            isFalsePositive ? 'Normal' : _mapAlertTypeToClassName(alertType),
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
