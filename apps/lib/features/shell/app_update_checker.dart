import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../models/app_update_info.dart';
import '../../providers/core_providers.dart';

/// Checks for an app update once per launch and, if one is available,
/// offers to download and install it in-app. Wrap the app shell with this
/// widget; it renders nothing on its own.
///
/// The check is the very last thing at start-up: it waits for the splash,
/// permissions, locating and the current-location choice
/// ([startupSettledProvider]), then a few more seconds so home's API calls
/// and images get to load first.
class AppUpdateChecker extends ConsumerStatefulWidget {
  const AppUpdateChecker({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AppUpdateChecker> createState() => _AppUpdateCheckerState();
}

/// Once per process: the shell can be rebuilt (e.g. after logging in again)
/// and must not ask a second time.
bool _checkedThisLaunch = false;

class _AppUpdateCheckerState extends ConsumerState<AppUpdateChecker> {
  static const _afterStartupDelay = Duration(seconds: 4);

  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (_checkedThisLaunch || !ref.read(appUpdateServiceProvider).isSupported) {
      return;
    }
    ref.listenManual<bool>(startupSettledProvider, (_, settled) {
      if (!settled || _checkedThisLaunch || _timer != null) return;
      _timer = Timer(_afterStartupDelay, _checkForUpdate);
    }, fireImmediately: true);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _checkForUpdate() async {
    _checkedThisLaunch = true;
    try {
      final info = await ref.read(appUpdateServiceProvider).checkForUpdate();
      if (info == null || !mounted) return;
      await showAppUpdateDialog(context, info);
    } catch (_) {
      // Silent failure: update checks must never block or interrupt app usage.
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// "Update Tersedia": downloads the APK with a progress bar and hands it to
/// the Android installer. Not dismissible when [AppUpdateInfo.forceUpdate].
Future<void> showAppUpdateDialog(BuildContext context, AppUpdateInfo info) {
  return showDialog<void>(
    context: context,
    useRootNavigator: true,
    barrierDismissible: !info.forceUpdate,
    builder: (context) => _UpdateDialog(info: info),
  );
}

class _UpdateDialog extends ConsumerStatefulWidget {
  const _UpdateDialog({required this.info});

  final AppUpdateInfo info;

  @override
  ConsumerState<_UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends ConsumerState<_UpdateDialog> {
  bool _downloading = false;
  double _progress = 0;
  String? _error;
  final _cancelToken = CancelToken();

  @override
  void dispose() {
    _cancelToken.cancel();
    super.dispose();
  }

  Future<void> _startUpdate() async {
    setState(() {
      _downloading = true;
      _progress = 0;
      _error = null;
    });

    try {
      final status = await Permission.requestInstallPackages.request();
      if (!status.isGranted) {
        if (!mounted) return;
        setState(() {
          _downloading = false;
          _error = 'Izinkan "Instal aplikasi tidak dikenal" untuk melanjutkan update.';
        });
        return;
      }

      final file = await ref
          .read(appUpdateServiceProvider)
          .downloadApk(
            widget.info,
            cancelToken: _cancelToken,
            onProgress: (progress) {
              if (mounted) setState(() => _progress = progress);
            },
          );

      final result = await OpenFilex.open(
        file.path,
        type: 'application/vnd.android.package-archive',
      );
      if (!mounted) return;
      if (result.type != ResultType.done) {
        setState(() {
          _downloading = false;
          _error = 'Gagal membuka installer. Silakan coba lagi.';
        });
        return;
      }
      // A forced update stays up so the app cannot be used if the user backs
      // out of the installer; they can simply tap the button again.
      if (widget.info.forceUpdate) {
        setState(() => _downloading = false);
      } else {
        Navigator.of(context).pop();
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _downloading = false;
        _error = 'Gagal mengunduh update. Periksa koneksi lalu coba lagi.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !widget.info.forceUpdate && !_downloading,
      child: AlertDialog(
        title: const Text('Update Tersedia'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Versi baru ${widget.info.version} sudah tersedia.'),
            if (widget.info.forceUpdate) ...[
              const SizedBox(height: 4),
              const Text(
                'Versi aplikasi kamu sudah tidak didukung, update untuk melanjutkan.',
              ),
            ],
            if (widget.info.releaseNotes.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(widget.info.releaseNotes),
            ],
            if (_downloading) ...[
              const SizedBox(height: 16),
              LinearProgressIndicator(value: _progress > 0 ? _progress : null),
              const SizedBox(height: 4),
              Text('${(_progress * 100).toStringAsFixed(0)}%'),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
          ],
        ),
        actions: [
          if (!widget.info.forceUpdate && !_downloading)
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Nanti'),
            ),
          FilledButton(
            onPressed: _downloading ? null : _startUpdate,
            child: Text(_downloading ? 'Mengunduh...' : 'Update Sekarang'),
          ),
        ],
      ),
    );
  }
}
