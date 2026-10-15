class User {
  User({
    required this.id,
    required this.name,
    this.email,
    required this.phone,
    required this.role,
    required this.isSeller,
    required this.hasAddress,
    this.addressLabel,
    this.avatarUrl,
    this.emailVerifiedAt,
    this.provinceCode,
    this.cityCode,
    this.districtCode,
    this.villageCode,
    this.gender,
    this.dateOfBirth,
    this.isBlocked = false,
    this.blockReason,
    this.contactUrl,
    this.bannedFeatures = const [],
    this.banReason,
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
    addressLabel: json['address_label'] as String?,
    emailVerifiedAt: json['email_verified_at'] as String?,
    provinceCode: json['province_code'] as String?,
    cityCode: json['city_code'] as String?,
    districtCode: json['district_code'] as String?,
    villageCode: json['village_code'] as String?,
    gender: json['gender'] as String?,
    dateOfBirth: json['date_of_birth'] as String?,
    isBlocked: json['is_blocked'] as bool? ?? false,
    blockReason: json['block_reason'] as String?,
    contactUrl: json['contact_url'] as String?,
    bannedFeatures:
        (json['banned_features'] as List?)?.map((e) => e.toString()).toList() ??
        const [],
    banReason: json['ban_reason'] as String?,
  );

  final String id;
  final String name;
  final String? email;
  final String? phone;
  final String? role;
  final String? avatarUrl;
  final bool isSeller;
  final bool hasAddress;
  final String? addressLabel;
  final String? emailVerifiedAt;
  final String? provinceCode;
  final String? cityCode;
  final String? districtCode;
  final String? villageCode;
  final String? gender;
  final String? dateOfBirth;
  final bool isBlocked;
  final String? blockReason;
  final String? contactUrl;
  final List<String> bannedFeatures;
  final String? banReason;
}
