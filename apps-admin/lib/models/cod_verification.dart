class CodVerification {
  CodVerification({
    required this.id,
    required this.videoUrl,
    required this.status,
    required this.steps,
    required this.createdAt,
    this.userId,
    this.userName,
    this.userContact,
    this.device,
    this.ipAddress,
    this.revokedReason,
    this.revokedAt,
  });

  factory CodVerification.fromJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>?;
    return CodVerification(
      id: json['id'] as String,
      videoUrl: json['video_url'] as String,
      status: json['status'] as String? ?? 'verified',
      steps: (json['steps'] as List? ?? []).map((e) => e.toString()).toList(),
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '')?.toLocal(),
      userId: (json['user_id'] ?? user?['id']) as String?,
      userName: user?['name'] as String?,
      userContact: (user?['email'] ?? user?['phone']) as String?,
      device: json['device'] as String?,
      ipAddress: json['ip_address'] as String?,
      revokedReason: json['revoked_reason'] as String?,
      revokedAt: DateTime.tryParse(json['revoked_at'] as String? ?? '')?.toLocal(),
    );
  }

  final String id;
  final String videoUrl;

  /// `verified` or `revoked`.
  final String status;
  final List<String> steps;
  final DateTime? createdAt;
  final String? userId;
  final String? userName;
  final String? userContact;
  final String? device;
  final String? ipAddress;
  final String? revokedReason;
  final DateTime? revokedAt;

  bool get isRevoked => status == 'revoked';
}
