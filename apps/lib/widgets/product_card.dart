import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/utils/formatters.dart';
import '../features/cart/cart_providers.dart';
import '../models/product.dart';
import '../providers/auth_provider.dart';

/// Grid delegate whose item height = image (square) + details area, so the
/// card never overflows regardless of screen width or system font scale.
class ProductGridDelegate extends SliverGridDelegate {
  const ProductGridDelegate({
    required this.textScale,
    this.crossAxisCount = 3,
    this.spacing = 8,
    this.compact = true,
  });

  final double textScale;
  final int crossAxisCount;
  final double spacing;

  /// Tighter card used for narrow (3 per row) grids; must match
  /// [ProductCard.compact].
  final bool compact;

  // Non-text padding/margins in the details area (incl. the add-to-cart
  // button) + scalable text area.
  static const double _fixedDetails = 50;
  static const double _textDetails = 92;
  static const double _compactFixedDetails = 42;
  static const double _compactTextDetails = 84;

  /// Card height for a given card width (used by horizontal lists).
  static double tileHeight(double width, double textScale, {bool compact = false}) =>
      compact
          ? width + _compactFixedDetails + _compactTextDetails * textScale
          : width + _fixedDetails + _textDetails * textScale;

  @override
  SliverGridLayout getLayout(SliverConstraints constraints) {
    final tileWidth =
        (constraints.crossAxisExtent - spacing * (crossAxisCount - 1)) / crossAxisCount;
    final tileHeight =
        ProductGridDelegate.tileHeight(tileWidth, textScale, compact: compact);
    return SliverGridRegularTileLayout(
      crossAxisCount: crossAxisCount,
      mainAxisStride: tileHeight + spacing,
      crossAxisStride: tileWidth + spacing,
      childMainAxisExtent: tileHeight,
      childCrossAxisExtent: tileWidth,
      reverseCrossAxis: axisDirectionIsReversed(constraints.crossAxisDirection),
    );
  }

  @override
  bool shouldRelayout(ProductGridDelegate old) =>
      old.textScale != textScale ||
      old.crossAxisCount != crossAxisCount ||
      old.compact != compact ||
      old.spacing != spacing;
}

class ProductCard extends ConsumerWidget {
  const ProductCard({
    super.key,
    required this.product,
    required this.onTap,
    this.badgeText,
    this.compact = false,
  });

  final Product product;
  final VoidCallback onTap;
  final String? badgeText;

  /// Smaller type and padding for 3-per-row grids.
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final edge = compact ? 6.0 : 8.0;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE9EEF4), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Image Stack with Badges & Quick Add (+)
            AspectRatio(
              aspectRatio: 1,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    color: const Color(0xFFF8FAFC),
                    padding: EdgeInsets.all(edge),
                    child: product.listImageUrl != null
                        ? CachedNetworkImage(memCacheWidth: 400, imageUrl: product.listImageUrl!,
                            fit: BoxFit.contain,
                            placeholder: (_, _) => Container(color: const Color(0xFFF1F5F9)),
                            errorWidget: (_, _, _) => const Icon(
                              Icons.image_outlined,
                              color: Color(0xFF94A3B8),
                            ),
                          )
                        : const Icon(Icons.image_outlined, color: Color(0xFF94A3B8)),
                  ),
                  // Quality / Halal Badge on Top Left
                  Positioned(
                    top: edge,
                    left: edge,
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: compact ? 6 : 8, vertical: compact ? 2.5 : 3.5),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF14B8A6), Color(0xFF0D9488)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF0D9488).withValues(alpha: 0.28),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        badgeText ?? 'Fresh',
                        style: TextStyle(
                          fontSize: compact ? 8.5 : 9.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Product Details
            Expanded(
              child: Padding(
                padding: compact
                    ? const EdgeInsets.fromLTRB(8, 6, 8, 8)
                    : const EdgeInsets.fromLTRB(10, 8, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Discount row if available
                        if (product.hasDiscount) ...[
                          Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 5,
                            runSpacing: 1,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEF4444),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '${product.discountPercent}%',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: compact ? 9 : 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              Text(
                                formatCurrency(product.regularPrice),
                                style: TextStyle(
                                  fontSize: compact ? 10 : 11,
                                  color: Color(0xFF94A3B8),
                                  decoration: TextDecoration.lineThrough,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                        ],

                        // Main Price
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            formatCurrency(product.displayPrice),
                            maxLines: 1,
                            style: TextStyle(
                              fontSize: compact ? 13 : 14.5,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF0F172A),
                              letterSpacing: -0.2,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),

                        // Title
                        Text(
                          product.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: compact ? 11.5 : 12.5,
                            fontWeight: FontWeight.w500,
                            height: 1.25,
                            color: Color(0xFF334155),
                          ),
                        ),
                      ],
                    ),

                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: _AddToCartButton(product: product, compact: compact),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddToCartButton extends ConsumerStatefulWidget {
  const _AddToCartButton({required this.product, required this.compact});

  final Product product;
  final bool compact;

  @override
  ConsumerState<_AddToCartButton> createState() => _AddToCartButtonState();
}

class _AddToCartButtonState extends ConsumerState<_AddToCartButton> {
  bool _adding = false;

  Future<void> _addToCart() async {
    if (ref.read(authProvider).status != AuthStatus.authenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Masuk dulu untuk menambahkan ke keranjang')),
      );
      context.push('/account/login');
      return;
    }

    setState(() => _adding = true);
    final success = await ref
        .read(cartProvider.notifier)
        .addItem(productId: widget.product.id);
    if (!mounted) return;
    setState(() => _adding = false);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white, size: 20),
              SizedBox(width: 10),
              Text('Ditambahkan ke keranjang.'),
            ],
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ref.read(cartProvider).error ?? 'Gagal menambahkan ke keranjang.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final compact = widget.compact;
    final height = compact ? 28.0 : 32.0;

    return SizedBox(
      width: double.infinity,
      height: height,
      child: Material(
        color: const Color(0xFF0D9488),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: _adding ? null : _addToCart,
          borderRadius: BorderRadius.circular(10),
          child: Center(
            child: _adding
                ? SizedBox(
                    width: compact ? 13 : 15,
                    height: compact ? 13 : 15,
                    child: const CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.add_shopping_cart_rounded,
                            size: compact ? 13 : 15,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            compact ? 'Keranjang' : 'Tambah ke Keranjang',
                            maxLines: 1,
                            style: TextStyle(
                              fontSize: compact ? 10.5 : 11.5,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
