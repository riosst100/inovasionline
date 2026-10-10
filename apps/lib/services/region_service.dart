import '../core/api/api_client.dart';
import '../models/region.dart';

class RegionService {
  RegionService(this._apiClient);

  final ApiClient _apiClient;

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
