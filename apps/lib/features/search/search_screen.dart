import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/product.dart';
import '../../providers/core_providers.dart';
import '../../services/analytics.dart';
import '../../widgets/product_grid.dart';
import '../../widgets/skeleton.dart';
import '../ads/ad_banner.dart';
import '../ads/admob.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;
  List<Product> _products = [];
  bool _loading = false;
  bool _searched = false;
  List<String> _suggestions = [];
  String _lastKeyword = '';

  @override
  void initState() {
    super.initState();
    _loadSuggestions('');
  }

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
        _searched = false;
      });
      _loadSuggestions('');
      return;
    }
    setState(() => _searched = false);
    _debounce = Timer(const Duration(milliseconds: 300), () => _loadSuggestions(query.trim()));
  }

  Future<void> _loadSuggestions(String query) async {
    try {
      final result = await ref.read(searchServiceProvider).suggestions(query);
      if (!mounted || _controller.text.trim() != query) return;
      setState(() => _suggestions = result);
    } catch (_) {}
  }

  void _selectSuggestion(String keyword) {
    _controller.text = keyword;
    _controller.selection = TextSelection.collapsed(offset: keyword.length);
    FocusScope.of(context).unfocus();
    _search(keyword);
  }

  Future<void> _search(String query) async {
    Analytics.search(query);
    setState(() => _loading = true);
    try {
      final result = await ref.read(searchServiceProvider).search(query);
      if (!mounted) return;
      setState(() {
        _products = result.products;
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
                      hintText: 'Cari produk...',
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                    ),
                    textInputAction: TextInputAction.search,
                    onChanged: _onChanged,
                    onSubmitted: (q) {
                      if (q.trim().isNotEmpty) _search(q.trim());
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      // Only with results on screen, not over the keyword suggestions.
      bottomNavigationBar: _searched && _products.isNotEmpty
          ? const AdBanner(placement: AdPlacement.productList)
          : null,
      body: _loading
          ? const ProductGridSkeleton()
          : !_searched
              ? ListView(
                  children: [
                    for (final keyword in _suggestions)
                      ListTile(
                        leading: const Icon(Icons.trending_up),
                        title: Text(keyword),
                        onTap: () => _selectSuggestion(keyword),
                      ),
                  ],
                )
              : _products.isEmpty
                  ? const Center(child: Text('Tidak ada hasil ditemukan.'))
                  : ListView(
                      children: [
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
                    ),
    );
  }
}
