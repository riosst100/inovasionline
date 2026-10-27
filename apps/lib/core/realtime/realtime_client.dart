import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../config/env.dart';
import '../api/api_client.dart';

/// Minimal Pusher-protocol client for Laravel Reverb (private channels only).
///
/// The backend only signals that something changed (see `ChatMessageSent`); listeners refetch
/// through the normal API. Best effort: while the socket is down, [connected] is false and screens
/// fall back to polling. The socket is closed while the app is in the background.
class RealtimeClient with WidgetsBindingObserver {
  RealtimeClient(this._api) {
    WidgetsBinding.instance.addObserver(this);
  }

  final ApiClient _api;

  /// True while the socket is connected and the handshake finished.
  final ValueNotifier<bool> connected = ValueNotifier(false);

  final Map<String, Map<String, Set<VoidCallback>>> _listeners = {};
  final Set<String> _subscribed = {};

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _socketSub;
  Timer? _retryTimer;
  String? _socketId;
  int _attempt = 0;
  bool _foreground = true;

  /// Calls [onEvent] whenever [event] arrives on private channel [name] (without the `private-` prefix).
  /// Returns a function that removes the listener; the socket closes once nobody listens.
  VoidCallback listen(String name, String event, VoidCallback onEvent) {
    final channel = 'private-$name';
    _listeners.putIfAbsent(channel, () => {}).putIfAbsent(event, () => {}).add(onEvent);
    _ensureConnected();
    _subscribe(channel);

    return () {
      final events = _listeners[channel];
      events?[event]?.remove(onEvent);
      if (events != null && events.values.every((s) => s.isEmpty)) {
        _listeners.remove(channel);
        if (_subscribed.remove(channel)) {
          _send({'event': 'pusher:unsubscribe', 'data': {'channel': channel}});
        }
      }
      if (_listeners.isEmpty) _close();
    };
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _foreground = true;
      if (_listeners.isNotEmpty) _ensureConnected();
    } else if (state == AppLifecycleState.paused) {
      _foreground = false;
      _close();
    }
  }

  Uri get _socketUri {
    final secure = Env.reverbScheme == 'https';
    return Uri(
      scheme: secure ? 'wss' : 'ws',
      host: Env.reverbHost,
      port: Env.reverbPort,
      path: '/app/${Env.reverbAppKey}',
      queryParameters: {'protocol': '7', 'client': 'flutter', 'version': '1.0', 'flash': 'false'},
    );
  }

  void _ensureConnected() {
    if (_channel != null || !_foreground || _listeners.isEmpty) return;
    _retryTimer?.cancel();
    try {
      final channel = WebSocketChannel.connect(_socketUri);
      _channel = channel;
      // A failed handshake completes `ready` with an error; unhandled it surfaces as a crash log.
      channel.ready.then((_) {}, onError: (_) => _onClosed(channel));
      _socketSub = channel.stream.listen(
        _onMessage,
        onError: (_) => _onClosed(channel),
        onDone: () => _onClosed(channel),
        cancelOnError: true,
      );
    } catch (_) {
      _scheduleRetry();
    }
  }

  void _onMessage(dynamic raw) {
    if (raw is! String) return;
    final Map<String, dynamic> message;
    try {
      message = jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return;
    }

    switch (message['event']) {
      case 'pusher:connection_established':
        final data = _decodeData(message['data']);
        _socketId = data['socket_id'] as String?;
        _attempt = 0;
        connected.value = true;
        for (final channel in _listeners.keys) {
          _subscribe(channel);
        }
      case 'pusher:ping':
        _send({'event': 'pusher:pong', 'data': <String, dynamic>{}});
      case final String event:
        final channel = message['channel'] as String?;
        if (channel == null) return;
        final callbacks = _listeners[channel]?[event];
        if (callbacks == null) return;
        for (final callback in List.of(callbacks)) {
          callback();
        }
    }
  }

  Map<String, dynamic> _decodeData(dynamic data) {
    if (data is String) {
      try {
        return jsonDecode(data) as Map<String, dynamic>;
      } catch (_) {
        return {};
      }
    }
    return data is Map<String, dynamic> ? data : {};
  }

  Future<void> _subscribe(String channel) async {
    final socketId = _socketId;
    if (!connected.value || socketId == null || _subscribed.contains(channel)) return;
    _subscribed.add(channel);
    try {
      final response = await _api.dio.post(
        '${Env.appBaseUrl}/broadcasting/auth',
        data: {'socket_id': socketId, 'channel_name': channel},
      );
      final auth = (response.data as Map<String, dynamic>)['auth'];
      // The socket may have been replaced while the auth call was in flight.
      if (socketId != _socketId || !connected.value) return;
      _send({'event': 'pusher:subscribe', 'data': {'auth': auth, 'channel': channel}});
    } catch (_) {
      // Not authorized (or offline): this channel just stays on the polling fallback.
      _subscribed.remove(channel);
    }
  }

  void _send(Map<String, dynamic> message) {
    try {
      _channel?.sink.add(jsonEncode(message));
    } catch (_) {}
  }

  void _onClosed(WebSocketChannel channel) {
    if (_channel != channel) return;
    _teardown();
    if (_foreground && _listeners.isNotEmpty) _scheduleRetry();
  }

  void _scheduleRetry() {
    _retryTimer?.cancel();
    // 1s, 2s, 4s ... capped at 30s, with jitter so a server restart doesn't get a thundering herd.
    final seconds = min(30, 1 << min(_attempt, 5));
    _attempt++;
    _retryTimer = Timer(
      Duration(milliseconds: seconds * 1000 + Random().nextInt(500)),
      _ensureConnected,
    );
  }

  void _close() {
    _retryTimer?.cancel();
    _retryTimer = null;
    _channel?.sink.close();
    _teardown();
  }

  void _teardown() {
    _socketSub?.cancel();
    _socketSub = null;
    _channel = null;
    _socketId = null;
    _subscribed.clear();
    connected.value = false;
  }
}
