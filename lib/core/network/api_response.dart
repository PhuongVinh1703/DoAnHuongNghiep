/// Generic wrapper cho kết quả API — tránh try/catch rải rác trong UI
class ApiResult<T> {
  final T? data;
  final String? error;
  final bool isSuccess;

  const ApiResult._({this.data, this.error, required this.isSuccess});

  factory ApiResult.success(T data) =>
      ApiResult._(data: data, isSuccess: true);

  factory ApiResult.failure(String error) =>
      ApiResult._(error: error, isSuccess: false);

  bool get isFailure => !isSuccess;

  /// Xử lý kết quả kiểu functional
  R fold<R>({
    required R Function(T data) onSuccess,
    required R Function(String error) onFailure,
  }) {
    if (isSuccess) {
      // Dart allows null to be cast to void or nullable types.
      // If T is non-nullable and data is null, it will throw a type error, which is correct.
      return onSuccess(data as T);
    }
    return onFailure(error ?? 'Lỗi không xác định');
  }

  @override
  String toString() => isSuccess
      ? 'ApiResult.success($data)'
      : 'ApiResult.failure($error)';
}

/// Dạng paged response phổ biến trong API
class PagedResponse<T> {
  final List<T> data;
  final int totalCount;
  final int page;
  final int pageSize;

  const PagedResponse({
    required this.data,
    required this.totalCount,
    required this.page,
    required this.pageSize,
  });

  bool get hasMore => (page * pageSize) < totalCount;

  factory PagedResponse.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    final rawList = json['data'] as List? ?? [];
    return PagedResponse(
      data: rawList.map((e) => fromJson(e as Map<String, dynamic>)).toList(),
      totalCount: json['totalCount'] ?? rawList.length,
      page: json['page'] ?? 1,
      pageSize: json['pageSize'] ?? rawList.length,
    );
  }
}
