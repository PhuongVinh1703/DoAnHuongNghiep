import 'package:doanquanlyquananai_mobileapp/core/network/api_response.dart';
import 'package:doanquanlyquananai_mobileapp/models/customer/customer.dart';
import 'package:doanquanlyquananai_mobileapp/models/customer/voucher.dart';
import 'package:doanquanlyquananai_mobileapp/models/customer/point_transaction.dart';
import 'package:doanquanlyquananai_mobileapp/models/customer/point_reward.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CustomerService {
  final _db = Supabase.instance.client;

  Future<ApiResult<List<Customer>>> searchCustomers({
    String? search,
    int page = 1,
  }) async {
    try {
      var query = _db.from('Customers').select();
      if (search != null && search.isNotEmpty) {
        query = query.or('FullName.ilike.%$search%,Phone.ilike.%$search%');
      }
      final pageSize = 20;
      final from = (page - 1) * pageSize;
      final to = from + pageSize - 1;
      final res = await query.order('FullName').range(from, to);
      final list = (res as List).map((e) => Customer.fromJson(e)).toList();
      return ApiResult.success(list);
    } catch (e) {
      return ApiResult.failure('Lỗi tìm kiếm khách hàng: $e');
    }
  }

  Future<ApiResult<Map<String, dynamic>>> getById(int id) async {
    try {
      final customerData = await _db
          .from('Customers')
          .select()
          .eq('CustomerId', id)
          .single();

      final rawVouchers = await _db
          .from('CustomerVouchers')
          .select('*, PointRewards(*)')
          .eq('CustomerId', id)
          .eq('IsUsed', false)
          .gt('ExpiresAt', DateTime.now().toIso8601String());

      return ApiResult.success({
        'customer': Customer.fromJson(customerData),
        'vouchers': (rawVouchers as List)
            .map((e) => Voucher.fromJson(e))
            .toList(),
      });
    } catch (e) {
      return ApiResult.failure('Lỗi lấy thông tin khách hàng: $e');
    }
  }

  Future<ApiResult<Customer?>> findByPhone(String phone) async {
    try {
      final res = await _db
          .from('Customers')
          .select()
          .eq('Phone', phone)
          .maybeSingle();
      if (res == null) return ApiResult.success(null);
      return ApiResult.success(Customer.fromJson(res));
    } catch (e) {
      return ApiResult.failure('Lỗi tìm khách hàng theo SĐT: $e');
    }
  }

  Future<ApiResult<Customer?>> findByIdentifier(String identifier) async {
    try {
      // 1. Thử tìm trực tiếp bằng Phone hoặc SerialCode trong bảng Customers
      var res = await _db
          .from('Customers')
          .select()
          .or('Phone.eq.$identifier,SerialCode.eq.$identifier')
          .maybeSingle();
      
      if (res != null) {
        return ApiResult.success(Customer.fromJson(res));
      }

      // 2. Nếu không tìm thấy, thử tìm Account có Username = identifier để lấy Phone
      final accRes = await _db
          .from('Accounts')
          .select('Phone')
          .eq('Username', identifier)
          .maybeSingle();

      if (accRes != null) {
        final phone = accRes['Phone'] as String?;
        if (phone != null && phone.isNotEmpty) {
          res = await _db
              .from('Customers')
              .select()
              .eq('Phone', phone)
              .maybeSingle();
          if (res != null) {
            return ApiResult.success(Customer.fromJson(res));
          }
        }
      }

      return ApiResult.success(null);
    } catch (e) {
      return ApiResult.failure('Lỗi tìm khách hàng theo mã/SĐT/Username: $e');
    }
  }

  Future<ApiResult<Customer?>> findBySerial(String code) async {
    try {
      final res = await _db
          .from('Customers')
          .select()
          .eq('SerialCode', code)
          .maybeSingle();
      if (res == null) return ApiResult.success(null);
      return ApiResult.success(Customer.fromJson(res));
    } catch (e) {
      return ApiResult.failure('Lỗi tìm khách hàng theo Serial: $e');
    }
  }

  Future<ApiResult<Customer>> createCustomer({
    required String fullName,
    required String phone,
    String? email,
  }) async {
    try {
      final res = await _db.from('Customers').insert({
        'FullName': fullName,
        'Phone': phone,
        'Email': email,
        'SerialCode': 'KH-${(DateTime.now().millisecondsSinceEpoch % 1000000).toString().padLeft(6, '0')}',
        'LoyaltyPoints': 0,
        'Tier': 0,
        'IsActive': true,
        'CreatedAt': DateTime.now().toIso8601String(),
      }).select().single();
      return ApiResult.success(Customer.fromJson(res));
    } catch (e) {
      return ApiResult.failure('Lỗi tạo khách hàng mới: $e');
    }
  }

  Future<ApiResult<Customer>> updateCustomer(int id, {
    String? fullName,
    String? phone,
    String? email,
  }) async {
    try {
      final data = <String, dynamic>{};
      if (fullName != null) data['FullName'] = fullName;
      if (phone != null) data['Phone'] = phone;
      if (email != null) data['Email'] = email;
      final res = await _db
          .from('Customers')
          .update(data)
          .eq('CustomerId', id)
          .select()
          .single();
      return ApiResult.success(Customer.fromJson(res));
    } catch (e) {
      return ApiResult.failure('Lỗi cập nhật khách hàng: $e');
    }
  }

  Future<ApiResult<void>> toggleStatus(int id) async {
    try {
      final current = await _db
          .from('Customers')
          .select('IsActive')
          .eq('CustomerId', id)
          .single();
      final newStatus = !(current['IsActive'] as bool);
      await _db
          .from('Customers')
          .update({'IsActive': newStatus})
          .eq('CustomerId', id);
      return ApiResult.success(null);
    } catch (e) {
      return ApiResult.failure('Lỗi thay đổi trạng thái khách hàng: $e');
    }
  }

  Future<ApiResult<List<PointTransaction>>> getTransactions(int customerId, {int page = 1}) async {
    try {
      final pageSize = 20;
      final from = (page - 1) * pageSize;
      final to = from + pageSize - 1;
      final res = await _db
          .from('PointTransactions')
          .select()
          .eq('CustomerId', customerId)
          .order('CreatedAt', ascending: false)
          .range(from, to);
      final list = (res as List).map((e) => PointTransaction.fromJson(e)).toList();
      return ApiResult.success(list);
    } catch (e) {
      return ApiResult.failure('Lỗi tải lịch sử giao dịch điểm: $e');
    }
  }

  Future<ApiResult<List<PointReward>>> getRewards() async {
    try {
      final res = await _db
          .from('PointRewards')
          .select()
          .eq('IsActive', true)
          .order('PointCost');
      final list = (res as List).map((e) => PointReward.fromJson(e)).toList();
      return ApiResult.success(list);
    } catch (e) {
      return ApiResult.failure('Lỗi tải danh sách đổi thưởng: $e');
    }
  }

  Future<ApiResult<Voucher>> redeemPoints(int customerId, int rewardId) async {
    try {
      // 1. Lấy thông tin phần thưởng & điểm khách hàng
      final reward = await _db.from('PointRewards').select().eq('RewardId', rewardId).single();
      final cust = await _db.from('Customers').select('LoyaltyPoints').eq('CustomerId', customerId).single();

      final cost = reward['PointCost'] as int;
      final points = cust['LoyaltyPoints'] as int;

      if (points < cost) {
        return ApiResult.failure('Không đủ điểm để đổi phần thưởng này.');
      }

      // 2. Tạo mã Voucher
      final code = 'VOU-${(DateTime.now().millisecondsSinceEpoch % 1000000).toString().padLeft(6, '0')}';
      final expiresAt = DateTime.now().add(Duration(days: reward['ValidDays'] as int));

      // 3. Trừ điểm khách hàng và chèn Voucher
      final updatedPoints = points - cost;
      await _db.from('Customers').update({
        'LoyaltyPoints': updatedPoints,
        'Tier': Customer.calculateTier(updatedPoints),
      }).eq('CustomerId', customerId);

      final newVoucher = await _db.from('CustomerVouchers').insert({
        'CustomerId': customerId,
        'RewardId': rewardId,
        'Code': code,
        'DiscountPercent': (reward['DiscountPercent'] as num).toDouble(),
        'MinOrderAmount': (reward['MinOrderAmount'] as num).toDouble(),
        'PointSpent': cost,
        'IssuedAt': DateTime.now().toIso8601String(),
        'ExpiresAt': expiresAt.toIso8601String(),
        'IsUsed': false,
      }).select().single();

      // 4. Ghi nhận giao dịch điểm
      await _db.from('PointTransactions').insert({
        'CustomerId': customerId,
        'PointDelta': -cost,
        'Note': 'Đổi điểm lấy Voucher: ${reward['Name']}',
        'CreatedAt': DateTime.now().toIso8601String(),
      });

      return ApiResult.success(Voucher.fromJson(newVoucher));
    } catch (e) {
      return ApiResult.failure('Lỗi đổi điểm: $e');
    }
  }

  /// Đổi mã QR token hoặc mã QR hóa đơn ('INVOICE:INV-...') lấy điểm
  Future<ApiResult<void>> redeemQrToken(int customerId, String token) async {
    try {
      final cleanToken = token.trim();

      // Hỗ trợ quét trực tiếp mã QR trên hóa đơn vãng lai (định dạng INVOICE:INV-xxx)
      if (cleanToken.toUpperCase().startsWith('INVOICE:') ||
          cleanToken.toUpperCase().startsWith('INV-')) {
        final invoiceNo = cleanToken.toUpperCase().startsWith('INVOICE:')
            ? cleanToken.substring('INVOICE:'.length).trim()
            : cleanToken;
        final inv = await _db
            .from('Invoices')
            .select('InvoiceId, InvoiceNo, TotalAmount, CustomerId')
            .eq('InvoiceNo', invoiceNo)
            .maybeSingle();

        if (inv == null) {
          return ApiResult.failure('Không tìm thấy hóa đơn $invoiceNo.');
        }
        if (inv['CustomerId'] != null) {
          return ApiResult.failure('Hóa đơn này đã được tích điểm trước đó.');
        }

        final totalAmount = (inv['TotalAmount'] as num? ?? 0).toDouble();
        final earnedPoints = (totalAmount / 100000).floor().clamp(1, 100000);

        final cust = await _db
            .from('Customers')
            .select('LoyaltyPoints')
            .eq('CustomerId', customerId)
            .single();
        final currentPoints = cust['LoyaltyPoints'] as int? ?? 0;
        final updatedPoints = currentPoints + earnedPoints;

        await _db.from('Customers').update({
          'LoyaltyPoints': updatedPoints,
          'Tier': Customer.calculateTier(updatedPoints),
        }).eq('CustomerId', customerId);

        await _db.from('Invoices').update({
          'CustomerId': customerId,
        }).eq('InvoiceId', inv['InvoiceId']);

        await _db.from('PointTransactions').insert({
          'CustomerId': customerId,
          'PointDelta': earnedPoints,
          'Note': 'Tích điểm từ hóa đơn $invoiceNo',
          'QrToken': cleanToken,
          'QrRedeemedAt': DateTime.now().toIso8601String(),
          'CreatedAt': DateTime.now().toIso8601String(),
        });

        return ApiResult.success(null);
      }

      // 1. Tìm transaction theo QrToken chuẩn
      final tx = await _db
          .from('PointTransactions')
          .select()
          .eq('QrToken', cleanToken)
          .maybeSingle();

      if (tx == null) {
        return ApiResult.failure('Mã tích điểm không hợp lệ.');
      }
      if (tx['QrRedeemedAt'] != null) {
        return ApiResult.failure('Mã tích điểm này đã được sử dụng.');
      }
      final expiresAtStr = tx['QrExpiresAt'] as String?;
      if (expiresAtStr != null && DateTime.parse(expiresAtStr).isBefore(DateTime.now())) {
        return ApiResult.failure('Mã tích điểm đã hết hạn.');
      }

      final delta = tx['PointDelta'] as int;

      // 2. Cộng điểm cho khách hàng
      final cust = await _db
          .from('Customers')
          .select('LoyaltyPoints')
          .eq('CustomerId', customerId)
          .single();
      final currentPoints = cust['LoyaltyPoints'] as int;

      final updatedPoints = currentPoints + delta;
      await _db
          .from('Customers')
          .update({
            'LoyaltyPoints': updatedPoints,
            'Tier': Customer.calculateTier(updatedPoints),
          })
          .eq('CustomerId', customerId);

      // 3. Cập nhật transaction QR đã đổi
      await _db.from('PointTransactions').update({
        'CustomerId': customerId,
        'QrRedeemedAt': DateTime.now().toIso8601String(),
      }).eq('QrToken', token);

      return ApiResult.success(null);
    } catch (e) {
      return ApiResult.failure('Lỗi đổi mã tích điểm: $e');
    }
  }

  /// Kiểm tra voucher có hợp lệ không
  Future<ApiResult<Voucher>> validateVoucher(String code, double subtotal, {int? customerId}) async {
    try {
      final res = await _db
          .from('CustomerVouchers')
          .select('*, PointRewards(*)')
          .eq('Code', code)
          .eq('IsUsed', false)
          .gt('ExpiresAt', DateTime.now().toIso8601String())
          .maybeSingle();

      if (res == null) {
        return ApiResult.failure('Mã Voucher không tồn tại hoặc đã sử dụng / hết hạn.');
      }

      if (customerId != null && res['CustomerId'] != null && res['CustomerId'] != customerId) {
        return ApiResult.failure('Voucher này thuộc về tài khoản khách hàng khác.');
      }
      final voucher = Voucher.fromJson(res);
      if (subtotal < voucher.minSubtotal) {
        return ApiResult.failure('Đơn hàng chưa đạt giá trị tối thiểu để áp dụng Voucher này (Yêu cầu tối thiểu: ${voucher.minSubtotal}).');
      }

      return ApiResult.success(voucher);
    } catch (e) {
      return ApiResult.failure('Lỗi xác thực Voucher: $e');
    }
  }
}
