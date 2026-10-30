import '../core/api/api_client.dart';
import '../models/banner.dart';

class LaunchPopupConfig {
  const LaunchPopupConfig({required this.mode, required this.maxPerDay, required this.items});

  /// 'off' | 'admob' | 'image'
  final String mode;
  final int maxPerDay;
  final List<AppBanner> items;
}

class BannerService {
  BannerService(this._apiClient);

  final ApiClient _apiClient;

  /// Home hero slider banners.
  Future<List<AppBanner>> banners() => _fetch(const {});

  /// What to show as a popup on opening the app today; the server already
  /// applied the admin's schedule (days, date range), so `mode` is 'off' when nothing is due.
  Future<LaunchPopupConfig> launchPopup() async {
    final response = await _apiClient.dio.get('/launch-popup');
    final data = response.data['data'] as Map<String, dynamic>;
    return LaunchPopupConfig(
      mode: data['mode'] as String? ?? 'off',
      maxPerDay: (data['max_per_day'] as num?)?.toInt() ?? 1,
      items: ((data['items'] as List<dynamic>?) ?? const [])
          .map((e) => AppBanner.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Future<List<AppBanner>> _fetch(Map<String, dynamic> query) async {
    final response = await _apiClient.dio.get('/banners', queryParameters: query);
    final data = response.data['data'] as List<dynamic>;
    return data.map((e) => AppBanner.fromJson(e as Map<String, dynamic>)).toList();
  }
}
