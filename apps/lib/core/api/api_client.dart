import 'package:dio/dio.dart';
import '../../config/env.dart';
import '../storage/token_storage.dart';
import 'account_block.dart';
import 'api_exception.dart';
import 'cache_versions.dart';
import 'connectivity.dart';
import 'response_cache.dart';
import 'session_expired.dart';

class ApiClient {
  ApiClient(this._tokenStorage) : dio = Dio(
          BaseOptions(
            baseUrl: Env.apiBaseUrl,
            // Fail fast on a dead connection instead of hanging. No sendTimeout: uploads (photos,
            // video) legitimately take long on slow networks.
            connectTimeout: const Duration(seconds: 15),
            receiveTimeout: const Duration(seconds: 45),
            headers: {
              'Accept': 'application/json',
              'X-Client': 'mobile',
            },
          ),
        ) {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // Reads (GET) may fail or be served from what is already loaded, but
          // anything sent to the server needs internet: refuse it up front
          // instead of letting it hang until a timeout.
          if (options.method != 'GET' &&
              !Connectivity.online.value &&
              !await Connectivity.check()) {
            return handler.reject(
              DioException(
                requestOptions: options,
                type: DioExceptionType.connectionError,
                error: ApiException(
                  'Tidak ada koneksi internet. Periksa koneksi Anda lalu coba lagi.',
                ),
              ),
            );
          }
          final token = await _tokenStorage.readToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          if (ResponseCache.applies(options)) {
            // Still current according to the server's version: answer from the phone, no request.
            final saved = await ResponseCache.fresh(options, _versions);
            if (saved != null) return handler.resolve(saved);
            await ResponseCache.prepare(options);
          }
          handler.next(options);
        },
        onResponse: (response, handler) async {
          if (ResponseCache.applies(response.requestOptions)) await ResponseCache.store(response, _versions);
          handler.next(response);
        },
        onError: (error, handler) async {
          final retried = await _retryOnce(error);
          if (retried != null) return handler.resolve(retried);
          final network = error.type == DioExceptionType.connectionTimeout ||
              error.type == DioExceptionType.receiveTimeout ||
              error.type == DioExceptionType.connectionError;
          if (network && ResponseCache.applies(error.requestOptions)) {
            final saved = await ResponseCache.offline(error.requestOptions);
            if (saved != null) return handler.resolve(saved);
          }
          await _notifyIfSessionExpired(error);
          handler.next(_mapError(error));
        },
      ),
    );
  }

  final Dio dio;
  final TokenStorage _tokenStorage;

  /// What the server says about each cached data group; asked once on first use.
  late final CacheVersions _versions = CacheVersions(() async {
    final response = await dio.get<dynamic>('/cache-versions');
    final body = response.data;
    return (body is Map ? body['data'] : null) as Map<String, dynamic>;
  });

  /// Asks the server again which cached data changed (throttled), e.g. when the app returns to
  /// the foreground. Screens that reload afterwards pick up whatever was invalidated.
  Future<void> refreshCacheVersions() => _versions.refresh();

  /// One automatic retry for GET requests that failed on the network itself (flaky mobile data).
  /// Never for writes: a timed-out POST may have gone through on the server.
  Future<Response<dynamic>?> _retryOnce(DioException error) async {
    final request = error.requestOptions;
    final transient = error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.connectionError;
    if (request.method != 'GET' || !transient || request.extra['retried'] == true) return null;

    try {
      await Future<void>.delayed(const Duration(milliseconds: 600));
      return await dio.fetch<dynamic>(request.copyWith(extra: {...request.extra, 'retried': true}));
    } catch (_) {
      return null;
    }
  }

  /// A 401 for the token we are still holding means the session is over. A late answer to a
  /// request made with an older token (e.g. before a fresh login) is ignored.
  Future<void> _notifyIfSessionExpired(DioException error) async {
    if (error.response?.statusCode != 401) return;
    final sent = error.requestOptions.headers['Authorization'];
    if (sent == null) return;
    final current = await _tokenStorage.readToken();
    if (current != null && sent == 'Bearer $current') SessionExpired.notify();
  }

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
