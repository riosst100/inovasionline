import '../core/api/api_client.dart';
import '../models/order.dart';

class OrderService {
  OrderService(this._apiClient);

  final ApiClient _apiClient;

  Future<List<Order>> myOrders() async {
    final response = await _apiClient.dio.get('/orders');
    return (response.data['data'] as List<dynamic>).map((e) => Order.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Order> orderDetail(String orderId) async {
    final response = await _apiClient.dio.get('/orders/$orderId');
    return Order.fromJson(response.data['data'] as Map<String, dynamic>);
  }

  Future<Order> cancel(String orderId) async {
    final response = await _apiClient.dio.post('/orders/$orderId/cancel');
    return Order.fromJson(response.data['data'] as Map<String, dynamic>);
  }
}
