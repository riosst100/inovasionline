/// A customer account (Pengguna), from /admin/customers.
class Customer {
  Customer({
    required this.id,
    required this.name,
    this.email,
    this.phone,
    this.avatarUrl,
    this.verificationStatus,
    this.verificationId,
    this.lastSeenAt,
    this.createdAt,
    this.isBlocked = false,
    this.bannedFeatures = const [],
  });

  factory Customer.fromJson(Map<String, dynamic> json) => Customer(
    id: json['id'] as String,
    name: json['name'] as String? ?? '-',
    email: json['email'] as String?,
    phone: json['phone'] as String?,
    avatarUrl: json['avatar_url'] as String?,
    verificationStatus: json['verification_status'] as String?,
    verificationId: json['verification_id'] as String?,
    lastSeenAt: DateTime.tryParse(json['last_seen_at'] as String? ?? '')?.toLocal(),
    createdAt: DateTime.tryParse(json['created_at'] as String? ?? '')?.toLocal(),
    isBlocked: json['is_blocked'] as bool? ?? false,
    bannedFeatures: (json['banned_features'] as List? ?? []).map((e) => e.toString()).toList(),
  );

  final String id;
  final String name;
  final String? email;
  final String? phone;
  final String? avatarUrl;

  /// Face verification (COD/Paylater): null = never, `verified`, or `revoked`.
  final String? verificationStatus;

  /// The verification event behind [verificationStatus] (verified by it, or revoked on it).
  final String? verificationId;

  /// Latest app heartbeat or API call; only sent by the list and detail endpoints.
  final DateTime? lastSeenAt;
  final DateTime? createdAt;
  final bool isBlocked;
  final List<String> bannedFeatures;

  String? get contact => (email?.isNotEmpty ?? false) ? email : phone;

  /// Responses to actions (e.g. revoke) don't carry last_seen_at, so keep the listed one.
  Customer withLastSeenOf(Customer previous) => Customer(
    id: id,
    name: name,
    email: email,
    phone: phone,
    avatarUrl: avatarUrl,
    verificationStatus: verificationStatus,
    verificationId: verificationId,
    lastSeenAt: lastSeenAt ?? previous.lastSeenAt,
    createdAt: createdAt,
    isBlocked: isBlocked,
    bannedFeatures: bannedFeatures,
  );
}
