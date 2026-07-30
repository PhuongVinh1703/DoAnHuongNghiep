import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:doanquanlyquananai_mobileapp/config/constants.dart';
import 'package:doanquanlyquananai_mobileapp/models/auth/login_response.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:doanquanlyquananai_mobileapp/core/utils/error_handler.dart';

class AuthService extends ChangeNotifier {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final _db = Supabase.instance.client;

  LoginResponse? _currentUser;
  bool _isLoading = false;
  String? _errorMessage;

  LoginResponse? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get isLoggedIn => _currentUser != null;
  String? get errorMessage => _errorMessage;


  Future<bool> login(String username, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // 1. Tìm account theo username
      final rows = await _db
          .from('Accounts')
          .select()
          .eq('Username', username)
          .eq('IsActive', true)
          .limit(1);

      if (rows.isEmpty) {
        _errorMessage = 'Tài khoản không tồn tại hoặc đã bị khóa.';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      final account = rows.first;
      final storedHash = account['PasswordHash'] as String;

      // 2. Verify BCrypt qua Supabase RPC (PostgreSQL extension pgcrypto)
      final verifyResult = await _db.rpc('verify_password', params: {
        'plain_password': password,
        'hashed_password': storedHash,
      });

      final isValid = verifyResult == true;
      if (!isValid) {
        _errorMessage = 'Mật khẩu không đúng.';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // 3. Tạo LoginResponse từ data
      _currentUser = LoginResponse(
        token: 'supabase-direct-${account['AccountId']}',
        accountId: account['AccountId'] as int,
        username: account['Username'] as String,
        fullName: account['FullName'] as String,
        role: account['Role'] as int,
        branchId: account['BranchId'] as int?,
        avatar: account['Avatar'] as String?,
      );

      // 4. Lưu vào secure storage
      await _storage.write(key: AppConstants.tokenKey,    value: _currentUser!.token);
      await _storage.write(key: AppConstants.userIdKey,   value: _currentUser!.accountId.toString());
      await _storage.write(key: AppConstants.userRoleKey, value: _currentUser!.role.toString());
      await _storage.write(key: AppConstants.userNameKey, value: _currentUser!.username);
      await _storage.write(key: AppConstants.fullNameKey, value: _currentUser!.fullName);
      if (_currentUser!.branchId != null) {
        await _storage.write(key: AppConstants.branchIdKey, value: _currentUser!.branchId.toString());
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = ErrorHandler.formatError(e);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Đăng xuất
  Future<void> logout() async {
    await _storage.deleteAll();
    _currentUser = null;
    notifyListeners();
  }

  /// Kiểm tra token đã lưu (tự đăng nhập)
  Future<bool> tryAutoLogin() async {
    final token = await _storage.read(key: AppConstants.tokenKey);
    if (token == null) return false;

    final accountId = await _storage.read(key: AppConstants.userIdKey);
    final role      = await _storage.read(key: AppConstants.userRoleKey);
    final username  = await _storage.read(key: AppConstants.userNameKey);
    final fullName  = await _storage.read(key: AppConstants.fullNameKey);
    final branchId  = await _storage.read(key: AppConstants.branchIdKey);

    if (accountId == null || role == null || username == null || fullName == null) {
      return false;
    }

    _currentUser = LoginResponse(
      token:     token,
      accountId: int.parse(accountId),
      username:  username,
      fullName:  fullName,
      role:      int.parse(role),
      branchId:  branchId != null ? int.parse(branchId) : null,
    );
    notifyListeners();
    return true;
  }

  /// Đổi mật khẩu (qua RPC)
  Future<bool> changePassword({
    required int accountId,
    required String oldPassword,
    required String newPassword,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _db.rpc('change_account_password', params: {
        'p_account_id':   accountId,
        'p_old_password': oldPassword,
        'p_new_password': newPassword,
      });
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = ErrorHandler.formatError(e);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Xác thực mã OTP bằng cách thử qua các loại (signup, magiclink, recovery) để đảm bảo tương thích mọi template
  Future<bool> verifyOtp(String email, String token) async {
    try {
      final res = await _db.auth.verifyOTP(
        email: email,
        token: token,
        type: OtpType.signup,
      );
      if (res.user != null) return true;
    } catch (_) {}

    try {
      final res = await _db.auth.verifyOTP(
        email: email,
        token: token,
        type: OtpType.magiclink,
      );
      if (res.user != null) return true;
    } catch (_) {}

    try {
      final res = await _db.auth.verifyOTP(
        email: email,
        token: token,
        type: OtpType.recovery,
      );
      if (res.user != null) return true;
    } catch (_) {}

    return false;
  }

  /// Đăng ký tài khoản khách mới kèm xác thực OTP
  Future<bool> register({
    required String fullName,
    required String username,
    required String password,
    String? phone,
    String? email,
    required String otp,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // 1. Kiểm tra xem username đã tồn tại chưa
      final existUsername = await _db
          .from('Accounts')
          .select('AccountId')
          .eq('Username', username)
          .maybeSingle();

      if (existUsername != null) {
        _errorMessage = 'Tên đăng nhập đã tồn tại.';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // 2. Xác thực mã OTP
      if (email != null && email.isNotEmpty) {
        final otpValid = await verifyOtp(email, otp);
        if (!otpValid) {
          _errorMessage = 'Mã OTP không chính xác hoặc đã hết hạn.';
          _isLoading = false;
          notifyListeners();
          return false;
        }
      }

      // 3. Gọi RPC register_customer để mã hóa BCrypt password và tạo account + profile
      await _db.rpc('register_customer', params: {
        'p_username': username,
        'p_password': password,
        'p_fullname': fullName,
        'p_phone':    phone ?? '',
        'p_email':    email ?? '',
      });

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = ErrorHandler.formatError(e);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Gửi OTP qua Email dùng Supabase Auth SMTP
  Future<bool> sendOtp(String email) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _db.auth.signInWithOtp(
        email: email,
        shouldCreateUser: true,
      );
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = ErrorHandler.formatError(e);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Đặt lại mật khẩu bằng OTP
  Future<bool> resetPassword({
    required String email,
    required String newPassword,
    required String otp,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // 1. Xác thực mã OTP
      final otpValid = await verifyOtp(email, otp);
      if (!otpValid) {
        _errorMessage = 'Mã OTP không chính xác hoặc đã hết hạn.';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // 2. Gọi RPC reset_account_password để cập nhật băm BCrypt mới
      await _db.rpc('reset_account_password', params: {
        'p_email':        email,
        'p_new_password': newPassword,
      });

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = ErrorHandler.formatError(e);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Cập nhật tên hiển thị trong cache
  Future<void> updateCachedFullName(String newName) async {
    if (_currentUser != null) {
      _currentUser = LoginResponse(
        token:     _currentUser!.token,
        accountId: _currentUser!.accountId,
        username:  _currentUser!.username,
        fullName:  newName,
        role:      _currentUser!.role,
        branchId:  _currentUser!.branchId,
        avatar:    _currentUser!.avatar,
      );
      await _storage.write(key: AppConstants.fullNameKey, value: newName);
      notifyListeners();
    }
  }
}
