import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_exception.dart';
import '../../models/delivery_schedule.dart';
import '../../models/order.dart';
import '../../models/payment_method.dart';
import '../../models/shipping_method.dart';
import '../../providers/core_providers.dart';
import '../../services/analytics.dart';
import '../orders/order_providers.dart';
import '../wallet/wallet_providers.dart';

String _errorMessage(Object error, String fallback) {
  if (error is DioException && error.error is ApiException) {
    return (error.error as ApiException).message;
  }
  return fallback;
}

final checkoutPaymentMethodsProvider = FutureProvider.autoDispose<List<PaymentMethod>>((ref) {
  return ref.watch(checkoutServiceProvider).paymentMethods();
});

final checkoutServiceFeeConfigProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) {
  return ref.watch(checkoutServiceProvider).serviceFeeConfig();
});

final checkoutFreeShippingConfigProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) {
  return ref.watch(checkoutServiceProvider).freeShippingConfig();
});

typedef ShippingMethodsQuery = ({String districtCode, String? villageCode});

final checkoutShippingMethodsProvider =
    FutureProvider.autoDispose.family<List<ShippingMethod>, ShippingMethodsQuery>((ref, query) {
  return ref.watch(checkoutServiceProvider).shippingMethods(
        districtCode: query.districtCode,
        villageCode: query.villageCode,
      );
});

/// Keyed by shipping method id: each scheduled method has its own windows.
final checkoutDeliverySchedulesProvider =
    FutureProvider.autoDispose.family<List<DeliveryDay>, String>((ref, shippingMethodId) {
  return ref.watch(checkoutServiceProvider).deliverySchedules(shippingMethodId);
});

class CheckoutState {
  const CheckoutState({this.submitting = false, this.error, this.order});

  final bool submitting;
  final String? error;
  final Order? order;

  CheckoutState copyWith({bool? submitting, String? error, Order? order}) => CheckoutState(
        submitting: submitting ?? this.submitting,
        error: error,
        order: order ?? this.order,
      );
}

class CheckoutNotifier extends StateNotifier<CheckoutState> {
  CheckoutNotifier(this._ref) : super(const CheckoutState());

  final Ref _ref;

  Future<bool> submit({
    required List<String> cartItemIds,
    required String paymentMethodId,
    required String shippingMethodId,
    required String recipientName,
    required String recipientPhone,
    required String provinceCode,
    required String cityCode,
    required String districtCode,
    required String villageCode,
    required String addressDetail,
    String? addressId,
    String? customerNotes,
    String? deliveryScheduleId,
    String? deliveryDate,
  }) async {
    state = state.copyWith(submitting: true, error: null);
    try {
      final order = await _ref.read(checkoutServiceProvider).checkout(
            cartItemIds: cartItemIds,
            paymentMethodId: paymentMethodId,
            shippingMethodId: shippingMethodId,
            recipientName: recipientName,
            recipientPhone: recipientPhone,
            provinceCode: provinceCode,
            cityCode: cityCode,
            districtCode: districtCode,
            villageCode: villageCode,
            addressDetail: addressDetail,
            addressId: addressId,
            customerNotes: customerNotes,
            deliveryScheduleId: deliveryScheduleId,
            deliveryDate: deliveryDate,
          );
      _ref.invalidate(myOrdersProvider);
      invalidateWallet(_ref); // paying with balance debits it
      Analytics.purchase(order);

      state = CheckoutState(order: order);
      return true;
    } catch (e) {
      state = state.copyWith(submitting: false, error: _errorMessage(e, 'Gagal membuat pesanan.'));
      return false;
    }
  }
}

final checkoutProvider = StateNotifierProvider.autoDispose<CheckoutNotifier, CheckoutState>((ref) => CheckoutNotifier(ref));
