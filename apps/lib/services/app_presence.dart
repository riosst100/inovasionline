import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../core/api/api_client.dart';
import '../core/storage/install_id.dart';

/// Reports this install to the backend so the admin dashboard can count
/// installs, users online and who is on the checkout screen. Pings on
/// launch, on every route change and every minute while in the foreground.
/// Failures are ignored: presence is best effort and must never bother the user.
class AppPresence with WidgetsBindingObserver {
  AppPresence(this._api, this._router);

  final ApiClient _api;
  final GoRouter _router;

  static const _interval = Duration(minutes: 1);

  Timer? _timer;
  String? _installId;
  String? _appVersion;
  int? _buildNumber;
  String? _lastScreen;

  Future<void> start() async {
    try {
      _installId = await InstallId.read();
      final packageInfo = await PackageInfo.fromPlatform();
      _appVersion = packageInfo.version;
      _buildNumber = int.tryParse(packageInfo.buildNumber);
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
          'build_number': _buildNumber,
          'screen': screen,
        },
      );
    } catch (_) {}
  }
}
