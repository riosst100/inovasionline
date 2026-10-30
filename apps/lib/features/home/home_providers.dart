import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/banner.dart';
import '../../models/category.dart';
import '../../models/flash_sale.dart';
import '../../models/product.dart';
import '../../providers/core_providers.dart';

final bannersProvider = FutureProvider.autoDispose<List<AppBanner>>((ref) {
  return ref.watch(bannerServiceProvider).banners();
});

/// Admin-managed texts for the home promo strip (Promosi > Gratis Ongkir).
final promoTextsProvider = FutureProvider.autoDispose<List<String>>((ref) async {
  final config = await ref.watch(checkoutServiceProvider).freeShippingConfig();
  final texts = config['promo_texts'];
  if (texts is! List) return const [];
  return texts.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
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
