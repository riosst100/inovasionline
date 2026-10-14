import 'package:flutter/material.dart';
import '../models/product.dart';
import 'product_card.dart';

class ProductGrid extends StatelessWidget {
  const ProductGrid({
    super.key,
    required this.products,
    required this.onProductTap,
    this.shrinkWrap = false,
    this.physics,
    this.padding = const EdgeInsets.all(12),
  });

  final List<Product> products;
  final ValueChanged<Product> onProductTap;
  final bool shrinkWrap;
  final ScrollPhysics? physics;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: shrinkWrap,
      physics: physics,
      padding: padding,
      itemCount: products.length,
      gridDelegate: ProductGridDelegate(
        textScale: MediaQuery.textScalerOf(context).scale(1),
      ),
      itemBuilder: (context, index) {
        final product = products[index];
        return ProductCard(product: product, onTap: () => onProductTap(product));
      },
    );
  }
}
