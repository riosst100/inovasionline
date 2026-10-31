import 'dart:async';
import 'dart:developer' as developer;

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:go_router/go_router.dart';

import '../models/cart.dart';
import '../models/order.dart';
import '../models/product.dart';
import 'push_notification_handler.dart';

const _currency = 'IDR';

/// Firebase Analytics for in-app behaviour: screens, the shopping funnel and
/// retention. Orders, revenue and stock are reported from our own database
/// (admin dashboard), not from here.
///
/// Every call is fire-and-forget: it waits for Firebase to be set up and
/// swallows errors, so analytics can never slow down or break a screen.
/// Never put personal data (name, phone, email, address) in an event.
class Analytics {
  Analytics._();

  static String? _lastScreen;

  static void _log(Future<void> Function(FirebaseAnalytics fa) send) {
    unawaited(() async {
      try {
        await firebaseReady.future;
        await send(FirebaseAnalytics.instance);
      } catch (e) {
        developer.log('Analytics failed: $e', name: 'analytics');
      }
    }());
  }

  /// Logs a screen_view on every route change. GoRouter's shell branches
  /// don't go through Navigator observers, so this listens to the router.
  /// The route pattern (/products/:slug) is the screen name, so every
  /// product page is counted as one screen.
  static void trackScreens(GoRouter router) {
    void onChanged() {
      final screen = router.routerDelegate.currentConfiguration.fullPath;
      if (screen.isEmpty || screen == _lastScreen) return;
      _lastScreen = screen;
      _log((fa) => fa.logScreenView(screenName: screen == '/' ? '/home' : screen));
    }

    router.routerDelegate.addListener(onChanged);
    onChanged();
  }

  /// Ties events to the account so retention is counted per user across
  /// reinstalls and devices. Pass null on logout.
  static void setUser(String? userId) => _log((fa) => fa.setUserId(id: userId));

  static void login(String method) => _log((fa) => fa.logLogin(loginMethod: method));

  static void signUp(String method) => _log((fa) => fa.logSignUp(signUpMethod: method));

  static void search(String keyword) => _log((fa) => fa.logSearch(searchTerm: keyword));

  static void viewItem(ProductDetail product) => _log(
    (fa) => fa.logViewItem(
      currency: _currency,
      value: product.displayPrice,
      items: [
        AnalyticsEventItem(
          itemId: product.id,
          itemName: product.name,
          itemCategory: product.category?.name,
          price: product.displayPrice,
        ),
      ],
    ),
  );

  static void addToCart(CartItem item, int quantity) => _log(
    (fa) => fa.logAddToCart(
      currency: _currency,
      value: item.unitPrice * quantity,
      items: [_cartItem(item, quantity: quantity)],
    ),
  );

  static void beginCheckout(CartSelection selection) => _log(
    (fa) => fa.logBeginCheckout(
      currency: _currency,
      value: selection.subtotal,
      items: selection.items.map(_cartItem).toList(),
    ),
  );

  /// Logged when the order is placed, before any online payment completes.
  static void purchase(Order order) => _log(
    (fa) => fa.logPurchase(
      currency: _currency,
      value: order.grandTotal,
      transactionId: order.orderNumber,
      shipping: order.shippingFee,
      tax: order.taxTotal,
      items: order.items
          .map(
            (item) => AnalyticsEventItem(
              itemId: item.productId,
              itemName: item.productName,
              itemVariant: item.variantName,
              price: item.unitPrice,
              quantity: item.quantity,
            ),
          )
          .toList(),
    ),
  );

  static void event(String name, [Map<String, Object>? params]) =>
      _log((fa) => fa.logEvent(name: name, parameters: params));

  // Permission / location flow.
  static void homeTourCompleted() => event('tutorial_complete');

  static void locationIntroShown() => event('location_intro_shown');
  static void locationButtonTapped() => event('location_button_tapped');
  static void locationPermission({required bool granted, required bool permanent}) =>
      event('location_permission_result', {
        'granted': granted ? 1 : 0,
        'permanently_denied': permanent ? 1 : 0,
      });
  static void locationServiceResult({required bool enabled}) =>
      event('location_service_result', {'enabled': enabled ? 1 : 0});
  static void outOfArea() => event('location_out_of_area');

  static AnalyticsEventItem _cartItem(CartItem item, {int? quantity}) => AnalyticsEventItem(
    itemId: item.productId,
    itemName: item.productName,
    itemVariant: item.variantName,
    price: item.unitPrice,
    quantity: quantity ?? item.quantity,
  );
}
