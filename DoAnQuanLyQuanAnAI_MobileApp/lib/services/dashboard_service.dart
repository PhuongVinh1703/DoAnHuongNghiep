import 'package:doanquanlyquananai_mobileapp/core/network/api_response.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DashboardData {
  final double totalRevenue;
  final int totalInvoices;
  final double avgOrderValue;
  final int openOrders;
  final int unresolvedAlerts;

  const DashboardData({
    required this.totalRevenue,
    required this.totalInvoices,
    required this.avgOrderValue,
    required this.openOrders,
    required this.unresolvedAlerts,
  });

  factory DashboardData.fromJson(Map<String, dynamic> json) => DashboardData(
    totalRevenue:    (json['totalRevenue'] ?? 0).toDouble(),
    totalInvoices:   json['totalInvoices'] ?? 0,
    avgOrderValue:   (json['avgOrderValue'] ?? 0).toDouble(),
    openOrders:      json['openOrders'] ?? 0,
    unresolvedAlerts: json['unresolvedAlerts'] ?? 0,
  );
}

class TopItem {
  final int itemId;
  final String itemName;
  final int totalQty;
  final double totalRevenue;

  const TopItem({
    required this.itemId,
    required this.itemName,
    required this.totalQty,
    required this.totalRevenue,
  });

  factory TopItem.fromJson(Map<String, dynamic> json) => TopItem(
    itemId:       json['itemId'] ?? 0,
    itemName:     json['itemName'] ?? '',
    totalQty:     json['totalQty'] ?? 0,
    totalRevenue: (json['totalRevenue'] ?? 0).toDouble(),
  );
}

class RevenueByDay {
  final DateTime date;
  final double revenue;
  final int invoiceCount;

  const RevenueByDay({
    required this.date,
    required this.revenue,
    required this.invoiceCount,
  });

  factory RevenueByDay.fromJson(Map<String, dynamic> json) => RevenueByDay(
    date:         DateTime.parse(json['date']),
    revenue:      (json['revenue'] ?? 0).toDouble(),
    invoiceCount: json['invoiceCount'] ?? 0,
  );
}

class DashboardService {
  final _db = Supabase.instance.client;

  Future<ApiResult<DashboardData>> getSummary({
    String? from,
    String? to,
    int? branchId,
  }) async {
    try {
      // 1. Lấy dữ liệu hóa đơn (doanh thu, số lượng hóa đơn)
      var invQuery = _db.from('Invoices').select('TotalAmount, PaidAt, DiningTables!inner(BranchId)');
      if (from != null) invQuery = invQuery.gte('PaidAt', from);
      if (to != null) invQuery = invQuery.lte('PaidAt', to);
      if (branchId != null) invQuery = invQuery.eq('DiningTables.BranchId', branchId);
      
      final invoices = await invQuery;
      double totalRevenue = 0;
      int totalInvoices = invoices.length;
      for (var inv in invoices) {
        totalRevenue += (inv['TotalAmount'] as num? ?? 0).toDouble();
      }
      double avgOrderValue = totalInvoices > 0 ? totalRevenue / totalInvoices : 0;

      // 2. Lấy số đơn hàng đang phục vụ (Status = 0)
      var orderQuery = _db.from('Orders').select('OrderId, DiningTables!inner(BranchId)').eq('Status', 0);
      if (branchId != null) orderQuery = orderQuery.eq('DiningTables.BranchId', branchId);
      final openOrdersList = await orderQuery;
      int openOrders = openOrdersList.length;

      // 3. Lấy số cảnh báo chưa giải quyết (IsResolved = false)
      final alertsList = await _db.from('Alerts').select('AlertId').eq('IsResolved', false);
      int unresolvedAlerts = alertsList.length;

      return ApiResult.success(DashboardData(
        totalRevenue: totalRevenue,
        totalInvoices: totalInvoices,
        avgOrderValue: avgOrderValue,
        openOrders: openOrders,
        unresolvedAlerts: unresolvedAlerts,
      ));
    } catch (e) {
      return ApiResult.failure('Lỗi lấy tổng hợp báo cáo: $e');
    }
  }

