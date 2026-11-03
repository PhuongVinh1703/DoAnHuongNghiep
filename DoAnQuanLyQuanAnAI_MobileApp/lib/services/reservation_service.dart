import 'package:doanquanlyquananai_mobileapp/core/network/api_response.dart';
import 'package:doanquanlyquananai_mobileapp/models/reservation/reservation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ReservationService {
  final _db = Supabase.instance.client;

  Future<ApiResult<List<Reservation>>> getReservations({
    int? status,
    int? branchId,
    int page = 1,
  }) async {
    try {
      var query = _db.from('Reservations').select('*, Customers(FullName, Phone), Branches(Name)');
      if (status != null) {
        query = query.eq('Status', status);
      }
      if (branchId != null) {
        query = query.eq('BranchId', branchId);
      }
      final pageSize = 50;
      final from = (page - 1) * pageSize;
      final to = from + pageSize - 1;
      final res = await query.order('ReservedAt', ascending: false).range(from, to);
      final list = (res as List).map((e) => Reservation.fromJson(e)).toList();
      return ApiResult.success(list);
    } catch (e) {
      return ApiResult.failure('Không thể tải danh sách đặt bàn: $e');
    }
  }

  Future<ApiResult<Reservation>> getById(int id) async {
    try {
      final res = await _db
          .from('Reservations')
          .select('*, Customers(FullName, Phone), Branches(Name)')
          .eq('ReservationId', id)
          .single();
      return ApiResult.success(Reservation.fromJson(res));
    } catch (e) {
      return ApiResult.failure('Không tìm thấy đặt bàn: $e');
    }
  }

  Future<ApiResult<List<Reservation>>> getMyReservations(int customerId, {int page = 1}) async {
    try {
      final pageSize = 20;
      final from = (page - 1) * pageSize;
      final to = from + pageSize - 1;
      final res = await _db
          .from('Reservations')
          .select('*, Customers(FullName, Phone), Branches(Name)')
          .eq('CustomerId', customerId)
          .order('ReservedAt', ascending: false)
          .range(from, to);
      final list = (res as List).map((e) => Reservation.fromJson(e)).toList();
      return ApiResult.success(list);
    } catch (e) {
      return ApiResult.failure('Không thể tải lịch sử đặt bàn của bạn: $e');
    }
  }

  Future<ApiResult<Reservation>> createReservation({
    required String customerName,
    required String customerPhone,
    required int branchId,
    required int guestCount,
    required DateTime reservedAt,
    String? note,
    int? customerId,
  }) async {
    try {
      int? finalCustomerId = customerId;

      // Nếu chưa có customerId, tìm kiếm theo SĐT
      if (finalCustomerId == null) {
        final existingCust = await _db
            .from('Customers')
            .select('CustomerId')
            .eq('Phone', customerPhone)
            .maybeSingle();
        if (existingCust != null) {
          finalCustomerId = existingCust['CustomerId'] as int;
        } else {
          // Tạo mới Customer
          final newCust = await _db.from('Customers').insert({
            'FullName': customerName,
            'Phone': customerPhone,
            'SerialCode': 'KH-${upperCaseHex(DateTime.now().millisecondsSinceEpoch.toRadixString(16))}',
            'LoyaltyPoints': 0,
            'Tier': 0,
            'IsActive': true,
            'CreatedAt': DateTime.now().toIso8601String(),
          }).select('CustomerId').single();
          finalCustomerId = newCust['CustomerId'] as int;
        }
      }

      // Chặn spam đơn ảo / đặt trùng giờ (trong phạm vi ±2 giờ cùng khách hàng)
      final existingBookings = await _db
          .from('Reservations')
          .select('ReservationId, ReservedAt, Status, ManagerNote')
          .eq('CustomerId', finalCustomerId)
          .inFilter('Status', [0, 1]);

      for (final row in (existingBookings as List)) {
        final existingTime = DateTime.tryParse(row['ReservedAt']?.toString() ?? '');
        final mgrNote = row['ManagerNote']?.toString() ?? '';
        if (mgrNote.contains('[SEATED]')) continue;
        if (existingTime != null) {
          final diffMins = existingTime.difference(reservedAt).inMinutes.abs();
          if (diffMins < 120) {
            return ApiResult.failure(
              'Bạn đã có một lịch đặt bàn đang chờ hoặc đã xác nhận trong khung giờ này. Vui lòng kiểm tra mục Lịch sử đặt bàn.',
            );
          }
        }
      }

      // Tạo đặt bàn
      final resInsert = await _db.from('Reservations').insert({
        'CustomerId': finalCustomerId,
        'BranchId': branchId,
        'ReservedAt': reservedAt.toIso8601String(),
        'GuestCount': guestCount,
        'Note': note,
        'Status': 0, // Pending
        'CreatedAt': DateTime.now().toIso8601String(),
      }).select('ReservationId').single();

      final newId = resInsert['ReservationId'] as int;

      // Query ngược lại đầy đủ thông tin kèm joins để trả về cho UI
      final fullRes = await getById(newId);
      if (fullRes.isSuccess && fullRes.data != null) {
        return ApiResult.success(fullRes.data!);
      } else {
        return ApiResult.failure(fullRes.error ?? 'Lỗi truy vấn đặt bàn sau khi tạo.');
      }
    } catch (e) {
      return ApiResult.failure('Lỗi đặt bàn: $e');
    }
  }

  Future<ApiResult<void>> updateStatus(int id, int status, {String? managerNote}) async {
    try {
      final data = <String, dynamic>{
        'Status': status,
        'RespondedAt': DateTime.now().toIso8601String(),
      };
      if (managerNote != null) {
        data['ManagerNote'] = managerNote;
      }
      await _db.from('Reservations').update(data).eq('ReservationId', id);
      return ApiResult.success(null);
    } catch (e) {
      return ApiResult.failure('Không thể cập nhật trạng thái: $e');
    }
  }

  Future<ApiResult<void>> cancelReservation(int id) async {
    try {
      // Nếu phiếu đặt bàn đã được gán bàn và bàn đang ở trạng thái Đã đặt (2), giải phóng bàn về Trống (0)
      try {
        final currentRes = await getById(id);
        final tableId = currentRes.data?.assignedTableId;
        if (tableId != null) {
          final tbl = await _db
              .from('DiningTables')
              .select('Status')
              .eq('TableId', tableId)
              .maybeSingle();
          if (tbl != null && tbl['Status'] == 2) {
            await _db
                .from('DiningTables')
                .update({'Status': 0})
                .eq('TableId', tableId);
          }
        }
      } catch (_) {}

      await _db.from('Reservations').update({
        'Status': 3, // Cancelled
        'RespondedAt': DateTime.now().toIso8601String(),
      }).eq('ReservationId', id);
      return ApiResult.success(null);
    } catch (e) {
      return ApiResult.failure('Không thể hủy đặt bàn: $e');
    }
  }

  String upperCaseHex(String val) {
    return val.toUpperCase();
  }
}
