import 'payment_method.dart';
import 'shipping_method.dart';

class OrderItem {
  OrderItem({
    required this.id,
    required this.productName,
    required this.unitPrice,
    required this.quantity,
    required this.discountAmount,
    required this.lineTotal,
    this.productId,
    this.productVariantId,
    this.productSku,
    this.variantName,
    this.productImageUrl,
    this.notes,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) => OrderItem(
        id: json['id'] as String,
        productId: json['product_id'] as String?,
        productVariantId: json['product_variant_id'] as String?,
        productName: json['product_name'] as String,
        productSku: json['product_sku'] as String?,
        variantName: json['variant_name'] as String?,
        productImageUrl: json['product_image_url'] as String?,
        unitPrice: double.tryParse(json['unit_price'].toString()) ?? 0,
        quantity: json['quantity'] as int? ?? 0,
        discountAmount: double.tryParse(json['discount_amount'].toString()) ?? 0,
        lineTotal: double.tryParse(json['line_total'].toString()) ?? 0,
        notes: json['notes'] as String?,
      );

  final String id;
  final String? productId;
  final String? productVariantId;
  final String productName;
  final String? productSku;
  final String? variantName;
  final String? productImageUrl;
  final double unitPrice;
  final int quantity;
  final double discountAmount;
  final double lineTotal;
  final String? notes;
}

class OrderStoreSummary {
  OrderStoreSummary({required this.id, required this.name, required this.slug, this.logoUrl});

  factory OrderStoreSummary.fromJson(Map<String, dynamic> json) => OrderStoreSummary(
        id: json['id'] as String,
        name: json['name'] as String,
        slug: json['slug'] as String,
        logoUrl: json['logo_url'] as String?,
      );

  final String id;
  final String name;
  final String slug;
  final String? logoUrl;
}

class OrderStatusHistoryEntry {
  OrderStatusHistoryEntry({required this.status, required this.at, required this.by});

  factory OrderStatusHistoryEntry.fromJson(Map<String, dynamic> json) => OrderStatusHistoryEntry(
        status: json['status'] as String? ?? '',
        at: json['at'] as String? ?? '',
        by: json['by'] as String? ?? '',
      );

  final String status;
  final String at;
  final String by;
}

class Order {
  Order({
    required this.id,
    required this.orderNumber,
    required this.subtotal,
    required this.discountTotal,
    required this.shippingFee,
    this.serviceFee = 0,
    required this.taxTotal,
    required this.grandTotal,
    required this.status,
    required this.paymentStatus,
    required this.items,
    required this.statusHistory,
    required this.createdAt,
    this.store,
    this.paymentMethod,
    this.shippingMethod,
    this.deliveryMethod,
    this.deliveryAddress,
    this.customerNotes,
    this.sellerNotes,
    this.paymentRedirectUrl,
  });

  factory Order.fromJson(Map<String, dynamic> json) => Order(
        id: json['id'] as String,
        orderNumber: json['order_number'] as String,
        store: json['store'] != null ? OrderStoreSummary.fromJson(json['store'] as Map<String, dynamic>) : null,
        paymentMethod:
            json['payment_method'] != null ? PaymentMethod.fromJson(json['payment_method'] as Map<String, dynamic>) : null,
        shippingMethod:
            json['shipping_method'] != null ? ShippingMethod.fromJson(json['shipping_method'] as Map<String, dynamic>) : null,
        subtotal: double.tryParse(json['subtotal'].toString()) ?? 0,
        discountTotal: double.tryParse(json['discount_total'].toString()) ?? 0,
        shippingFee: double.tryParse(json['shipping_fee'].toString()) ?? 0,
        serviceFee: double.tryParse(json['service_fee']?.toString() ?? '') ?? 0,
        taxTotal: double.tryParse(json['tax_total'].toString()) ?? 0,
        grandTotal: double.tryParse(json['grand_total'].toString()) ?? 0,
        status: json['status'] as String? ?? 'pending',
        paymentStatus: json['payment_status'] as String? ?? 'unpaid',
        deliveryMethod: json['delivery_method'] as String?,
        deliveryAddress: (json['delivery_address'] as Map?)?.cast<String, dynamic>(),
        customerNotes: json['customer_notes'] as String?,
        sellerNotes: json['seller_notes'] as String?,
        paymentRedirectUrl: json['payment_redirect_url'] as String?,
        statusHistory: (json['status_history'] as List<dynamic>? ?? [])
            .map((e) => OrderStatusHistoryEntry.fromJson(e as Map<String, dynamic>))
            .toList(),
        items: (json['items'] as List<dynamic>? ?? []).map((e) => OrderItem.fromJson(e as Map<String, dynamic>)).toList(),
        createdAt: json['created_at'] as String? ?? '',
      );

  final String id;
  final String orderNumber;
  final OrderStoreSummary? store;
  final PaymentMethod? paymentMethod;
  final ShippingMethod? shippingMethod;
  final double subtotal;
  final double discountTotal;
  final double shippingFee;
  final double serviceFee;
  final double taxTotal;
  final double grandTotal;
  final String status;
  final String paymentStatus;
  final String? deliveryMethod;
  final Map<String, dynamic>? deliveryAddress;
  final String? customerNotes;
  final String? sellerNotes;
  final String? paymentRedirectUrl;
  final List<OrderStatusHistoryEntry> statusHistory;
  final List<OrderItem> items;
  final String createdAt;

  bool get isPending => status == 'pending';

  bool get needsOnlinePayment =>
      isPending && paymentStatus != 'paid' && paymentMethod?.type == 'payment_gateway';
}
