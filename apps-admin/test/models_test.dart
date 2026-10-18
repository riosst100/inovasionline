import 'package:flutter_test/flutter_test.dart';
import 'package:inovasionline_admin/models/order.dart';
import 'package:inovasionline_admin/models/product.dart';

void main() {
  test('order transitions mirror the backend', () {
    expect(OrderStatus.pending.next, [OrderStatus.accepted, OrderStatus.processing, OrderStatus.cancelled]);
    expect(OrderStatus.processing.next, [OrderStatus.ready, OrderStatus.cancelled]);
    expect(OrderStatus.ready.next, [OrderStatus.completed]);
    expect(OrderStatus.completed.next, isEmpty);
    expect(OrderStatus.cancelled.next, isEmpty);
  });

  test('order parses the admin API payload', () {
    final order = Order.fromJson({
      'id': '01J',
      'order_number': 'ORD-1',
      'status': 'processing',
      'payment_status': 'paid',
      'grand_total': 45000,
      'subtotal': '45000.00',
      'user': {'id': 1, 'name': 'Budi'},
      'delivery_address': {
        'recipient_name': 'Budi',
        'address_detail': 'Jl. Mawar 1',
        'city_name': 'Bandung',
        'province_name': null,
      },
      'items': [
        {'product_name': 'Beras', 'quantity': 2, 'unit_price': 22500, 'line_total': 45000},
      ],
      'status_history': [
        {'status': 'processing', 'at': '2026-10-18T10:00:00+07:00', 'by': 'admin:5'},
      ],
      'created_at': '2026-10-18T10:00:00+07:00',
    });

    expect(order.status, OrderStatus.processing);
    expect(order.customerName, 'Budi');
    expect(order.subtotal, 45000);
    expect(order.fullAddress, 'Jl. Mawar 1, Bandung');
    expect(order.items.single.quantity, 2);
    expect(order.history.single.byLabel, 'Admin');
  });

  test('product status round-trips out_of_stock', () {
    expect(ProductStatus.parse('out_of_stock'), ProductStatus.outOfStock);
    expect(ProductStatus.outOfStock.value, 'out_of_stock');
  });
}
