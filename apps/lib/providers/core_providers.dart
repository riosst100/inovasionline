import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../core/api/api_client.dart';
import '../core/storage/token_storage.dart';
import '../services/app_update_service.dart';
import '../services/auth_service.dart';
import '../services/banner_service.dart';
import '../services/cart_service.dart';
import '../services/catalog_service.dart';
import '../services/checkout_service.dart';
import '../services/chat_service.dart';
import '../services/notification_service.dart';
import '../services/order_service.dart';
import '../services/wallet_service.dart';
import '../services/post_service.dart';
import '../services/region_service.dart';
import '../services/search_service.dart';
import '../services/user_address_service.dart';

final tokenStorageProvider = Provider<TokenStorage>((ref) => TokenStorage());

final apiClientProvider = Provider<ApiClient>(
  (ref) => ApiClient(ref.watch(tokenStorageProvider)),
);

final authServiceProvider = Provider<AuthService>(
  (ref) => AuthService(
    ref.watch(apiClientProvider),
    ref.watch(tokenStorageProvider),
  ),
);

final catalogServiceProvider = Provider<CatalogService>(
  (ref) => CatalogService(ref.watch(apiClientProvider)),
);

final searchServiceProvider = Provider<SearchService>(
  (ref) => SearchService(ref.watch(apiClientProvider)),
);

final bannerServiceProvider = Provider<BannerService>(
  (ref) => BannerService(ref.watch(apiClientProvider)),
);

final regionServiceProvider = Provider<RegionService>(
  (ref) => RegionService(ref.watch(apiClientProvider)),
);

final userAddressServiceProvider = Provider<UserAddressService>(
  (ref) => UserAddressService(ref.watch(apiClientProvider)),
);

final chatServiceProvider =Provider<ChatService>(
  (ref) => ChatService(ref.watch(apiClientProvider)),
);

final cartServiceProvider = Provider<CartService>(
  (ref) => CartService(ref.watch(apiClientProvider)),
);

final checkoutServiceProvider = Provider<CheckoutService>(
  (ref) => CheckoutService(ref.watch(apiClientProvider)),
);

final orderServiceProvider = Provider<OrderService>(
  (ref) => OrderService(ref.watch(apiClientProvider)),
);

final walletServiceProvider = Provider<WalletService>(
  (ref) => WalletService(ref.watch(apiClientProvider)),
);

final postServiceProvider = Provider<PostService>(
  (ref) => PostService(ref.watch(apiClientProvider)),
);

final appUpdateServiceProvider = Provider<AppUpdateService>(
  (ref) => AppUpdateService(),
);

/// Installed version, e.g. for "Versi Aplikasi" on the account page.
final packageInfoProvider = FutureProvider<PackageInfo>(
  (ref) => PackageInfo.fromPlatform(),
);

/// Set by PermissionGate once the start-up flow (intro, permissions,
/// locating, the current-location choice) is over and the app is showing.
/// Anything that would pop up over the app at launch waits for this.
final startupSettledProvider = StateProvider<bool>((ref) => false);

final notificationServiceProvider = Provider<NotificationService>(
  (ref) => NotificationService(ref.watch(apiClientProvider)),
);
