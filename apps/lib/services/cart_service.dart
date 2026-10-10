import '../core/api/api_client.dart';
import '../models/cart.dart';

class CartService {
  CartService(this._apiClient);

  final ApiClient _apiClient;

  Future<Cart> cart() async {
    final response = await _apiClient.dio.get('/cart');
    return Cart.fromJson(response.data['data'] as Map<String, dynamic>);
  }

  Future<Cart> addItem({required String productId, String? variantId, int quantity = 1}) async {
    final response = await _apiClient.dio.post('/cart/items', data: {
      'product_id': productId,
      'product_variant_id': variantId,
      'quantity': quantity,
    });
    return Cart.fromJson(response.data['data'] as Map<String, dynamic>);
  }

  Future<Cart> updateQuantity(String cartItemId, int quantity) async {
    final response = await _apiClient.dio.patch('/cart/items/$cartItemId', data: {'quantity': quantity});
    return Cart.fromJson(response.data['data'] as Map<String, dynamic>);
  }

  Future<Cart> removeItem(String cartItemId) async {
    final response = await _apiClient.dio.delete('/cart/items/$cartItemId');
    return Cart.fromJson(response.data['data'] as Map<String, dynamic>);
  }
}
