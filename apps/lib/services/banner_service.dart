import '../core/api/api_client.dart';
import '../models/banner.dart';

class BannerService {
  BannerService(this._apiClient);

  final ApiClient _apiClient;

  Future<List<AppBanner>> banners() async {
    final response = await _apiClient.dio.get('/banners');
    final data = response.data['data'] as List<dynamic>;
    return data.map((e) => AppBanner.fromJson(e as Map<String, dynamic>)).toList();
  }
}
