import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:doanquanlyquananai_mobileapp/core/network/api_response.dart';
import 'package:doanquanlyquananai_mobileapp/core/utils/ai_tracker.dart';
import 'package:doanquanlyquananai_mobileapp/models/invoice/invoice.dart';
import 'package:doanquanlyquananai_mobileapp/models/invoice/checkout_response.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dio/dio.dart';

class InvoiceService {
  final _db = Supabase.instance.client;
  final _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 4),
    receiveTimeout: const Duration(seconds: 4),
  ));

  String get _aiBaseUrl {
    if (kIsWeb) return 'http://localhost:5050';
    try {
      if (Platform.isAndroid) return 'http://10.0.2.2:5050';
    } catch (_) {}
    return 'http://localhost:5050';
  }

  /// Lấy lịch sử hóa đơn của một khách hàng
  Future<ApiResult<List<Invoice>>> getByCustomer(int customerId, {int page = 1}) async {
    try {
      final pageSize = 20;
      final from = (page - 1) * pageSize;
      final to = from + pageSize - 1;
      
      final res = await _db
          .from('Invoices')
          .select('*, DiningTables(TableName), Accounts(FullName)')
          .eq('CustomerId', customerId)
          .order('PaidAt', ascending: false)
          .range(from, to);
          
      final list = (res as List).map((e) => Invoice.fromJson(e)).toList();
      return ApiResult.success(list);
    } catch (e) {
      return ApiResult.failure('Lỗi lấy lịch sử hóa đơn: $e');
    }
  }

  /// Lấy chi tiết một hóa đơn
  Future<ApiResult<Invoice>> getById(int id) async {
    try {
      final res = await _db
          .from('Invoices')
          .select('*, DiningTables(TableName), Accounts(FullName), Customers(FullName), InvoiceItems(*)')
          .eq('InvoiceId', id)
          .single();
      return ApiResult.success(Invoice.fromJson(res));
    } catch (e) {
      return ApiResult.failure('Không tìm thấy hóa đơn: $e');
    }
  }

  /// Thanh toán hóa đơn (gọi RPC checkout_order + phát hiện hành vi gian lận)
  Future<ApiResult<CheckoutResponse>> checkout({
    required int orderId,
    required int accountId,
    required int tableId,
    required int paymentMethod,
    required AiTracker tracker,
    int? customerId,
    String? voucherCode,
    String? discountCampaignCode,
    double vatPercent = 8.0,
  }) async {
    try {
      // 1. Lấy thông tin order mở trước để làm dữ liệu đầu vào cho AI
      DateTime openedAt = DateTime.now();
      int numItemsOrdered = 0;
      try {
        final orderInfo = await _db
            .from('Orders')
            .select('OpenedAt, OrderItems(Quantity)')
            .eq('OrderId', orderId)
            .eq('Status', 0)
            .maybeSingle();
            
        if (orderInfo != null) {
          openedAt = DateTime.parse(orderInfo['OpenedAt'] ?? DateTime.now().toIso8601String());
          final items = orderInfo['OrderItems'] as List? ?? [];
          numItemsOrdered = items.fold<int>(0, (sum, item) => sum + (item['Quantity'] as int? ?? 0));
        }
      } catch (_) {}

      // 2. Thực thi RPC checkout trong 1 transaction ACID
      final res = await _db.rpc('checkout_order', params: {
        'p_order_id': orderId,
        'p_account_id': accountId,
        'p_table_id': tableId,
        'p_payment_method': paymentMethod,
        'p_vat_percent': vatPercent,
        'p_customer_id': customerId,
        'p_voucher_code': voucherCode,
        'p_discount_campaign_code': discountCampaignCode,
      });

      final checkoutResponse = CheckoutResponse.fromJson(res as Map<String, dynamic>);

      // 3. Phân tích hành vi gian lận (AI Fraud Detection)
      try {
        final discountPercent = discountCampaignCode != null && discountCampaignCode.isNotEmpty ? 10.0 : (voucherCode != null && voucherCode.isNotEmpty ? 15.0 : 0.0);
        final payload = {
          'staff_id': accountId.toString(),
          'session_duration': DateTime.now().difference(openedAt).inSeconds.toDouble(),
          'num_items_ordered': numItemsOrdered,
          'transaction_hour': DateTime.now().hour.toDouble(),
          'checkout_time_sec': tracker.checkoutTimeSec,
          'void_count': tracker.voidCount,
          'discount_percent': discountPercent,
          'add_remove_ratio': tracker.addRemoveRatio,
          'items_removed_after_confirm': tracker.itemsRemovedAfterConfirm,
          'cancel_rate': 0.0,
        };

        final aiRes = await _dio.post('$_aiBaseUrl/predict', data: payload);
        if (aiRes.statusCode == 200 && aiRes.data != null) {
          final isAnomaly = aiRes.data['is_anomaly'] == true;
          final anomalyScore = (aiRes.data['anomaly_score'] ?? 0.0) as double;
          final riskLevel = (aiRes.data['risk_level'] ?? 'Low').toString();

          if (isAnomaly) {
            // Lưu cảnh báo gian lận vào bảng Alerts trực tiếp trên Supabase
            await _db.from('Alerts').insert({
              'AccountId': accountId,
              'OrderId': orderId,
              'AlertType': 1, // AnomalyTransaction
              'Severity': anomalyScore > 0.8 ? 2 : 1, // 2=High, 1=Medium
              'Message': 'AI phát hiện giao dịch bất thường (score: ${anomalyScore.toStringAsFixed(4)})',
              'Detail': 'InvoiceNo: ${checkoutResponse.invoiceNo}, RiskLevel: $riskLevel',
              'AnomalyScore': anomalyScore,
              'IsResolved': false,
              'CreatedAt': DateTime.now().toIso8601String(),
            });
          }
        }
      } catch (e) {
        // AI ngoại tuyến/lỗi -> Bỏ qua, vẫn cho phép thanh toán bình thường
        if (kDebugMode) {
          print('Không thể gọi dịch vụ AI dự đoán gian lận: $e');
        }
      }

      return ApiResult.success(checkoutResponse);
    } catch (e) {
      return ApiResult.failure('Lỗi thanh toán hóa đơn: $e');
    }
  }
}
