import '../core/api/api_client.dart';
import '../core/api/paginated.dart';
import '../models/order.dart';

class OrderService {
  OrderService(this._api);

  final ApiClient _api;

  Future<PaginatedResult<Order>> list({int page = 1, OrderStatus? status, String search = ''}) async {
    final res = await _api.dio.get(
      '/admin/orders',
      queryParameters: {'page': page, 'per_page': 20, 'status': ?status?.name, if (search.isNotEmpty) 'search': search},
    );
    return PaginatedResult.fromEnvelope(res.data as Map<String, dynamic>, Order.fromJson);
  }

  /// Order count per status name, plus `all`, matching [list]'s search.
  Future<Map<String, int>> counts({String search = ''}) async {
    final res = await _api.dio.get('/admin/orders/counts', queryParameters: {if (search.isNotEmpty) 'search': search});
    final data = res.data['data'] as Map<String, dynamic>? ?? {};
    return data.map((k, v) => MapEntry(k, (v as num?)?.toInt() ?? 0));
  }

  Future<Order> detail(String id) async {
    final res = await _api.dio.get('/admin/orders/$id');
    return Order.fromJson(res.data['data'] as Map<String, dynamic>);
  }

  Future<Order> updateStatus(String id, OrderStatus status, {String? adminNotes}) async {
    final res = await _api.dio.patch(
      '/admin/orders/$id/status',
      data: {'status': status.name, 'admin_notes': ?adminNotes},
    );
    return Order.fromJson(res.data['data'] as Map<String, dynamic>);
  }
}
