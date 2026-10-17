class Category {
  Category({
    required this.id,
    required this.name,
    required this.slug,
    this.parentId,
    this.description,
    this.imageUrl,
    this.isActive = true,
    this.productsCount,
  });

  factory Category.fromJson(Map<String, dynamic> json) => Category(
        id: json['id'] as String,
        parentId: json['parent_id'] as String?,
        name: json['name'] as String,
        slug: json['slug'] as String,
        description: json['description'] as String?,
        imageUrl: json['image_url'] as String?,
        isActive: json['is_active'] as bool? ?? true,
        productsCount: (json['products_count'] as num?)?.toInt(),
      );

  final String id;
  final String? parentId;
  final String name;
  final String slug;
  final String? description;
  final String? imageUrl;
  final bool isActive;

  /// Active products in this category and its children; null when unknown.
  final int? productsCount;

  bool get isEmpty => productsCount == 0;

  Category copyWith({String? imageUrl}) => Category(
        id: id,
        parentId: parentId,
        name: name,
        slug: slug,
        description: description,
        imageUrl: imageUrl ?? this.imageUrl,
        isActive: isActive,
        productsCount: productsCount,
      );
}
