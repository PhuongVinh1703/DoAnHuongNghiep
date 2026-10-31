import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:doanquanlyquananai_mobileapp/core/network/api_response.dart';
import 'package:doanquanlyquananai_mobileapp/core/utils/ai_tracker.dart';
import 'package:doanquanlyquananai_mobileapp/models/invoice/invoice.dart';
import 'package:doanquanlyquananai_mobileapp/models/invoice/checkout_response.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dio/dio.dart';

class InvoiceService {
  final _db = Supabase.instance.client;
  final _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 4),
      receiveTimeout: const Duration(seconds: 4),
    ),
  );

  String get _aiBaseUrl {
    return 'https://module-ai-myproject.onrender.com';
  }

  /// Lấy lịch sử hóa đơn của một khách hàng
  Future<ApiResult<List<Invoice>>> getByCustomer(
    int customerId, {
    int page = 1,
  }) async {
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
          .select(
            '*, DiningTables(TableName), Accounts(FullName), Customers(FullName), InvoiceItems(*)',
          )
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
    double? appliedDiscountPercent,
    double vatPercent = 8.0,
  }) async {
    try {
      // 1. Lấy thông tin order mở trước để làm dữ liệu đầu vào cho AI
      DateTime openedAt = DateTime.now();
      int numItemsOrdered = 0;
      String? orderNote;
      int? orderAccountId;
      try {
        final orderInfo = await _db
            .from('Orders')
            .select('OpenedAt, Note, AccountId, OrderItems(Quantity, IsDeleted)')
            .eq('OrderId', orderId)
            .eq('Status', 0)
            .maybeSingle();

        if (orderInfo != null) {
          orderNote = orderInfo['Note']?.toString();
          orderAccountId = orderInfo['AccountId'] as int?;
          openedAt = DateTime.parse(
            orderInfo['OpenedAt'] ?? DateTime.now().toIso8601String(),
          );
          final items = orderInfo['OrderItems'] as List? ?? [];
          numItemsOrdered = items
              .where((item) => item['IsDeleted'] != true)
              .fold<int>(
                0,
                (sum, item) => sum + (item['Quantity'] as int? ?? 0),
              );
        }
      } catch (_) {}

      // Đồng bộ AiTracker từ Orders.Note với tracker hiện tại của quầy
      final effectiveTracker = AiTracker.mergeFromOrderNote(
        orderNote,
        tracker,
        openedAt: openedAt,
      );

      // 2. Thực thi RPC checkout trong 1 transaction ACID
      final res = await _db.rpc(
        'checkout_order',
        params: {
          'p_order_id': orderId,
          'p_account_id': accountId,
          'p_table_id': tableId,
          'p_payment_method': paymentMethod,
          'p_vat_percent': vatPercent,
          'p_customer_id': customerId,
          'p_voucher_code': voucherCode,
          'p_discount_campaign_code': discountCampaignCode,
        },
      );

      var checkoutResponse = CheckoutResponse.fromJson(
        res as Map<String, dynamic>,
      );

      // 3. Phân tích hành vi gian lận (AI Fraud Detection)
      try {
        // Lấy chính xác phần trăm giảm giá từ tham số truyền vào hoặc truy vấn từ DB
        double discountPercent = appliedDiscountPercent ?? 0.0;
        if (appliedDiscountPercent == null) {
          if (discountCampaignCode != null && discountCampaignCode.isNotEmpty) {
            final campRes = await _db
                .from('DiscountCampaigns')
                .select('DiscountPercent')
                .eq('Code', discountCampaignCode.toUpperCase())
                .maybeSingle();
            if (campRes != null && campRes['DiscountPercent'] != null) {
              discountPercent = (campRes['DiscountPercent'] as num).toDouble();
            }
          } else if (voucherCode != null && voucherCode.isNotEmpty) {
            final vouRes = await _db
                .from('CustomerVouchers')
                .select('DiscountPercent')
                .eq('Code', voucherCode)
                .maybeSingle();
            if (vouRes != null && vouRes['DiscountPercent'] != null) {
              discountPercent = (vouRes['DiscountPercent'] as num).toDouble();
            }
          }
        }

        final sessionDuration = DateTime.now()
            .difference(openedAt)
            .inSeconds
            .toDouble();

        // Tính toán cancel_rate: dùng giá trị từ effectiveTracker (nếu có),
        // ngược lại truy vấn từ cơ sở dữ liệu dựa trên AccountId tạo đơn hoặc thanh toán.
        final targetStaffId = orderAccountId ?? accountId;
        double cancelRate = effectiveTracker.cancelRate;
        if (cancelRate == 0.0) {
          try {
            final ordersList = await _db
                .from('Orders')
                .select('Status')
                .eq('AccountId', targetStaffId);
            if (ordersList.isNotEmpty) {
              final cancelledCount =
                  ordersList.where((o) => o['Status'] == 2).length;
              cancelRate = cancelledCount / ordersList.length;
            }
          } catch (_) {}
        }

        final payload = {
          'staff_id': targetStaffId.toString(),
          'session_duration': sessionDuration,
          'num_items_ordered': numItemsOrdered,
          'transaction_hour': DateTime.now().hour.toDouble(),
          'checkout_time_sec': effectiveTracker.checkoutTimeSec,
          'void_count': effectiveTracker.voidCount,
          'discount_percent': discountPercent,
          'add_remove_ratio': effectiveTracker.addRemoveRatio,
          'items_removed_after_confirm':
              effectiveTracker.itemsRemovedAfterConfirm,
          'cancel_rate': cancelRate,
        };

        bool isAnomaly = false;
        double anomalyScore = 0.0;
        String riskLevel = 'Low';
        int alertType = 1; // Mặc định: Giao dịch bất thường
        String alertMessage = 'AI phát hiện giao dịch bất thường';

        // --- Kịch bản Luật thép ở Client (đảm bảo không bị sót lỗi nghiêm trọng) ---
        // 0. Hủy món sau khi đã gửi bếp / xác nhận (CancelAfterPayment)
        if (effectiveTracker.itemsRemovedAfterConfirm > 0) {
          isAnomaly = true;
          anomalyScore = 0.98;
          riskLevel = 'HIGH';
          alertType = 0; // CancelAfterPayment
          alertMessage =
              '[Hủy món sau xác nhận] Phát hiện xóa ${effectiveTracker.itemsRemovedAfterConfirm} món sau khi gửi bếp/xác nhận';
        }
        // 1. Thanh toán siêu tốc (Session duration < 120 giây)
        else if (sessionDuration > 0 && sessionDuration < 120.0) {
          isAnomaly = true;
          anomalyScore = 0.95;
          riskLevel = 'HIGH';
          alertType = 5; // SpeedAnomaly
          alertMessage =
              '[Thanh toán siêu tốc] Bất thường khi thanh toán (session: ${sessionDuration.toInt()}s)';
        }
        // 2. Giảm giá vượt ngưỡng (giảm giá >= 25%)
        else if (discountPercent >= 25.0) {
          isAnomaly = true;
          anomalyScore = 0.95;
          riskLevel = 'HIGH';
          alertType = 2; // ExcessiveDiscount
          alertMessage =
              '[Lạm dụng giảm giá] Giảm giá quá lớn ($discountPercent%)';
        }
        // 3. Giao dịch ngoài giờ (từ 23h đến trước 8h sáng)
        else if (DateTime.now().hour < 8 || DateTime.now().hour >= 23) {
          isAnomaly = true;
          anomalyScore = 0.90;
          riskLevel = 'HIGH';
          alertType = 3; // UnusualHours
          alertMessage =
              '[Giao dịch ngoài giờ] Thực hiện lúc ${DateTime.now().hour}h';
        }
        // 4. Hủy bill liên tục (Void count >= 5 và tỷ lệ hủy đơn >= 50%)
        else if (effectiveTracker.voidCount >= 5 && cancelRate >= 0.50) {
          isAnomaly = true;
          anomalyScore = 0.90;
          riskLevel = 'HIGH';
          alertType = 4; // FrequentCancellation
          alertMessage =
              '[Hủy bill liên tục] Tần suất hủy món cao (${effectiveTracker.voidCount} lần) và tỷ lệ hủy đơn của NV là ${(cancelRate * 100).toInt()}%';
        }
        // 5. Thêm/xóa món bất thường (Tỷ lệ add_remove_ratio >= 70%)
        else if (effectiveTracker.addRemoveRatio >= 0.70) {
          isAnomaly = true;
          anomalyScore = 0.85;
          riskLevel = 'MEDIUM';
          alertType = 6; // AddRemoveAnomaly
          alertMessage =
              '[Thêm/xóa món bất thường] Tỷ lệ chỉnh sửa giỏ hàng cao (${(effectiveTracker.addRemoveRatio * 100).toInt()}%)';
        }

        // Nếu luật thép chưa kích hoạt, gọi AI Microservice để phân tích sâu hơn
        if (!isAnomaly) {
          final aiRes = await _dio.post('$_aiBaseUrl/predict', data: payload);
          if (aiRes.statusCode == 200 && aiRes.data != null) {
            isAnomaly = aiRes.data['is_anomaly'] == true;
            anomalyScore =
                (aiRes.data['anomaly_score'] as num? ?? 0.0).toDouble();
            riskLevel = (aiRes.data['risk_level'] ?? 'Low').toString();

            if (isAnomaly) {
              final anomalies = aiRes.data['anomalies'] as List?;
              if (anomalies != null && anomalies.isNotEmpty) {
                final firstAnomaly = anomalies.first as Map?;
                final typeStr = firstAnomaly?['type']?.toString();
                if (typeStr == 'CancelAfterPayment') {
                  alertType = 0;
                  alertMessage =
                      '[Hủy sau khi khách trả tiền] Bất thường khi thanh toán';
                } else if (typeStr == 'ExcessiveDiscount') {
                  alertType = 2;
                  alertMessage =
                      '[Lạm dụng giảm giá] Bất thường khi thanh toán';
                } else if (typeStr == 'UnusualHours') {
                  alertType = 3;
                  alertMessage =
                      '[Giao dịch ngoài giờ] Bất thường khi thanh toán';
                } else if (typeStr == 'FrequentCancellation') {
                  alertType = 4;
                  alertMessage =
                      '[Hành vi đáng ngờ] Bất thường khi thanh toán';
                } else if (typeStr == 'SpeedAnomaly') {
                  alertType = 5;
                  alertMessage =
                      '[Thanh toán siêu tốc] Bất thường khi thanh toán';
                } else if (typeStr == 'AddRemoveAnomaly') {
                  alertType = 6;
                  alertMessage =
                      '[Thêm/xóa món bất thường] Bất thường khi thanh toán';
                } else {
                  alertType = 1;
                  alertMessage =
                      'AI phát hiện giao dịch bất thường (score: ${anomalyScore.toStringAsFixed(4)})';
                }
              } else {
                alertType = 1;
                alertMessage =
                    'AI phát hiện giao dịch bất thường (score: ${anomalyScore.toStringAsFixed(4)})';
              }
            }
          }
        }

        if (isAnomaly) {
          final detailJson = jsonEncode({
            'invoiceNo': checkoutResponse.invoiceNo,
            'riskLevel': riskLevel,
            'features': payload,
          });

          // Lưu cảnh báo gian lận vào bảng Alerts trực tiếp trên Supabase
          await _db.from('Alerts').insert({
            'AccountId': accountId,
            'OrderId': orderId,
            'AlertType': alertType,
            'Severity': anomalyScore > 0.8 ? 2 : 1, // 2=High, 1=Medium
            'Message': alertMessage,
            'Detail': detailJson,
            'AnomalyScore': anomalyScore,
            'IsResolved': false,
            'CreatedAt': DateTime.now().toIso8601String(),
          });

          // Gán thông tin aiAlert vào checkoutResponse để hiển thị ở màn hình thành công
          checkoutResponse = CheckoutResponse(
            invoiceId: checkoutResponse.invoiceId,
            invoiceNo: checkoutResponse.invoiceNo,
            totalAmount: checkoutResponse.totalAmount,
            earnedPoints: checkoutResponse.earnedPoints,
            aiAlert: AiAlertSummary(
              isAnomaly: true,
              anomalyScore: anomalyScore,
              riskLevel: riskLevel,
            ),
          );
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
