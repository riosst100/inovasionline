import '../core/utils/formatters.dart';
import 'order.dart';

/// One row of GET /admin/orders/instant or /admin/orders/scheduled.
class QueuedOrder {
  const QueuedOrder({
    required this.id,
    required this.orderNumber,
    required this.status,
    required this.grandTotal,
    required this.createdAt,
    this.customer,
    this.deadlineAt,
    this.deliveryScheduleId,
  });

  final String id;
  final String orderNumber;
  final OrderStatus status;
  final double grandTotal;
  final DateTime createdAt;
  final String? customer;

  /// Instant orders only: createdAt + dispatch minutes.
  final DateTime? deadlineAt;

  /// Scheduled orders only.
  final String? deliveryScheduleId;

  factory QueuedOrder.fromJson(Map<String, dynamic> json) => QueuedOrder(
    id: json['id'].toString(),
    orderNumber: json['order_number'] as String? ?? '-',
    status: OrderStatus.parse(json['status'] as String?),
    grandTotal: parseNum(json['grand_total']),
    createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
    customer: json['customer'] as String?,
    deadlineAt: DateTime.tryParse(json['deadline_at']?.toString() ?? ''),
    deliveryScheduleId: json['delivery_schedule_id']?.toString(),
  );
}

/// GET /admin/orders/instant: instant orders not yet shipped, longest waiting first.
class InstantOrderQueue {
  const InstantOrderQueue({
    required this.dispatchMinutes,
    required this.count,
    required this.unpacked,
    required this.orders,
  });

  final int dispatchMinutes;
  final int count;

  /// Still `pending`: nobody has started packing them.
  final int unpacked;
  final List<QueuedOrder> orders;

  factory InstantOrderQueue.fromJson(Map<String, dynamic> json) => InstantOrderQueue(
    dispatchMinutes: parseNum(json['dispatch_minutes']).toInt(),
    count: parseNum(json['count']).toInt(),
    unpacked: parseNum(json['unpacked']).toInt(),
    orders: (json['orders'] as List? ?? []).map((e) => QueuedOrder.fromJson(e as Map<String, dynamic>)).toList(),
  );
}

/// A delivery time slot running on the requested date, with its booked order count.
class DeliverySlotCount {
  const DeliverySlotCount({
    required this.id,
    required this.label,
    required this.timeRange,
    required this.count,
    this.shippingMethod,
    this.quota,
  });

  final String id;
  final String label;

  /// "08:00 - 10:00" (WIB).
  final String timeRange;
  final int count;
  final String? shippingMethod;
  final int? quota;

  factory DeliverySlotCount.fromJson(Map<String, dynamic> json) => DeliverySlotCount(
    id: json['id'].toString(),
    label: json['label'] as String? ?? '-',
    timeRange: json['time_range'] as String? ?? '',
    count: parseNum(json['count']).toInt(),
    shippingMethod: json['shipping_method'] as String?,
    quota: json['quota'] == null ? null : parseNum(json['quota']).toInt(),
  );
}

/// GET /admin/orders/scheduled?date=: scheduled orders of one delivery date, per slot.
class ScheduledOrders {
  const ScheduledOrders({required this.date, required this.count, required this.slots, required this.orders});

  final String date;
  final int count;
  final List<DeliverySlotCount> slots;
  final List<QueuedOrder> orders;

  factory ScheduledOrders.fromJson(Map<String, dynamic> json) => ScheduledOrders(
    date: json['date'] as String? ?? '',
    count: parseNum(json['count']).toInt(),
    slots: (json['slots'] as List? ?? []).map((e) => DeliverySlotCount.fromJson(e as Map<String, dynamic>)).toList(),
    orders: (json['orders'] as List? ?? []).map((e) => QueuedOrder.fromJson(e as Map<String, dynamic>)).toList(),
  );
}
