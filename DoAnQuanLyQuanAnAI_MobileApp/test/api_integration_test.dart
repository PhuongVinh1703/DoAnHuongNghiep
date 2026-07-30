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
import 'package:doanquanlyquananai_mobileapp/services/invoice_service.dart';
import 'package:doanquanlyquananai_mobileapp/services/order_service.dart';
import 'package:doanquanlyquananai_mobileapp/core/utils/ai_tracker.dart';

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

    test('InvoiceService - checkout and AI prediction (SpeedAnomaly)', () async {
      final orderService = OrderService();
      final invoiceService = InvoiceService();
      
      // 1. Create a temporary order on Table 1 (TableId: 1), using Account 5
      final orderResult = await orderService.createOrder(tableId: 1, accountId: 5);
      expect(orderResult.isSuccess, true);
      final order = orderResult.data!;
      print('✓ Created temporary order ${order.orderId} for testing.');

      // 2. Add an item
      final addResult = await orderService.addItem(order.orderId, 29, 1);
      expect(addResult.isSuccess, true);
      print('✓ Added item to temporary order.');

      // 3. Create a tracker representing a quick checkout
      final tracker = AiTracker.fromRaw(
        startTime: DateTime.now().subtract(const Duration(seconds: 15)),
        voidCount: 0,
        totalAdded: 1,
        totalRemoved: 0,
        removedAfterConfirm: 0,
        hasConfirmed: true,
      );

      // 4. Perform checkout
      print('Calling invoiceService.checkout...');
      final checkoutResult = await invoiceService.checkout(
        orderId: order.orderId,
        accountId: 5,
        tableId: 1,
        paymentMethod: 0, // Cash
        tracker: tracker,
      );

      if (checkoutResult.isSuccess) {
        print('✓ Checkout succeeded!');
        final resp = checkoutResult.data!;
        print('Invoice No: ${resp.invoiceNo}');
        print('AI Alert summary: ${resp.aiAlert?.toJson()}');
      } else {
        print('❌ Checkout failed: ${checkoutResult.error}');
      }
      expect(checkoutResult.isSuccess, true);
    });

    test('InvoiceService - checkout and AI prediction (ExcessiveDiscount)', () async {
      final orderService = OrderService();
      final invoiceService = InvoiceService();
      
      final orderResult = await orderService.createOrder(tableId: 1, accountId: 5);
      expect(orderResult.isSuccess, true);
      final order = orderResult.data!;

      final addResult = await orderService.addItem(order.orderId, 29, 1);
      expect(addResult.isSuccess, true);

      // Manually set database OpenedAt to 300s ago to bypass SpeedAnomaly rule
      await Supabase.instance.client
          .from('Orders')
          .update({'OpenedAt': DateTime.now().subtract(const Duration(seconds: 300)).toIso8601String()})
          .eq('OrderId', order.orderId);

      // Normal session duration (300s) to avoid speed anomaly rule, but apply GIAM30 campaign code
      final tracker = AiTracker.fromRaw(
        startTime: DateTime.now().subtract(const Duration(seconds: 300)),
        voidCount: 0,
        totalAdded: 1,
        totalRemoved: 0,
        removedAfterConfirm: 0,
        hasConfirmed: true,
      );

      print('Calling checkout with GIAM30 discount campaign...');
      final checkoutResult = await invoiceService.checkout(
        orderId: order.orderId,
        accountId: 5,
        tableId: 1,
        paymentMethod: 0,
        tracker: tracker,
        discountCampaignCode: 'GIAM30', // 30% discount -> triggers ExcessiveDiscount rule/AI
      );

      expect(checkoutResult.isSuccess, true);
      final resp = checkoutResult.data!;
      print('ExcessiveDiscount Alert: ${resp.aiAlert?.toJson()}');
    });

    test('InvoiceService - checkout and AI prediction (AddRemoveAnomaly)', () async {
      final orderService = OrderService();
      final invoiceService = InvoiceService();
      
      final orderResult = await orderService.createOrder(tableId: 1, accountId: 5);
      expect(orderResult.isSuccess, true);
      final order = orderResult.data!;

      final addResult = await orderService.addItem(order.orderId, 29, 1);
      expect(addResult.isSuccess, true);

      // Manually set database OpenedAt to 300s ago to bypass SpeedAnomaly rule
      await Supabase.instance.client
          .from('Orders')
          .update({'OpenedAt': DateTime.now().subtract(const Duration(seconds: 300)).toIso8601String()})
          .eq('OrderId', order.orderId);

      // Normal session duration (300s), but simulate anomalous item removals
      final tracker = AiTracker.fromRaw(
        startTime: DateTime.now().subtract(const Duration(seconds: 300)),
        voidCount: 4,
        totalAdded: 10,
        totalRemoved: 8,
        removedAfterConfirm: 8,
        hasConfirmed: true,
      );

      print('Calling checkout with AddRemoveAnomaly tracker...');
      final checkoutResult = await invoiceService.checkout(
        orderId: order.orderId,
        accountId: 5,
        tableId: 1,
        paymentMethod: 0,
        tracker: tracker,
      );

      expect(checkoutResult.isSuccess, true);
      final resp = checkoutResult.data!;
      print('AddRemoveAnomaly Alert: ${resp.aiAlert?.toJson()}');
    });

    test('InvoiceService - checkout and AI prediction (FrequentCancellation)', () async {
      final orderService = OrderService();
      final invoiceService = InvoiceService();
      
      final orderResult = await orderService.createOrder(tableId: 1, accountId: 5);
      expect(orderResult.isSuccess, true);
      final order = orderResult.data!;

      final addResult = await orderService.addItem(order.orderId, 29, 1);
      expect(addResult.isSuccess, true);

      // Manually set database OpenedAt to 300s ago to bypass SpeedAnomaly rule
      await Supabase.instance.client
          .from('Orders')
          .update({'OpenedAt': DateTime.now().subtract(const Duration(seconds: 300)).toIso8601String()})
          .eq('OrderId', order.orderId);

      // Normal session duration (300s), but high number of void/cancellation count
      final tracker = AiTracker.fromRaw(
        startTime: DateTime.now().subtract(const Duration(seconds: 300)),
        voidCount: 8, // High void count
        totalAdded: 5,
        totalRemoved: 0,
        removedAfterConfirm: 0,
        hasConfirmed: true,
        cancelRate: 0.60, // 60% cancellation rate
      );

      print('Calling checkout with FrequentCancellation tracker...');
      final checkoutResult = await invoiceService.checkout(
        orderId: order.orderId,
        accountId: 5,
        tableId: 1,
        paymentMethod: 0,
        tracker: tracker,
      );

      expect(checkoutResult.isSuccess, true);
      final resp = checkoutResult.data!;
      print('FrequentCancellation Alert: ${resp.aiAlert?.toJson()}');
    });
  });
}
