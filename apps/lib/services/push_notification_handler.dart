import 'dart:developer' as developer;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/router.dart';
import '../providers/core_providers.dart';

const _broadcastTopic = 'all_users';

const _androidChannel = AndroidNotificationChannel(
  'default_channel',
  'General notifications',
  description: 'Order updates, chat messages, and promotions.',
  importance: Importance.high,
);

/// Must be a top-level function: the OS calls this in a separate isolate
/// when a data message arrives while the app is fully terminated/background.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {}

class PushNotificationHandler {
  PushNotificationHandler(this._container);

  final ProviderContainer _container;
  final _localNotifications = FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    await FirebaseMessaging.instance.requestPermission();
    await FirebaseMessaging.instance.subscribeToTopic(_broadcastTopic);

    await _localNotifications.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
      onDidReceiveNotificationResponse: (response) {
        final threadOrOrderId = response.payload;
        if (threadOrOrderId != null) _navigate(threadOrOrderId);
      },
    );
    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(_androidChannel);

    await _syncToken();
    FirebaseMessaging.instance.onTokenRefresh.listen((_) => _syncToken());

    FirebaseMessaging.onMessage.listen(_showForegroundNotification);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleTap);

    final initialMessage = await FirebaseMessaging.instance
        .getInitialMessage();
    if (initialMessage != null) _handleTap(initialMessage);
  }

  Future<void> _syncToken() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await _container
            .read(notificationServiceProvider)
            .registerToken(token);
      }
    } catch (e) {
      developer.log('Failed to sync FCM token: $e', name: 'push');
    }
  }

  void _showForegroundNotification(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;

    _localNotifications.show(
      notification.hashCode,
      notification.title,
      notification.body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'default_channel',
          'General notifications',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      payload: _payloadFor(message.data),
    );
  }

  void _handleTap(RemoteMessage message) {
    final payload = _payloadFor(message.data);
    if (payload != null) _navigate(payload);
  }

  String? _payloadFor(Map<String, dynamic> data) {
    final type = data['type'];
    if (type == 'order' && data['order_id'] != null) {
      return 'order:${data['order_id']}';
    }
    if (type == 'chat') {
      return 'chat:';
    }
    return null;
  }

  void _navigate(String payload) {
    final [kind, id] = payload.split(':');
    switch (kind) {
      case 'order':
        router.push('/orders/$id');
      case 'chat':
        // Thread detail needs data (title, avatar) beyond what the push
        // payload carries, so land on the chat list and let the user open it.
        router.go('/chat');
    }
  }
}
