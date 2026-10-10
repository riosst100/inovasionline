import '../core/api/api_client.dart';
import '../core/api/api_response.dart';
import '../models/product.dart';
import '../models/store.dart';

class StoreService {
  StoreService(this._apiClient);

  final ApiClient _apiClient;

  Future<List<Store>> stores({String sort = 'newest', String? cityCode, int limit = 12}) async {
    final response = await _apiClient.dio.get('/stores', queryParameters: {
      'sort': sort,
      'city_code': cityCode,
      'limit': limit,
    });
    final data = response.data['data'] as List<dynamic>;
    return data.map((e) => Store.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<(Store, PaginatedResult<Product>)> store(String slug, {int page = 1, int perPage = 20}) async {
    final response = await _apiClient.dio.get('/stores/$slug', queryParameters: {
      'page': page,
      'per_page': perPage,
    });

    final data = response.data['data'] as Map<String, dynamic>;
    final store = Store.fromJson(data['store'] as Map<String, dynamic>);
    final products = (data['products'] as List<dynamic>)
        .map((e) => Product.fromJson(e as Map<String, dynamic>))
        .toList();
    final meta = PaginatedMeta.fromJson(response.data['meta'] as Map<String, dynamic>);

    return (store, PaginatedResult<Product>(data: products, meta: meta));
  }
}
