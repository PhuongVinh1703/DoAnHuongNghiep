import 'dart:io';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/foundation.dart';
import '../storage/secure_storage.dart';
import '../constants/api_constants.dart';

class ApiClient {
  static ApiClient? _instance;
  late final Dio _dio;
  
  ApiClient._() {
    _dio = Dio(BaseOptions(
      baseUrl: ApiConstants.baseUrl,
      connectTimeout: ApiConstants.connectTimeout,
      receiveTimeout: ApiConstants.receiveTimeout,
      headers: {'Content-Type': 'application/json'},
    ));
    
    // Bypass self-signed SSL certificate check (for local development HTTPS)
    if (!kIsWeb) {
      _dio.httpClientAdapter = IOHttpClientAdapter(
        createHttpClient: () {
          final client = HttpClient();
          client.badCertificateCallback = (X509Certificate cert, String host, int port) => true;
          return client;
        },
      );
    }
    
    _dio.interceptors.addAll([
      _AuthInterceptor(),
      if (kDebugMode) LogInterceptor(requestBody: true, responseBody: true),
    ]);
  }
  
  static ApiClient get instance => _instance ??= ApiClient._();
  
  Future<Response> get(String path, {Map<String, dynamic>? params}) =>
    _dio.get(path, queryParameters: params);
  
  Future<Response> post(String path, {dynamic data}) =>
    _dio.post(path, data: data);
  
  Future<Response> patch(String path, {dynamic data}) =>
    _dio.patch(path, data: data);
  
  Future<Response> put(String path, {dynamic data}) =>
    _dio.put(path, data: data);
  
  Future<Response> delete(String path) =>
    _dio.delete(path);
}

class _AuthInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    final token = await SecureStorage.getToken();
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode == 401) {
      await SecureStorage.clearAll();
      // Navigate to login handled outside or via stream
    }
    handler.next(err);
  }
}
