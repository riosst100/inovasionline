import '../core/api/api_client.dart';
import '../core/api/paginated.dart';
import '../models/cod_verification.dart';

class CodVerificationService {
  CodVerificationService(this._api);

  final ApiClient _api;

  /// [userId] narrows to one customer's events (then [search] is ignored).
  Future<PaginatedResult<CodVerification>> list({
    int page = 1,
    String? status,
    String search = '',
    String? userId,
  }) async {
    final res = await _api.dio.get(
      '/admin/cod-verifications',
      queryParameters: {
        'page': page,
        'per_page': 20,
        'status': ?status,
        if (userId != null) 'user_id': userId else if (search.isNotEmpty) 'search': search,
      },
    );
    return PaginatedResult.fromEnvelope(res.data as Map<String, dynamic>, CodVerification.fromJson);
  }

  Future<CodVerification?> find(String id) async {
    final res = await _api.dio.get('/admin/cod-verifications', queryParameters: {'id': id});
    final rows = res.data['data'] as List? ?? [];
    return rows.isEmpty ? null : CodVerification.fromJson(rows.first as Map<String, dynamic>);
  }

  Future<CodVerification> revoke(String id, String reason) async {
    final res = await _api.dio.post('/admin/cod-verifications/$id/revoke', data: {'reason': reason});
    return CodVerification.fromJson(res.data['data'] as Map<String, dynamic>);
  }
}
