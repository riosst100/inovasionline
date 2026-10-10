class ShippingMethod {
  ShippingMethod({
    required this.id,
    required this.storeId,
    required this.type,
    required this.rateType,
    required this.name,
    required this.baseFee,
    required this.isEnabled,
    required this.sortOrder,
    this.description,
    this.resolvedFee,
    this.minOrderAmount,
    this.estimatedDeliveryTime,
    this.pickupAddress,
    this.pickupInstructions,
    this.freeShippingMinAmount,
  });

  factory ShippingMethod.fromJson(Map<String, dynamic> json) => ShippingMethod(
        id: json['id'] as String,
        storeId: json['store_id'] as String,
        type: json['type'] as String,
        rateType: json['rate_type'] as String? ?? 'flat',
        name: json['name'] as String,
        description: json['description'] as String?,
        baseFee: double.tryParse(json['base_fee'].toString()) ?? 0,
        resolvedFee: json['resolved_fee'] != null ? double.tryParse(json['resolved_fee'].toString()) : null,
        minOrderAmount: json['min_order_amount'] != null ? double.tryParse(json['min_order_amount'].toString()) : null,
        estimatedDeliveryTime: json['estimated_delivery_time'] as String?,
        pickupAddress: json['pickup_address'] as String?,
        pickupInstructions: json['pickup_instructions'] as String?,
        freeShippingMinAmount:
            json['free_shipping_min_amount'] != null ? double.tryParse(json['free_shipping_min_amount'].toString()) : null,
        isEnabled: json['is_enabled'] as bool? ?? true,
        sortOrder: json['sort_order'] as int? ?? 0,
      );

  final String id;
  final String storeId;
  final String type;
  final String rateType;
  final String name;
  final String? description;
  final double baseFee;
  final double? resolvedFee;
  final double? minOrderAmount;
  final String? estimatedDeliveryTime;
  final String? pickupAddress;
  final String? pickupInstructions;
  final double? freeShippingMinAmount;
  final bool isEnabled;
  final int sortOrder;

  double get displayFee => resolvedFee ?? baseFee;

  bool get isTableRate => rateType == 'table';
}
