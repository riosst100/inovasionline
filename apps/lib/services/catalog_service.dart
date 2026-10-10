import '../core/api/api_client.dart';
import '../core/api/api_response.dart';
import '../models/category.dart';
import '../models/product.dart';
import '../models/flash_sale.dart';

class CatalogService {
  CatalogService(this._apiClient);

  final ApiClient _apiClient;

  Future<List<Category>> categories({bool rootOnly = false}) async {
    final response = await _apiClient.dio.get('/categories', queryParameters: {
      if (rootOnly) 'root_only': true,
    });
    final data = response.data['data'] as List<dynamic>;
    return data.map((e) => Category.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<(Category, PaginatedResult<Product>)> categoryProducts(String slug, {int page = 1, int perPage = 20}) async {
    final response = await _apiClient.dio.get('/categories/$slug', queryParameters: {
      'page': page,
      'per_page': perPage,
    });

    final data = response.data['data'] as Map<String, dynamic>;
    final category = Category.fromJson(data['category'] as Map<String, dynamic>);
    final products = (data['products'] as List<dynamic>)
        .map((e) => Product.fromJson(e as Map<String, dynamic>))
        .toList();
    final meta = PaginatedMeta.fromJson(response.data['meta'] as Map<String, dynamic>);

    return (category, PaginatedResult<Product>(data: products, meta: meta));
  }

  Future<ProductDetail> product(String slug) async {
    final response = await _apiClient.dio.get('/products/$slug');
    return ProductDetail.fromJson(response.data['data'] as Map<String, dynamic>);
  }

  Future<List<Product>> bestSellers({int limit = 12}) async {
    final response = await _apiClient.dio.get('/products/best-sellers', queryParameters: {'limit': limit});
    final data = response.data['data'] as List<dynamic>;
    return data.map((e) => Product.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<FlashSaleSchedule> flashSale({String? date}) async {
    final response = await _apiClient.dio.get('/products/flash-sale', queryParameters: {
      'date': date,
    });
    return FlashSaleSchedule.fromJson(response.data['data'] as Map<String, dynamic>);
  }
}
