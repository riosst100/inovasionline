import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// Whether the device can reach the internet. Probes public DNS resolvers by
/// IP (no DNS needed) because an active WiFi/mobile interface does not mean
/// there is internet behind it.
class Connectivity {
  Connectivity._();

  static const _probes = ['1.1.1.1', '8.8.8.8'];

  /// Optimistic until the first check says otherwise.
  static final ValueNotifier<bool> online = ValueNotifier<bool>(true);

  static Future<bool>? _inFlight;

  /// Runs a fresh probe (concurrent callers share one) and updates [online].
  static Future<bool> check() => _inFlight ??= _probe().whenComplete(() {
    _inFlight = null;
  });

  static Future<bool> _probe() async {
    final results = await Future.wait(
      _probes.map((host) async {
        try {
          final socket = await Socket.connect(
            host,
            443,
            timeout: const Duration(seconds: 3),
          );
          socket.destroy();
          return true;
        } catch (_) {
          return false;
        }
      }),
    );
    final ok = results.any((r) => r);
    online.value = ok;
    return ok;
  }
}
