import '../core/utils/formatters.dart';

/// Mirrors App\Support\Enums\ProductStatus.
enum ProductStatus {
  active('Aktif'),
  draft('Draf'),
  inactive('Nonaktif'),
  outOfStock('Stok Habis'),
  archived('Diarsipkan');

  const ProductStatus(this.label);

  final String label;

  String get value => this == outOfStock ? 'out_of_stock' : name;

  static ProductStatus parse(String? value) => values.firstWhere((s) => s.value == value, orElse: () => draft);
}

class ProductImage {
  ProductImage({required this.id, required this.url, required this.isPrimary});

  factory ProductImage.fromJson(Map<String, dynamic> json) => ProductImage(
    id: json['id'].toString(),
    url: json['url'] as String? ?? '',
    isPrimary: json['is_primary'] as bool? ?? false,
  );

  final String id;
  final String url;
  final bool isPrimary;
}

class Product {
  Product({
    required this.id,
    required this.name,
    required this.regularPrice,
    required this.status,
    this.salePrice,
    this.categoryId,
    this.categoryName,
    this.sku,
    this.shortDescription,
    this.description,
    this.stock = 0,
    this.stocks = const {},
    this.images = const [],
    this.imageUrl,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    final sale = json['sale_price'];
    return Product(
      id: json['id'].toString(),
      name: json['name'] as String? ?? '',
      regularPrice: parseNum(json['regular_price']),
      salePrice: sale == null ? null : parseNum(sale),
      status: ProductStatus.parse(json['status'] as String?),
      categoryId: json['category_id']?.toString(),
      categoryName: json['category_name'] as String?,
      sku: json['sku'] as String?,
      shortDescription: json['short_description'] as String?,
      description: json['description'] as String?,
      stock: parseNum(json['stock']).toInt(),
      stocks: {
        for (final row in (json['stocks'] as List? ?? []).cast<Map<String, dynamic>>())
          row['warehouse_id'].toString(): parseNum(row['quantity']).toInt(),
      },
      images: (json['images'] as List? ?? []).map((e) => ProductImage.fromJson(e as Map<String, dynamic>)).toList(),
      imageUrl: json['image_url'] as String?,
    );
  }

  final String id;
  final String name;
  final double regularPrice;
  final double? salePrice;
  final ProductStatus status;
  final String? categoryId;
  final String? categoryName;
  final String? sku;
  final String? shortDescription;
  final String? description;
  final int stock;

  /// Quantity per warehouse id (only filled by the detail endpoint).
  final Map<String, int> stocks;
  final List<ProductImage> images;
  final String? imageUrl;

  bool get onSale => salePrice != null && salePrice! < regularPrice;

  double get effectivePrice => onSale ? salePrice! : regularPrice;
}
