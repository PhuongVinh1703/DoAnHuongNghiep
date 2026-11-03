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

  /// Xây dựng thông báo tiếng Việt chi tiết theo từng loại bất thường
  String _buildDetailedAlertMessage({
    required int alertType,
    required double sessionDuration,
    required double discountPercent,
    required int txHour,
    required int voidCount,
    required double cancelRate,
    required double addRemoveRatio,
    required int itemsRemovedAfterConfirm,
    required double anomalyScore,
  }) {
    switch (alertType) {
      case 0: // CancelAfterPayment
        return '[Hủy món sau xác nhận] Phát hiện xóa $itemsRemovedAfterConfirm món sau khi đã gửi bếp/xác nhận đơn';
      case 2: // ExcessiveDiscount
        return '[Lạm dụng giảm giá] Áp mức chiết khấu cao bất thường (${discountPercent.toStringAsFixed(0)}%)';
      case 3: // UnusualHours
        return '[Giao dịch ngoài giờ] Thanh toán vào khung giờ bất thường (${txHour}h)';
      case 4: // FrequentCancellation
        return '[Hủy bill liên tục] Hủy món $voidCount lần, tỷ lệ hủy đơn của NV đạt ${(cancelRate * 100).toInt()}%';
      case 5: // SpeedAnomaly
        return '[Thanh toán siêu tốc] Thời gian mở bàn đến thanh toán quá nhanh (${sessionDuration.toInt()}s)';
      case 6: // AddRemoveAnomaly
        return '[Thêm/xóa món bất thường] Tỷ lệ chỉnh sửa giỏ hàng cao (${(addRemoveRatio * 100).toInt()}%)';
      default:
        return 'AI phát hiện giao dịch bất thường (Độ tin cậy: ${(anomalyScore * 100).toInt()}%)';
    }
  }

  /// Thanh toán hóa đơn (gọi RPC checkout_order + phát hiện hành vi gian lận qua AI Module + Hybrid Fallback)
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

      // 3. Phân tích hành vi gian lận (Ưu tiên gọi AI Microservice -> Fallback Luật thép khi AI offline)
      try {
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
        final currentHour = DateTime.now().hour;

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
          'transaction_hour': currentHour.toDouble(),
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
        String riskLevel = 'LOW';
        int alertType = 1;
        String alertMessage = '';

        // Bước 3A: Gọi trực tiếp AI Microservice (/predict) để chạy mô hình Random Forest + Hybrid Rules
        try {
          final aiRes = await _dio.post('$_aiBaseUrl/predict', data: payload);
          if (aiRes.statusCode == 200 && aiRes.data != null) {
            isAnomaly = aiRes.data['is_anomaly'] == true;
            anomalyScore =
                (aiRes.data['anomaly_score'] as num? ?? 0.0).toDouble();
            riskLevel = (aiRes.data['risk_level'] ?? 'LOW').toString().toUpperCase();

            if (isAnomaly) {
              final anomalies = aiRes.data['anomalies'] as List?;
              if (anomalies != null && anomalies.isNotEmpty) {
                final firstAnomaly = anomalies.first as Map?;
                final typeStr = firstAnomaly?['type']?.toString();
                if (typeStr == 'CancelAfterPayment') {
                  alertType = 0;
                } else if (typeStr == 'ExcessiveDiscount') {
                  alertType = 2;
                } else if (typeStr == 'UnusualHours') {
                  alertType = 3;
                } else if (typeStr == 'FrequentCancellation') {
                  alertType = 4;
                } else if (typeStr == 'SpeedAnomaly') {
                  alertType = 5;
                } else if (typeStr == 'AddRemoveAnomaly') {
                  alertType = 6;
                } else {
                  alertType = 1;
                }
              }
              alertMessage = _buildDetailedAlertMessage(
                alertType: alertType,
                sessionDuration: sessionDuration,
                discountPercent: discountPercent,
                txHour: currentHour,
                voidCount: effectiveTracker.voidCount,
                cancelRate: cancelRate,
                addRemoveRatio: effectiveTracker.addRemoveRatio,
                itemsRemovedAfterConfirm:
                    effectiveTracker.itemsRemovedAfterConfirm,
                anomalyScore: anomalyScore,
              );
            }
          }
        } catch (aiErr) {
          if (kDebugMode) {
            print('AI Microservice đang ngoại tuyến hoặc khởi động lại, dùng bộ Luật thép dự phòng: $aiErr');
          }
        }

        // Bước 3B: Bộ Luật thép dự phòng (Safety Net) nếu AI Server ngủ hoặc chưa bắt trúng ngưỡng cứng
        if (!isAnomaly) {
          if (effectiveTracker.itemsRemovedAfterConfirm > 0) {
            isAnomaly = true;
            anomalyScore = 0.98;
            riskLevel = 'HIGH';
            alertType = 0; // CancelAfterPayment
          } else if (sessionDuration > 0 && sessionDuration < 120.0) {
            isAnomaly = true;
            anomalyScore = 0.95;
            riskLevel = 'HIGH';
            alertType = 5; // SpeedAnomaly
          } else if (discountPercent >= 25.0) {
            isAnomaly = true;
            anomalyScore = 0.95;
            riskLevel = 'HIGH';
            alertType = 2; // ExcessiveDiscount
          } else if (currentHour < 8 || currentHour >= 23) {
            isAnomaly = true;
            anomalyScore = 0.90;
            riskLevel = 'HIGH';
            alertType = 3; // UnusualHours
          } else if (effectiveTracker.voidCount >= 5 && cancelRate >= 0.50) {
            isAnomaly = true;
            anomalyScore = 0.90;
            riskLevel = 'HIGH';
            alertType = 4; // FrequentCancellation
          } else if (effectiveTracker.addRemoveRatio >= 0.70) {
            isAnomaly = true;
            anomalyScore = 0.85;
            riskLevel = 'MEDIUM';
            alertType = 6; // AddRemoveAnomaly
          }

          if (isAnomaly) {
            alertMessage = _buildDetailedAlertMessage(
              alertType: alertType,
              sessionDuration: sessionDuration,
              discountPercent: discountPercent,
              txHour: currentHour,
              voidCount: effectiveTracker.voidCount,
              cancelRate: cancelRate,
              addRemoveRatio: effectiveTracker.addRemoveRatio,
              itemsRemovedAfterConfirm:
                  effectiveTracker.itemsRemovedAfterConfirm,
              anomalyScore: anomalyScore,
            );
          }
        }

        if (isAnomaly) {
          final detailJson = jsonEncode({
            'invoiceNo': checkoutResponse.invoiceNo,
            'riskLevel': riskLevel,
            'features': payload,
          });

          // Gán đúng nhân sự chịu trách nhiệm:
          // Các lỗi thao tác hủy/sửa món (0, 4, 6) gắn cho nhân viên tạo/phục vụ đơn (targetStaffId);
          // Các lỗi tại khâu thanh toán/chiết khấu (2, 3, 5) gắn cho thu ngân (accountId).
          final responsibleAccountId =
              (alertType == 0 || alertType == 4 || alertType == 6)
                  ? targetStaffId
                  : accountId;

          await _db.from('Alerts').insert({
            'AccountId': responsibleAccountId,
            'OrderId': orderId,
            'AlertType': alertType,
            'Severity': (riskLevel == 'HIGH' || anomalyScore >= 0.75) ? 2 : 1,
            'Message': alertMessage,
            'Detail': detailJson,
            'AnomalyScore': anomalyScore,
            'IsResolved': false,
            'CreatedAt': DateTime.now().toIso8601String(),
          });

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
        if (kDebugMode) {
          print('Lỗi ghi nhận cảnh báo AI: $e');
        }
      }

      return ApiResult.success(checkoutResponse);
    } catch (e) {
      return ApiResult.failure('Lỗi thanh toán hóa đơn: $e');
    }
  }
}
