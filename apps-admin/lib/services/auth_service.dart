import 'package:dio/dio.dart';

import '../core/api/api_client.dart';
import '../core/storage/token_storage.dart';
import '../models/admin_user.dart';

class AuthService {
  AuthService(this._api, this._tokenStorage);

  final ApiClient _api;
  final TokenStorage _tokenStorage;

  Future<AdminUser> login({required String username, required String password}) async {
    final res = await _api.dio.post('/admin/auth/login', data: {'username': username, 'password': password});
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

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
    required String confirmation,
  }) async {
    await _api.dio.put('/admin/auth/password', data: {
      'current_password': currentPassword,
      'password': newPassword,
      'password_confirmation': confirmation,
    });
  }

  Future<AdminUser> updateAvatar(String path) async {
    final form = FormData.fromMap({'avatar': await MultipartFile.fromFile(path)});
    final res = await _api.dio.post('/admin/auth/avatar', data: form);
    return AdminUser.fromJson(res.data['data'] as Map<String, dynamic>);
  }

  Future<AdminUser> deleteAvatar() async {
    final res = await _api.dio.delete('/admin/auth/avatar');
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
