import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../api/response_cache.dart';

class TokenStorage {
  TokenStorage() : _storage = const FlutterSecureStorage();

  final FlutterSecureStorage _storage;
  static const _tokenKey = 'auth_token';

  /// The token lives in the Keystore-backed secure storage, and reading it is a slow platform call
  /// with decryption. Every API request needs it, so it is read once and kept in memory
  /// (this class is a single shared instance, see tokenStorageProvider).
  String? _token;
  bool _loaded = false;
  Future<String?>? _loading;

  Future<String?> readToken() {
    if (_loaded) return Future.value(_token);
    return _loading ??= _storage.read(key: _tokenKey).then((value) {
      // A save/clear that happened meanwhile wins over what was on disk.
      if (!_loaded) {
        _token = value;
        _loaded = true;
      }
      _loading = null;
      return _token;
    });
  }

  Future<void> saveToken(String token) async {
    _token = token;
    _loaded = true;
    await _storage.write(key: _tokenKey, value: token);
  }

  Future<void> clearToken() async {
    _token = null;
    _loaded = true;
    await _storage.delete(key: _tokenKey);
    await ResponseCache.clearPrivate();
  }
}
