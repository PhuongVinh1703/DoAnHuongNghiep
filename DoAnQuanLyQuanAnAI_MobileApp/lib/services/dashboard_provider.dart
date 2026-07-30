import 'package:flutter/material.dart';
import 'package:doanquanlyquananai_mobileapp/core/network/api_response.dart';
import 'package:doanquanlyquananai_mobileapp/services/dashboard_service.dart';
import 'package:doanquanlyquananai_mobileapp/core/utils/error_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

double _parseDouble(dynamic value) {
  if (value == null) return 0.0;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0.0;
  return 0.0;
}

int _parseInt(dynamic value) {
  if (value == null) return 0;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

class DashboardSummary {
  final double totalRevenue;
  final int totalInvoices;
  final double avgOrderValue;
  final int openOrders;
  final int unresolvedAlerts;

  DashboardSummary({
    required this.totalRevenue,
    required this.totalInvoices,
    required this.avgOrderValue,
    required this.openOrders,
    required this.unresolvedAlerts,
  });

  factory DashboardSummary.fromJson(Map<String, dynamic> json) {
    return DashboardSummary(
      totalRevenue: _parseDouble(json['totalRevenue'] ?? json['TotalRevenue']),
      totalInvoices: _parseInt(json['totalInvoices'] ?? json['TotalInvoices']),
      avgOrderValue: _parseDouble(
        json['avgOrderValue'] ?? json['AvgOrderValue'],
      ),
      openOrders: _parseInt(json['openOrders'] ?? json['OpenOrders']),
      unresolvedAlerts: _parseInt(
        json['unresolvedAlerts'] ?? json['UnresolvedAlerts'],
      ),
    );
  }
}

class DashboardTopItem {
  final int itemId;
  final String itemName;
  final int totalQty;
  final double totalRevenue;

  DashboardTopItem({
    required this.itemId,
    required this.itemName,
    required this.totalQty,
    required this.totalRevenue,
  });

  factory DashboardTopItem.fromJson(Map<String, dynamic> json) {
    return DashboardTopItem(
      itemId: _parseInt(json['itemId'] ?? json['ItemId']),
      itemName: (json['itemName'] ?? json['ItemName'] ?? '').toString(),
      totalQty: _parseInt(json['totalQty'] ?? json['TotalQty']),
      totalRevenue: _parseDouble(json['totalRevenue'] ?? json['TotalRevenue']),
    );
  }
}

class DashboardRevenueDay {
  final DateTime date;
  final double revenue;
  final int count;

  DashboardRevenueDay({
    required this.date,
    required this.revenue,
    required this.count,
  });

  factory DashboardRevenueDay.fromJson(Map<String, dynamic> json) {
    return DashboardRevenueDay(
      date: DateTime.parse(
        json['date'] ?? json['Date'] ?? DateTime.now().toIso8601String(),
      ),
      revenue: _parseDouble(json['revenue'] ?? json['Revenue']),
      count: _parseInt(json['count'] ?? json['Count']),
    );
  }
}

class DashboardProvider extends ChangeNotifier {
  DashboardSummary? summary;
  List<DashboardTopItem> topItems = [];
  List<DashboardRevenueDay> revenueDays = [];

  bool isLoading = false;
  String? errorMessage;

  DateTime? fromDate;
  DateTime? toDate;

  DashboardProvider();

  int? _lastBranchId;
  RealtimeChannel? _realtimeChannel;

  void _subscribeRealtime() {
    if (_realtimeChannel != null) return;
    _realtimeChannel = Supabase.instance.client.channel(
      'dashboard-realtime-channel',
    );

    _realtimeChannel!
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'Invoices',
          callback: (payload) {
            loadDashboardData(branchId: _lastBranchId, showLoading: false);
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'InvoiceItems',
          callback: (payload) {
            loadDashboardData(branchId: _lastBranchId, showLoading: false);
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'Orders',
          callback: (payload) {
            loadDashboardData(branchId: _lastBranchId, showLoading: false);
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'Alerts',
          callback: (payload) {
            loadDashboardData(branchId: _lastBranchId, showLoading: false);
          },
        );

    _realtimeChannel!.subscribe();
  }

  @override
  void dispose() {
    if (_realtimeChannel != null) {
      Supabase.instance.client.removeChannel(_realtimeChannel!);
    }
    super.dispose();
  }

  Future<void> loadDashboardData({
    int? branchId,
    DateTime? from,
    DateTime? to,
    bool showLoading = true,
  }) async {
    _lastBranchId = branchId;
    _subscribeRealtime();

    if (showLoading) {
      isLoading = true;
      errorMessage = null;
      notifyListeners();
    }

    if (from != null) fromDate = from;
    if (to != null) toDate = to;

    try {
      final svc = DashboardService();
      // Tải song song cả 3 báo cáo để tối ưu hiệu năng
      final results = await Future.wait([
        svc.getSummary(
          from: fromDate?.toIso8601String(),
          to: toDate?.toIso8601String(),
          branchId: branchId,
        ),
        svc.getTopItems(
          from: fromDate?.toIso8601String(),
          to: toDate?.toIso8601String(),
          branchId: branchId,
        ),
        svc.getRevenueByDay(
          from: fromDate?.toIso8601String(),
          to: toDate?.toIso8601String(),
          branchId: branchId,
        ),
      ]);

      final sumResult = results[0] as ApiResult<DashboardData>;
      final topResult = results[1] as ApiResult<List<TopItem>>;
      final revResult = results[2] as ApiResult<List<RevenueByDay>>;

      if (sumResult.isSuccess && sumResult.data != null) {
        summary = DashboardSummary(
          totalRevenue: sumResult.data!.totalRevenue,
          totalInvoices: sumResult.data!.totalInvoices,
          avgOrderValue: sumResult.data!.avgOrderValue,
          openOrders: sumResult.data!.openOrders,
          unresolvedAlerts: sumResult.data!.unresolvedAlerts,
        );
      } else {
        errorMessage = sumResult.error;
      }

      if (topResult.isSuccess && topResult.data != null) {
        topItems = topResult.data!
            .map(
              (e) => DashboardTopItem(
                itemId: e.itemId,
                itemName: e.itemName,
                totalQty: e.totalQty,
                totalRevenue: e.totalRevenue,
              ),
            )
            .toList();
      } else {
        errorMessage = errorMessage ?? topResult.error;
      }

      if (revResult.isSuccess && revResult.data != null) {
        revenueDays = revResult.data!
            .map(
              (e) => DashboardRevenueDay(
                date: e.date,
                revenue: e.revenue,
                count: e.invoiceCount,
              ),
            )
            .toList();
      } else {
        errorMessage = errorMessage ?? revResult.error;
      }
    } catch (e) {
      errorMessage = ErrorHandler.formatError(e);
    } finally {
      if (showLoading) {
        isLoading = false;
      }
      notifyListeners();
    }
  }
}
