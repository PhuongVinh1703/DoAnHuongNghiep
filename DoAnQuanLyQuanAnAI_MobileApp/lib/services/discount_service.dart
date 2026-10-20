import 'package:doanquanlyquananai_mobileapp/core/network/api_response.dart';
import 'package:doanquanlyquananai_mobileapp/models/discount/discount_campaign.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DiscountService {
  final SupabaseClient _client = Supabase.instance.client;

  Future<ApiResult<List<DiscountCampaign>>> getCampaigns({int? branchId}) async {
    try {
      var query = _client.from('DiscountCampaigns').select();
      if (branchId != null) {
        query = query.or('BranchId.eq.$branchId,BranchId.is.null');
      }
      final List<dynamic> res = await query.order('CreatedAt', ascending: false);
      final list = res.map((e) => DiscountCampaign.fromJson(e)).toList();
      return ApiResult.success(list);
    } catch (e) {
      return ApiResult.failure(e.toString());
    }
  }

  Future<ApiResult<DiscountCampaign>> validateCampaign(String code, double subtotal) async {
    try {
      final res = await _client
          .from('DiscountCampaigns')
          .select()
          .eq('Code', code.toUpperCase())
          .eq('IsActive', true)
          .lte('StartDate', DateTime.now().toIso8601String())
          .gte('EndDate', DateTime.now().toIso8601String())
          .maybeSingle();

      if (res == null) {
        return ApiResult.failure('Mã khuyến mãi không tồn tại, chưa kích hoạt hoặc đã hết hạn.');
      }

      final campaign = DiscountCampaign.fromJson(res);
      if (campaign.usageLimit > 0 &&
          campaign.usedCount >= campaign.usageLimit) {
        return ApiResult.failure('Mã khuyến mãi này đã hết lượt sử dụng.');
      }
      if (subtotal < campaign.minOrderValue) {
        return ApiResult.failure('Đơn hàng chưa đạt giá trị tối thiểu để áp dụng mã khuyến mãi này (Yêu cầu tối thiểu: ${campaign.minOrderValue}).');
      }

      return ApiResult.success(campaign);
    } catch (e) {
      return ApiResult.failure('Lỗi xác thực mã khuyến mãi: $e');
    }
  }

  Future<ApiResult<DiscountCampaign>> createCampaign(Map<String, dynamic> data) async {
    try {
      final Map<String, dynamic> pgData = {
        'Code': data['code']?.toString().trim().toUpperCase(),
        'DiscountPercent': data['discountValue'] ?? data['discountPercent'],
        'Description': data['description']?.toString().trim(),
        'StartDate': data['startDate'],
        'EndDate': data['endDate'],
        'BranchId': data['branchId'],
        'IsActive': data['isActive'] ?? true,
        'CreatedAt': DateTime.now().toIso8601String(),
        'MinOrderValue': data['minOrderValue'] ?? 0,
        'MaxDiscountAmount': data['maxDiscountAmount'],
        'UsageLimit': data['usageLimit'],
        'UsedCount': 0,
      };

      final res = await _client.from('DiscountCampaigns').insert(pgData).select().single();
      return ApiResult.success(DiscountCampaign.fromJson(res));
    } catch (e) {
      return ApiResult.failure(e.toString());
    }
  }

  Future<ApiResult<DiscountCampaign>> updateCampaign(int id, Map<String, dynamic> data) async {
    try {
      final Map<String, dynamic> pgData = {};
      if (data.containsKey('code')) pgData['Code'] = data['code']?.toString().trim().toUpperCase();
      if (data.containsKey('discountValue')) pgData['DiscountPercent'] = data['discountValue'];
      if (data.containsKey('discountPercent')) pgData['DiscountPercent'] = data['discountPercent'];
      if (data.containsKey('description')) pgData['Description'] = data['description']?.toString().trim();
      if (data.containsKey('startDate')) pgData['StartDate'] = data['startDate'];
      if (data.containsKey('endDate')) pgData['EndDate'] = data['endDate'];
      if (data.containsKey('branchId')) pgData['BranchId'] = data['branchId'];
      if (data.containsKey('isActive')) pgData['IsActive'] = data['isActive'];
      if (data.containsKey('minOrderValue')) pgData['MinOrderValue'] = data['minOrderValue'];
      if (data.containsKey('maxDiscountAmount')) pgData['MaxDiscountAmount'] = data['maxDiscountAmount'];
      if (data.containsKey('usageLimit')) pgData['UsageLimit'] = data['usageLimit'];

      final res = await _client
          .from('DiscountCampaigns')
          .update(pgData)
          .eq('CampaignId', id)
          .select()
          .single();
      return ApiResult.success(DiscountCampaign.fromJson(res));
    } catch (e) {
      return ApiResult.failure(e.toString());
    }
  }

  Future<ApiResult<void>> toggleStatus(int id) async {
    try {
      final currentRes = await _client
          .from('DiscountCampaigns')
          .select('IsActive')
          .eq('CampaignId', id)
          .single();
      final bool currentIsActive = currentRes['IsActive'] ?? false;

      await _client
          .from('DiscountCampaigns')
          .update({'IsActive': !currentIsActive})
          .eq('CampaignId', id);
      return ApiResult.success(null);
    } catch (e) {
      return ApiResult.failure(e.toString());
    }
  }

  Future<ApiResult<void>> deleteCampaign(int id) async {
    try {
      await _client.from('DiscountCampaigns').delete().eq('CampaignId', id);
      return ApiResult.success(null);
    } catch (e) {
      return ApiResult.failure(e.toString());
    }
  }
}
