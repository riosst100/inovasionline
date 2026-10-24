import 'package:intl/intl.dart';

import '../core/api/api_client.dart';
import '../models/delivery_schedule.dart';

class DeliveryScheduleInput {
  DeliveryScheduleInput({
    required this.label,
    required this.startTime,
    required this.endTime,
    required this.cutoffMinutes,
    required this.days,
    required this.isActive,
    this.quota,
  });

  final String label;
  final String startTime;
  final String endTime;
  final int cutoffMinutes;
  final int? quota;
  final List<int> days;
  final bool isActive;

  Map<String, dynamic> toJson() => {
    'label': label,
    'start_time': startTime,
    'end_time': endTime,
    'cutoff_minutes': cutoffMinutes,
    'quota': quota,
    'days': days,
    'is_active': isActive,
  };
}

class DeliveryScheduleService {
  DeliveryScheduleService(this._api);

  final ApiClient _api;

  List<Map<String, dynamic>> _list(dynamic body) =>
      (body['data'] as List? ?? []).cast<Map<String, dynamic>>();

  Future<List<ScheduledShippingMethod>> scheduledMethods() async {
    final res = await _api.dio.get('/admin/shipping-methods', queryParameters: {'per_page': 100});
    return [
      for (final json in _list(res.data))
        if (json['requires_schedule'] == true) ScheduledShippingMethod.fromJson(json),
    ];
  }

  Future<List<DeliverySchedule>> schedules(String methodId) async {
    final res = await _api.dio.get('/admin/delivery-schedules', queryParameters: {'shipping_method_id': methodId});
    return _list(res.data).map(DeliverySchedule.fromJson).toList();
  }

  Future<void> saveSchedule(String methodId, DeliveryScheduleInput input, {String? id}) async {
    if (id == null) {
      await _api.dio.post('/admin/delivery-schedules', data: {'shipping_method_id': methodId, ...input.toJson()});
    } else {
      await _api.dio.put('/admin/delivery-schedules/$id', data: input.toJson());
    }
  }

  Future<void> setScheduleActive(DeliverySchedule s, bool isActive) => _api.dio.put(
    '/admin/delivery-schedules/${s.id}',
    data: DeliveryScheduleInput(
      label: s.label,
      startTime: s.startTime,
      endTime: s.endTime,
      cutoffMinutes: s.cutoffMinutes,
      quota: s.quota,
      days: s.days ?? const [1, 2, 3, 4, 5, 6, 7],
      isActive: isActive,
    ).toJson(),
  );

  Future<void> deleteSchedule(String id) => _api.dio.delete('/admin/delivery-schedules/$id');

  /// Upcoming holidays for this method, including those that apply to every method.
  Future<List<DeliveryHoliday>> holidays(String methodId) async {
    final res = await _api.dio.get('/admin/delivery-holidays', queryParameters: {'shipping_method_id': methodId});
    return _list(res.data).map(DeliveryHoliday.fromJson).toList();
  }

  /// [methodId] null = the holiday applies to every shipping method.
  Future<void> addHoliday({required DateTime date, required String name, String? methodId}) =>
      _api.dio.post(
        '/admin/delivery-holidays',
        data: {'date': DateFormat('yyyy-MM-dd').format(date), 'name': name, 'shipping_method_id': methodId},
      );

  Future<void> deleteHoliday(String id) => _api.dio.delete('/admin/delivery-holidays/$id');
}
