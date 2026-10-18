import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_exception.dart';
import '../../models/order.dart';
import '../../providers/auth_provider.dart';
import '../../providers/core_providers.dart';
import '../wallet/wallet_providers.dart';

String _errorMessage(Object error, String fallback) {
  if (error is DioException && error.error is ApiException) {
    return (error.error as ApiException).message;
  }
  return fallback;
}

final myOrdersProvider = FutureProvider.autoDispose<List<Order>>((ref) {
  return ref.watch(orderServiceProvider).myOrders();
});

/// The signed-in buyer's in-progress orders, newest first; empty when signed out.
final activeOrdersProvider = FutureProvider.autoDispose<List<Order>>((ref) async {
  final authenticated = ref.watch(authProvider.select((s) => s.status == AuthStatus.authenticated));
  if (!authenticated) return const [];
  final orders = await ref.watch(myOrdersProvider.future);
  return orders.where((order) => order.isActive).toList();
});

final orderDetailProvider = FutureProvider.autoDispose.family<Order, String>((ref, orderId) {
  return ref.watch(orderServiceProvider).orderDetail(orderId);
});

class OrderCancelState {
  const OrderCancelState({this.cancelling = false, this.error});

  final bool cancelling;
  final String? error;
}

class OrderCancelNotifier extends StateNotifier<OrderCancelState> {
  OrderCancelNotifier(this._ref) : super(const OrderCancelState());

  final Ref _ref;

  Future<bool> cancel(String orderId) async {
    state = const OrderCancelState(cancelling: true);
    try {
      await _ref.read(orderServiceProvider).cancel(orderId);
      _ref.invalidate(orderDetailProvider(orderId));
      _ref.invalidate(myOrdersProvider);
      invalidateWallet(_ref); // a paid order is refunded to the balance
      state = const OrderCancelState();
      return true;
    } catch (e) {
      state = OrderCancelState(error: _errorMessage(e, 'Gagal membatalkan pesanan.'));
      return false;
    }
  }

  /// Freezes the cancel countdown before showing the confirmation; false when the window already closed.
  Future<bool> hold(String orderId) async {
    state = const OrderCancelState(cancelling: true);
    try {
      await _ref.read(orderServiceProvider).holdCancel(orderId);
      _ref.invalidate(orderDetailProvider(orderId)); // the screen behind the dialog shows the frozen countdown
      state = const OrderCancelState();
      return true;
    } catch (e) {
      _ref.invalidate(orderDetailProvider(orderId)); // refresh, so the stale button goes away
      state = OrderCancelState(error: _errorMessage(e, 'Gagal membatalkan pesanan.'));
      return false;
    }
  }

  /// Buyer backed out: the order carries on and the cancel button goes away for good.
  Future<void> decline(String orderId) async {
    try {
      await _ref.read(orderServiceProvider).declineCancel(orderId);
    } catch (_) {
      // An unreleased hold expires on the server and counts as declining anyway.
    }
    _ref.invalidate(orderDetailProvider(orderId));
    _ref.invalidate(myOrdersProvider);
  }
}

final orderCancelProvider =
    StateNotifierProvider.autoDispose<OrderCancelNotifier, OrderCancelState>((ref) => OrderCancelNotifier(ref));
