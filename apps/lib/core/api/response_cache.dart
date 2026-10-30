import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

/// Disk cache for rarely-changing public GET endpoints, validated with ETag.
///
/// Every request still asks the server, but sends `If-None-Match`; when nothing changed the server
/// answers `304` with no body and we serve the saved copy. When the admin changes something the
/// ETag differs, the server sends fresh data and the saved copy is replaced, so it can never go stale.
/// Offline, the saved copy is served instead of an error.
class ResponseCache {
  ResponseCache._();

  /// Endpoints that return the same thing for every user (each must send an ETag).
  static final _public = [
    RegExp(r'^/(banners|categories|launch-popup|payment-methods|shipping-methods|delivery-schedules|service-fee|free-shipping|flash-sale-slots|app-version|admob-config)$'),
    RegExp(r'^/categories/[^/]+$'),
    RegExp(r'^/products/(flash-sale|best-sellers|[^/]+)$'),
    RegExp(r'^/regions/(provinces|provinces/[^/]+/cities|cities/[^/]+/districts|districts/[^/]+/villages)$'),
  ];

  /// Endpoints that depend on who is signed in. Saved per account (keyed by a hash of the login token),
  /// never shown offline (a stale balance or order status would mislead), and wiped on logout.
  static final _private = [
    RegExp(r'^/(auth/user|auth/user/addresses|cart|orders|wallet|wallet/transactions|verifications/me)$'),
    RegExp(r'^/orders/[0-9]+$'),
  ];

  static const _privatePrefix = 'api_cache_p_';
  static const _publicPrefix = 'api_cache_';

  static final Map<String, _Entry> _memory = {};
  static Directory? _dir;

  static bool _isPrivate(RequestOptions options) => _private.any((r) => r.hasMatch(options.path));

  static bool applies(RequestOptions options) =>
      options.method == 'GET' && (_isPrivate(options) || _public.any((r) => r.hasMatch(options.path)));

  static String _key(RequestOptions options) {
    final query = options.queryParameters.entries.map((e) => '${e.key}=${e.value}').toList()..sort();
    final owner = _isPrivate(options) ? '|${_fnv('${options.headers['Authorization']}')}' : '';
    return '${options.path}?${query.join('&')}$owner';
  }

  /// Small stable hash (String.hashCode changes between runs); the raw token is never written to disk.
  static String _fnv(String input) {
    var hash = 0xcbf29ce484222325;
    for (final unit in input.codeUnits) {
      hash = ((hash ^ unit) * 0x100000001b3) & 0x7fffffffffffffff;
    }
    return hash.toRadixString(16);
  }

  static Future<File?> _file(String key, {required bool private}) async {
    try {
      _dir ??= await getApplicationSupportDirectory();
      final name = base64Url.encode(utf8.encode(key)).replaceAll('=', '');
      return File('${_dir!.path}/${private ? _privatePrefix : _publicPrefix}$name.json');
    } catch (_) {
      return null;
    }
  }

  static Future<_Entry?> _read(RequestOptions options) async {
    final key = _key(options);
    final cached = _memory[key];
    if (cached != null) return cached;
    try {
      final file = await _file(key, private: _isPrivate(options));
      if (file == null || !await file.exists()) return null;
      final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      return _memory[key] = _Entry(json['etag'] as String, json['data']);
    } catch (_) {
      return null;
    }
  }

  static Future<void> _write(RequestOptions options, _Entry entry) async {
    final key = _key(options);
    _memory[key] = entry;
    try {
      final file = await _file(key, private: _isPrivate(options));
      await file?.writeAsString(jsonEncode({'etag': entry.etag, 'data': entry.data}));
    } catch (_) {
      // Cache is best-effort; the response itself is still delivered.
    }
  }

  /// Forget everything saved for signed-in users (call on logout).
  static Future<void> clearPrivate() async {
    _memory.removeWhere((key, _) => _private.any((r) => r.hasMatch(key.split('?').first)));
    try {
      _dir ??= await getApplicationSupportDirectory();
      await for (final entity in _dir!.list()) {
        if (entity is File && entity.uri.pathSegments.last.startsWith(_privatePrefix)) await entity.delete();
      }
    } catch (_) {}
  }

  /// Adds `If-None-Match` and lets `304` through as a normal response.
  static Future<void> prepare(RequestOptions options) async {
    final entry = await _read(options);
    if (entry != null) options.headers['If-None-Match'] = entry.etag;
    options.validateStatus = (status) => status != null && ((status >= 200 && status < 300) || status == 304);
  }

  /// Swaps a `304` for the saved body, or saves a fresh `200` that carries an ETag.
  static Future<void> store(Response<dynamic> response) async {
    final options = response.requestOptions;
    if (response.statusCode == 304) {
      final entry = await _read(options);
      if (entry != null) {
        response
          ..statusCode = 200
          ..data = entry.data;
      }
      return;
    }
    final etag = response.headers.value('etag');
    if (etag != null && response.data != null) await _write(options, _Entry(etag, response.data));
  }

  /// The saved copy to show when the network is unreachable.
  static Future<Response<dynamic>?> offline(RequestOptions options) async {
    if (_isPrivate(options)) return null;
    final entry = await _read(options);
    if (entry == null) return null;
    return Response<dynamic>(requestOptions: options, statusCode: 200, data: entry.data);
  }
}

class _Entry {
  const _Entry(this.etag, this.data);

  final String etag;
  final dynamic data;
}
