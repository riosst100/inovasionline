/// The courier's latest position for one order (`GET /orders/{id}/tracking`).
class OrderTracking {
  OrderTracking({required this.status, required this.active, this.driver, this.location});

  factory OrderTracking.fromJson(Map<String, dynamic> json) => OrderTracking(
        status: json['status'] as String? ?? '',
        active: json['active'] as bool? ?? false,
        driver: json['driver'] != null ? TrackingDriver.fromJson(json['driver'] as Map<String, dynamic>) : null,
        location:
            json['location'] != null ? TrackingLocation.fromJson(json['location'] as Map<String, dynamic>) : null,
      );

  final String status;

  /// The order is on the way with a courier assigned; otherwise [driver] and [location] are null.
  final bool active;
  final TrackingDriver? driver;

  /// Null until the courier's app has sent a first GPS fix.
  final TrackingLocation? location;
}

class TrackingDriver {
  TrackingDriver({required this.name, this.phone, this.vehicleType, this.vehiclePlateNumber});

  factory TrackingDriver.fromJson(Map<String, dynamic> json) => TrackingDriver(
        name: json['name'] as String? ?? 'Kurir',
        phone: json['phone'] as String?,
        vehicleType: json['vehicle_type'] as String?,
        vehiclePlateNumber: json['vehicle_plate_number'] as String?,
      );

  final String name;
  final String? phone;
  final String? vehicleType;
  final String? vehiclePlateNumber;
}

class TrackingLocation {
  TrackingLocation({required this.latitude, required this.longitude, this.accuracy, required this.updatedAt});

  factory TrackingLocation.fromJson(Map<String, dynamic> json) => TrackingLocation(
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        accuracy: (json['accuracy'] as num?)?.toDouble(),
        // Server sends seconds ago (not only a timestamp) so a skewed device clock doesn't matter.
        updatedAt: DateTime.now().subtract(Duration(seconds: (json['seconds_ago'] as num?)?.toInt() ?? 0)),
      );

  final double latitude;
  final double longitude;
  final double? accuracy;

  /// Device-local moment of the fix.
  final DateTime updatedAt;
}
