import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api_client.dart';
import '../core/token_storage.dart';
import '../models/driver_user.dart';
import '../models/parcel.dart';
import '../services/auth_service.dart';
import '../services/delivery_service.dart';

final _tokenStorageProvider = Provider((ref) => TokenStorage());
final _apiClientProvider = Provider((ref) => ApiClient(ref.watch(_tokenStorageProvider)));
final _authServiceProvider = Provider(
  (ref) => AuthService(ref.watch(_apiClientProvider), ref.watch(_tokenStorageProvider)),
);
final deliveryServiceProvider = Provider((ref) => DeliveryService(ref.watch(_apiClientProvider)));

/// Parcels the driver has on the road (`false`) or has delivered (`true`).
final parcelsProvider = FutureProvider.autoDispose.family<List<Parcel>, bool>(
  (ref, done) => ref.watch(deliveryServiceProvider).parcels(done: done),
);

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthState {
  const AuthState({this.status = AuthStatus.unknown, this.user});

  final AuthStatus status;
  final DriverUser? user;
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier(this._service) : super(const AuthState()) {
    ApiClient.unauthorized.addListener(_onUnauthorized);
    _restore();
  }

  final AuthService _service;

  Future<void> _restore() async {
    try {
      final user = await _service.currentUser();
      state = AuthState(status: user != null ? AuthStatus.authenticated : AuthStatus.unauthenticated, user: user);
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) await _service.clearLocalSession();
      state = const AuthState(status: AuthStatus.unauthenticated);
    }
  }

  /// Throws on failure so the form can show the server's message.
  Future<void> login({required String phone, required String password}) async {
    final user = await _service.login(phone: phone, password: password);
    state = AuthState(status: AuthStatus.authenticated, user: user);
  }

  Future<void> logout() async {
    await _service.logout();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  void _onUnauthorized() {
    if (state.status != AuthStatus.authenticated) return;
    _service.clearLocalSession();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  @override
  void dispose() {
    ApiClient.unauthorized.removeListener(_onUnauthorized);
    super.dispose();
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>(
  (ref) => AuthNotifier(ref.watch(_authServiceProvider)),
);
