/// A shipping method whose buyers pick a delivery slot (requires_schedule).
class ScheduledShippingMethod {
  ScheduledShippingMethod({
    required this.id,
    required this.name,
    required this.isEnabled,
    required this.scheduleDaysAhead,
  });

  factory ScheduledShippingMethod.fromJson(Map<String, dynamic> json) => ScheduledShippingMethod(
    id: json['id'] as String,
    name: json['name'] as String? ?? '-',
    isEnabled: json['is_enabled'] as bool? ?? false,
    scheduleDaysAhead: (json['schedule_days_ahead'] as num?)?.toInt() ?? 1,
  );

  final String id;
  final String name;
  final bool isEnabled;

  /// Buyers can book today up to (n - 1) days ahead.
  final int scheduleDaysAhead;
}

class DeliverySchedule {
  DeliverySchedule({
    required this.id,
    required this.label,
    required this.startTime,
    required this.endTime,
    required this.cutoffMinutes,
    required this.isActive,
    this.quota,
    this.days,
  });

  factory DeliverySchedule.fromJson(Map<String, dynamic> json) => DeliverySchedule(
    id: json['id'] as String,
    label: json['label'] as String? ?? '',
    startTime: json['start_time'] as String? ?? '',
    endTime: json['end_time'] as String? ?? '',
    cutoffMinutes: (json['cutoff_minutes'] as num?)?.toInt() ?? 0,
    quota: (json['quota'] as num?)?.toInt(),
    days: (json['days'] as List?)?.map((e) => (e as num).toInt()).toList(),
    isActive: json['is_active'] as bool? ?? true,
  );

  final String id;
  final String label;

  /// HH:MM, WIB.
  final String startTime;
  final String endTime;

  /// Ordering closes this many minutes before [startTime].
  final int cutoffMinutes;

  /// Max orders per day; null = unlimited.
  final int? quota;

  /// ISO weekdays (1 = Senin … 7 = Minggu); null = every day.
  final List<int>? days;
  final bool isActive;
}

class DeliveryHoliday {
  DeliveryHoliday({required this.id, required this.date, required this.name, this.shippingMethodId});

  factory DeliveryHoliday.fromJson(Map<String, dynamic> json) => DeliveryHoliday(
    id: json['id'] as String,
    date: DateTime.parse(json['date'] as String),
    name: json['name'] as String? ?? '',
    shippingMethodId: json['shipping_method_id'] as String?,
  );

  final String id;
  final DateTime date;
  final String name;

  /// null = applies to every shipping method.
  final String? shippingMethodId;
}
