import 'dart:io';

import 'package:android_intent_plus/android_intent.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../config/theme.dart';

/// Blocks access to the app until notification permission is granted.
/// Push notifications carry order updates and chat messages the user
/// cannot otherwise be reached for, so the app refuses to proceed without
/// them rather than degrading silently.
class NotificationPermissionGate extends StatefulWidget {
  const NotificationPermissionGate({super.key, required this.child});

  final Widget child;

  @override
  State<NotificationPermissionGate> createState() =>
      _NotificationPermissionGateState();
}

class _NotificationPermissionGateState
    extends State<NotificationPermissionGate>
    with WidgetsBindingObserver {
  bool _checking = true;
  bool _granted = false;
  bool _permanentlyDenied = false;
  bool _requesting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Catches the user granting the permission from system Settings and
    // coming back, without requiring them to restart the app.
    if (state == AppLifecycleState.resumed && !_granted) {
      _refreshStatus();
    }
  }

  Future<void> _refreshStatus() async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      setState(() {
        _checking = false;
        _granted = true;
      });
      return;
    }

    final status = await Permission.notification.status;
    if (!mounted) return;
    setState(() {
      _checking = false;
      _granted = status.isGranted;
      _permanentlyDenied = status.isPermanentlyDenied;
    });
  }

  Future<void> _requestPermission() async {
    setState(() => _requesting = true);

    if (_permanentlyDenied) {
      await _openNotificationSettings();
      setState(() => _requesting = false);
      return;
    }

    final status = await Permission.notification.request();
    if (!mounted) return;
    setState(() {
      _requesting = false;
      _granted = status.isGranted;
      _permanentlyDenied = status.isPermanentlyDenied;
    });
  }

  /// Jumps straight to the app's notification settings screen on Android
  /// (skipping the generic App Info page) so the user only has to flip one
  /// switch. Falls back to the generic app settings page elsewhere.
  Future<void> _openNotificationSettings() async {
    if (Platform.isAndroid) {
      try {
        final packageInfo = await PackageInfo.fromPlatform();
        final intent = AndroidIntent(
          action: 'android.settings.APP_NOTIFICATION_SETTINGS',
          arguments: {
            'android.provider.extra.APP_PACKAGE': packageInfo.packageName,
          },
        );
        await intent.launch();
        return;
      } catch (_) {
        // Fall through to the generic settings page below.
      }
    }
    await openAppSettings();
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_granted) {
      return widget.child;
    }

    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.notifications_active_outlined,
                  size: 96,
                  color: AppColors.primary,
                ),
                const SizedBox(height: 24),
                Text(
                  'Izinkan Notifikasi',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Inovasi Online butuh izin notifikasi untuk mengabari '
                  'status pesanan dan pesan chat kamu. Izinkan notifikasi '
                  'untuk melanjutkan.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.mutedForeground),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _requesting ? null : _requestPermission,
                    child: Text(
                      _requesting
                          ? 'Menunggu...'
                          : _permanentlyDenied
                          ? 'Buka Pengaturan'
                          : 'Izinkan Notifikasi',
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => SystemNavigator.pop(),
                    child: const Text('Keluar Aplikasi'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
