class Category {
  Category({
    required this.id,
    required this.name,
    required this.slug,
    this.parentId,
    this.description,
    this.icon,
    this.isActive = true,
  });

  factory Category.fromJson(Map<String, dynamic> json) => Category(
        id: json['id'] as String,
        parentId: json['parent_id'] as String?,
        name: json['name'] as String,
        slug: json['slug'] as String,
        description: json['description'] as String?,
        icon: json['icon'] as String?,
        isActive: json['is_active'] as bool? ?? true,
      );

  final String id;
  final String? parentId;
  final String name;
  final String slug;
  final String? description;
  final String? icon;
  final bool isActive;

  Category copyWith({String? icon}) => Category(
        id: id,
        parentId: parentId,
        name: name,
        slug: slug,
        description: description,
        icon: icon ?? this.icon,
        isActive: isActive,
      );
}
