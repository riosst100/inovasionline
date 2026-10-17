import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../models/order.dart';

/// Keeps one ongoing (non-swipeable) Android notification for the newest active order.
/// The plugin is initialised by PushNotificationHandler, whose tap handler already
/// opens `order:<id>` payloads.
class ActiveOrderNotification {
  ActiveOrderNotification._();

  static const _id = 7001;
  static final _plugin = FlutterLocalNotificationsPlugin();
  static String? _lastShown;

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'active_order_channel',
      'Pesanan aktif',
      channelDescription: 'Status pesanan yang sedang berjalan.',
      // Low importance: stays in the shade without sound or heads-up on every update.
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,
      autoCancel: false,
      onlyAlertOnce: true,
      showWhen: false,
      category: AndroidNotificationCategory.status,
    ),
  );

  static Future<void> sync(List<Order> activeOrders) async {
    if (activeOrders.isEmpty) {
      if (_lastShown != null) await _plugin.cancel(_id);
      _lastShown = null;
      return;
    }

    final order = activeOrders.first;
    final title = order.needsOnlinePayment ? 'Menunggu pembayaran' : order.statusLabel;
    final others = activeOrders.length - 1;
    final body = [
      order.orderNumber,
      if (others > 0) '+$others pesanan aktif lainnya',
    ].join(' · ');

    // Skip identical re-posts so refreshes do not churn the notification, unless the user
    // swiped it away (Android 14+ lets them dismiss even ongoing notifications).
    final signature = '${order.id}|$title|$body';
    if (signature == _lastShown && await _isShowing()) return;
    _lastShown = signature;

    await _plugin.show(_id, title, body, _details, payload: 'order:${order.id}');
  }

  static Future<bool> _isShowing() async {
    try {
      final active = await _plugin.getActiveNotifications();
      return active.any((n) => n.id == _id);
    } catch (_) {
      // Unsupported platform/OS version: assume it is still there.
      return true;
    }
  }
}
