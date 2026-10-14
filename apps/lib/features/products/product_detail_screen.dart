import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../config/theme.dart';
import '../../core/utils/formatters.dart';
import '../../models/product.dart';
import '../../providers/auth_provider.dart';
import '../../providers/core_providers.dart';
import '../../widgets/skeleton.dart';
import '../cart/cart_providers.dart';

final productDetailProvider = FutureProvider.autoDispose
    .family<ProductDetail, String>((ref, slug) {
      return ref.watch(catalogServiceProvider).product(slug);
    });

class ProductDetailScreen extends ConsumerStatefulWidget {
  const ProductDetailScreen({super.key, required this.slug});

  final String slug;

  @override
  ConsumerState<ProductDetailScreen> createState() =>
      _ProductDetailScreenState();
}

class _ProductDetailScreenState extends ConsumerState<ProductDetailScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _cartBeatController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
  );
  late final Animation<double> _cartBeatScale =
      TweenSequence<double>([
        TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.4), weight: 50),
        TweenSequenceItem(tween: Tween(begin: 1.4, end: 1.0), weight: 50),
      ]).animate(
        CurvedAnimation(parent: _cartBeatController, curve: Curves.easeOut),
      );

  @override
  void dispose() {
    _cartBeatController.dispose();
    super.dispose();
  }

  void _onAddedToCart() {
    _cartBeatController.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final productAsync = ref.watch(productDetailProvider(widget.slug));
    final cartItemCount = ref.watch(cartProvider).cart?.itemCount ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detail Produk'),
        actions: [
          IconButton(
            icon: ScaleTransition(
              scale: _cartBeatScale,
              child: Badge(
                label: Text('$cartItemCount'),
                isLabelVisible: cartItemCount > 0,
                child: const Icon(Icons.shopping_bag_outlined),
              ),
            ),
            onPressed: () => context.push('/cart'),
          ),
        ],
      ),
      body: productAsync.when(
        data: (product) => RefreshIndicator(
          onRefresh: () =>
              ref.refresh(productDetailProvider(widget.slug).future),
          child: _ProductDetailBody(product: product),
        ),
        loading: () => const _ProductDetailSkeleton(),
        error: (error, _) => Center(child: Text('Gagal memuat produk: $error')),
      ),
      bottomNavigationBar: productAsync.maybeWhen(
        data: (product) =>
            _AddToCartBar(product: product, onAdded: _onAddedToCart),
        orElse: () => null,
      ),
    );
  }
}

class _ProductDetailSkeleton extends StatelessWidget {
  const _ProductDetailSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const AspectRatio(
          aspectRatio: 1,
          child: Skeleton(borderRadius: 0, width: double.infinity),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Skeleton(height: 20, width: 220),
              const SizedBox(height: 12),
              Skeleton(height: 16, width: 120),
              const SizedBox(height: 20),
              const Skeleton(height: 14, width: double.infinity),
              const SizedBox(height: 8),
              const Skeleton(height: 14, width: double.infinity),
              const SizedBox(height: 8),
              Skeleton(height: 14, width: 180),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProductDetailBody extends StatelessWidget {
  const _ProductDetailBody({required this.product});

  final ProductDetail product;

  @override
  Widget build(BuildContext context) {
    final images = product.images;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        AspectRatio(
          aspectRatio: 1,
          child: images.isEmpty
              ? Container(
                  color: AppColors.surface,
                  child: const Icon(
                    Icons.image_outlined,
                    size: 64,
                    color: AppColors.mutedForeground,
                  ),
                )
              : PageView(
                  children: images
                      .map(
                        (img) => CachedNetworkImage(
                          imageUrl: img.url,
                          fit: BoxFit.cover,
                        ),
                      )
                      .toList(),
                ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                product.name,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    formatCurrency(product.displayPrice),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                  if (product.hasDiscount) ...[
                    const SizedBox(width: 8),
                    Text(
                      formatCurrency(product.regularPrice),
                      style: const TextStyle(
                        color: AppColors.mutedForeground,
                        decoration: TextDecoration.lineThrough,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.error,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '-${product.discountPercent}%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${product.soldCount} terjual · Stok ${product.stock}',
                style: const TextStyle(color: AppColors.mutedForeground),
              ),
              const Divider(height: 32),
              const Text(
                'Deskripsi',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(
                product.description ??
                    product.shortDescription ??
                    'Tidak ada deskripsi.',
              ),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ],
    );
  }
}

class _AddToCartBar extends ConsumerStatefulWidget {
  const _AddToCartBar({required this.product, required this.onAdded});

  final ProductDetail product;
  final VoidCallback onAdded;

  @override
  ConsumerState<_AddToCartBar> createState() => _AddToCartBarState();
}

class _AddToCartBarState extends ConsumerState<_AddToCartBar> {
  bool _adding = false;

  Future<void> _handleAddToCart() async {
    final product = widget.product;

    if (ref.read(authProvider).status != AuthStatus.authenticated) {
      await _showLoginRequiredDialog();
      return;
    }

    if (product.variants.isNotEmpty) {
      final variant = await showModalBottomSheet<ProductVariant>(
        context: context,
        isScrollControlled: true,
        builder: (context) => _VariantPickerSheet(variants: product.variants),
      );
      if (variant == null) return;
      await _addToCart(variantId: variant.id, stock: variant.stock);
      return;
    }

    await _addToCart(variantId: null, stock: product.stock);
  }

  Future<void> _showLoginRequiredDialog() async {
    final destination = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Masuk ke Akun Anda'),
        content: const Text(
          'Untuk menambahkan produk ke keranjang dan melanjutkan belanja, silahkan masuk atau daftar terlebih dahulu.',
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(dialogContext).pop('/account/register'),
                  child: const Text('Daftar'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.of(dialogContext).pop('/account/login'),
                  child: const Text('Masuk'),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    if (destination == null || !mounted) return;
    context.push(destination);
  }

  Future<void> _addToCart({
    required String? variantId,
    required int stock,
  }) async {
    if (stock <= 0) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Stok habis.')));
      return;
    }

    setState(() => _adding = true);

    final success = await ref
        .read(cartProvider.notifier)
        .addItem(productId: widget.product.id, variantId: variantId);
    if (!mounted) return;
    setState(() => _adding = false);

    if (success) {
      widget.onAdded();
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
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _adding ? null : _handleAddToCart,
                icon: _adding
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.shopping_bag_outlined, size: 18),
                label: const Text('Tambah ke Keranjang'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VariantPickerSheet extends StatelessWidget {
  const _VariantPickerSheet({required this.variants});

  final List<ProductVariant> variants;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Pilih Varian',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),
            for (final variant in variants)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(variant.name),
                subtitle: Text(
                  '${formatCurrency(variant.price)} · Stok ${variant.stock}',
                ),
                enabled: variant.stock > 0,
                onTap: variant.stock > 0
                    ? () => Navigator.of(context).pop(variant)
                    : null,
              ),
          ],
        ),
      ),
    );
  }
}
