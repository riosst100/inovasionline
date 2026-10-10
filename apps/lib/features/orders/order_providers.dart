import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_exception.dart';
import '../../models/order.dart';
import '../../providers/core_providers.dart';

String _errorMessage(Object error, String fallback) {
  if (error is DioException && error.error is ApiException) {
    return (error.error as ApiException).message;
  }
  return fallback;
}

final myOrdersProvider = FutureProvider.autoDispose<List<Order>>((ref) {
  return ref.watch(orderServiceProvider).myOrders();
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
      state = const OrderCancelState();
      return true;
    } catch (e) {
      state = OrderCancelState(error: _errorMessage(e, 'Gagal membatalkan pesanan.'));
      return false;
    }
  }
}

final orderCancelProvider =
    StateNotifierProvider.autoDispose<OrderCancelNotifier, OrderCancelState>((ref) => OrderCancelNotifier(ref));
