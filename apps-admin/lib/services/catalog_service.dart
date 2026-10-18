import 'package:dio/dio.dart';

import '../core/api/api_client.dart';
import '../core/api/paginated.dart';
import '../models/category.dart';
import '../models/product.dart';

class ProductInput {
  ProductInput({
    required this.name,
    required this.regularPrice,
    required this.status,
    this.salePrice,
    this.categoryId,
    this.sku,
    this.shortDescription,
    this.description,
    this.stocks,
  });

  final String name;
  final double regularPrice;
  final double? salePrice;
  final ProductStatus status;
  final String? categoryId;
  final String? sku;
  final String? shortDescription;
  final String? description;

  /// Quantity per warehouse id; null leaves stock untouched.
  final Map<String, int>? stocks;

  Map<String, dynamic> toJson() => {
    'name': name,
    'regular_price': regularPrice,
    'sale_price': salePrice,
    'status': status.value,
    'category_id': categoryId,
    'sku': sku,
    'short_description': shortDescription,
    'description': description,
    if (stocks != null)
      'stocks': [
        for (final e in stocks!.entries) {'warehouse_id': e.key, 'quantity': e.value},
      ],
  };
}

class CatalogService {
  CatalogService(this._api);

  final ApiClient _api;

  // ---- Products ----

  Future<PaginatedResult<Product>> products({int page = 1, String search = '', ProductStatus? status}) async {
    final res = await _api.dio.get(
      '/admin/products',
      queryParameters: {
        'page': page,
        'per_page': 20,
        if (search.isNotEmpty) 'search': search,
        'status': ?status?.value,
      },
    );
    return PaginatedResult.fromEnvelope(res.data as Map<String, dynamic>, Product.fromJson);
  }

  Future<Product> product(String id) async {
    final res = await _api.dio.get('/admin/products/$id');
    return Product.fromJson(res.data['data'] as Map<String, dynamic>);
  }

  Future<Product> createProduct(ProductInput input) async {
    final res = await _api.dio.post('/admin/products', data: input.toJson());
    return Product.fromJson(res.data['data'] as Map<String, dynamic>);
  }

  Future<Product> updateProduct(String id, ProductInput input) async {
    final res = await _api.dio.put('/admin/products/$id', data: input.toJson());
    return Product.fromJson(res.data['data'] as Map<String, dynamic>);
  }

  Future<Product> updateProductStatus(String id, ProductStatus status) async {
    final res = await _api.dio.patch('/admin/products/$id/status', data: {'status': status.value});
    return Product.fromJson(res.data['data'] as Map<String, dynamic>);
  }

  Future<void> deleteProduct(String id) => _api.dio.delete('/admin/products/$id');

  Future<Product> uploadProductImages(String id, List<String> paths) async {
    final form = FormData.fromMap({
      'images[]': [for (final p in paths) await MultipartFile.fromFile(p)],
    });
    final res = await _api.dio.post('/admin/products/$id/images', data: form);
    return Product.fromJson(res.data['data'] as Map<String, dynamic>);
  }

  Future<Product> setPrimaryImage(String productId, String imageId) async {
    final res = await _api.dio.post('/admin/products/$productId/images/$imageId/primary');
    return Product.fromJson(res.data['data'] as Map<String, dynamic>);
  }

  Future<Product> deleteImage(String productId, String imageId) async {
    final res = await _api.dio.delete('/admin/products/$productId/images/$imageId');
    return Product.fromJson(res.data['data'] as Map<String, dynamic>);
  }

  Future<List<Warehouse>> warehouses() async {
    final res = await _api.dio.get('/admin/warehouses');
    return (res.data['data'] as List).map((e) => Warehouse.fromJson(e as Map<String, dynamic>)).toList();
  }

  // ---- Categories ----

  Future<List<Category>> categories() async {
    final res = await _api.dio.get('/admin/categories', queryParameters: {'per_page': 200});
    return (res.data['data'] as List).map((e) => Category.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Creates when [id] is null. Multipart because the image is optional on both.
  Future<Category> saveCategory({
    String? id,
    required String name,
    String? description,
    String? parentId,
    bool isActive = true,
    String? imagePath,
  }) async {
    final form = FormData.fromMap({
      'name': name,
      'description': description ?? '',
      'parent_id': parentId ?? '',
      'is_active': isActive ? '1' : '0',
      if (imagePath != null) 'image': await MultipartFile.fromFile(imagePath),
    });
    final res = await _api.dio.post(id == null ? '/admin/categories' : '/admin/categories/$id', data: form);
    return Category.fromJson(res.data['data'] as Map<String, dynamic>);
  }

  Future<Category> toggleCategory(String id) async {
    final res = await _api.dio.post('/admin/categories/$id/toggle');
    return Category.fromJson(res.data['data'] as Map<String, dynamic>);
  }

  Future<void> deleteCategory(String id) => _api.dio.delete('/admin/categories/$id');
}
