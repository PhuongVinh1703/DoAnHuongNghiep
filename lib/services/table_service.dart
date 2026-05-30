import 'package:doanquanlyquananai_mobileapp/core/network/api_response.dart';
import 'package:doanquanlyquananai_mobileapp/models/table/dining_table.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TableService {
  final _db = Supabase.instance.client;

  Future<ApiResult<List<DiningTable>>> getTables({
    int? branchId,
    int? status,
    bool includeInactive = false,
  }) async {
    try {
      var query = _db.from('DiningTables').select();
      if (!includeInactive) {
        query = query.eq('IsActive', true);
      }
      if (branchId != null) {
        query = query.eq('BranchId', branchId);
      }
      if (status != null) {
        query = query.eq('Status', status);
      }
      final res = await query.order('TableId');
      final list = (res as List).map((e) => DiningTable.fromJson(e)).toList();
      return ApiResult.success(list);
    } catch (e) {
      return ApiResult.failure('Không thể tải danh sách bàn: $e');
    }
  }

  Future<ApiResult<DiningTable>> getTableById(int id) async {
    try {
      final res = await _db
          .from('DiningTables')
          .select()
          .eq('TableId', id)
          .single();
      return ApiResult.success(DiningTable.fromJson(res));
    } catch (e) {
      return ApiResult.failure('Không tìm thấy bàn: $e');
    }
  }

  Future<ApiResult<void>> updateStatus(int tableId, int status) async {
    try {
      await _db
          .from('DiningTables')
          .update({'Status': status})
          .eq('TableId', tableId);
      return ApiResult.success(null);
    } catch (e) {
      return ApiResult.failure('Không thể cập nhật trạng thái bàn: $e');
    }
  }

  Future<ApiResult<DiningTable>> createTable({
    required String tableName,
    required int capacity,
    required int branchId,
  }) async {
    try {
      final res = await _db.from('DiningTables').insert({
        'TableName': tableName,
        'Capacity':  capacity,
        'BranchId':  branchId,
        'Status':    0,
        'IsActive':  true,
      }).select().single();
      return ApiResult.success(DiningTable.fromJson(res));
    } catch (e) {
      return ApiResult.failure('Không thể tạo bàn: $e');
    }
  }

  Future<ApiResult<void>> toggleActive(int tableId) async {
    try {
      // Lấy trạng thái hiện tại rồi đảo ngược
      final current = await _db
          .from('DiningTables')
          .select('IsActive')
          .eq('TableId', tableId)
          .single();
      final newActive = !(current['IsActive'] as bool);
      await _db
          .from('DiningTables')
          .update({'IsActive': newActive})
          .eq('TableId', tableId);
      return ApiResult.success(null);
    } catch (e) {
      return ApiResult.failure('Không thể thay đổi trạng thái bàn: $e');
    }
  }
}
