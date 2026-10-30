import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

import 'cache_versions.dart';

/// Disk cache for rarely-changing public GET endpoints.
///
/// Most public endpoints belong to a group with a version number kept by the server
/// ([CacheVersions]). While a saved copy carries the server's current version (and is not older
/// than the group's max age) it is served with no request at all. The version goes up when the data
/// changes (admin edits, stock moving, "Segarkan cache" in the web admin), and the copy is then
/// fetched again.
///
/// Anything else, and any copy whose version cannot be checked, falls back to validation with ETag:
/// the request is sent with `If-None-Match`, and a `304` answer means the saved copy is still good.
/// Offline, the saved copy is served instead of an error.
class ResponseCache {
  ResponseCache._();

  /// Endpoints that return the same thing for every user (each must send an ETag).
  static final _public = [
    RegExp(r'^/(banners|categories|launch-popup|payment-methods|shipping-methods|delivery-schedules|service-fee|free-shipping|flash-sale-slots|app-version|admob-config|nav-badge)$'),
    RegExp(r'^/categories/[^/]+$'),
    RegExp(r'^/products/(flash-sale|best-sellers|[^/]+)$'),
    RegExp(r'^/regions/(provinces|provinces/[^/]+/cities|cities/[^/]+/districts|districts/[^/]+/villages)$'),
  ];

  /// Which version group an endpoint belongs to (names match the server's AppCache::GROUPS).
  /// Endpoints not listed are always validated with the server.
  static final _groups = <(RegExp, String)>[
    (RegExp(r'^/(banners|launch-popup)$'), 'banners'),
    (RegExp(r'^/categories$'), 'categories'),
    (RegExp(r'^/(payment-methods|shipping-methods|delivery-schedules|service-fee|free-shipping)$'), 'checkout'),
    (RegExp(r'^/regions/'), 'regions'),
    (RegExp(r'^/(app-version|admob-config|nav-badge)$'), 'app_config'),
    // Shows stock, so it moves whenever someone checks out.
    (RegExp(r'^/(products/|categories/|flash-sale-slots$)'), 'products'),
  ];

  static String? groupOf(RequestOptions options) {
    if (_isPrivate(options)) return null;
    for (final (pattern, group) in _groups) {
      if (pattern.hasMatch(options.path)) return group;
    }
    return null;
  }

  /// Endpoints that depend on who is signed in. Saved per account (keyed by a hash of the login token),
  /// never shown offline (a stale balance or order status would mislead), and wiped on logout.
  static final _private = [
    RegExp(r'^/(auth/user|auth/user/addresses|cart|orders|wallet|wallet/transactions|verifications/me)$'),
    RegExp(r'^/orders/[0-9]+$'),
  ];

  static const _privatePrefix = 'api_cache_p_';
  static const _publicPrefix = 'api_cache_';

  /// Most recently used copies kept in memory. Every product page adds an entry, so without a
  /// limit a long session keeps growing.
  static const _memoryLimit = 60;
  static final Map<String, _Entry> _memory = {};
  static Directory? _dir;

  /// Saved copies on disk: removed after [_maxAge], and only the newest [_maxFiles] are kept.
  static const _maxAge = Duration(days: 14);
  static const _maxFiles = 150;
  static bool _trimScheduled = false;

  static void _remember(String key, _Entry entry) {
    _memory.remove(key);
    _memory[key] = entry;
    while (_memory.length > _memoryLimit) {
      _memory.remove(_memory.keys.first);
    }
  }

