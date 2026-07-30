import 'package:doanquanlyquananai_mobileapp/core/network/api_response.dart';
import 'package:doanquanlyquananai_mobileapp/core/storage/local_cache.dart';
import 'package:doanquanlyquananai_mobileapp/models/menu/menu_category.dart';
import 'package:doanquanlyquananai_mobileapp/models/menu/menu_item.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MenuService {
  final _db = Supabase.instance.client;

  // ── Categories ────────────────────────────────────────────────
  Future<ApiResult<List<MenuCategoryModel>>> getActiveCategories(
      {bool forceRefresh = false}) async {
    // Thử cache trước (bỏ qua nếu forceRefresh)
    if (!forceRefresh) {
      final cached = LocalCache.getMenuCategories();
      if (cached != null) {
        return ApiResult.success(cached.map(MenuCategoryModel.fromJson).toList());
      }
    }
    try {
      final res = await _db
          .from('MenuCategories')
          .select()
          .eq('IsActive', true)
          .order('DisplayOrder');
      final list = (res as List).map((e) => MenuCategoryModel.fromJson(e)).toList();
      await LocalCache.saveMenuCategories(list.map((e) => e.toJson()).toList());
      return ApiResult.success(list);
    } catch (e) {
      return ApiResult.failure('Không thể tải danh mục: $e');
    }
  }

  Future<ApiResult<List<MenuCategoryModel>>> getAllCategories() async {
    try {
      final res = await _db
          .from('MenuCategories')
          .select()
          .order('DisplayOrder');
      final list = (res as List).map((e) => MenuCategoryModel.fromJson(e)).toList();
      return ApiResult.success(list);
    } catch (e) {
      return ApiResult.failure('Không thể tải danh mục: $e');
    }
  }

  // ── Items ─────────────────────────────────────────────────────
  Future<ApiResult<List<MenuItemModel>>> getAvailableItems(
      {int? categoryId, bool forceRefresh = false}) async {
    // Thử cache (bỏ qua nếu forceRefresh)
    if (!forceRefresh) {
      final cached = LocalCache.getMenuItems();
      if (cached != null) {
        var list = cached.map(MenuItemModel.fromJson).toList();
        if (categoryId != null && categoryId != 0) {
          list = list.where((i) => i.categoryId == categoryId).toList();
        }
        return ApiResult.success(list);
      }
    }
    try {
      var query = _db
          .from('MenuItems')
          .select('*, MenuCategories(Name)')
          .eq('IsAvailable', true);
      if (categoryId != null && categoryId != 0) {
        query = query.eq('CategoryId', categoryId);
      }
      final res = await query.order('CategoryId');
      final list = (res as List).map((e) => MenuItemModel.fromJson(e)).toList();
      if (categoryId == null || categoryId == 0) {
        await LocalCache.saveMenuItems(list.map((e) => e.toJson()).toList());
      }
      return ApiResult.success(list);
    } catch (e) {
      return ApiResult.failure('Không thể tải thực đơn: $e');
    }
  }

  Future<ApiResult<List<MenuItemModel>>> getAllItems() async {
    try {
      final res = await _db
          .from('MenuItems')
          .select('*, MenuCategories(Name)')
          .order('CategoryId');
      final list = (res as List).map((e) => MenuItemModel.fromJson(e)).toList();
      return ApiResult.success(list);
    } catch (e) {
      return ApiResult.failure('Không thể tải thực đơn: $e');
    }
  }

  Future<ApiResult<MenuItemModel>> getItemById(int id) async {
    try {
      final res = await _db
          .from('MenuItems')
          .select('*, MenuCategories(Name)')
          .eq('ItemId', id)
          .single();
      return ApiResult.success(MenuItemModel.fromJson(res));
    } catch (e) {
      return ApiResult.failure('Không tìm thấy món: $e');
    }
  }

  Future<ApiResult<void>> toggleAvailability(int itemId, bool isAvailable) async {
    try {
      await _db
          .from('MenuItems')
          .update({'IsAvailable': isAvailable})
          .eq('ItemId', itemId);
      await LocalCache.clearMenuCache();
      return ApiResult.success(null);
    } catch (e) {
      return ApiResult.failure('Không thể cập nhật trạng thái: $e');
    }
  }

  Future<ApiResult<MenuItemModel>> createMenuItem(Map<String, dynamic> data) async {
    try {
      // Chuyển camelCase → PascalCase cho DB
      final dbData = {
        'CategoryId':  data['categoryId'] ?? data['CategoryId'],
        'Name':        data['name']        ?? data['Name'],
        'Description': data['description'] ?? data['Description'],
        'Price':       data['price']       ?? data['Price'],
        'Emoji':       data['emoji']       ?? data['Emoji'] ?? '🍽️',
        'ImagePath':   data['imagePath']   ?? data['ImagePath'],
        'IsAvailable': data['isAvailable'] ?? data['IsAvailable'] ?? true,
        'CreatedAt':   DateTime.now().toIso8601String(),
      };
      final res = await _db.from('MenuItems').insert(dbData).select().single();
      await LocalCache.clearMenuCache();
      return ApiResult.success(MenuItemModel.fromJson(res));
    } catch (e) {
      return ApiResult.failure('Không thể tạo món: $e');
    }
  }

  Future<ApiResult<MenuItemModel>> updateMenuItem(int id, Map<String, dynamic> data) async {
    try {
      final dbData = <String, dynamic>{};
      if (data.containsKey('categoryId') || data.containsKey('CategoryId')) {
        dbData['CategoryId'] = data['categoryId'] ?? data['CategoryId'];
      }
      if (data.containsKey('name') || data.containsKey('Name')) {
        dbData['Name'] = data['name'] ?? data['Name'];
      }
      if (data.containsKey('description') || data.containsKey('Description')) {
        dbData['Description'] = data['description'] ?? data['Description'];
      }
      if (data.containsKey('price') || data.containsKey('Price')) {
        dbData['Price'] = data['price'] ?? data['Price'];
      }
      if (data.containsKey('emoji') || data.containsKey('Emoji')) {
        dbData['Emoji'] = data['emoji'] ?? data['Emoji'];
      }
      if (data.containsKey('imagePath') || data.containsKey('ImagePath')) {
        dbData['ImagePath'] = data['imagePath'] ?? data['ImagePath'];
      }
      if (data.containsKey('isAvailable') || data.containsKey('IsAvailable')) {
        dbData['IsAvailable'] = data['isAvailable'] ?? data['IsAvailable'];
      }

      final res = await _db
          .from('MenuItems')
          .update(dbData)
          .eq('ItemId', id)
          .select()
          .single();
      await LocalCache.clearMenuCache();
      return ApiResult.success(MenuItemModel.fromJson(res));
    } catch (e) {
      return ApiResult.failure('Không thể cập nhật món: $e');
    }
  }

  Future<ApiResult<void>> deleteMenuItem(int id) async {
    try {
      await _db.from('MenuItems').delete().eq('ItemId', id);
      await LocalCache.clearMenuCache();
      return ApiResult.success(null);
    } catch (e) {
      return ApiResult.failure('Không thể xóa món: $e');
    }
  }
}
