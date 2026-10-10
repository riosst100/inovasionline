class User {
  User({
    required this.id,
    required this.name,
    this.email,
    required this.phone,
    required this.role,
    required this.isSeller,
    required this.hasAddress,
    this.avatarUrl,
    this.emailVerifiedAt,
    this.provinceCode,
    this.cityCode,
    this.districtCode,
    this.villageCode,
    this.gender,
    this.dateOfBirth,
  });

  factory User.fromJson(Map<String, dynamic> json) => User(
    id: json['id'] as String,
    name: json['name'] as String,
    email: json['email'] as String?,
    phone: json['phone'] as String?,
    role: json['role'] as String?,
    avatarUrl: json['avatar_url'] as String?,
    isSeller: json['is_seller'] as bool? ?? false,
    hasAddress: json['has_address'] as bool? ?? false,
    emailVerifiedAt: json['email_verified_at'] as String?,
    provinceCode: json['province_code'] as String?,
    cityCode: json['city_code'] as String?,
    districtCode: json['district_code'] as String?,
    villageCode: json['village_code'] as String?,
    gender: json['gender'] as String?,
    dateOfBirth: json['date_of_birth'] as String?,
  );

  final String id;
  final String name;
  final String? email;
  final String? phone;
  final String? role;
  final String? avatarUrl;
  final bool isSeller;
  final bool hasAddress;
  final String? emailVerifiedAt;
  final String? provinceCode;
  final String? cityCode;
  final String? districtCode;
  final String? villageCode;
  final String? gender;
  final String? dateOfBirth;
}
