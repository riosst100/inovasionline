import 'package:go_router/go_router.dart';

import '../features/account/account_screen.dart';
import '../features/auth/complete_address_screen.dart';
import '../features/auth/forgot_password_screen.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/register_screen.dart';
import '../features/cart/cart_screen.dart';
import '../features/categories/category_products_screen.dart';
import '../features/checkout/checkout_screen.dart';
import '../features/checkout/face_verification_screen.dart';
import '../features/chat/chat_screen.dart';
import '../features/flash_sale/flash_sale_screen.dart';
import '../features/home/ad_chest.dart';
import '../features/home/home_screen.dart';
import '../features/orders/order_detail_screen.dart';
import '../features/orders/order_list_screen.dart';
import '../features/orders/order_tracking_screen.dart';
import '../features/orders/payment_webview_screen.dart';
import '../features/posts/posts_screen.dart';
import '../features/products/product_detail_screen.dart';
import '../features/search/search_screen.dart';
import '../features/shell/main_shell.dart';
import '../features/wallet/topup_screen.dart';
import '../features/wallet/wallet_screen.dart';
import '../models/cart.dart';

final router = GoRouter(
  initialLocation: '/',
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) =>
          MainShell(navigationShell: navigationShell),
      // Order must match the destinations in MainShell.
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/posts',
              builder: (context, state) => const PostsScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/chat',
              builder: (context, state) => const ChatScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/orders',
              builder: (context, state) => const OrderListScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/account',
              builder: (context, state) => const AccountScreen(),
            ),
          ],
        ),
      ],
    ),
    GoRoute(
      path: '/account/login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/account/register',
      builder: (context, state) => const RegisterScreen(),
    ),
    GoRoute(
      path: '/account/forgot-password',
      builder: (context, state) => const ForgotPasswordScreen(),
    ),
    GoRoute(
      path: '/complete-address',
      builder: (context, state) => const CompleteAddressScreen(),
    ),
    GoRoute(path: '/search', builder: (context, state) => const SearchScreen()),
    GoRoute(path: '/cart', builder: (context, state) => const CartScreen()),
    GoRoute(
      path: '/flash-sale',
      builder: (context, state) => const FlashSaleScreen(),
    ),
    GoRoute(
      path: '/categories/:slug',
      builder: (context, state) => CategoryProductsScreen(
        slug: state.pathParameters['slug']!,
        categoryName: state.extra as String?,
      ),
    ),
    GoRoute(
      path: '/products/:slug',
      builder: (context, state) =>
          ProductDetailScreen(slug: state.pathParameters['slug']!),
    ),
    GoRoute(
      path: '/checkout',
      builder: (context, state) =>
          CheckoutScreen(selection: state.extra as CartSelection),
    ),
    GoRoute(path: '/face-verification', builder: (context, state) => const FaceVerificationScreen()),
    GoRoute(path: '/wallet', builder: (context, state) => const WalletScreen()),
    GoRoute(path: '/chest', builder: (context, state) => const AdChestScreen()),
    GoRoute(
      path: '/wallet/topup',
      builder: (context, state) =>
          TopupScreen(fromCheckout: state.extra == topupFromCheckout),
    ),
    GoRoute(
      path: '/wallet/topups/:id/pay',
      builder: (context, state) => PaymentWebViewScreen.topup(
        topupId: state.pathParameters['id']!,
        redirectUrl: state.extra as String,
      ),
    ),
    GoRoute(
      path: '/orders/:id',
      builder: (context, state) =>
          OrderDetailScreen(orderId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/orders/:id/track',
      builder: (context, state) =>
          OrderTrackingScreen(orderId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/orders/:id/pay',
      builder: (context, state) => PaymentWebViewScreen(
        orderId: state.pathParameters['id']!,
        redirectUrl: state.extra as String,
      ),
    ),
  ],
);
