import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../core/api/api_client.dart';

/// Reports this install to the backend so the admin dashboard can count
/// installs, users online and who is on the checkout screen. Pings on
/// launch, on every route change and every minute while in the foreground.
/// Failures are ignored: presence is best effort and must never bother the user.
class AppPresence with WidgetsBindingObserver {
  AppPresence(this._api, this._router);

  final ApiClient _api;
  final GoRouter _router;

  static const _interval = Duration(minutes: 1);
  static const _installIdKey = 'install_id';

  Timer? _timer;
  String? _installId;
  String? _appVersion;
  String? _lastScreen;

  Future<void> start() async {
    try {
      _installId = await _readInstallId();
      _appVersion = (await PackageInfo.fromPlatform()).version;
    } catch (_) {
      return;
    }
    WidgetsBinding.instance.addObserver(this);
    _router.routerDelegate.addListener(_onRouteChanged);
    _resume();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _resume();
    } else if (state == AppLifecycleState.paused) {
      _timer?.cancel();
      _timer = null;
    }
  }

  void _resume() {
    _timer?.cancel();
    _timer = Timer.periodic(_interval, (_) => _send());
    _send();
  }

  void _onRouteChanged() {
    final screen = _currentScreen();
    if (screen == _lastScreen) return;
    _send();
  }

  String _currentScreen() => _router.routerDelegate.currentConfiguration.uri.path;

  Future<void> _send() async {
    final screen = _currentScreen();
    _lastScreen = screen;
    try {
      await _api.dio.post(
        '/app/heartbeat',
        data: {
          'install_id': _installId,
          'platform': Platform.isAndroid ? 'android' : (Platform.isIOS ? 'ios' : 'other'),
          'app_version': _appVersion,
          'screen': screen,
        },
      );
    } catch (_) {}
  }

  static Future<String> _readInstallId() async {
    const storage = FlutterSecureStorage();
    final existing = await storage.read(key: _installIdKey);
    if (existing != null && existing.isNotEmpty) return existing;
    final random = Random.secure();
    final id = List.generate(16, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
    await storage.write(key: _installIdKey, value: id);
    return id;
  }
}
