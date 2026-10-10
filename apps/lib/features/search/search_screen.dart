import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/product.dart';
import '../../models/store.dart';
import '../../providers/core_providers.dart';
import '../../widgets/product_grid.dart';
import '../../widgets/skeleton.dart';

final popularSearchProductsProvider = FutureProvider.autoDispose<List<Product>>((ref) {
  return ref.watch(searchServiceProvider).popular();
});

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;
  List<Product> _products = [];
  List<Store> _stores = [];
  bool _loading = false;
  bool _searched = false;
  String _lastKeyword = '';

  @override
  void dispose() {
    _controller.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onChanged(String query) {
    _debounce?.cancel();
    if (query.trim().isEmpty) {
      setState(() {
        _products = [];
        _stores = [];
        _searched = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () => _search(query.trim()));
  }

  Future<void> _search(String query) async {
    setState(() => _loading = true);
    try {
      final result = await ref.read(searchServiceProvider).search(query);
      if (!mounted) return;
      setState(() {
        _products = result.products;
        _stores = result.stores;
        _searched = true;
        _loading = false;
        _lastKeyword = query;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openProduct(Product product, {required String keyword}) {
    ref.read(searchServiceProvider).trackClick(productId: product.id, keyword: keyword).catchError((_) {});
    context.push('/products/${product.slug}');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        automaticallyImplyLeading: false,
        title: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.of(context).pop(),
              ),
              Expanded(
                child: Container(
                  margin: const EdgeInsets.only(right: 16),
                  child: TextField(
                    controller: _controller,
                    autofocus: true,
                    textAlignVertical: TextAlignVertical.center,
                    decoration: const InputDecoration(
                      hintText: 'Cari produk atau toko...',
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                    ),
                    onChanged: _onChanged,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      body: _loading
          ? const ProductGridSkeleton()
          : !_searched
              ? const _PopularSearchSection()
              : (_products.isEmpty && _stores.isEmpty)
                  ? const Center(child: Text('Tidak ada hasil ditemukan.'))
                  : ListView(
                      children: [
                        if (_stores.isNotEmpty) ...[
                          const Padding(
                            padding: EdgeInsets.all(16),
                            child: Text('Toko', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          ),
                          ..._stores.map(
                            (store) => ListTile(
                              leading: CircleAvatar(
                                backgroundColor: const Color(0xFFF3F4F6),
                                backgroundImage: store.logoUrl != null ? NetworkImage(store.logoUrl!) : null,
                                child: store.logoUrl == null ? const Icon(Icons.storefront_outlined) : null,
                              ),
                              title: Text(store.name),
                              subtitle: Text(store.city ?? ''),
                            ),
                          ),
                          const Divider(),
                        ],
                        if (_products.isNotEmpty) ...[
                          const Padding(
                            padding: EdgeInsets.all(16),
                            child: Text('Produk', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          ),
                          ProductGrid(
                            products: _products,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            onProductTap: (product) => _openProduct(product, keyword: _lastKeyword),
                          ),
                        ],
                      ],
                    ),
    );
  }
}

class _PopularSearchSection extends ConsumerWidget {
  const _PopularSearchSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final popular = ref.watch(popularSearchProductsProvider);

    return ListView(
      children: [
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text('Pencarian Pilihan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ),
        popular.when(
          data: (items) => items.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text('Belum ada pencarian pilihan.'),
                )
              : ProductGrid(
                  products: items,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  onProductTap: (product) => context.push('/products/${product.slug}'),
                ),
          loading: () => const ProductGridSkeleton(shrinkWrap: true),
          error: (_, _) => const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text('Gagal memuat produk pilihan.'),
          ),
        ),
      ],
    );
  }
}
