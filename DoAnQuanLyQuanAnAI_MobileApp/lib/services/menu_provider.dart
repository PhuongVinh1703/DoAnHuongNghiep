import 'package:flutter/material.dart';
import 'package:doanquanlyquananai_mobileapp/models/menu/menu_category.dart';
import 'package:doanquanlyquananai_mobileapp/models/menu/menu_item.dart';
import 'package:doanquanlyquananai_mobileapp/core/network/api_response.dart';
import 'package:doanquanlyquananai_mobileapp/services/menu_service.dart';

class MenuProvider extends ChangeNotifier {
  
  List<MenuCategoryModel> _categories = [];
  List<MenuItemModel> _items = [];
  bool _isLoading = false;
  String? _errorMessage;

  MenuProvider();

  List<MenuCategoryModel> get categories => _categories;
  List<MenuItemModel> get items => _items;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> loadMenuData() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final menuService = MenuService();
      
      // Tải song song danh mục và món ăn
      final results = await Future.wait([
        menuService.getActiveCategories(),
        menuService.getAvailableItems(),
      ]);

      final catResult = results[0] as ApiResult<List<MenuCategoryModel>>;
      final itemResult = results[1] as ApiResult<List<MenuItemModel>>;

      if (catResult.isSuccess && catResult.data != null) {
        _categories = catResult.data!;
      } else {
        _errorMessage = catResult.error;
      }

      if (itemResult.isSuccess && itemResult.data != null) {
        _items = itemResult.data!;
      } else {
        _errorMessage = itemResult.error ?? _errorMessage;
      }
      
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Không thể tải dữ liệu thực đơn';
      notifyListeners();
    }
  }

  List<MenuItemModel> getItemsByCategory(int categoryId) {
    if (categoryId == 0) return _items; // 0 = All
    return _items.where((item) => item.categoryId == categoryId).toList();
  }
}
