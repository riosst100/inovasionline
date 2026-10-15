import '../core/api/api_client.dart';
import '../models/nearest_address.dart';
import '../models/region.dart';

class RegionService {
  RegionService(this._apiClient);

  final ApiClient _apiClient;

  /// Nearest served village to the coordinates. Throws (422) when the
  /// location is outside the service area.
  Future<NearestAddress> nearest({
    required double latitude,
    required double longitude,
  }) async {
    final response = await _apiClient.dio.get(
      '/regions/nearest',
      queryParameters: {'latitude': latitude, 'longitude': longitude},
    );
    return NearestAddress.fromJson(response.data['data'] as Map<String, dynamic>);
  }

  Future<List<Region>> provinces() async {
    final response = await _apiClient.dio.get('/regions/provinces');
    final data = response.data['data'] as List<dynamic>;
    return data.map((e) => Region.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<Region>> cities(String provinceCode) async {
    final response = await _apiClient.dio.get('/regions/provinces/${Uri.encodeComponent(provinceCode)}/cities');
    final data = response.data['data'] as List<dynamic>;
    return data.map((e) => Region.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<Region>> districts(String cityCode) async {
    final response = await _apiClient.dio.get('/regions/cities/${Uri.encodeComponent(cityCode)}/districts');
    final data = response.data['data'] as List<dynamic>;
    return data.map((e) => Region.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<Region>> villages(String districtCode) async {
    final response = await _apiClient.dio.get('/regions/districts/${Uri.encodeComponent(districtCode)}/villages');
    final data = response.data['data'] as List<dynamic>;
    return data.map((e) => Region.fromJson(e as Map<String, dynamic>)).toList();
  }
}
