import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../config/env.dart';
import 'api_exception.dart';
import 'token_storage.dart';

class ApiClient {
  ApiClient(this._tokens)
    : dio = Dio(
        BaseOptions(
          baseUrl: Env.apiBaseUrl,
          connectTimeout: const Duration(seconds: 15),
          // Photo uploads over a weak mobile connection need more room.
          receiveTimeout: const Duration(seconds: 60),
          sendTimeout: const Duration(seconds: 60),
          // X-Client: mobile makes /admin/auth/login return the token in the body instead of a cookie.
          headers: {'Accept': 'application/json', 'X-Client': 'mobile'},
        ),
      ) {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _tokens.read();
          if (token != null && !options.headers.containsKey('Authorization')) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (error, handler) {
          if (error.response?.statusCode == 401) unauthorized.value++;
          handler.next(_mapError(error));
        },
      ),
    );
  }

  final Dio dio;
  final TokenStorage _tokens;

  /// Bumped on every 401 so the auth state can drop the expired session.
  static final ValueNotifier<int> unauthorized = ValueNotifier(0);

  DioException _mapError(DioException error) {
    final data = error.response?.data;
    if (data is Map<String, dynamic>) {
      final errors = data['errors'];
      return error.copyWith(
        error: ApiException(
          data['message']?.toString() ?? 'Terjadi kesalahan sistem.',
          statusCode: error.response?.statusCode,
          errors: errors is Map<String, dynamic> ? errors : null,
        ),
      );
    }

    final message = switch (error.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.receiveTimeout ||
      DioExceptionType.sendTimeout => 'Server tidak merespons. Coba lagi.',
      DioExceptionType.connectionError => 'Tidak dapat terhubung ke server.',
      _ => 'Terjadi kesalahan sistem.',
    };
    return error.copyWith(error: ApiException(message, statusCode: error.response?.statusCode));
  }
}
