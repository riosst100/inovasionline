class Product {
  Product({
    required this.id,
    required this.name,
    required this.slug,
    required this.regularPrice,
    this.salePrice,
    this.discountPercent,
    this.stock = 0,
    this.soldCount = 0,
    this.imageUrl,
    this.promotionEndsAt,
  });

  factory Product.fromJson(Map<String, dynamic> json) => Product(
        id: json['id'] as String,
        name: json['name'] as String,
        slug: json['slug'] as String,
        regularPrice: double.tryParse(json['regular_price'].toString()) ?? 0,
        salePrice: json['sale_price'] != null ? double.tryParse(json['sale_price'].toString()) : null,
        discountPercent: json['discount_percent'] as int?,
        stock: json['stock'] as int? ?? 0,
        soldCount: json['sold_count'] as int? ?? 0,
        imageUrl: json['image_url'] as String?,
        promotionEndsAt: json['promotion_ends_at'] as String?,
      );

  final String id;
  final String name;
  final String slug;
  final double regularPrice;
  final double? salePrice;
  final int? discountPercent;
  final int stock;
  final int soldCount;
  final String? imageUrl;
  final String? promotionEndsAt;

  double get displayPrice => salePrice ?? regularPrice;
  bool get hasDiscount => salePrice != null && salePrice! < regularPrice;
}

class ProductImage {
  ProductImage({required this.url, this.isPrimary = false, this.sortOrder = 0});

  factory ProductImage.fromJson(Map<String, dynamic> json) => ProductImage(
        url: json['url'] as String? ?? '',
        isPrimary: json['is_primary'] as bool? ?? false,
        sortOrder: json['sort_order'] as int? ?? 0,
      );

  final String url;
  final bool isPrimary;
  final int sortOrder;
}

class ProductVariant {
  ProductVariant({required this.id, required this.name, required this.price, required this.stock});

  factory ProductVariant.fromJson(Map<String, dynamic> json) => ProductVariant(
        id: json['id'] as String,
        name: json['name'] as String,
        price: double.tryParse(json['price'].toString()) ?? 0,
        stock: json['stock'] as int? ?? 0,
      );

  final String id;
  final String name;
  final double price;
  final int stock;
}

class ProductCategorySummary {
  ProductCategorySummary({required this.id, required this.name, required this.slug});

  factory ProductCategorySummary.fromJson(Map<String, dynamic> json) => ProductCategorySummary(
        id: json['id'] as String,
        name: json['name'] as String,
        slug: json['slug'] as String,
      );

  final String id;
  final String name;
  final String slug;
}

class ProductDetail {
  ProductDetail({
    required this.id,
    required this.name,
    required this.slug,
    required this.regularPrice,
    this.shortDescription,
    this.description,
    this.productType,
    this.salePrice,
    this.discountPercent,
    this.promotionEndsAt,
    this.stock = 0,
    this.soldCount = 0,
    this.weight,
    this.requiresShipping = true,
    this.images = const [],
    this.variants = const [],
    this.category,
    this.createdAt,
  });

  factory ProductDetail.fromJson(Map<String, dynamic> json) => ProductDetail(
        id: json['id'] as String,
        name: json['name'] as String,
        slug: json['slug'] as String,
        shortDescription: json['short_description'] as String?,
        description: json['description'] as String?,
        productType: json['product_type'] as String?,
        regularPrice: double.tryParse(json['regular_price'].toString()) ?? 0,
        salePrice: json['sale_price'] != null ? double.tryParse(json['sale_price'].toString()) : null,
        discountPercent: json['discount_percent'] as int?,
        promotionEndsAt: json['promotion_ends_at'] as String?,
        stock: json['stock'] as int? ?? 0,
        soldCount: json['sold_count'] as int? ?? 0,
        weight: json['weight'] != null ? double.tryParse(json['weight'].toString()) : null,
        requiresShipping: json['requires_shipping'] as bool? ?? true,
        images: (json['images'] as List<dynamic>? ?? [])
            .map((e) => ProductImage.fromJson(e as Map<String, dynamic>))
            .toList(),
        variants: (json['variants'] as List<dynamic>? ?? [])
            .map((e) => ProductVariant.fromJson(e as Map<String, dynamic>))
            .toList(),
        category: json['category'] != null
            ? ProductCategorySummary.fromJson(json['category'] as Map<String, dynamic>)
            : null,
        createdAt: json['created_at'] as String?,
      );

  final String id;
  final String name;
  final String slug;
  final String? shortDescription;
  final String? description;
  final String? productType;
  final double regularPrice;
  final double? salePrice;
  final int? discountPercent;
  final String? promotionEndsAt;
  final int stock;
  final int soldCount;
  final double? weight;
  final bool requiresShipping;
  final List<ProductImage> images;
  final List<ProductVariant> variants;
  final ProductCategorySummary? category;
  final String? createdAt;

  double get displayPrice => salePrice ?? regularPrice;
  bool get hasDiscount => salePrice != null && salePrice! < regularPrice;
}
