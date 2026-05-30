class LoginResponse {
  final String token;
  final int accountId;
  final String username;
  final String fullName;
  final int role; // 0=Owner, 1=Manager, 2=Staff
  final int? branchId;
  final String? avatar;

  LoginResponse({
    required this.token,
    required this.accountId,
    required this.username,
    required this.fullName,
    required this.role,
    this.branchId,
    this.avatar,
  });

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    return LoginResponse(
      token: json['token'] as String,
      accountId: json['accountId'] as int,
      username: json['username'] as String,
      fullName: json['fullName'] as String,
      role: json['role'] as int,
      branchId: json['branchId'] as int?,
      avatar: json['avatar'] as String?,
    );
  }
}
