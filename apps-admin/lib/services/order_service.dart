import '../core/api/api_client.dart';
import '../core/api/paginated.dart';
import '../models/order.dart';

class OrderService {
  OrderService(this._api);

  final ApiClient _api;

  Future<PaginatedResult<Order>> list({int page = 1, OrderStatus? status, String search = ''}) async {
    final res = await _api.dio.get(
      '/admin/orders',
      queryParameters: {'page': page, 'per_page': 20, 'status': ?status?.value, if (search.isNotEmpty) 'search': search},
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
      data: {'status': status.value, 'admin_notes': ?adminNotes},
    );
    return Order.fromJson(res.data['data'] as Map<String, dynamic>);
  }

  /// Saves the parcel split: each map is order item id -> quantity in that parcel.
  Future<Order> updatePackages(String id, List<Map<String, int>> packages) async {
    final res = await _api.dio.put(
      '/admin/orders/$id/packages',
      data: {
        'packages': [
          for (final package in packages)
            [
              for (final MapEntry(:key, :value) in package.entries) {'order_item_id': key, 'quantity': value},
            ],
        ],
      },
    );
    return Order.fromJson(res.data['data'] as Map<String, dynamic>);
  }
}
