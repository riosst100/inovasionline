class FaceProfile {
  const FaceProfile({required this.id, required this.status, required this.selfieUrl});

  factory FaceProfile.fromJson(Map<String, dynamic> json) => FaceProfile(
        id: json['id'] as String,
        status: json['status'] as String,
        selfieUrl: json['selfie_url'] as String,
      );

  final String id;
  final String status;
  final String selfieUrl;

  bool get isReady => status == 'ready';
  bool get isPending => status == 'pending';
  bool get isFailed => status == 'failed';
}
