import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:doanquanlyquananai_mobileapp/services/branch_service.dart';
import 'package:doanquanlyquananai_mobileapp/services/menu_service.dart';
import 'package:doanquanlyquananai_mobileapp/services/table_service.dart';
import 'package:doanquanlyquananai_mobileapp/services/customer_service.dart';
import 'package:doanquanlyquananai_mobileapp/services/discount_service.dart';
import 'package:doanquanlyquananai_mobileapp/core/storage/local_cache.dart';

void main() {
  HttpOverrides.global = null; // Allow real network requests in flutter test
  const String supabaseUrl = 'https://usaybsihqbymbemnqzgr.supabase.co';
  const String supabaseAnonKey = 'sb_publishable_oDIUjhTQpjEfr2qLZzDkYQ_Dhc4vYmE';

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    HttpOverrides.global = null; // Override mock HTTP client after binding initialization
    // Setup SharedPreferences mock initial values
    SharedPreferences.setMockInitialValues({});
    await LocalCache.init();
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );
  });

  group('Supabase Service Integration Tests', () {
    test('BranchService - getBranches', () async {
      final service = BranchService();
      final result = await service.getBranches();
      if (!result.isSuccess) {
        print('BranchService error: ${result.error}');
      }
      expect(result.isSuccess, true);
      expect(result.data, isNotNull);
      print('✓ Loaded ${result.data!.length} branches successfully.');
    });

    test('MenuService - getActiveCategories', () async {
      final service = MenuService();
      final result = await service.getActiveCategories();
      if (!result.isSuccess) {
        print('getActiveCategories error: ${result.error}');
      }
      expect(result.isSuccess, true);
      expect(result.data, isNotNull);
      print('✓ Loaded ${result.data!.length} menu categories successfully.');
    });

    test('MenuService - getAvailableItems', () async {
      final service = MenuService();
      final result = await service.getAvailableItems();
      if (!result.isSuccess) {
        print('getAvailableItems error: ${result.error}');
      }
      expect(result.isSuccess, true);
      expect(result.data, isNotNull);
      print('✓ Loaded ${result.data!.length} menu items successfully.');
    });

    test('TableService - getTables', () async {
      final service = TableService();
      final result = await service.getTables();
      if (!result.isSuccess) {
        print('getTables error: ${result.error}');
      }
      expect(result.isSuccess, true);
      expect(result.data, isNotNull);
      print('✓ Loaded ${result.data!.length} dining tables successfully.');
    });

    test('CustomerService - searchCustomers', () async {
      final service = CustomerService();
      final result = await service.searchCustomers();
      if (!result.isSuccess) {
        print('searchCustomers error: ${result.error}');
      }
      expect(result.isSuccess, true);
      expect(result.data, isNotNull);
      print('✓ CustomerService searchCustomers runs and loads data successfully.');
    });

    test('DiscountService - getCampaigns and validateCampaign', () async {
      final service = DiscountService();
      final result = await service.getCampaigns();
      if (!result.isSuccess) {
        print('getCampaigns error: ${result.error}');
      }
      expect(result.isSuccess, true);
      expect(result.data, isNotNull);
      print('✓ Loaded ${result.data!.length} discount campaigns successfully.');

      // Test validateCampaign with 'GIAM30'
      final valResult = await service.validateCampaign('GIAM30', 200000);
      if (!valResult.isSuccess) {
        print('validateCampaign error: ${valResult.error}');
      }
      expect(valResult.isSuccess, true);
      expect(valResult.data, isNotNull);
      expect(valResult.data!.code, 'GIAM30');
      print('✓ Validated campaign code GIAM30 successfully: Giảm ${valResult.data!.discountValue}%');
    });
  });
}
