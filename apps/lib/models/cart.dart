class CartItem {
  CartItem({
    required this.id,
    required this.productId,
    required this.productName,
    required this.productSlug,
    required this.unitPrice,
    required this.stock,
    required this.quantity,
    required this.lineTotal,
    this.productImageUrl,
    this.variantId,
    this.variantName,
  });

  factory CartItem.fromJson(Map<String, dynamic> json) => CartItem(
        id: json['id'] as String,
        productId: json['product_id'] as String,
        productName: json['product_name'] as String,
        productSlug: json['product_slug'] as String,
        productImageUrl: json['product_image_url'] as String?,
        variantId: json['variant_id'] as String?,
        variantName: json['variant_name'] as String?,
        unitPrice: double.tryParse(json['unit_price'].toString()) ?? 0,
        stock: json['stock'] as int? ?? 0,
        quantity: json['quantity'] as int? ?? 0,
        lineTotal: double.tryParse(json['line_total'].toString()) ?? 0,
      );

  final String id;
  final String productId;
  final String productName;
  final String productSlug;
  final String? productImageUrl;
  final String? variantId;
  final String? variantName;
  final double unitPrice;
  final int stock;
  final int quantity;
  final double lineTotal;
}

class CartStoreSummary {
  CartStoreSummary({required this.id, required this.name, required this.slug, this.logoUrl});

  factory CartStoreSummary.fromJson(Map<String, dynamic> json) => CartStoreSummary(
        id: json['id'] as String,
        name: json['name'] as String,
        slug: json['slug'] as String,
        logoUrl: json['logo_url'] as String?,
      );

  final String id;
  final String name;
  final String slug;
  final String? logoUrl;
}

class CartStoreGroup {
  CartStoreGroup({required this.store, required this.items, required this.subtotal});

  factory CartStoreGroup.fromJson(Map<String, dynamic> json) => CartStoreGroup(
        store: CartStoreSummary.fromJson(json['store'] as Map<String, dynamic>),
        items: (json['items'] as List<dynamic>).map((e) => CartItem.fromJson(e as Map<String, dynamic>)).toList(),
        subtotal: double.tryParse(json['subtotal'].toString()) ?? 0,
      );

  final CartStoreSummary store;
  final List<CartItem> items;
  final double subtotal;
}

class Cart {
  Cart({required this.stores, required this.grandTotal, required this.itemCount});

  factory Cart.fromJson(Map<String, dynamic> json) => Cart(
        stores: (json['stores'] as List<dynamic>).map((e) => CartStoreGroup.fromJson(e as Map<String, dynamic>)).toList(),
        grandTotal: double.tryParse(json['grand_total'].toString()) ?? 0,
        itemCount: json['item_count'] as int? ?? 0,
      );

  final List<CartStoreGroup> stores;
  final double grandTotal;
  final int itemCount;

  bool get isEmpty => stores.isEmpty;
}
