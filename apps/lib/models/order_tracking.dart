import 'dart:math';

/// The courier's latest position for one order (`GET /orders/{id}/tracking`).
class OrderTracking {
  OrderTracking({
    required this.status,
    required this.active,
    this.driver,
    this.location,
    this.destination,
    this.route,
  });

  factory OrderTracking.fromJson(Map<String, dynamic> json) => OrderTracking(
        status: json['status'] as String? ?? '',
        active: json['active'] as bool? ?? false,
        driver: json['driver'] != null ? TrackingDriver.fromJson(json['driver'] as Map<String, dynamic>) : null,
        location:
            json['location'] != null ? TrackingLocation.fromJson(json['location'] as Map<String, dynamic>) : null,
        destination: json['destination'] != null ? GeoPoint.fromJson(json['destination'] as Map<String, dynamic>) : null,
        route: json['route'] != null ? TrackingRoute.fromJson(json['route'] as Map<String, dynamic>) : null,
      );

  final String status;

  /// The order is on the way with a courier assigned; otherwise [driver] and [location] are null.
  final bool active;
  final TrackingDriver? driver;

  /// Null until the courier's app has sent a first GPS fix.
  final TrackingLocation? location;

  /// Where the buyer's phone was at checkout (the address itself has no coordinates); null when unknown.
  final GeoPoint? destination;

  /// Road route from the courier to [destination]; null without a route service (draw a straight line).
  final TrackingRoute? route;

  /// Meters left: along the road when [route] is known, otherwise as the crow flies.
  double? get remainingMeters {
    final from = location;
    final to = destination;
    if (route != null) return route!.distanceMeters.toDouble();
    if (from == null || to == null) return null;
    return GeoPoint(from.latitude, from.longitude).metersTo(to);
  }
}

class GeoPoint {
  const GeoPoint(this.latitude, this.longitude);

  factory GeoPoint.fromJson(Map<String, dynamic> json) =>
      GeoPoint((json['latitude'] as num).toDouble(), (json['longitude'] as num).toDouble());

  final double latitude;
  final double longitude;

  double metersTo(GeoPoint other) {
    double rad(double deg) => deg * pi / 180;
    final dLat = rad(other.latitude - latitude);
    final dLng = rad(other.longitude - longitude);
    final a = pow(sin(dLat / 2), 2) + cos(rad(latitude)) * cos(rad(other.latitude)) * pow(sin(dLng / 2), 2);
    return 6371000 * 2 * atan2(sqrt(a), sqrt(1 - a));
  }
}

class TrackingRoute {
  TrackingRoute({required this.points, required this.distanceMeters, required this.durationSeconds});

  factory TrackingRoute.fromJson(Map<String, dynamic> json) => TrackingRoute(
        points: (json['points'] as List<dynamic>)
            .map((p) => GeoPoint(((p as List)[0] as num).toDouble(), (p[1] as num).toDouble()))
            .toList(),
        distanceMeters: (json['distance_m'] as num?)?.toInt() ?? 0,
        durationSeconds: (json['duration_s'] as num?)?.toInt() ?? 0,
      );

  /// From (near) the courier to the destination, already trimmed to the part not yet driven.
  final List<GeoPoint> points;
  final int distanceMeters;

  /// By car; a motorbike in city traffic is often a bit quicker.
  final int durationSeconds;
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
