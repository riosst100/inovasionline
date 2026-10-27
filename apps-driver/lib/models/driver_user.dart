class DriverUser {
  DriverUser({required this.id, required this.name, this.phone, this.vehicle});

  factory DriverUser.fromJson(Map<String, dynamic> json) {
    final type = json['vehicle_type'] as String?;
    final plate = json['vehicle_plate_number'] as String?;
    return DriverUser(
      id: json['id'].toString(),
      name: json['name'] as String? ?? '',
      phone: json['phone'] as String?,
      vehicle: [type, plate].whereType<String>().where((e) => e.isNotEmpty).join(' - '),
    );
  }

  /// Mirrors the backend gate on /admin/driver/*: super admins and roles with delivery.update.
  static bool canDeliver(Map<String, dynamic> json) {
    final role = json['role'] as Map<String, dynamic>?;
    final perms = (role?['permissions'] as List?) ?? const [];
    return json['is_super_admin'] == true || perms.contains('*') || perms.contains('delivery.update');
  }

  final String id;
  final String name;
  final String? phone;
  final String? vehicle;
}
