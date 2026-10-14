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
    this.crossAxisCount = 2,
    this.spacing = 12,
  });

  final double textScale;
  final int crossAxisCount;
  final double spacing;

  // Non-text padding/margins in the details area + scalable text area.
  static const double _fixedDetails = 34;
  static const double _textDetails = 100;

  /// Card height for a given card width (used by horizontal lists).
  static double tileHeight(double width, double textScale) =>
      width + _fixedDetails + _textDetails * textScale;

  @override
  SliverGridLayout getLayout(SliverConstraints constraints) {
    final tileWidth =
        (constraints.crossAxisExtent - spacing * (crossAxisCount - 1)) / crossAxisCount;
    final tileHeight = ProductGridDelegate.tileHeight(tileWidth, textScale);
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
      old.spacing != spacing;
}

class ProductCard extends ConsumerWidget {
  const ProductCard({
    super.key,
    required this.product,
    required this.onTap,
    this.badgeText,
    this.etaText = '15 Menit',
  });

  final Product product;
  final VoidCallback onTap;
  final String? badgeText;
  final String etaText;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                    padding: const EdgeInsets.all(8),
                    child: product.imageUrl != null
                        ? CachedNetworkImage(
                            imageUrl: product.imageUrl!,
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
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
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
                        style: const TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  // Quick Add (+) Button on Top Right
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Material(
                      color: Colors.white,
                      shape: const CircleBorder(),
                      elevation: 2,
                      shadowColor: Colors.black.withValues(alpha: 0.15),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () async {
                          if (ref.read(authProvider).status != AuthStatus.authenticated) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Masuk dulu untuk menambahkan ke keranjang')),
                            );
                            context.push('/account/login');
                            return;
                          }
                          final success = await ref
                              .read(cartProvider.notifier)
                              .addItem(productId: product.id);
                          if (!context.mounted) return;
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
                        },
                        child: Container(
                          width: 32,
                          height: 32,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xFF0D9488).withValues(alpha: 0.3), width: 1.2),
                          ),
                          child: const Icon(
                            Icons.add,
                            size: 18,
                            color: Color(0xFF0D9488),
                          ),
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
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Discount row if available
                        if (product.hasDiscount) ...[
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEF4444),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '${product.discountPercent}%',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                formatCurrency(product.regularPrice),
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF94A3B8),
                                  decoration: TextDecoration.lineThrough,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                        ],

                        // Main Price
                        Text(
                          formatCurrency(product.displayPrice),
                          style: const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 4),

                        // Title
                        Text(
                          product.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                            height: 1.25,
                            color: Color(0xFF334155),
                          ),
                        ),
                      ],
                    ),

                    // Delivery ETA Badge
                    Container(
                      margin: const EdgeInsets.only(top: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.timer_outlined, size: 12, color: Color(0xFF0D9488)),
                          const SizedBox(width: 4),
                          Text(
                            etaText,
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF0D9488),
                            ),
                          ),
                        ],
                      ),
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
