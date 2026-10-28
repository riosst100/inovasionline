import '../core/api/api_client.dart';
import '../models/banner.dart';

class BannerService {
  BannerService(this._apiClient);

  final ApiClient _apiClient;

  /// Home hero slider banners.
  Future<List<AppBanner>> banners() => _fetch(const {});

  /// Popup images shown on opening the app; the first one is used.
  Future<List<AppBanner>> popupBanners() => _fetch(const {'placement': 'popup'});

  Future<List<AppBanner>> _fetch(Map<String, dynamic> query) async {
    final response = await _apiClient.dio.get('/banners', queryParameters: query);
    final data = response.data['data'] as List<dynamic>;
    return data.map((e) => AppBanner.fromJson(e as Map<String, dynamic>)).toList();
  }
}
