import 'package:dio/dio.dart';

import '../core/api_client.dart';
import '../models/parcel.dart';

class DeliveryService {
  DeliveryService(this._api);

  final ApiClient _api;

  /// `done`: delivered ones; otherwise the ones on the road. [ready] lists parcels waiting for pickup.
  Future<List<Parcel>> parcels({required bool done, bool ready = false}) async {
    final res = await _api.dio.get(
      '/admin/driver/orders',
      queryParameters: {'tab': ready ? 'ready' : (done ? 'done' : 'active'), 'per_page': 50},
    );
    return (res.data['data'] as List).map((e) => Parcel.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Looks up the order behind a scanned QR code.
  Future<Parcel> scan(String code) async {
    final res = await _api.dio.post('/admin/driver/scan', data: {'code': code});
    return Parcel.fromJson(res.data['data'] as Map<String, dynamic>);
  }

  /// Latest GPS fix, shown on the tracking map of every buyer whose parcel this driver carries.
  Future<void> reportLocation({required double latitude, required double longitude, double? accuracy}) =>
      _api.dio.post(
        '/admin/driver/location',
        data: {'latitude': latitude, 'longitude': longitude, 'accuracy': ?accuracy},
      );

  /// Pickup: the parcel leaves with this driver.
  Future<Parcel> ship(Parcel parcel, {String? code, required String photoPath}) =>
      _confirm(parcel, 'ship', code, photoPath);

  /// Handover to the buyer.
  Future<Parcel> deliver(Parcel parcel, {String? code, required String photoPath}) =>
      _confirm(parcel, 'deliver', code, photoPath);

  Future<Parcel> _confirm(Parcel parcel, String step, String? code, String photoPath) async {
    final res = await _api.dio.post(
      '/admin/driver/orders/${parcel.id}/$step',
      data: FormData.fromMap({'code': ?code, 'photo': await MultipartFile.fromFile(photoPath, filename: 'proof.jpg')}),
    );
    return Parcel.fromJson(res.data['data'] as Map<String, dynamic>);
  }
}
