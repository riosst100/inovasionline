import '../core/api/api_client.dart';
import '../models/user_address.dart';

class UserAddressService {
  UserAddressService(this._apiClient);

  final ApiClient _apiClient;

  /// Most recently added or used first.
  Future<List<UserAddress>> list() async {
    final response = await _apiClient.dio.get('/auth/user/addresses');
    final data = response.data['data'] as List<dynamic>;
    return data
        .map((e) => UserAddress.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<UserAddress> create(UserAddressInput input) async {
    final response = await _apiClient.dio.post(
      '/auth/user/addresses',
      data: input.toJson(),
    );
    return UserAddress.fromJson(response.data['data'] as Map<String, dynamic>);
  }

  Future<UserAddress> update(String id, UserAddressInput input) async {
    final response = await _apiClient.dio.put(
      '/auth/user/addresses/${Uri.encodeComponent(id)}',
      data: input.toJson(),
    );
    return UserAddress.fromJson(response.data['data'] as Map<String, dynamic>);
  }

  Future<void> delete(String id) async {
    await _apiClient.dio.delete(
      '/auth/user/addresses/${Uri.encodeComponent(id)}',
    );
  }
}
