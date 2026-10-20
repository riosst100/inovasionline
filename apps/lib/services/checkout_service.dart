import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../core/api/api_client.dart';
import '../models/delivery_schedule.dart';
import '../models/order.dart';
import '../models/payment_method.dart';
import '../models/shipping_method.dart';

class CheckoutService {
  CheckoutService(this._apiClient);

  final ApiClient _apiClient;

  /// Returns {is_active, label, type: fixed|percent, value, min_fee, max_fee}.
  Future<Map<String, dynamic>> serviceFeeConfig() async {
    final response = await _apiClient.dio.get('/service-fee');
    return (response.data['data'] as Map).cast<String, dynamic>();
  }

  Future<List<PaymentMethod>> paymentMethods() async {
    final response = await _apiClient.dio.get('/payment-methods');
    return (response.data['data'] as List<dynamic>)
        .map((e) => PaymentMethod.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<ShippingMethod>> shippingMethods({
    required String districtCode,
    String? villageCode,
  }) async {
    final response = await _apiClient.dio.get('/shipping-methods', queryParameters: {
      'district_code': districtCode,
      'village_code': ?villageCode,
    });
    return (response.data['data'] as List<dynamic>)
        .map((e) => ShippingMethod.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<DeliveryDay>> deliverySchedules(String shippingMethodId) async {
    final response = await _apiClient.dio.get('/delivery-schedules', queryParameters: {
      'shipping_method_id': shippingMethodId,
    });
    return (response.data['data'] as List<dynamic>)
        .map((e) => DeliveryDay.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Order> payOrder(String orderId) async {
    final response = await _apiClient.dio.post('/orders/$orderId/pay');
    return Order.fromJson(response.data['data'] as Map<String, dynamic>);
  }

  /// Asks the backend to re-check the transaction with Midtrans, then returns the order.
  Future<Order> paymentStatus(String orderId) async {
    final response = await _apiClient.dio.get('/orders/$orderId/payment-status');
    return Order.fromJson(response.data['data'] as Map<String, dynamic>);
  }

  Future<Order> checkout({
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
    String? deliveryScheduleId,
    String? deliveryDate,
  }) async {
    final response = await _apiClient.dio.post('/checkout', data: {
      'cart_item_ids': cartItemIds,
      'payment_method_id': paymentMethodId,
      'shipping_method_id': shippingMethodId,
      'delivery_schedule_id': ?deliveryScheduleId,
      'delivery_date': ?deliveryDate,
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

  /// Whether this account already passed the one-time face check (COD and Paylater).
  Future<bool> faceVerified() async {
    final response = await _apiClient.dio.get('/checkout/face-verification');
    return (response.data['data'] as Map)['verified'] == true;
  }

  /// Uploads the liveness recording; the server stores it for later review.
  Future<void> submitFaceVerification({required String videoPath, required List<String> steps}) async {
    final form = FormData.fromMap({
      'video': await MultipartFile.fromFile(videoPath, filename: 'face-verification.mp4'),
      'steps': steps,
      'device': defaultTargetPlatform.name,
    });
    await _apiClient.dio.post(
      '/checkout/face-verification',
      data: form,
      options: Options(sendTimeout: const Duration(minutes: 2), receiveTimeout: const Duration(minutes: 2)),
    );
  }
}
