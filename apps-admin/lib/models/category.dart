class Category {
  Category({
    required this.id,
    required this.name,
    required this.isActive,
    this.parentId,
    this.description,
    this.imageUrl,
    this.sortOrder = 0,
  });

  factory Category.fromJson(Map<String, dynamic> json) => Category(
    id: json['id'].toString(),
    parentId: json['parent_id']?.toString(),
    name: json['name'] as String? ?? '',
    description: json['description'] as String?,
    imageUrl: json['image_url'] as String?,
    sortOrder: json['sort_order'] as int? ?? 0,
    isActive: json['is_active'] as bool? ?? false,
  );

  final String id;
  final String? parentId;
  final String name;
  final String? description;
  final String? imageUrl;
  final int sortOrder;
  final bool isActive;
}

class Warehouse {
  Warehouse({required this.id, required this.name, this.code});

  factory Warehouse.fromJson(Map<String, dynamic> json) =>
      Warehouse(id: json['id'].toString(), name: json['name'] as String? ?? '', code: json['code'] as String?);

  final String id;
  final String name;
  final String? code;
}
