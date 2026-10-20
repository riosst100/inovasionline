import 'package:dio/dio.dart';

import '../core/api_client.dart';
import '../core/api_exception.dart';
import '../core/token_storage.dart';
import '../models/driver_user.dart';

class AuthService {
  AuthService(this._api, this._tokens);

  final ApiClient _api;
  final TokenStorage _tokens;

  Future<DriverUser> login({required String email, required String password}) async {
    final res = await _api.dio.post('/admin/auth/login', data: {'email': email, 'password': password});
    final data = res.data['data'] as Map<String, dynamic>;
    final user = data['user'] as Map<String, dynamic>;

    if (!DriverUser.canDeliver(user)) {
      // A valid admin account that does not deliver: do not keep its session on the phone.
      try {
        await _api.dio.post(
          '/admin/auth/logout',
          options: Options(headers: {'Authorization': 'Bearer ${data['token']}'}),
        );
      } catch (_) {}
      throw ApiException('Akun ini bukan akun driver.');
    }

    await _tokens.save(data['token'] as String);
    return DriverUser.fromJson(user);
  }

  /// Null when there is no stored session.
  Future<DriverUser?> currentUser() async {
    if (await _tokens.read() == null) return null;
    final res = await _api.dio.get('/admin/auth/me');
    return DriverUser.fromJson(res.data['data'] as Map<String, dynamic>);
  }

  Future<void> logout() async {
    try {
      await _api.dio.post('/admin/auth/logout');
    } catch (_) {
      // The local session is dropped either way.
    }
    await _tokens.clear();
  }

  Future<void> clearLocalSession() => _tokens.clear();
}
