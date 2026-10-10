import 'product.dart';

class FlashSaleScheduleSlot {
  FlashSaleScheduleSlot({
    required this.id,
    required this.label,
    required this.startTime,
    required this.endTime,
    required this.startsAt,
    required this.endsAt,
    required this.status,
    required this.products,
  });

  factory FlashSaleScheduleSlot.fromJson(Map<String, dynamic> json) => FlashSaleScheduleSlot(
        id: json['id'] as String,
        label: json['label'] as String,
        startTime: json['start_time'] as String,
        endTime: json['end_time'] as String,
        startsAt: DateTime.parse(json['starts_at'] as String),
        endsAt: DateTime.parse(json['ends_at'] as String),
        status: json['status'] as String,
        products: (json['products'] as List<dynamic>? ?? [])
            .map((e) => Product.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  final String id;
  final String label;
  final String startTime;
  final String endTime;
  final DateTime startsAt;
  final DateTime endsAt;
  final String status;
  final List<Product> products;

  bool get isActive => status == 'active';
  bool get isUpcoming => status == 'upcoming';
}

class FlashSaleSchedule {
  FlashSaleSchedule({required this.date, required this.slots, required this.availableDates});

  factory FlashSaleSchedule.fromJson(Map<String, dynamic> json) => FlashSaleSchedule(
        date: json['date'] as String?,
        slots: (json['slots'] as List<dynamic>? ?? [])
            .map((e) => FlashSaleScheduleSlot.fromJson(e as Map<String, dynamic>))
            .toList(),
        availableDates: (json['available_dates'] as List<dynamic>? ?? []).map((e) => e.toString()).toList(),
      );

  final String? date;
  final List<FlashSaleScheduleSlot> slots;
  final List<String> availableDates;
}
