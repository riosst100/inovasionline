/// Where the server says each cached data group stands (`GET /cache-versions`).
///
/// [ResponseCache] serves a saved copy without any request while its version still matches the
/// server's. The numbers go up when the admin changes the data, when stock moves, or when an admin
/// refreshes the cache from the web panel.
class CacheVersions {
  CacheVersions(this._fetch);

  final Future<Map<String, dynamic>> Function() _fetch;

  Map<String, int>? _versions;
  Map<String, int> _maxAge = const {};
  Future<void>? _inflight;
  DateTime? _lastOk;
  DateTime? _lastFail;

  /// Versions not known (offline, or the server never answered): copies are then checked with the
  /// server as before instead of being trusted.
  int? versionOf(String group) => _versions?[group];

  /// Seconds a copy may be trusted even if its version never moved.
  int maxAgeOf(String group) => _maxAge[group] ?? 3600;

  /// Waits for the first answer (at most a few seconds). After a failure it does not retry for a
  /// while, so an offline start does not slow down every request.
  Future<void> ensure() {
    if (_inflight != null) return _inflight!;
    if (_versions != null) return Future.value();
    final failed = _lastFail;
    if (failed != null && DateTime.now().difference(failed) < const Duration(seconds: 30)) {
      return Future.value();
    }
    return _start();
  }

  /// Asks again, e.g. when the app comes back to the foreground. Skipped when the last answer is
  /// recent.
  Future<void> refresh({Duration minInterval = const Duration(minutes: 10)}) {
    if (_inflight != null) return _inflight!;
    final ok = _lastOk;
    if (ok != null && DateTime.now().difference(ok) < minInterval) return Future.value();
    return _start();
  }

  Future<void> _start() {
    final load = _load().whenComplete(() => _inflight = null);
    _inflight = load;
    return load;
  }

  Future<void> _load() async {
    try {
      final data = await _fetch().timeout(const Duration(seconds: 4));
      final versions = data['versions'];
      if (versions is! Map) throw const FormatException('no versions');
      _versions = versions.map((k, v) => MapEntry(k.toString(), (v as num).toInt()));
      final maxAge = data['max_age'];
      if (maxAge is Map) {
        _maxAge = maxAge.map((k, v) => MapEntry(k.toString(), (v as num).toInt()));
      }
      _lastOk = DateTime.now();
      _lastFail = null;
    } catch (_) {
      _lastFail = DateTime.now();
    }
  }
}
