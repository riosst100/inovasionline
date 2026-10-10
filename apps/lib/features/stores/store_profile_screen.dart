import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../config/theme.dart';
import '../../core/api/api_response.dart';
import '../../models/product.dart';
import '../../models/store.dart';
import '../../providers/core_providers.dart';
import '../../widgets/chat_seller_button.dart';
import '../../widgets/product_grid.dart';
import '../../widgets/skeleton.dart';

class StoreProfileScreen extends ConsumerStatefulWidget {
  const StoreProfileScreen({super.key, required this.slug});

  final String slug;

  @override
  ConsumerState<StoreProfileScreen> createState() => _StoreProfileScreenState();
}

class _StoreProfileScreenState extends ConsumerState<StoreProfileScreen> {
  Store? _store;
  final List<Product> _products = [];
  PaginatedMeta? _meta;
  int _page = 1;
  bool _loading = true;
  bool _loadingMore = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final (store, result) = await ref.read(storeServiceProvider).store(widget.slug, page: 1);
      if (!mounted) return;
      setState(() {
        _store = store;
        _products
          ..clear()
          ..addAll(result.data);
        _meta = result.meta;
        _page = 1;
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
      final (_, result) = await ref.read(storeServiceProvider).store(widget.slug, page: _page + 1);
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
    final store = _store;

    return Scaffold(
      appBar: AppBar(title: Text(store?.name ?? 'Toko')),
      body: _loading
          ? const _StoreProfileSkeleton()
          : store == null
              ? const Center(child: Text('Toko tidak ditemukan.'))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: NotificationListener<ScrollNotification>(
                    onNotification: (notification) {
                      if (notification.metrics.pixels >= notification.metrics.maxScrollExtent - 200) {
                        _loadMore();
                      }
                      return false;
                    },
                    child: CustomScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      slivers: [
                        SliverToBoxAdapter(child: _StoreHeader(store: store)),
                        if (_products.isEmpty)
                          const SliverFillRemaining(
                            hasScrollBody: false,
                            child: Center(child: Text('Belum ada produk di toko ini.')),
                          )
                        else
                          SliverPadding(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            sliver: SliverToBoxAdapter(
                              child: ProductGrid(
                                products: _products,
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                onProductTap: (product) => context.push('/products/${product.slug}'),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
    );
  }
}

class _StoreHeader extends StatelessWidget {
  const _StoreHeader({required this.store});

  final Store store;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AspectRatio(
          aspectRatio: 16 / 7,
          child: store.coverUrl != null
              ? CachedNetworkImage(imageUrl: store.coverUrl!, fit: BoxFit.cover)
              : Container(color: AppColors.surface),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: AppColors.surface,
                    backgroundImage: store.logoUrl != null ? CachedNetworkImageProvider(store.logoUrl!) : null,
                    child: store.logoUrl == null ? const Icon(Icons.storefront_outlined) : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(store.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        if (store.city != null)
                          Text(store.city!, style: const TextStyle(color: AppColors.mutedForeground, fontSize: 13)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Text('${store.productCount} produk', style: const TextStyle(color: AppColors.mutedForeground, fontSize: 13)),
                  const SizedBox(width: 12),
                  Text('${store.soldCount} terjual', style: const TextStyle(color: AppColors.mutedForeground, fontSize: 13)),
                ],
              ),
              const SizedBox(height: 12),
              ChatSellerButton(sellerUserId: store.ownerUserId, sellerName: store.name),
              if (store.description != null) ...[
                const Divider(height: 32),
                Text(store.description!),
              ],
            ],
          ),
        ),
        const Divider(height: 1),
      ],
    );
  }
}

class _StoreProfileSkeleton extends StatelessWidget {
  const _StoreProfileSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const AspectRatio(aspectRatio: 16 / 7, child: Skeleton(borderRadius: 0, width: double.infinity)),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Skeleton(width: 56, height: 56, borderRadius: 28),
              const SizedBox(width: 12),
              Expanded(child: Skeleton(height: 16, width: double.infinity)),
            ],
          ),
        ),
      ],
    );
  }
}
