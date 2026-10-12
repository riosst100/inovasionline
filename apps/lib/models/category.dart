class Category {
  Category({
    required this.id,
    required this.name,
    required this.slug,
    this.parentId,
    this.description,
    this.icon,
    this.imageUrl,
    this.isActive = true,
  });

  factory Category.fromJson(Map<String, dynamic> json) => Category(
        id: json['id'] as String,
        parentId: json['parent_id'] as String?,
        name: json['name'] as String,
        slug: json['slug'] as String,
        description: json['description'] as String?,
        icon: json['icon'] as String?,
        imageUrl: json['image_url'] as String?,
        isActive: json['is_active'] as bool? ?? true,
      );

  final String id;
  final String? parentId;
  final String name;
  final String slug;
  final String? description;
  final String? icon;
  final String? imageUrl;
  final bool isActive;

  Category copyWith({String? icon, String? imageUrl}) => Category(
        id: id,
        parentId: parentId,
        name: name,
        slug: slug,
        description: description,
        icon: icon ?? this.icon,
        imageUrl: imageUrl ?? this.imageUrl,
        isActive: isActive,
      );
}
