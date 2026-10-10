class Store {
  Store({
    required this.id,
    required this.name,
    required this.slug,
    this.logoUrl,
    this.coverUrl,
    this.city,
    this.province,
    this.cityCode,
    this.isFeatured = false,
    this.deliveryAvailable = false,
    this.productCount = 0,
    this.soldCount = 0,
    this.description,
    this.address,
    this.ownerUserId,
  });

  factory Store.fromJson(Map<String, dynamic> json) => Store(
        id: json['id'] as String,
        name: json['name'] as String,
        slug: json['slug'] as String,
        logoUrl: json['logo_url'] as String?,
        coverUrl: json['cover_url'] as String?,
        city: json['city'] as String?,
        province: json['province'] as String?,
        cityCode: json['city_code'] as String?,
        isFeatured: json['is_featured'] as bool? ?? false,
        deliveryAvailable: json['delivery_available'] as bool? ?? false,
        productCount: json['product_count'] as int? ?? 0,
        soldCount: json['sold_count'] as int? ?? 0,
        description: json['description'] as String?,
        address: json['address'] as String?,
        ownerUserId: json['owner_user_id'] as String?,
      );

  final String id;
  final String name;
  final String slug;
  final String? logoUrl;
  final String? coverUrl;
  final String? city;
  final String? province;
  final String? cityCode;
  final bool isFeatured;
  final bool deliveryAvailable;
  final int productCount;
  final int soldCount;
  final String? description;
  final String? address;
  final String? ownerUserId;
}
