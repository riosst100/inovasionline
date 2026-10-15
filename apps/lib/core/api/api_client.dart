import 'package:dio/dio.dart';
import '../../config/env.dart';
import '../storage/token_storage.dart';
import 'account_block.dart';
import 'api_exception.dart';

class ApiClient {
  ApiClient(this._tokenStorage) : dio = Dio(
          BaseOptions(
            baseUrl: Env.apiBaseUrl,
            headers: {
              'Accept': 'application/json',
              'X-Client': 'mobile',
            },
          ),
        ) {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _tokenStorage.readToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (error, handler) {
          handler.next(_mapError(error));
        },
      ),
    );
  }

  final Dio dio;
  final TokenStorage _tokenStorage;

  DioException _mapError(DioException error) {
    final data = error.response?.data;
    if (data is Map<String, dynamic>) {
      if (error.response?.statusCode == 403 &&
          data['code'] == 'FEATURE_BANNED') {
        final info = data['data'] as Map<String, dynamic>?;
        AccountBlock.featureBan.value = FeatureBanInfo(
          feature: info?['feature'] as String? ?? '',
          reason: info?['ban_reason'] as String?,
          contactUrl: info?['contact_url'] as String?,
        );
      }
      if (error.response?.statusCode == 403 &&
          data['code'] == 'ACCOUNT_BLOCKED') {
        final info = data['data'] as Map<String, dynamic>?;
        AccountBlock.notifier.value = AccountBlockInfo(
          reason: info?['block_reason'] as String?,
          contactUrl: info?['contact_url'] as String?,
        );
      }
      final message = data['message']?.toString() ?? error.message ?? 'Something went wrong.';
      final errors = data['errors'] as Map<String, dynamic>?;
      return error.copyWith(
        error: ApiException(message, statusCode: error.response?.statusCode, errors: errors),
      );
    }

    return error.copyWith(
      error: ApiException(error.message ?? 'Something went wrong.', statusCode: error.response?.statusCode),
    );
  }
}
