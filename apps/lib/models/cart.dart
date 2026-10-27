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
    this.productThumbUrl,
    this.variantId,
    this.variantName,
  });

  factory CartItem.fromJson(Map<String, dynamic> json) => CartItem(
    id: json['id'] as String,
    productId: json['product_id'] as String,
    productName: json['product_name'] as String,
    productSlug: json['product_slug'] as String,
    productImageUrl: json['product_image_url'] as String?,
    productThumbUrl: json['product_thumb_url'] as String?,
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
  final String? productThumbUrl;

  String? get listImageUrl => productThumbUrl ?? productImageUrl;
  final String? variantId;
  final String? variantName;
  final double unitPrice;
  final int stock;
  final int quantity;
  final double lineTotal;

  /// Out-of-stock items cannot be ordered.
  bool get isAvailable => stock > 0;
}

/// Items picked in the cart to check out together.
class CartSelection {
  CartSelection({required this.items}) : subtotal = items.fold(0.0, (sum, item) => sum + item.lineTotal);

  final List<CartItem> items;
  final double subtotal;
}

class Cart {
  Cart({required this.items, required this.grandTotal, required this.itemCount});

  factory Cart.fromJson(Map<String, dynamic> json) => Cart(
    items: (json['items'] as List<dynamic>).map((e) => CartItem.fromJson(e as Map<String, dynamic>)).toList(),
    grandTotal: double.tryParse(json['grand_total'].toString()) ?? 0,
    itemCount: json['item_count'] as int? ?? 0,
  );

  final List<CartItem> items;
  final double grandTotal;
  final int itemCount;

  bool get isEmpty => items.isEmpty;
}
