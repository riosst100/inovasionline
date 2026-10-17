import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api/api_response.dart';
import '../../models/product.dart';
import '../../providers/core_providers.dart';
import '../../widgets/product_grid.dart';
import '../../widgets/skeleton.dart';
import '../cart/cart_providers.dart';

class CategoryProductsScreen extends ConsumerStatefulWidget {
  const CategoryProductsScreen({super.key, required this.slug, this.categoryName});

  final String slug;
  final String? categoryName;

  @override
  ConsumerState<CategoryProductsScreen> createState() => _CategoryProductsScreenState();
}

class _CategoryProductsScreenState extends ConsumerState<CategoryProductsScreen> {
  final List<Product> _products = [];
  PaginatedMeta? _meta;
  int _page = 1;
  bool _loading = true;
  bool _loadingMore = false;
  String? _title;

  @override
  void initState() {
    super.initState();
    _title = widget.categoryName;
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final (category, result) = await ref.read(catalogServiceProvider).categoryProducts(widget.slug, page: 1);
      if (!mounted) return;
      setState(() {
        _products
          ..clear()
          ..addAll(result.data);
        _meta = result.meta;
        _page = 1;
        _title = category.name;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    if (_meta == null || !_meta!.hasMore || _loadingMore) return;
    setState(() => _loadingMore = true);
    try {
      final (_, result) = await ref.read(catalogServiceProvider).categoryProducts(widget.slug, page: _page + 1);
      if (!mounted) return;
      setState(() {
        _products.addAll(result.data);
        _meta = result.meta;
        _page += 1;
        _loadingMore = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cartItemCount = ref.watch(cartProvider).cart?.itemCount ?? 0;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Kembali',
          onPressed: () => context.canPop() ? context.pop() : context.go('/'),
        ),
        title: Text(_title ?? 'Kategori', maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            icon: Badge(
              label: Text(cartItemCount > 99 ? '99+' : '$cartItemCount'),
              isLabelVisible: cartItemCount > 0,
              child: const Icon(Icons.shopping_bag_outlined),
            ),
            tooltip: 'Keranjang',
            onPressed: () => context.push('/cart'),
          ),
        ],
      ),
      body: _loading
          ? const ProductGridSkeleton()
          : RefreshIndicator(
              onRefresh: _load,
              child: _products.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: const [
                        SizedBox(height: 120),
                        Center(child: Text('Belum ada produk di kategori ini.')),
                      ],
                    )
                  : NotificationListener<ScrollNotification>(
                      onNotification: (notification) {
                        if (notification.metrics.pixels >= notification.metrics.maxScrollExtent - 200) {
                          _loadMore();
                        }
                        return false;
                      },
                      child: ProductGrid(
                        products: _products,
                        physics: const AlwaysScrollableScrollPhysics(),
                        onProductTap: (product) => context.push('/products/${product.slug}'),
                      ),
                    ),
            ),
    );
  }
}
