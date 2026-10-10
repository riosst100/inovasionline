import 'dart:io';

import '../core/api/api_client.dart';

class NotificationService {
  NotificationService(this._apiClient);

  final ApiClient _apiClient;

  Future<void> registerToken(String token) async {
    await _apiClient.dio.post(
      '/device-tokens',
      data: {'token': token, 'platform': Platform.isIOS ? 'ios' : 'android'},
    );
  }

  Future<void> unregisterToken(String token) async {
    await _apiClient.dio.delete('/device-tokens', data: {'token': token});
  }
}
