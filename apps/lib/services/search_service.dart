import '../core/api/api_client.dart';
import '../models/product.dart';
import '../models/store.dart';

class SearchResult {
  SearchResult({required this.products, required this.stores});

  final List<Product> products;
  final List<Store> stores;
}

class SearchService {
  SearchService(this._apiClient);

  final ApiClient _apiClient;

  Future<SearchResult> search(String query, {int limit = 24}) async {
    final response = await _apiClient.dio.get('/search', queryParameters: {'q': query, 'limit': limit});
    final data = response.data['data'] as Map<String, dynamic>;

    return SearchResult(
      products: (data['products'] as List<dynamic>)
          .map((e) => Product.fromJson(e as Map<String, dynamic>))
          .toList(),
      stores: (data['stores'] as List<dynamic>).map((e) => Store.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }

  Future<List<String>> suggestions(String query, {int limit = 8}) async {
    final response = await _apiClient.dio.get('/search/suggestions', queryParameters: {'q': query, 'limit': limit});
    final data = response.data['data'] as List<dynamic>;
    return data.map((e) => e.toString()).toList();
  }

  Future<List<Product>> popular({int limit = 12}) async {
    final response = await _apiClient.dio.get('/search/popular', queryParameters: {'limit': limit});
    final data = response.data['data'] as List<dynamic>;
    return data.map((e) => Product.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> trackClick({required String productId, required String keyword}) async {
    await _apiClient.dio.post('/search/click', data: {'product_id': productId, 'keyword': keyword});
  }
}
