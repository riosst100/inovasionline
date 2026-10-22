import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/api/api_exception.dart';
import '../../models/cart.dart';
import '../../providers/auth_provider.dart';
import '../../providers/core_providers.dart';

String _errorMessage(Object error, String fallback) {
  if (error is DioException && error.error is ApiException) {
    return (error.error as ApiException).message;
  }
  return fallback;
}

class CartState {
  const CartState({this.cart, this.loading = false, this.error, this.busyItemIds = const {}});

  final Cart? cart;
  final bool loading;
  final String? error;

  /// Items with an update or removal in flight; their controls are locked.
  final Set<String> busyItemIds;

  CartState copyWith({Cart? cart, bool? loading, String? error, Set<String>? busyItemIds}) => CartState(
    cart: cart ?? this.cart,
    loading: loading ?? this.loading,
    error: error,
    busyItemIds: busyItemIds ?? this.busyItemIds,
  );

  CartState _withBusy(String id, bool busy) => CartState(
    cart: cart,
    loading: loading,
    error: error,
    busyItemIds: busy ? {...busyItemIds, id} : ({...busyItemIds}..remove(id)),
  );
}

class CartNotifier extends StateNotifier<CartState> {
  CartNotifier(this._ref) : super(const CartState());

  final Ref _ref;

  Future<void> load() async {
    state = state.copyWith(loading: true, error: null);
    try {
      final cart = await _ref.read(cartServiceProvider).cart();
      state = CartState(cart: cart);
    } catch (e) {
      state = state.copyWith(loading: false, error: _errorMessage(e, 'Gagal memuat keranjang.'));
    }
  }

  Future<bool> addItem({required String productId, String? variantId, int quantity = 1}) async {
    try {
      final cart = await _ref
          .read(cartServiceProvider)
          .addItem(productId: productId, variantId: variantId, quantity: quantity);
      state = CartState(cart: cart);
      return true;
    } catch (e) {
      state = state.copyWith(error: _errorMessage(e, 'Gagal menambahkan ke keranjang.'));
      return false;
    }
  }

  Future<void> updateQuantity(String cartItemId, int quantity) async {
    if (state.busyItemIds.contains(cartItemId)) return;
    state = state._withBusy(cartItemId, true);
    try {
      final cart = await _ref.read(cartServiceProvider).updateQuantity(cartItemId, quantity);
      state = CartState(cart: cart);
    } catch (e) {
      state = state._withBusy(cartItemId, false).copyWith(error: _errorMessage(e, 'Gagal mengubah jumlah.'));
    }
  }

  void clear() => state = const CartState();

  /// Returns whether the item was removed.
  Future<bool> removeItem(String cartItemId) async {
    if (state.busyItemIds.contains(cartItemId)) return false;
    state = state._withBusy(cartItemId, true);
    try {
      final cart = await _ref.read(cartServiceProvider).removeItem(cartItemId);
      state = CartState(cart: cart);
      return true;
    } catch (e) {
      state = state._withBusy(cartItemId, false).copyWith(error: _errorMessage(e, 'Gagal menghapus item.'));
      return false;
    }
  }
}

/// Ids of the cart items ticked for checkout. Persisted so the last choice is
/// restored when the cart is reopened, and cleared on logout.
class CartSelectionNotifier extends StateNotifier<Set<String>> {
  CartSelectionNotifier() : super(const {}) {
    _restore();
  }

  static const _key = 'cart_selected_item_ids';
  final _storage = const FlutterSecureStorage();

  Future<void> _restore() async {
    try {
      final raw = await _storage.read(key: _key);
      if (raw == null || raw.isEmpty) return;
      // Anything toggled before the read finished wins over the stored value.
      state = {...raw.split(','), ...state};
    } catch (_) {}
  }

  void _save() {
    try {
      if (state.isEmpty) {
        _storage.delete(key: _key);
      } else {
        _storage.write(key: _key, value: state.join(','));
      }
    } catch (_) {}
  }

  void toggle(String itemId, bool selected) {
    state = selected ? {...state, itemId} : ({...state}..remove(itemId));
    _save();
  }

  void toggleAll(Iterable<String> itemIds, bool selected) {
    state = selected ? {...state, ...itemIds} : ({...state}..removeAll(itemIds));
    _save();
  }

  /// Drops ids of items that are no longer in the cart.
  void retainOnly(Set<String> validIds) {
    if (state.every(validIds.contains)) return;
    state = state.where(validIds.contains).toSet();
    _save();
  }

  void clear() {
    state = const {};
    _save();
  }
}

final cartSelectionProvider = StateNotifierProvider<CartSelectionNotifier, Set<String>>((ref) {
  final notifier = CartSelectionNotifier();
  ref.listen<AuthStatus>(authProvider.select((s) => s.status), (_, status) {
    if (status == AuthStatus.unauthenticated) notifier.clear();
  });
  return notifier;
});

/// Loads on login and clears on logout, so the cart badges are filled before
/// the cart screen is ever opened.
final cartProvider = StateNotifierProvider<CartNotifier, CartState>((ref) {
  final notifier = CartNotifier(ref);
  ref.listen<AuthStatus>(authProvider.select((s) => s.status), (_, status) {
    if (status == AuthStatus.authenticated) {
      Future.microtask(notifier.load);
    } else if (status == AuthStatus.unauthenticated) {
      notifier.clear();
    }
  }, fireImmediately: true);
  return notifier;
});
