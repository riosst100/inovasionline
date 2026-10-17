/// One day of IO Same Day windows, as returned by GET /delivery-schedules.
class DeliveryDay {
  DeliveryDay({
    required this.date,
    required this.dayLabel,
    required this.dateLabel,
    required this.slots,
    this.holiday,
  });

  factory DeliveryDay.fromJson(Map<String, dynamic> json) => DeliveryDay(
        date: json['date'] as String,
        dayLabel: json['day_label'] as String? ?? '',
        dateLabel: json['date_label'] as String? ?? '',
        holiday: json['holiday'] as String?,
        slots: (json['slots'] as List<dynamic>? ?? [])
            .map((e) => DeliverySlot.fromJson(e as Map<String, dynamic>, date: json['date'] as String))
            .toList(),
      );

  /// Y-m-d
  final String date;
  final String dayLabel;
  final String dateLabel;
  final List<DeliverySlot> slots;

  /// Holiday name when no deliveries run on this day.
  final String? holiday;

  bool get hasAvailable => slots.any((s) => s.available);
}

class DeliverySlot {
  DeliverySlot({
    required this.scheduleId,
    required this.date,
    required this.label,
    required this.timeRange,
    required this.available,
    this.remaining,
    this.reason,
  });

  factory DeliverySlot.fromJson(Map<String, dynamic> json, {required String date}) => DeliverySlot(
        scheduleId: json['schedule_id'] as String,
        date: date,
        label: json['label'] as String? ?? '',
        timeRange: json['time_range'] as String? ?? '',
        available: json['available'] as bool? ?? false,
        remaining: json['remaining'] as int?,
        reason: json['reason'] as String?,
      );

  final String scheduleId;

  /// Y-m-d
  final String date;
  final String label;
  final String timeRange;
  final bool available;
  final int? remaining;
  final String? reason;

  bool isSameAs(DeliverySlot? other) => other != null && other.scheduleId == scheduleId && other.date == date;
}

/// The chosen slot plus the day labels, for showing the selection back to the buyer.
class SelectedDeliverySlot {
  const SelectedDeliverySlot({required this.slot, required this.day});

  final DeliverySlot slot;
  final DeliveryDay day;

  String get summary => '${day.dayLabel}, ${day.dateLabel} · ${slot.label} (${slot.timeRange})';
}
