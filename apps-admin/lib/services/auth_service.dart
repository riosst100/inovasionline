import '../core/api/api_client.dart';
import '../core/storage/token_storage.dart';
import '../models/admin_user.dart';

class AuthService {
  AuthService(this._api, this._tokenStorage);

  final ApiClient _api;
  final TokenStorage _tokenStorage;

  Future<AdminUser> login({required String email, required String password}) async {
    final res = await _api.dio.post('/admin/auth/login', data: {'email': email, 'password': password});
    final data = res.data['data'] as Map<String, dynamic>;
    await _tokenStorage.saveToken(data['token'] as String);
    return AdminUser.fromJson(data['user'] as Map<String, dynamic>);
  }

  /// Null when there is no stored session.
  Future<AdminUser?> currentUser() async {
    if (await _tokenStorage.readToken() == null) return null;
    final res = await _api.dio.get('/admin/auth/me');
    return AdminUser.fromJson(res.data['data'] as Map<String, dynamic>);
  }

  Future<void> logout() async {
    try {
      await _api.dio.post('/admin/auth/logout');
    } catch (_) {
      // The local session is dropped either way.
    }
    await _tokenStorage.clearToken();
  }

  Future<void> clearLocalSession() => _tokenStorage.clearToken();
}
