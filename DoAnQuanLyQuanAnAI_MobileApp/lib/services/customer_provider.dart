import 'package:flutter/material.dart';
import 'package:doanquanlyquananai_mobileapp/models/customer/customer.dart';
import 'package:doanquanlyquananai_mobileapp/models/customer/voucher.dart';
import 'package:doanquanlyquananai_mobileapp/models/customer/point_reward.dart';
import 'package:doanquanlyquananai_mobileapp/models/customer/point_transaction.dart';
import 'package:doanquanlyquananai_mobileapp/services/customer_service.dart';
import 'package:doanquanlyquananai_mobileapp/services/discount_service.dart';
import 'package:doanquanlyquananai_mobileapp/models/discount/discount_campaign.dart';

class CustomerProvider with ChangeNotifier {
  final CustomerService _customerSvc = CustomerService();
  final DiscountService _discountSvc = DiscountService();

  Customer? _currentCustomer;
  List<PointReward> _rewards = [];
  final List<Voucher> _activeVouchers = [];
  List<DiscountCampaign> _activeCampaigns = [];
  List<PointTransaction> _transactions = [];
  bool _isLoading = false;
  String _error = '';

  Customer? get currentCustomer => _currentCustomer;
  List<PointReward> get rewards => _rewards;
  List<Voucher> get activeVouchers => _activeVouchers;
  List<DiscountCampaign> get activeCampaigns => _activeCampaigns;
  List<PointTransaction> get transactions => _transactions;
  bool get isLoading => _isLoading;
  String get error => _error;

  void clearError() {
    _error = '';
    notifyListeners();
  }

  // ── Profile fetching ─────────────────────────────────────────────────────

  Future<void> fetchCustomerProfile(int customerId) async {
    _isLoading = true;
    _error = '';
    notifyListeners();

    final result = await _customerSvc.getById(customerId);
    if (result.isSuccess && result.data != null) {
      _currentCustomer = result.data!['customer'] as Customer;
      _activeVouchers
        ..clear()
        ..addAll(result.data!['vouchers'] as List<Voucher>);
    } else {
      _error = result.error ?? 'Failed to load profile';
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> fetchCustomerProfileByIdentifier(String identifier) async {
    _isLoading = true;
    _error = '';
    notifyListeners();

    final result = await _customerSvc.findByIdentifier(identifier);
    if (result.isSuccess && result.data != null) {
      _currentCustomer = result.data;

      // Fetch vouchers by calling getById
      final fullProfile = await _customerSvc.getById(_currentCustomer!.customerId);
      if (fullProfile.isSuccess && fullProfile.data != null) {
        _activeVouchers
          ..clear()
          ..addAll(fullProfile.data!['vouchers'] as List<Voucher>);
      }
    } else {
      _error = result.isSuccess ? 'Không tìm thấy hồ sơ khách hàng' : (result.error ?? 'Failed to load profile');
      _currentCustomer = null;
      _activeVouchers.clear();
    }

    _isLoading = false;
    notifyListeners();
  }

  // ── Rewards ──────────────────────────────────────────────────────────────

  Future<void> fetchRewards() async {
    final result = await _customerSvc.getRewards();
    if (result.isSuccess) {
      _rewards = result.data ?? [];
      notifyListeners();
    }
  }

  Future<void> fetchActiveCampaigns() async {
    final result = await _discountSvc.getCampaigns();
    if (result.isSuccess) {
      final now = DateTime.now();
      _activeCampaigns = (result.data ?? []).where((c) {
        final effectiveEnd = DateTime(
          c.endDate.year,
          c.endDate.month,
          c.endDate.day,
          23,
          59,
          59,
        );
        return c.isActive &&
            !now.isBefore(c.startDate) &&
            !now.isAfter(effectiveEnd);
      }).toList();
      notifyListeners();
    }
  }

  // ── Redeem reward → voucher ───────────────────────────────────────────────

  Future<void> redeemReward(int rewardId) async {
    if (_currentCustomer == null) return;

    _isLoading = true;
    _error = '';
    notifyListeners();

    final result = await _customerSvc.redeemPoints(_currentCustomer!.customerId, rewardId);
    if (result.isSuccess) {
      // Refresh profile to update points + vouchers
      await fetchCustomerProfile(_currentCustomer!.customerId);
    } else {
      _error = result.error ?? 'Redeem failed';
    }

    _isLoading = false;
    notifyListeners();
  }

  // ── QR Token redemption ───────────────────────────────────────────────────

  Future<void> redeemQrToken(String token) async {
    if (_currentCustomer == null) return;

    _error = '';
    _isLoading = true;
    notifyListeners();

    final result = await _customerSvc.redeemQrToken(_currentCustomer!.customerId, token);
    if (result.isSuccess) {
      // Refresh profile to update points
      await fetchCustomerProfile(_currentCustomer!.customerId);
      await fetchTransactions();
    } else {
      _error = result.error ?? 'Mã không hợp lệ hoặc đã được sử dụng';
    }

    _isLoading = false;
    notifyListeners();
  }

  // ── Point transaction history ─────────────────────────────────────────────

  Future<void> fetchTransactions() async {
    if (_currentCustomer == null) return;

    final result = await _customerSvc.getTransactions(_currentCustomer!.customerId);
    if (result.isSuccess) {
      _transactions = result.data ?? [];
      notifyListeners();
    }
  }
}
