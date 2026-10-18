import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api/api_client.dart';
import '../core/storage/token_storage.dart';
import '../models/category.dart';
import '../models/dashboard.dart';
import '../services/auth_service.dart';
import '../services/catalog_service.dart';
import '../services/dashboard_service.dart';
import '../services/order_service.dart';

final tokenStorageProvider = Provider<TokenStorage>((ref) => TokenStorage());

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient(ref.watch(tokenStorageProvider)));

final authServiceProvider = Provider<AuthService>(
  (ref) => AuthService(ref.watch(apiClientProvider), ref.watch(tokenStorageProvider)),
);

final orderServiceProvider = Provider<OrderService>((ref) => OrderService(ref.watch(apiClientProvider)));

final catalogServiceProvider = Provider<CatalogService>((ref) => CatalogService(ref.watch(apiClientProvider)));

final dashboardServiceProvider = Provider<DashboardService>((ref) => DashboardService(ref.watch(apiClientProvider)));

final dashboardProvider = FutureProvider.autoDispose<DashboardStats>(
  (ref) => ref.watch(dashboardServiceProvider).stats(),
);

/// Shared by the category tab and the product form's category picker.
final categoriesProvider = FutureProvider.autoDispose<List<Category>>(
  (ref) => ref.watch(catalogServiceProvider).categories(),
);

final warehousesProvider = FutureProvider.autoDispose<List<Warehouse>>(
  (ref) => ref.watch(catalogServiceProvider).warehouses(),
);
