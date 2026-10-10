import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../widgets/product_grid.dart';
import '../../widgets/skeleton.dart';
import '../home/home_providers.dart';

class FlashSaleScreen extends ConsumerWidget {
  const FlashSaleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final flashSale = ref.watch(flashSaleProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Flash Sale')),
      body: flashSale.when(
        data: (schedule) {
          if (schedule.slots.isEmpty) {
            return const Center(child: Text('Belum ada flash sale hari ini.'));
          }

          return DefaultTabController(
            length: schedule.slots.length,
            child: Column(
              children: [
                TabBar(
                  isScrollable: true,
                  tabs: schedule.slots
                      .map((slot) => Tab(text: '${slot.label} (${slot.startTime})'))
                      .toList(),
                ),
                Expanded(
                  child: TabBarView(
                    children: schedule.slots.map((slot) {
                      return RefreshIndicator(
                        onRefresh: () => ref.refresh(flashSaleProvider.future),
                        child: slot.products.isEmpty
                            ? ListView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                children: const [
                                  SizedBox(height: 120),
                                  Center(child: Text('Belum ada produk di slot ini.')),
                                ],
                              )
                            : ProductGrid(
                                products: slot.products,
                                physics: const AlwaysScrollableScrollPhysics(),
                                onProductTap: (product) => context.push('/products/${product.slug}'),
                              ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => const ProductGridSkeleton(),
        error: (error, _) => Center(child: Text('Gagal memuat flash sale: $error')),
      ),
    );
  }
}
