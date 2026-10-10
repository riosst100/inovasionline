import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_exception.dart';
import '../../models/cart.dart';
import '../../providers/core_providers.dart';

String _errorMessage(Object error, String fallback) {
  if (error is DioException && error.error is ApiException) {
    return (error.error as ApiException).message;
  }
  return fallback;
}

class CartState {
  const CartState({this.cart, this.loading = false, this.error});

  final Cart? cart;
  final bool loading;
  final String? error;

  CartState copyWith({Cart? cart, bool? loading, String? error}) => CartState(
        cart: cart ?? this.cart,
        loading: loading ?? this.loading,
        error: error,
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
      final cart = await _ref.read(cartServiceProvider).addItem(
            productId: productId,
            variantId: variantId,
            quantity: quantity,
          );
      state = CartState(cart: cart);
      return true;
    } catch (e) {
      state = state.copyWith(error: _errorMessage(e, 'Gagal menambahkan ke keranjang.'));
      return false;
    }
  }

  Future<void> updateQuantity(String cartItemId, int quantity) async {
    try {
      final cart = await _ref.read(cartServiceProvider).updateQuantity(cartItemId, quantity);
      state = CartState(cart: cart);
    } catch (e) {
      state = state.copyWith(error: _errorMessage(e, 'Gagal mengubah jumlah.'));
    }
  }

  Future<void> removeItem(String cartItemId) async {
    try {
      final cart = await _ref.read(cartServiceProvider).removeItem(cartItemId);
      state = CartState(cart: cart);
    } catch (e) {
      state = state.copyWith(error: _errorMessage(e, 'Gagal menghapus item.'));
    }
  }
}

final cartProvider = StateNotifierProvider<CartNotifier, CartState>((ref) => CartNotifier(ref));
