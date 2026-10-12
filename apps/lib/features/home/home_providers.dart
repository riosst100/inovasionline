import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/banner.dart';
import '../../models/category.dart';
import '../../models/flash_sale.dart';
import '../../models/product.dart';
import '../../providers/core_providers.dart';

final bannersProvider = FutureProvider.autoDispose<List<AppBanner>>((ref) {
  return ref.watch(bannerServiceProvider).banners();
});

final rootCategoriesProvider = FutureProvider.autoDispose<List<Category>>((ref) async {
  final all = await ref.watch(catalogServiceProvider).categories();
  return all.where((c) => c.parentId == null).toList();
});

final bestSellersProvider = FutureProvider.autoDispose<List<Product>>((ref) {
  return ref.watch(catalogServiceProvider).bestSellers(limit: 20);
});

final flashSaleProvider = FutureProvider.autoDispose<FlashSaleSchedule>((ref) {
  return ref.watch(catalogServiceProvider).flashSale();
});

final popularProductsProvider = FutureProvider.autoDispose<List<Product>>((ref) {
  return ref.watch(searchServiceProvider).popular(limit: 20);
});
