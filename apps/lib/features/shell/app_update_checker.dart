import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../models/app_update_info.dart';
import '../../providers/core_providers.dart';

/// Silently checks for an app update once per app open and, if one is
/// available, prompts the user to download and install it. Wrap the app
/// shell with this widget; it renders nothing on its own.
class AppUpdateChecker extends ConsumerStatefulWidget {
  const AppUpdateChecker({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AppUpdateChecker> createState() => _AppUpdateCheckerState();
}

class _AppUpdateCheckerState extends ConsumerState<AppUpdateChecker> {
  @override
  void initState() {
    super.initState();
    if (Platform.isAndroid) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _checkForUpdate());
    }
  }

  Future<void> _checkForUpdate() async {
    try {
      final info = await ref.read(appUpdateServiceProvider).checkForUpdate();
      if (info == null || !mounted) return;

      await showDialog<void>(
        context: context,
        barrierDismissible: !info.forceUpdate,
        builder: (context) => _UpdateDialog(info: info),
      );
    } catch (_) {
      // Silent failure: update checks must never block or interrupt app usage.
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
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

  Future<void> _startUpdate() async {
    setState(() {
      _downloading = true;
      _error = null;
    });

    try {
      final status = await Permission.requestInstallPackages.request();
      if (!status.isGranted) {
        setState(() {
          _downloading = false;
          _error = 'Izin instal aplikasi diperlukan untuk melanjutkan update.';
        });
        return;
      }

      final file = await ref
          .read(appUpdateServiceProvider)
          .downloadApk(
            widget.info.apkUrl!,
            onProgress: (progress) {
              if (mounted) setState(() => _progress = progress);
            },
          );

      await OpenFilex.open(file.path);
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      setState(() {
        _downloading = false;
        _error = 'Gagal mengunduh update. Silakan coba lagi.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !widget.info.forceUpdate,
      child: AlertDialog(
        title: const Text('Update Tersedia'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Versi baru ${widget.info.version} sudah tersedia.'),
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
