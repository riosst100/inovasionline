import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api/api_client.dart';
import '../models/admin_user.dart';
import 'core_providers.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthState {
  const AuthState({this.status = AuthStatus.unknown, this.user});

  final AuthStatus status;
  final AdminUser? user;
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier(this._ref) : super(const AuthState()) {
    ApiClient.unauthorized.addListener(_onUnauthorized);
    _restore();
  }

  final Ref _ref;

  Future<void> _restore() async {
    try {
      final user = await _ref.read(authServiceProvider).currentUser();
      state = AuthState(status: user != null ? AuthStatus.authenticated : AuthStatus.unauthenticated, user: user);
    } on DioException catch (e) {
      // Offline at launch: keep the stored token, but the app still needs a
      // definite state to leave the splash. Only a 401 means the token is dead.
      if (e.response?.statusCode == 401) {
        await _ref.read(authServiceProvider).clearLocalSession();
      }
      state = const AuthState(status: AuthStatus.unauthenticated);
    }
  }

  /// Throws on failure so the form can show the server's message.
  Future<void> login({required String username, required String password}) async {
    final user = await _ref.read(authServiceProvider).login(username: username, password: password);
    state = AuthState(status: AuthStatus.authenticated, user: user);
  }

  /// Pass null to remove the current photo. Throws so the screen can show the error.
  Future<void> setAvatar(String? path) async {
    final service = _ref.read(authServiceProvider);
    final user = path == null ? await service.deleteAvatar() : await service.updateAvatar(path);
    state = AuthState(status: AuthStatus.authenticated, user: user);
  }

  Future<void> logout() async {
    await _ref.read(authServiceProvider).logout();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  void _onUnauthorized() {
    if (state.status != AuthStatus.authenticated) return;
    _ref.read(authServiceProvider).clearLocalSession();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  @override
  void dispose() {
    ApiClient.unauthorized.removeListener(_onUnauthorized);
    super.dispose();
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) => AuthNotifier(ref));
