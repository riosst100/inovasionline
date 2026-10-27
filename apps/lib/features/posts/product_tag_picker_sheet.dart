import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/theme.dart';
import '../../core/utils/formatters.dart';
import '../../models/product.dart';
import '../../providers/core_providers.dart';

class ProductTagPickerSheet extends ConsumerStatefulWidget {
  const ProductTagPickerSheet({super.key, required this.initiallySelected});

  final List<Product> initiallySelected;

  @override
  ConsumerState<ProductTagPickerSheet> createState() => _ProductTagPickerSheetState();
}

class _ProductTagPickerSheetState extends ConsumerState<ProductTagPickerSheet> {
  final _searchController = TextEditingController();
  Timer? _debounce;
  List<Product> _results = [];
  late final List<Product> _selected = List.of(widget.initiallySelected);
  bool _loading = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onQueryChanged(String query) {
    _debounce?.cancel();
    if (query.trim().length < 2) {
      setState(() => _results = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(query.trim()));
  }

  Future<void> _search(String query) async {
    setState(() => _loading = true);
    try {
      final result = await ref.read(searchServiceProvider).search(query, limit: 20);
      if (mounted) setState(() => _results = result.products);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _toggle(Product product) {
    setState(() {
      if (_selected.any((p) => p.id == product.id)) {
        _selected.removeWhere((p) => p.id == product.id);
      } else {
        _selected.add(product);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  const Text('Tandai Produk', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(_selected),
                    child: Text('Selesai${_selected.isNotEmpty ? ' (${_selected.length})' : ''}'),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _searchController,
                onChanged: _onQueryChanged,
                decoration: InputDecoration(
                  hintText: 'Cari produk...',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: AppColors.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _results.isEmpty
                      ? Center(
                          child: Text(
                            _searchController.text.trim().length < 2 ? 'Ketik untuk mencari produk' : 'Tidak ada hasil',
                            style: const TextStyle(color: AppColors.mutedForeground),
                          ),
                        )
                      : ListView.builder(
                          controller: scrollController,
                          itemCount: _results.length,
                          itemBuilder: (context, index) {
                            final product = _results[index];
                            final isSelected = _selected.any((p) => p.id == product.id);
                            return ListTile(
                              onTap: () => _toggle(product),
                              leading: ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: SizedBox(
                                  width: 44,
                                  height: 44,
                                  child: product.listImageUrl != null
                                      ? CachedNetworkImage(memCacheWidth: 200, imageUrl: product.listImageUrl!, fit: BoxFit.cover)
                                      : Container(color: AppColors.surface, child: const Icon(Icons.image_outlined, size: 18)),
                                ),
                              ),
                              title: Text(product.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                              subtitle: Text(formatCurrency(product.displayPrice)),
                              trailing: Icon(
                                isSelected ? Icons.check_circle : Icons.circle_outlined,
                                color: isSelected ? AppColors.primary : AppColors.mutedForeground,
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
