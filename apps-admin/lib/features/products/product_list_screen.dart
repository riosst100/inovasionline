import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../config/theme.dart';
import '../../core/utils/formatters.dart';
import '../../models/product.dart';
import '../../providers/core_providers.dart';
import '../../widgets/common.dart';
import '../../widgets/paged_list.dart';

Color productStatusColor(ProductStatus status) => switch (status) {
  ProductStatus.active => AppColors.success,
  ProductStatus.draft => AppColors.mutedForeground,
  ProductStatus.inactive => AppColors.warning,
  ProductStatus.outOfStock => AppColors.destructive,
  ProductStatus.archived => AppColors.mutedForeground,
};

class ProductListScreen extends ConsumerStatefulWidget {
  const ProductListScreen({super.key});

  @override
  ConsumerState<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends ConsumerState<ProductListScreen> {
  final _listKey = GlobalKey<PagedListState<Product>>();
  ProductStatus? _status;
  String _search = '';

  void _filter(VoidCallback change) {
    setState(change);
    _listKey.currentState?.refresh();
  }

  Future<void> _openForm([Product? product]) async {
    final changed = await context.push<bool>(product == null ? '/product/new' : '/product/${product.id}');
    if (changed == true) _listKey.currentState?.refresh();
  }

  Future<void> _toggleActive(Product product) async {
    final next = product.status == ProductStatus.active ? ProductStatus.inactive : ProductStatus.active;
    try {
      final updated = await ref.read(catalogServiceProvider).updateProductStatus(product.id, next);
      if (!mounted) return;
      if (_status != null && updated.status != _status) {
        _listKey.currentState?.removeWhere((p) => p.id == updated.id);
      } else {
        _listKey.currentState?.replaceWhere((p) => p.id == updated.id, updated);
      }
      showMessage(context, '${product.name} kini ${next.label.toLowerCase()}.');
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = ref.watch(catalogServiceProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Produk')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add),
        label: const Text('Produk'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: SearchField(hint: 'Cari nama produk', onChanged: (v) => _filter(() => _search = v)),
          ),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                for (final status in <ProductStatus?>[null, ...ProductStatus.values])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(status?.label ?? 'Semua'),
                      selected: _status == status,
                      onSelected: (_) => _filter(() => _status = status),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: PagedList<Product>(
              key: _listKey,
              fetch: (page) => service.products(page: page, search: _search, status: _status),
              emptyIcon: Icons.inventory_2_outlined,
              emptyText: 'Tidak ada produk.',
              itemBuilder: (context, product) => _ProductCard(
                product: product,
                onTap: () => _openForm(product),
                onToggle: () => _toggleActive(product),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({required this.product, required this.onTap, required this.onToggle});

  final Product product;
  final VoidCallback onTap;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final canToggle = product.status == ProductStatus.active || product.status == ProductStatus.inactive;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              NetImage(product.imageUrl, size: 64),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          formatCurrency(product.effectivePrice),
                          style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.primary),
                        ),
                        if (product.onSale) ...[
                          const SizedBox(width: 6),
                          Text(
                            formatCurrency(product.regularPrice),
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.mutedForeground,
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        StatusBadge(label: product.status.label, color: productStatusColor(product.status)),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'Stok ${product.stock}${product.categoryName != null ? ' · ${product.categoryName}' : ''}',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: product.stock == 0 ? AppColors.destructive : AppColors.mutedForeground,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (canToggle) Switch(value: product.status == ProductStatus.active, onChanged: (_) => onToggle()),
            ],
          ),
        ),
      ),
    );
  }
}