  /// Deletes stale and surplus public copies; run once per launch, well after start-up.
  static Future<void> _trim() async {
    try {
      final dir = _dir;
      if (dir == null) return;
      final cutoff = DateTime.now().subtract(_maxAge);
      final files = <(File, DateTime)>[];
      await for (final entity in dir.list()) {
        if (entity is! File) continue;
        final name = entity.uri.pathSegments.last;
        // Private copies (per account) are handled by logout, not here.
        if (!name.startsWith(_publicPrefix) || name.startsWith(_privatePrefix)) continue;
        files.add((entity, (await entity.stat()).modified));
      }
      files.sort((a, b) => b.$2.compareTo(a.$2));
      for (var i = 0; i < files.length; i++) {
        if (i >= _maxFiles || files[i].$2.isBefore(cutoff)) await files[i].$1.delete();
      }
    } catch (_) {}
  }

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
      if (!_trimScheduled) {
        _trimScheduled = true;
        Timer(const Duration(seconds: 45), _trim);
      }
      final name = base64Url.encode(utf8.encode(key)).replaceAll('=', '');
      return File('${_dir!.path}/${private ? _privatePrefix : _publicPrefix}$name.json');
    } catch (_) {
      return null;
    }
  }

  static Future<_Entry?> _read(RequestOptions options) async {
    final key = _key(options);
    final cached = _memory[key];
    if (cached != null) {
      _remember(key, cached);
      return cached;
    }
    try {
      final file = await _file(key, private: _isPrivate(options));
      if (file == null || !await file.exists()) return null;
      final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      final entry = _Entry(
        json['etag'] as String,
        json['data'],
        version: json['v'] as int?,
        savedAt: json['t'] as int?,
      );
      _remember(key, entry);
      return entry;
    } catch (_) {
      return null;
    }
  }

  static Future<void> _write(RequestOptions options, _Entry entry) async {
    final key = _key(options);
    _remember(key, entry);
    try {
      final file = await _file(key, private: _isPrivate(options));
      await file?.writeAsString(jsonEncode({
        'etag': entry.etag,
        'data': entry.data,
        'v': entry.version,
        't': entry.savedAt,
      }));
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

  /// The saved copy to answer with, without contacting the server, when its group version still
  /// matches the server's. Null means: go and ask.
  static Future<Response<dynamic>?> fresh(RequestOptions options, CacheVersions versions) async {
    final group = groupOf(options);
    if (group == null) return null;
    await versions.ensure();
    final current = versions.versionOf(group);
    if (current == null) return null;
    final entry = await _read(options);
    if (entry == null || entry.version != current) return null;
    final savedAt = entry.savedAt;
    if (savedAt == null) return null;
    final age = DateTime.now().millisecondsSinceEpoch - savedAt;
    if (age > versions.maxAgeOf(group) * 1000) return null;
    return Response<dynamic>(requestOptions: options, statusCode: 200, data: entry.data);
  }

  /// Adds `If-None-Match` and lets `304` through as a normal response.
  static Future<void> prepare(RequestOptions options) async {
    final entry = await _read(options);
    if (entry != null) options.headers['If-None-Match'] = entry.etag;
    options.validateStatus = (status) => status != null && ((status >= 200 && status < 300) || status == 304);
  }

  /// Swaps a `304` for the saved body, or saves a fresh `200` that carries an ETag.
  static Future<void> store(Response<dynamic> response, CacheVersions versions) async {
    final options = response.requestOptions;
    final group = groupOf(options);
    final version = group == null ? null : versions.versionOf(group);
    final now = DateTime.now().millisecondsSinceEpoch;

    if (response.statusCode == 304) {
      final entry = await _read(options);
      if (entry != null) {
        response
          ..statusCode = 200
          ..data = entry.data;
        // Confirmed current by the server: the copy now counts as saved at this version.
        if (version != null) await _write(options, _Entry(entry.etag, entry.data, version: version, savedAt: now));
      }
      return;
    }
    final etag = response.headers.value('etag');
    if (etag != null && response.data != null) {
      await _write(options, _Entry(etag, response.data, version: version, savedAt: now));
    }
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
  const _Entry(this.etag, this.data, {this.version, this.savedAt});

  final String etag;
  final dynamic data;

  /// Group version the copy was confirmed at; null for copies saved before versions existed.
  final int? version;

  /// Milliseconds since epoch when the copy was last confirmed.
  final int? savedAt;
}
