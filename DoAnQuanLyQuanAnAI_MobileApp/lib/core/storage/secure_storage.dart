import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorage {
  static const _storage = FlutterSecureStorage();

  static const _keyToken = 'auth_token';
  static const _keyUserId = 'user_id';
  static const _keyRole = 'user_role';
  static const _keyBranchId = 'branch_id';

  static Future<void> saveToken(String token) async {
    await _storage.write(key: _keyToken, value: token);
  }

  static Future<String?> getToken() async {
    return await _storage.read(key: _keyToken);
  }

  static Future<void> saveUserId(String userId) async {
    await _storage.write(key: _keyUserId, value: userId);
  }

  static Future<String?> getUserId() async {
    return await _storage.read(key: _keyUserId);
  }

  static Future<void> saveRole(String role) async {
    await _storage.write(key: _keyRole, value: role);
  }

  static Future<String?> getRole() async {
    return await _storage.read(key: _keyRole);
  }

  static Future<void> saveBranchId(String branchId) async {
    await _storage.write(key: _keyBranchId, value: branchId);
  }

  static Future<String?> getBranchId() async {
    return await _storage.read(key: _keyBranchId);
  }

  static Future<void> clearAll() async {
    await _storage.deleteAll();
  }
}
