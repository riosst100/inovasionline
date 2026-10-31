import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../core/api/api_client.dart';
import '../core/device/device_details.dart';
import '../core/storage/install_id.dart';
import 'location_service.dart';

/// Reports this install to the backend so the admin dashboard can count
/// installs, users online and who is on the checkout screen. Pings on
/// launch, on every route change and every 2 minutes while in the foreground.
/// Failures are ignored: presence is best effort and must never bother the user.
class AppPresence with WidgetsBindingObserver {
  AppPresence(this._api, this._router);

  final ApiClient _api;
  final GoRouter _router;

  // The dashboard counts an install as online for 5 minutes (AppInstall::ONLINE_MINUTES).
  static const _interval = Duration(minutes: 2);

  Timer? _timer;
  String? _installId;
  String? _appVersion;
  int? _buildNumber;
  String? _lastScreen;

  /// Sent with heartbeats until one succeeds, then dropped for this launch.
  Map<String, dynamic>? _device;

  Future<void> start() async {
    try {
      _installId = await InstallId.read();
      final packageInfo = await PackageInfo.fromPlatform();
      _appVersion = packageInfo.version;
      _buildNumber = int.tryParse(packageInfo.buildNumber);
    } catch (_) {
      return;
    }
    _device = await DeviceDetails.collect();
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
    final device = _device;
    // Cached OS position; never prompts. Null without permission.
    final position = await LocationService.lastKnownPosition();
    try {
      await _api.dio.post(
        '/app/heartbeat',
        data: {
          'install_id': _installId,
          'platform': Platform.isAndroid ? 'android' : (Platform.isIOS ? 'ios' : 'other'),
          'app_version': _appVersion,
          'build_number': _buildNumber,
          'screen': screen,
          'device': ?device,
          if (position != null)
            'location': {
              'latitude': position.latitude,
              'longitude': position.longitude,
              'accuracy': position.accuracy,
              'at': position.timestamp.toUtc().toIso8601String(),
            },
        },
      );
      if (device != null) _device = null;
    } catch (_) {}
  }
}
