import 'package:doanquanlyquananai_mobileapp/core/network/api_response.dart';
import 'package:doanquanlyquananai_mobileapp/models/branch/branch.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BranchService {
  final _db = Supabase.instance.client;

  Future<ApiResult<List<Branch>>> getBranches() async {
    try {
      final res = await _db
          .from('Branches')
          .select()
          .eq('IsActive', true)
          .order('BranchId');
      final list = (res as List).map((e) => Branch.fromJson(e)).toList();
      return ApiResult.success(list);
    } catch (e) {
      return ApiResult.failure('Không thể tải danh sách chi nhánh: $e');
    }
  }
}
