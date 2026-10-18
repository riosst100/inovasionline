import 'package:flutter/material.dart';

import '../../config/theme.dart';
import '../../models/order.dart';
import '../../widgets/common.dart';

Color orderStatusColor(OrderStatus status) => switch (status) {
  OrderStatus.pending => AppColors.warning,
  OrderStatus.accepted => AppColors.info,
  OrderStatus.processing => AppColors.accent,
  OrderStatus.ready => AppColors.primary,
  OrderStatus.completed => AppColors.success,
  OrderStatus.cancelled => AppColors.destructive,
};

Color paymentStatusColor(String status) => switch (status) {
  'paid' => AppColors.success,
  'failed' => AppColors.destructive,
  'refunded' => AppColors.info,
  _ => AppColors.mutedForeground,
};

class OrderStatusBadge extends StatelessWidget {
  const OrderStatusBadge(this.status, {super.key});

  final OrderStatus status;

  @override
  Widget build(BuildContext context) => StatusBadge(label: status.label, color: orderStatusColor(status));
}

class PaymentStatusBadge extends StatelessWidget {
  const PaymentStatusBadge(this.order, {super.key});

  final Order order;

  @override
  Widget build(BuildContext context) =>
      StatusBadge(label: order.paymentStatusLabel, color: paymentStatusColor(order.paymentStatus));
}
