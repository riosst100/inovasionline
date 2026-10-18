import '../core/utils/formatters.dart';

/// Mirrors App\Support\Enums\OrderStatus; [next] mirrors Order::TRANSITIONS.
enum OrderStatus {
  pending('Menunggu'),
  accepted('Diterima'),
  processing('Disiapkan'),
  ready('Siap Kirim/Ambil'),
  completed('Selesai'),
  cancelled('Dibatalkan');

  const OrderStatus(this.label);

  final String label;

  static OrderStatus parse(String? value) => values.firstWhere((s) => s.name == value, orElse: () => pending);

  List<OrderStatus> get next => switch (this) {
    pending => [accepted, processing, cancelled],
    accepted => [processing, cancelled],
    processing => [ready, cancelled],
    ready => [completed],
    completed || cancelled => const [],
  };

  /// Verb shown on the button that moves an order into this status.
  String get actionLabel => switch (this) {
    accepted => 'Terima Pesanan',
    processing => 'Mulai Siapkan',
    ready => 'Tandai Siap',
    completed => 'Selesaikan',
    cancelled => 'Batalkan',
    pending => label,
  };
}

class OrderItem {
  OrderItem({
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.lineTotal,
    this.variantName,
    this.sku,
    this.imageUrl,
    this.notes,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) => OrderItem(
    productName: json['product_name'] as String? ?? '-',
    variantName: json['variant_name'] as String?,
    sku: json['product_sku'] as String?,
    imageUrl: json['product_image_url'] as String?,
    quantity: json['quantity'] as int? ?? 0,
    unitPrice: parseNum(json['unit_price']),
    lineTotal: parseNum(json['line_total']),
    notes: json['notes'] as String?,
  );

  final String productName;
  final String? variantName;
  final String? sku;
  final String? imageUrl;
  final int quantity;
  final double unitPrice;
  final double lineTotal;
  final String? notes;
}

class StatusHistoryEntry {
  StatusHistoryEntry({required this.status, this.at, this.by});

  factory StatusHistoryEntry.fromJson(Map<String, dynamic> json) => StatusHistoryEntry(
    status: OrderStatus.parse(json['status'] as String?),
    at: DateTime.tryParse(json['at']?.toString() ?? ''),
    by: json['by']?.toString(),
  );

  final OrderStatus status;
  final DateTime? at;
  final String? by;

  String get byLabel => switch (by) {
    null => '',
    'system' => 'Sistem',
    'buyer' => 'Pembeli',
    final b when b.startsWith('admin') => 'Admin',
    final b => b,
  };
}

class Order {
  Order({
    required this.id,
    required this.orderNumber,
    required this.status,
    required this.paymentStatus,
    required this.grandTotal,
    required this.createdAt,
    this.customerName,
    this.items = const [],
    this.itemsCount,
    this.subtotal = 0,
    this.discountTotal = 0,
    this.shippingFee = 0,
    this.serviceFee = 0,
    this.paymentMethodName,
    this.shippingMethodName,
    this.deliveryMethod,
    this.deliveryAddress,
    this.deliveryDate,
    this.deliverySlot,
    this.customerNotes,
    this.adminNotes,
    this.history = const [],
    this.paidAt,
  });

  factory Order.fromJson(Map<String, dynamic> json) => Order(
    id: json['id'].toString(),
    orderNumber: json['order_number'] as String? ?? '-',
    status: OrderStatus.parse(json['status'] as String?),
    paymentStatus: json['payment_status'] as String? ?? 'unpaid',
    customerName: (json['user'] as Map?)?['name'] as String?,
    items: (json['items'] as List? ?? []).map((e) => OrderItem.fromJson(e as Map<String, dynamic>)).toList(),
    itemsCount: json['items_count'] as int?,
    subtotal: parseNum(json['subtotal']),
    discountTotal: parseNum(json['discount_total']),
    shippingFee: parseNum(json['shipping_fee']),
    serviceFee: parseNum(json['service_fee']),
    grandTotal: parseNum(json['grand_total']),
    paymentMethodName: (json['payment_method'] as Map?)?['name'] as String?,
    shippingMethodName: (json['shipping_method'] as Map?)?['name'] as String?,
    deliveryMethod: json['delivery_method'] as String?,
    deliveryAddress: (json['delivery_address'] as Map?)?.cast<String, dynamic>(),
    deliveryDate: DateTime.tryParse(json['delivery_date']?.toString() ?? ''),
    deliverySlot: (json['delivery_slot'] as Map?)?.cast<String, dynamic>(),
    customerNotes: json['customer_notes'] as String?,
    adminNotes: json['admin_notes'] as String?,
    history: (json['status_history'] as List? ?? [])
        .map((e) => StatusHistoryEntry.fromJson(e as Map<String, dynamic>))
        .toList(),
    paidAt: DateTime.tryParse(json['paid_at']?.toString() ?? ''),
    createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
  );

  final String id;
  final String orderNumber;
  final OrderStatus status;
  final String paymentStatus;
  final String? customerName;
  final List<OrderItem> items;
  final int? itemsCount;
  final double subtotal;
  final double discountTotal;
  final double shippingFee;
  final double serviceFee;
  final double grandTotal;
  final String? paymentMethodName;
  final String? shippingMethodName;
  final String? deliveryMethod;
  final Map<String, dynamic>? deliveryAddress;
  final DateTime? deliveryDate;
  final Map<String, dynamic>? deliverySlot;
  final String? customerNotes;
  final String? adminNotes;
  final List<StatusHistoryEntry> history;
  final DateTime? paidAt;
  final DateTime createdAt;

  String get paymentStatusLabel => switch (paymentStatus) {
    'paid' => 'Lunas',
    'unpaid' => 'Belum Bayar',
    'failed' => 'Gagal',
    'refunded' => 'Dikembalikan',
    _ => paymentStatus,
  };

  String? get recipientName => deliveryAddress?['recipient_name'] as String?;

  String? get recipientPhone => deliveryAddress?['recipient_phone'] as String?;

  String? get fullAddress {
    final a = deliveryAddress;
    if (a == null) return null;
    return [
      a['address_detail'],
      a['village_name'],
      a['district_name'],
      a['city_name'],
      a['province_name'],
    ].whereType<String>().where((s) => s.trim().isNotEmpty).join(', ');
  }

  String? get deliverySlotLabel {
    final slot = deliverySlot;
    if (slot == null) return null;
    return '${slot['label'] ?? ''} (${slot['start_time']} - ${slot['end_time']})'.trim();
  }
}
