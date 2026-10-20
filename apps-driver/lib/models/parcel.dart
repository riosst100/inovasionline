import '../core/formatters.dart';

/// What the driver may do with a parcel next.
enum ParcelAction { ship, deliver, none }

class Parcel {
  Parcel({
    required this.id,
    required this.orderNumber,
    required this.status,
    required this.action,
    required this.customerName,
    this.customerPhone,
    this.recipientName,
    this.address,
    this.itemsCount = 0,
    this.grandTotal = 0,
    this.codAmount = 0,
    this.customerNotes,
    this.completedAt,
  });

  factory Parcel.fromJson(Map<String, dynamic> json) => Parcel(
    id: json['id'].toString(),
    orderNumber: json['order_number'] as String? ?? '',
    status: json['status'] as String? ?? '',
    action: switch (json['next_action']) {
      'ship' => ParcelAction.ship,
      'deliver' => ParcelAction.deliver,
      _ => ParcelAction.none,
    },
    customerName: json['customer_name'] as String? ?? 'Pelanggan',
    customerPhone: json['customer_phone'] as String?,
    recipientName: json['recipient_name'] as String?,
    address: json['address'] as String?,
    itemsCount: (json['items_count'] as num?)?.toInt() ?? 0,
    grandTotal: parseNum(json['grand_total']),
    codAmount: parseNum(json['cod_amount']),
    customerNotes: json['customer_notes'] as String?,
    completedAt: DateTime.tryParse(json['completed_at'] as String? ?? ''),
  );

  final String id;
  final String orderNumber;
  final String status;
  final ParcelAction action;
  final String customerName;
  final String? customerPhone;
  final String? recipientName;
  final String? address;
  final int itemsCount;
  final double grandTotal;

  /// Cash to collect at the door; 0 when already paid.
  final double codAmount;
  final String? customerNotes;
  final DateTime? completedAt;

  String get receiver => (recipientName?.isNotEmpty ?? false) ? recipientName! : customerName;
}
