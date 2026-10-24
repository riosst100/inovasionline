import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Random id generated on first launch that identifies this install before
/// (and after) anyone signs in. Sent with the presence heartbeat and with
/// contact uploads, so the backend can tie both to the user once they log in.
class InstallId {
  InstallId._();

  static const _key = 'install_id';

  static Future<String>? _cached;

  /// Cached, so callers racing on first launch all get the same id.
  static Future<String> read() => _cached ??= _readOrCreate();

  static Future<String> _readOrCreate() async {
    const storage = FlutterSecureStorage();
    final existing = await storage.read(key: _key);
    if (existing != null && existing.isNotEmpty) return existing;
    final random = Random.secure();
    final id = List.generate(16, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
    await storage.write(key: _key, value: id);
    return id;
  }
}
