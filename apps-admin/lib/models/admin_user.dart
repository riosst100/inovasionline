class AdminUser {
  AdminUser({required this.id, required this.name, required this.email, this.phone, this.avatarUrl, this.roleName});

  factory AdminUser.fromJson(Map<String, dynamic> json) => AdminUser(
    id: json['id'].toString(),
    name: json['name'] as String? ?? '',
    email: json['email'] as String? ?? '',
    phone: json['phone'] as String?,
    avatarUrl: json['avatar_url'] as String?,
    roleName: (json['role'] as Map?)?['name'] as String?,
  );

  final String id;
  final String name;
  final String email;
  final String? phone;
  final String? avatarUrl;
  final String? roleName;
}
