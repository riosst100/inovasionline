class PotoCandidPhoto {
  const PotoCandidPhoto({
    required this.id,
    required this.price,
    required this.status,
    required this.faceCount,
    required this.isPurchased,
    required this.isMatched,
    this.photographerName,
    this.eventTitle,
    this.confidenceScore,
    this.url,
    this.watermarkedUrl,
  });

  factory PotoCandidPhoto.fromJson(Map<String, dynamic> json) => PotoCandidPhoto(
        id: json['id'] as String,
        photographerName: json['photographer_name'] as String?,
        eventTitle: json['event_title'] as String?,
        price: (json['price'] as num?)?.toDouble() ?? 0,
        status: json['status'] as String? ?? 'processing',
        faceCount: json['face_count'] as int? ?? 0,
        isPurchased: json['is_purchased'] as bool? ?? false,
        isMatched: json['is_matched'] as bool? ?? false,
        confidenceScore: (json['confidence_score'] as num?)?.toDouble(),
        url: json['url'] as String?,
        watermarkedUrl: json['watermarked_url'] as String?,
      );

  final String id;
  final String? photographerName;
  final String? eventTitle;
  final double price;
  final String status;
  final int faceCount;
  final bool isPurchased;
  final bool isMatched;
  final double? confidenceScore;
  final String? url;
  final String? watermarkedUrl;

  /// The image to render: full resolution once purchased, watermarked
  /// preview otherwise.
  String? get displayUrl => isPurchased ? (url ?? watermarkedUrl) : watermarkedUrl;
}
