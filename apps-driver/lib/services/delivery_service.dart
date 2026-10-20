import 'package:dio/dio.dart';

import '../core/api_client.dart';
import '../models/parcel.dart';

class DeliveryService {
  DeliveryService(this._api);

  final ApiClient _api;

  Future<List<Parcel>> parcels({required bool done}) async {
    final res = await _api.dio.get(
      '/admin/driver/orders',
      queryParameters: {'tab': done ? 'done' : 'active', 'per_page': 50},
    );
    return (res.data['data'] as List).map((e) => Parcel.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Looks up the order behind a scanned QR code.
  Future<Parcel> scan(String code) async {
    final res = await _api.dio.post('/admin/driver/scan', data: {'code': code});
    return Parcel.fromJson(res.data['data'] as Map<String, dynamic>);
  }

  /// Pickup: the parcel leaves with this driver.
  Future<Parcel> ship(Parcel parcel, {required String code, required String photoPath}) =>
      _confirm(parcel, 'ship', code, photoPath);

  /// Handover to the buyer.
  Future<Parcel> deliver(Parcel parcel, {required String code, required String photoPath}) =>
      _confirm(parcel, 'deliver', code, photoPath);

  Future<Parcel> _confirm(Parcel parcel, String step, String code, String photoPath) async {
    final res = await _api.dio.post(
      '/admin/driver/orders/${parcel.id}/$step',
      data: FormData.fromMap({'code': code, 'photo': await MultipartFile.fromFile(photoPath, filename: 'proof.jpg')}),
    );
    return Parcel.fromJson(res.data['data'] as Map<String, dynamic>);
  }
}