  Future<ApiResult<List<RevenueByDay>>> getRevenueByDay({
    String? from,
    String? to,
    int? branchId,
  }) async {
    try {
      var invQuery = _db.from('Invoices').select('TotalAmount, PaidAt, DiningTables!inner(BranchId)');
      if (from != null) invQuery = invQuery.gte('PaidAt', from);
      if (to != null) invQuery = invQuery.lte('PaidAt', to);
      if (branchId != null) invQuery = invQuery.eq('DiningTables.BranchId', branchId);
      
      final invoices = await invQuery;
      
      final Map<String, List<double>> revenueByDayMap = {};
      for (var inv in invoices) {
        final paidAt = DateTime.parse(inv['PaidAt']);
        final dayKey = paidAt.toIso8601String().substring(0, 10); // yyyy-MM-dd
        final amount = (inv['TotalAmount'] as num? ?? 0).toDouble();
        revenueByDayMap.putIfAbsent(dayKey, () => []).add(amount);
      }

      final List<RevenueByDay> list = [];
      revenueByDayMap.forEach((day, amounts) {
        double sum = amounts.fold(0.0, (a, b) => a + b);
        list.add(RevenueByDay(
          date: DateTime.parse(day),
          revenue: sum,
          invoiceCount: amounts.length,
        ));
      });
      list.sort((a, b) => a.date.compareTo(b.date));
      return ApiResult.success(list);
    } catch (e) {
      return ApiResult.failure('Lỗi lấy thống kê doanh thu theo ngày: $e');
    }
  }

  Future<ApiResult<List<TopItem>>> getTopItems({
    String? from,
    String? to,
    int top = 10,
  }) async {
    try {
      var query = _db.from('InvoiceItems').select('ItemId, ItemName, Quantity, UnitPrice, Invoices!inner(PaidAt)');
      if (from != null) query = query.gte('Invoices.PaidAt', from);
      if (to != null) query = query.lte('Invoices.PaidAt', to);
      
      final items = await query;
      final Map<int, _TempTopItem> map = {};

      for (var it in items) {
        final id = it['ItemId'] as int;
        final name = it['ItemName'] as String;
        final qty = it['Quantity'] as int;
        final price = (it['UnitPrice'] as num).toDouble();
        final total = price * qty;
        
        map.update(id, (existing) {
          return _TempTopItem(
            itemId: id,
            itemName: name,
            qty: existing.qty + qty,
            revenue: existing.revenue + total,
          );
        }, ifAbsent: () => _TempTopItem(itemId: id, itemName: name, qty: qty, revenue: total));
      }

      final list = map.values.map((e) => TopItem(
        itemId: e.itemId,
        itemName: e.itemName,
        totalQty: e.qty,
        totalRevenue: e.revenue,
      )).toList();
      
      list.sort((a, b) => b.totalQty.compareTo(a.totalQty));
      return ApiResult.success(list.take(top).toList());
    } catch (e) {
      return ApiResult.failure('Lỗi lấy món ăn bán chạy: $e');
    }
  }

  Future<ApiResult<Map<String, dynamic>>> getAlertsSummary() async {
    try {
      final totalAlerts = await _db.from('Alerts').select('AlertId');
      final unresolved = await _db.from('Alerts').select('AlertId').eq('IsResolved', false);
      return ApiResult.success({
        'total': totalAlerts.length,
        'unresolved': unresolved.length,
      });
    } catch (e) {
      return ApiResult.failure('Lỗi lấy tổng hợp cảnh báo: $e');
    }
  }

  Future<ApiResult<List<Map<String, dynamic>>>> getTablesStatus({int? branchId}) async {
    try {
      var query = _db.from('DiningTables').select('TableId, TableName, Status');
      if (branchId != null) query = query.eq('BranchId', branchId);
      final res = await query.order('TableId');
      
      final list = (res as List).map((e) => {
        'tableId': e['TableId'],
        'tableName': e['TableName'],
        'status': e['Status'],
      }).toList();
      return ApiResult.success(list);
    } catch (e) {
      return ApiResult.failure('Lỗi lấy trạng thái bàn ăn: $e');
    }
  }
}

class _TempTopItem {
  final int itemId;
  final String itemName;
  final int qty;
  final double revenue;

  _TempTopItem({
    required this.itemId,
    required this.itemName,
    required this.qty,
    required this.revenue,
  });
}
