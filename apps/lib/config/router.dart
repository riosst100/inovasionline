import 'package:flutter/material.dart';
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
import '../widgets/auth_required.dart';

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
    GoRoute(
      path: '/cart',
      builder: (context, state) => AuthRequired(
        title: 'Keranjang',
        icon: Icons.shopping_cart_outlined,
        message: 'Masuk untuk melihat keranjang kamu.',
        builder: (_) => const CartScreen(),
      ),
    ),
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
      builder: (context, state) => AuthRequired(
        title: 'Checkout',
        icon: Icons.shopping_bag_outlined,
        message: 'Masuk untuk melanjutkan checkout.',
        builder: (_) => CheckoutScreen(selection: state.extra as CartSelection),
      ),
    ),
    GoRoute(
      path: '/face-verification',
      builder: (context, state) => AuthRequired(
        title: 'Verifikasi Wajah',
        icon: Icons.face_retouching_natural,
        message: 'Masuk untuk melakukan verifikasi.',
        builder: (_) => const FaceVerificationScreen(),
      ),
    ),
    GoRoute(
      path: '/wallet',
      builder: (context, state) => AuthRequired(
        title: 'Saldo Belanja',
        icon: Icons.account_balance_wallet_outlined,
        message: 'Masuk untuk melihat saldo belanja kamu.',
        builder: (_) => const WalletScreen(),
      ),
    ),
    GoRoute(
      path: '/wallet/topup',
      builder: (context, state) => AuthRequired(
        title: 'Top Up Saldo',
        icon: Icons.account_balance_wallet_outlined,
        message: 'Masuk untuk mengisi saldo belanja.',
        builder: (_) => TopupScreen(fromCheckout: state.extra == topupFromCheckout),
      ),
    ),
    GoRoute(
      path: '/wallet/topups/:id/pay',
      builder: (context, state) => AuthRequired(
        title: 'Pembayaran',
        icon: Icons.payment_outlined,
        message: 'Masuk untuk melanjutkan pembayaran.',
        builder: (_) => PaymentWebViewScreen.topup(
          topupId: state.pathParameters['id']!,
          redirectUrl: state.extra as String,
        ),
      ),
    ),
    GoRoute(
      path: '/orders/:id',
      builder: (context, state) => AuthRequired(
        title: 'Detail Pesanan',
        icon: Icons.receipt_long_outlined,
        message: 'Masuk untuk melihat pesanan kamu.',
        builder: (_) => OrderDetailScreen(orderId: state.pathParameters['id']!),
      ),
    ),
    GoRoute(
      path: '/orders/:id/track',
      builder: (context, state) => AuthRequired(
        title: 'Lacak Pesanan',
        icon: Icons.local_shipping_outlined,
        message: 'Masuk untuk melacak pesanan kamu.',
        builder: (_) => OrderTrackingScreen(orderId: state.pathParameters['id']!),
      ),
    ),
    GoRoute(
      path: '/orders/:id/pay',
      builder: (context, state) => AuthRequired(
        title: 'Pembayaran',
        icon: Icons.payment_outlined,
        message: 'Masuk untuk melanjutkan pembayaran.',
        builder: (_) => PaymentWebViewScreen(
          orderId: state.pathParameters['id']!,
          redirectUrl: state.extra as String,
        ),
      ),
    ),
  ],
);
