import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_update/in_app_update.dart';

import '../../config/theme.dart';
import '../../providers/core_providers.dart';
import '../../services/app_update_service.dart';
import '../home/home_tour.dart';

/// Checks Google Play for an app update once per launch. Wrap the app shell
/// with this widget; it renders nothing on its own.
///
/// The check is the very last thing at start-up: it waits for the splash,
/// permissions, locating and the current-location choice
/// ([startupSettledProvider]), then a few more seconds so home's API calls
/// and images get to load first. If the first-launch tour is up by then, it
/// waits until the tour is closed.
///
/// - Optional (default): Play's full-screen update, which installs and
///   restarts the app. The user may back out of it and keep using the app.
/// - Mandatory (this build is below the minimum set in admin, Pengaturan →
///   Update Aplikasi): Play's full-screen update starts right away, and a
///   screen that cannot be dismissed stays up until the user updates.
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
      // The first-launch tour goes first; Play's update dialog would cover it.
      await HomeTour.whenIdle();
      if (!mounted) return;
      final service = ref.read(appUpdateServiceProvider);
      final update = await service.checkForUpdate();
      if (update == null || !mounted) return;

      if (update.mandatory) {
        await _showMandatoryUpdate(context, update, service);
        return;
      }

      final info = update.play;
      // Already downloaded on an earlier launch but never installed.
      if (info.installStatus == InstallStatus.downloaded) {
        _offerRestart();
        return;
      }
      if (info.immediateUpdateAllowed) {
        // Same as Akun → Versi Aplikasi. Backing out of it = declined: not
        // asked again this launch.
        await service.updateNow(info);
        return;
      }
      // Play's update screen not allowed: let the user open the Play Store.
      _offerUpdate(info);
    } catch (_) {
      // Silent failure (offline, not installed from Play, ...): update checks
      // must never block or interrupt app usage.
    }
  }

  void _offerRestart() {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        content: const Text('Versi baru sudah diunduh.'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(days: 1),
        action: SnackBarAction(
          label: 'Pasang',
          onPressed: () => InAppUpdate.completeFlexibleUpdate().catchError((_) {}),
        ),
      ),
    );
  }

  void _offerUpdate(AppUpdateInfo info) {
    if (!mounted) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        content: const Text('Versi baru tersedia.'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 10),
        action: SnackBarAction(
          label: 'Update',
          onPressed: () => ref.read(appUpdateServiceProvider).updateNow(info),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Full-screen and not dismissible: the app stays unusable until the update
/// is installed (which restarts the app).
Future<void> _showMandatoryUpdate(
  BuildContext context,
  AvailableUpdate update,
  AppUpdateService service,
) {
  return showGeneralDialog<void>(
    context: context,
    useRootNavigator: true,
    barrierDismissible: false,
    pageBuilder: (_, _, _) =>
        _MandatoryUpdateScreen(update: update, service: service),
  );
}

class _MandatoryUpdateScreen extends StatefulWidget {
  const _MandatoryUpdateScreen({required this.update, required this.service});

  final AvailableUpdate update;
  final AppUpdateService service;

  @override
  State<_MandatoryUpdateScreen> createState() => _MandatoryUpdateScreenState();
}

class _MandatoryUpdateScreenState extends State<_MandatoryUpdateScreen> {
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // Straight into Play's own update screen; this one is what is left if
    // the user backs out of it.
    WidgetsBinding.instance.addPostFrameCallback((_) => _update());
  }

  Future<void> _update() async {
    if (_busy) return;
    setState(() => _busy = true);
    final info = widget.update.play;
    try {
      if (info.installStatus == InstallStatus.downloaded) {
        await InAppUpdate.completeFlexibleUpdate();
      } else {
        await widget.service.updateNow(info);
      }
    } catch (_) {
      await widget.service.openPlayStore(info.packageName);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Material(
        color: Colors.white,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
            child: Column(
              children: [
                const Spacer(),
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.system_update_rounded,
                    size: 44,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Update Diperlukan',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.foreground,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.update.message ??
                      'Versi aplikasi kamu sudah tidak didukung. '
                          'Update dulu untuk melanjutkan.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.4,
                    color: AppColors.mutedForeground,
                  ),
                ),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton(
                    onPressed: _busy ? null : _update,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: _busy
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Update Sekarang',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
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
