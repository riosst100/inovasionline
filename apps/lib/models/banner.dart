class AppBanner {
  AppBanner({required this.id, required this.name, required this.imageUrl, this.linkUrl});

  factory AppBanner.fromJson(Map<String, dynamic> json) => AppBanner(
        id: json['id'] as String,
        name: json['name'] as String,
        imageUrl: json['image_url'] as String,
        linkUrl: json['link_url'] as String?,
      );

  final String id;
  final String name;
  final String imageUrl;
  final String? linkUrl;
}
