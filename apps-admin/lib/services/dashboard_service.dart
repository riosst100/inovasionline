import '../core/api/api_client.dart';
import '../models/dashboard.dart';

class DashboardService {
  DashboardService(this._api);

  final ApiClient _api;

  Future<DashboardStats> stats() async {
    final res = await _api.dio.get('/admin/dashboard');
    return DashboardStats.fromJson(res.data['data'] as Map<String, dynamic>);
  }
}
