import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'package:firebase_messaging/firebase_messaging.dart';

import '../config/env.dart';
import '../core/api/api_exception.dart';
import '../models/user.dart';
import 'core_providers.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthState {
  const AuthState({this.status = AuthStatus.unknown, this.user, this.error});

  final AuthStatus status;
  final User? user;
  final String? error;

  AuthState copyWith({AuthStatus? status, User? user, String? error}) =>
      AuthState(
        status: status ?? this.status,
        user: user ?? this.user,
        error: error,
      );
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier(this._ref) : super(const AuthState()) {
    _restore();
  }

  final Ref _ref;

  Future<void> _restore() async {
    try {
      final user = await _ref.read(authServiceProvider).currentUser();
      state = AuthState(
        status: user != null
            ? AuthStatus.authenticated
            : AuthStatus.unauthenticated,
        user: user,
      );
    } on DioException {
      state = const AuthState(status: AuthStatus.unauthenticated);
    }
  }

  /// [login] accepts either an email address or a phone number.
  Future<bool> login({required String login, required String password}) async {
    try {
      final user = await _ref
          .read(authServiceProvider)
          .login(login: login, password: password);
      state = AuthState(status: AuthStatus.authenticated, user: user);
      await _syncDeviceToken();
      return true;
    } on DioException catch (e) {
      state = state.copyWith(error: _errorMessage(e));
      return false;
    }
  }

  /// The phone number must already be verified via [sendPhoneOtp] +
  /// [verifyPhoneOtp] before calling this.
  Future<bool> register({
    required String name,
    required String phone,
    required String gender,
    required String dateOfBirth,
    required String password,
    required String passwordConfirmation,
  }) async {
    try {
      final user = await _ref
          .read(authServiceProvider)
          .register(
            name: name,
            phone: phone,
            gender: gender,
            dateOfBirth: dateOfBirth,
            password: password,
            passwordConfirmation: passwordConfirmation,
          );
      state = AuthState(status: AuthStatus.authenticated, user: user);
      await _syncDeviceToken();
      return true;
    } on DioException catch (e) {
      state = state.copyWith(error: _errorMessage(e));
      return false;
    }
  }

  Future<bool> sendPhoneOtp(String phone) async {
    try {
      await _ref.read(authServiceProvider).sendPhoneOtp(phone);
      return true;
    } on DioException catch (e) {
      state = state.copyWith(error: _errorMessage(e));
      return false;
    }
  }

  Future<bool> verifyPhoneOtp({
    required String phone,
    required String code,
  }) async {
    try {
      await _ref
          .read(authServiceProvider)
          .verifyPhoneOtp(phone: phone, code: code);
      return true;
    } on DioException catch (e) {
      state = state.copyWith(error: _errorMessage(e));
      return false;
    }
  }

  Future<bool> loginWithGoogle() async {
    try {
      final googleSignIn = GoogleSignIn(
        serverClientId: Env.googleServerClientId,
      );
      final account = await googleSignIn.signIn();
      if (account == null) return false;

      final googleAuth = await account.authentication;
      final idToken = googleAuth.idToken;
      if (idToken == null) {
        state = state.copyWith(error: 'Failed to get Google credentials.');
        return false;
      }

      final user = await _ref
          .read(authServiceProvider)
          .loginWithGoogle(idToken);
      state = AuthState(status: AuthStatus.authenticated, user: user);
      await _syncDeviceToken();
      return true;
    } on DioException catch (e) {
      state = state.copyWith(error: _errorMessage(e));
      return false;
    }
  }

  Future<void> logout() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await _ref.read(notificationServiceProvider).unregisterToken(token);
      }
    } catch (_) {
      // Best-effort: an unreachable backend shouldn't block logout.
    }
    await _ref.read(authServiceProvider).logout();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  Future<void> _syncDeviceToken() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await _ref.read(notificationServiceProvider).registerToken(token);
      }
    } catch (_) {
      // Best-effort: notification registration shouldn't block login.
    }
  }

  Future<bool> updateProfile({
    required String name,
    required String phone,
    File? avatar,
  }) async {
    try {
      final user = await _ref
          .read(authServiceProvider)
          .updateProfile(name: name, phone: phone, avatar: avatar);
      state = state.copyWith(status: AuthStatus.authenticated, user: user);
      return true;
    } on DioException catch (e) {
      state = state.copyWith(error: _errorMessage(e));
      return false;
    }
  }

  Future<bool> updateAddress({
    required String provinceCode,
    required String cityCode,
    required String districtCode,
    required String villageCode,
  }) async {
    try {
      final user = await _ref
          .read(authServiceProvider)
          .updateAddress(
            provinceCode: provinceCode,
            cityCode: cityCode,
            districtCode: districtCode,
            villageCode: villageCode,
          );
      state = state.copyWith(status: AuthStatus.authenticated, user: user);
      return true;
    } on DioException catch (e) {
      state = state.copyWith(error: _errorMessage(e));
      return false;
    }
  }

  String _errorMessage(DioException e) {
    final error = e.error;
    if (error is ApiException) {
      final fieldErrors = error.errors;
      if (fieldErrors != null && fieldErrors.isNotEmpty) {
        final messages = fieldErrors.values
            .expand(
              (v) => v is List ? v.map((e) => e.toString()) : [v.toString()],
            )
            .toList();
        if (messages.isNotEmpty) return messages.join('\n');
      }
      return error.message;
    }
    return e.message ?? 'Something went wrong.';
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>(
  (ref) => AuthNotifier(ref),
);
