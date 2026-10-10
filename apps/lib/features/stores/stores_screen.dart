import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/core_providers.dart';
import '../../widgets/skeleton.dart';

final storesProvider = FutureProvider.autoDispose((ref) {
  return ref.watch(storeServiceProvider).stores(sort: 'popular');
});

class StoresScreen extends ConsumerWidget {
  const StoresScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stores = ref.watch(storesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Toko')),
      body: stores.when(
        data: (items) => items.isEmpty
            ? const Center(child: Text('Belum ada toko tersedia.'))
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: items.length,
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final store = items[index];
                  return Card(
                    clipBehavior: Clip.antiAlias,
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(12),
                      leading: CircleAvatar(
                        radius: 24,
                        backgroundColor: const Color(0xFFF3F4F6),
                        backgroundImage: store.logoUrl != null ? CachedNetworkImageProvider(store.logoUrl!) : null,
                        child: store.logoUrl == null ? const Icon(Icons.storefront_outlined) : null,
                      ),
                      title: Text(store.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text('${store.city ?? '-'} · ${store.productCount} produk · ${store.soldCount} terjual'),
                    ),
                  );
                },
              ),
        loading: () => ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: 6,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) => Card(
            clipBehavior: Clip.antiAlias,
            child: const ListTile(
              contentPadding: EdgeInsets.all(12),
              leading: Skeleton(width: 48, height: 48, borderRadius: 24),
              title: Skeleton(height: 14, width: 140),
              subtitle: Padding(
                padding: EdgeInsets.only(top: 8),
                child: Skeleton(height: 12, width: 100),
              ),
            ),
          ),
        ),
        error: (error, _) => Center(child: Text('Gagal memuat toko: $error')),
      ),
    );
  }
}
