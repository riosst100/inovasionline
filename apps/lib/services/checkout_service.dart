import '../core/api/api_client.dart';
import '../models/order.dart';
import '../models/payment_method.dart';
import '../models/shipping_method.dart';

class CheckoutService {
  CheckoutService(this._apiClient);

  final ApiClient _apiClient;

  Future<List<PaymentMethod>> paymentMethods(String storeSlug) async {
    final response = await _apiClient.dio.get('/stores/$storeSlug/payment-methods');
    return (response.data['data'] as List<dynamic>)
        .map((e) => PaymentMethod.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<ShippingMethod>> shippingMethods(
    String storeSlug, {
    required String districtCode,
    String? villageCode,
  }) async {
    final response = await _apiClient.dio.get('/stores/$storeSlug/shipping-methods', queryParameters: {
      'district_code': districtCode,
      'village_code': ?villageCode,
    });
    return (response.data['data'] as List<dynamic>)
        .map((e) => ShippingMethod.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Order> checkout({
    required String storeId,
    required List<String> cartItemIds,
    required String paymentMethodId,
    required String shippingMethodId,
    required String recipientName,
    required String recipientPhone,
    required String provinceCode,
    required String cityCode,
    required String districtCode,
    required String villageCode,
    required String addressDetail,
    String? customerNotes,
  }) async {
    final response = await _apiClient.dio.post('/checkout', data: {
      'store_id': storeId,
      'cart_item_ids': cartItemIds,
      'payment_method_id': paymentMethodId,
      'shipping_method_id': shippingMethodId,
      'recipient_name': recipientName,
      'recipient_phone': recipientPhone,
      'province_code': provinceCode,
      'city_code': cityCode,
      'district_code': districtCode,
      'village_code': villageCode,
      'address_detail': addressDetail,
      'customer_notes': customerNotes,
    });
    return Order.fromJson(response.data['data'] as Map<String, dynamic>);
  }
}
