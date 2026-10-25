import '../core/utils/formatters.dart';

/// Row of GET /admin/shipping-methods (App\Http\Resources\ShippingMethodResource).
class ShippingMethod {
  const ShippingMethod({
    required this.id,
    required this.name,
    required this.isEnabled,
    required this.requiresSchedule,
    required this.baseFee,
    this.estimatedDeliveryTime,
  });

  final String id;
  final String name;
  final bool isEnabled;

  /// Buyers pick a delivery slot (terjadwal); otherwise it ships right away (instan).
  final bool requiresSchedule;
  final double baseFee;
  final String? estimatedDeliveryTime;

  factory ShippingMethod.fromJson(Map<String, dynamic> json) => ShippingMethod(
    id: json['id'].toString(),
    name: json['name'] as String? ?? '-',
    isEnabled: json['is_enabled'] as bool? ?? false,
    requiresSchedule: json['requires_schedule'] == true,
    baseFee: parseNum(json['base_fee']),
    estimatedDeliveryTime: json['estimated_delivery_time'] as String?,
  );
}
