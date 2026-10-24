import '../core/api/api_client.dart';
import '../core/api/paginated.dart';
import '../models/customer.dart';

class CustomerService {
  CustomerService(this._api);

  final ApiClient _api;

  Future<PaginatedResult<Customer>> list({int page = 1, String search = ''}) async {
    final res = await _api.dio.get(
      '/admin/customers',
      queryParameters: {'page': page, 'per_page': 20, if (search.isNotEmpty) 'search': search},
    );
    return PaginatedResult.fromEnvelope(res.data as Map<String, dynamic>, Customer.fromJson);
  }

  /// Revokes the customer's face verification on the event it points at.
  Future<Customer> revokeVerification(String id, String reason) async {
    final res = await _api.dio.post('/admin/customers/$id/revoke-verification', data: {'reason': reason});
    return Customer.fromJson(res.data['data'] as Map<String, dynamic>);
  }
}
