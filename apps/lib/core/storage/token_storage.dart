import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../api/response_cache.dart';

class TokenStorage {
  TokenStorage() : _storage = const FlutterSecureStorage();

  final FlutterSecureStorage _storage;
  static const _tokenKey = 'auth_token';

  Future<String?> readToken() => _storage.read(key: _tokenKey);

  Future<void> saveToken(String token) => _storage.write(key: _tokenKey, value: token);

  Future<void> clearToken() async {
    await _storage.delete(key: _tokenKey);
    await ResponseCache.clearPrivate();
  }
}
