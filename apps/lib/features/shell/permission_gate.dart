import 'dart:io';

import 'package:android_intent_plus/android_intent.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/core_providers.dart';
import '../../providers/delivery_address_provider.dart';
import '../../services/location_service.dart';
import 'manual_address_screen.dart';

/// First thing that happens once the native splash is gone.
///
/// 1. Fires the system dialogs for notification and location permission right
///    away, over a backdrop that looks like the splash. Both are required:
///    push carries order updates and chat messages the user cannot otherwise
///    be reached for, and location sets the default delivery address. If
///    either is refused a blocking screen offers a retry / Settings.
/// 2. If the signed-in user has no address yet and location is allowed, shows
///    a loading screen while the current location is turned into the default
///    address.
class PermissionGate extends ConsumerStatefulWidget {
  const PermissionGate({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<PermissionGate> createState() => _PermissionGateState();
}

class _PermissionGateState extends ConsumerState<PermissionGate>
    with WidgetsBindingObserver {
  static const _maxLocateAttempts = 3;

  bool _checking = true;
  bool _requesting = false;

  bool _notificationGranted = false;
  bool _notificationPermanentlyDenied = false;
  bool _locationGranted = false;
  bool _locationPermanentlyDenied = false;

  /// No default address yet, so location permission/GPS is required.
  bool _locationNeeded = true;

  /// Notifications and location are both granted, so the app can proceed.
  bool _permissionsDone = false;
  bool _locatingStarted = false;
  bool _locatingDone = false;

  /// Status line for the loading screen; null while we do not yet know that a
  /// lookup will really happen (so nothing is shown when there is none).
  String? _locatingText;

  /// The enable-GPS dialog / switch is in progress; keeps the screen from
  /// flashing "GPS off" while Android is still turning it on.
  bool _enablingGps = false;

  /// GPS is off; the user has to switch it on before we locate.
  bool _gpsOff = false;

  /// The location resolved fine but is outside the service area, so the app
  /// shows a notice instead of the home page (and never fetches its data).
  bool _outOfArea = false;

  /// The user chose to pick a served area by hand from the out-of-area screen.
  bool _pickingManually = false;

  bool get _isMobile => Platform.isAndroid || Platform.isIOS;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _start();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Catches the user granting a permission from system Settings and coming
    // back. This only re-reads the status: a system dialog closing also fires
    // "resumed", and re-asking here would stack a second Android dialog on top
    // of our own screen. Asking only ever happens from a button press.
    if (state == AppLifecycleState.resumed &&
        !_checking &&
        !_permissionsDone &&
        !_requesting) {
      _syncStatuses();
    }
  }

  /// Straight after the splash: fire the system permission dialogs one after
  /// the other. The blocking screen only appears if notifications get refused.
  Future<void> _start() async {
    if (!_isMobile) {
      setState(() {
        _checking = false;
        _notificationGranted = true;
        _permissionsDone = true;
        _locatingDone = true;
      });
      return;
    }
    await _proceed();
  }

  Future<void> _readStatuses() async {
    final notification = await Permission.notification.status;
    final location = await Permission.locationWhenInUse.status;
    if (!mounted) return;
    setState(() {
      _notificationGranted = notification.isGranted;
      _notificationPermanentlyDenied = notification.isPermanentlyDenied;
      _locationGranted = location.isGranted;
      _locationPermanentlyDenied = location.isPermanentlyDenied;
    });
  }

  /// Cold start only: asks for whatever is still missing, one system dialog
  /// after the other. Anything refused here is then asked again only when the
  /// user presses a button on the blocking screen.
  Future<void> _proceed() async {
    await _readStatuses();
    if (!mounted) return;

    if (!_notificationGranted && !_notificationPermanentlyDenied) {
      await _requestNotification();
    }

    // Location is only needed to pick the default address. Once one exists
    // the GPS is never touched again (the user changes it by hand instead).
    _locationNeeded = await _needsDefaultAddress();
    if (!mounted) return;

    if (_locationNeeded && !_locationGranted && !_locationPermanentlyDenied) {
      await _requestLocation();
    }

    if (!mounted) return;
    setState(() => _checking = false);
    _evaluate();
  }

  /// Waits for auth and the saved guest address to load, then reports whether
  /// there is still no default address.
  Future<bool> _needsDefaultAddress() async {
    while (mounted && ref.read(authProvider).status == AuthStatus.unknown) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    if (!mounted) return false;
    final auth = ref.read(authProvider);
    final user = auth.user;
    if (auth.status == AuthStatus.authenticated && user != null) {
      return !user.hasAddress;
    }
    await ref.read(guestAddressProvider.notifier).ready;
    return ref.read(guestAddressProvider) == null;
  }

  /// Re-reads the permission status without prompting.
  Future<void> _syncStatuses() async {
    await _readStatuses();
    if (mounted) _evaluate();
  }

  void _evaluate() {
    setState(() => _permissionsDone =
        _notificationGranted && (_locationGranted || !_locationNeeded));
  }

  Future<void> _requestNotification() async {
    final status = await Permission.notification.request();
    if (status.isGranted) {
      // Registers for push on iOS; a no-op prompt-wise once granted.
      await FirebaseMessaging.instance.requestPermission();
    }
    if (!mounted) return;
    setState(() {
      _notificationGranted = status.isGranted;
      _notificationPermanentlyDenied = status.isPermanentlyDenied;
    });
  }

  Future<void> _requestLocation() async {
    final status = await Permission.locationWhenInUse.request();
    if (!mounted) return;
    setState(() {
      _locationGranted = status.isGranted;
      _locationPermanentlyDenied = status.isPermanentlyDenied;
    });
  }

  /// Blocking screen button: re-ask, or open Settings for whatever the OS
  /// will no longer show a dialog for.
  Future<void> _onNotificationAction() async {
    if (_notificationPermanentlyDenied) {
      await _openNotificationSettings();
      return;
    }
    setState(() => _requesting = true);
    await _requestNotification();
    if (!mounted) return;
    setState(() => _requesting = false);
    _evaluate();
  }

  Future<void> _onLocationAction() async {
    if (_locationPermanentlyDenied) {
      await openAppSettings();
      return;
    }
    setState(() => _requesting = true);
    await _requestLocation();
    if (!mounted) return;
    setState(() => _requesting = false);
    _evaluate();
  }

  /// Primary button: the first permission that is still missing.
  Future<void> _onPrimaryAction() =>
      !_notificationGranted ? _onNotificationAction() : _onLocationAction();

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

  /// Does not return until GPS is on: first the one-tap system dialog, then
  /// a screen that keeps checking while the user enables it in Settings.
  Future<void> _ensureGpsOn() async {
    if (await LocationService.isServiceEnabled()) return;

    if (mounted) setState(() => _locatingText = 'Menyalakan GPS...');
    final enabled = await _requestGps();
    if (enabled || !mounted) return;

    setState(() => _gpsOff = true);
    while (mounted && !await LocationService.isServiceEnabled()) {
      await Future<void>.delayed(const Duration(milliseconds: 700));
    }
    if (mounted) setState(() => _gpsOff = false);
  }

  Future<bool> _requestGps() async {
    if (mounted) setState(() => _enablingGps = true);
    final enabled = await LocationService.requestEnableService();
    if (mounted) setState(() => _enablingGps = false);
    return enabled;
  }

  /// Waits for auth to settle, then (only if there is something to do) turns
  /// the current location into the default address.
  Future<void> _runLocating() async {
    _locatingStarted = true;

    Future<void> work() async {
      // Auth restores asynchronously; wait until we know who the user is.
      while (mounted && ref.read(authProvider).status == AuthStatus.unknown) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
      if (!mounted) return;
      final auth = ref.read(authProvider);
      final user = auth.user;

      final signedIn = auth.status == AuthStatus.authenticated && user != null;
      final needsAddress = signedIn
          ? !user.hasAddress
          : ref.read(guestAddressProvider) == null;
      if (!needsAddress) return;

      // GPS first: Android pops its "turn on location" dialog from here; if
      // the user declines, wait on a screen until they enable it.
      await _ensureGpsOn();
      if (!mounted) return;

      // A GPS that was only just switched on can take a moment to get a fix,
      // so retry a few times before giving up on "no position" (definite
      // answers like out-of-area are not retried).
      for (var attempt = 0; attempt < _maxLocateAttempts && mounted; attempt++) {
        setState(() => _locatingText = 'Menentukan lokasi kamu...');
        final done = await (signedIn
            ? ref.read(authProvider.notifier).setDefaultAddressFromLocation()
            : ref.read(guestAddressProvider.notifier).setDefaultFromLocation());
        if (done) return;
        if (ref.read(locationFailureProvider) != LocationFailure.noFix &&
            ref.read(locationFailureProvider) != LocationFailure.serviceOff) {
          return;
        }
        await _ensureGpsOn();
      }
    }

    try {
      await work();
    } catch (_) {
      // Failed: carry on, the user can still pick an address by hand.
    }

    if (!mounted) return;
    setState(() {
      _outOfArea = ref.read(locationFailureProvider) == LocationFailure.outOfArea;
      _locatingDone = true;
    });
  }

  void _retryLocating() {
    ref.read(locationFailureProvider.notifier).state = null;
    setState(() {
      _outOfArea = false;
      _pickingManually = false;
      _locatingDone = false;
      _locatingStarted = false;
      _locatingText = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) return const _SplashBackdrop();

    if (!_permissionsDone) {
      return _PermissionScreen(
        notificationGranted: _notificationGranted,
        notificationPermanentlyDenied: _notificationPermanentlyDenied,
        locationGranted: _locationGranted,
        locationPermanentlyDenied: _locationPermanentlyDenied,
        requesting: _requesting,
        onPrimary: _onPrimaryAction,
        onRequestNotification: _onNotificationAction,
        onRequestLocation: _onLocationAction,
      );
    }

    if (!_locatingDone) {
      if (_gpsOff) {
        return _GpsOffScreen(
          busy: _enablingGps,
          onEnable: () async {
            if (!await _requestGps()) await LocationService.openSettings();
          },
        );
      }
      if (!_locatingStarted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _runLocating();
        });
      }
      return _LocatingScreen(text: _locatingText);
    }

    // Not building the child at all keeps the router, and with it every home
    // page API call, from starting for someone we cannot serve.
    if (_outOfArea) {
      if (_pickingManually) {
        // Own Navigator: this gate sits above the app's router, and dropdown
        // menus need a Navigator to open into.
        return Navigator(
          onGenerateRoute: (_) => MaterialPageRoute<void>(
            builder: (_) => ManualAddressScreen(
              onBack: () => setState(() => _pickingManually = false),
              onSaved: () => setState(() {
                _outOfArea = false;
                _pickingManually = false;
              }),
            ),
          ),
        );
      }
      return _OutOfAreaScreen(
        onRetry: _retryLocating,
        onPickManually: () => setState(() => _pickingManually = true),
      );
    }

    return widget.child;
  }
}

/// Mirrors the native splash (same colour and logo) so the system permission
/// dialogs appear to pop up over the splash itself.
class _SplashBackdrop extends StatelessWidget {
  const _SplashBackdrop();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F9B8E),
      body: Center(
        child: Image.asset(
          'assets/images/logo_splash.png',
          width: 160,
          errorBuilder: (_, _, _) => const SizedBox.shrink(),
        ),
      ),
    );
  }
}

class _PermissionScreen extends StatelessWidget {
  const _PermissionScreen({
    required this.notificationGranted,
    required this.notificationPermanentlyDenied,
    required this.locationGranted,
    required this.locationPermanentlyDenied,
    required this.requesting,
    required this.onPrimary,
    required this.onRequestNotification,
    required this.onRequestLocation,
  });

  final bool notificationGranted;
  final bool notificationPermanentlyDenied;
  final bool locationGranted;
  final bool locationPermanentlyDenied;
  final bool requesting;
  final VoidCallback onPrimary;
  final VoidCallback onRequestNotification;
  final VoidCallback onRequestLocation;

  @override
  Widget build(BuildContext context) {
    final missingNotification = !notificationGranted;
    final blockedForever = missingNotification
        ? notificationPermanentlyDenied
        : locationPermanentlyDenied;
    final primaryLabel = requesting
        ? 'Menunggu...'
        : blockedForever
        ? 'Buka Pengaturan'
        : missingNotification
        ? 'Izinkan Notifikasi'
        : 'Izinkan Lokasi';

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        Container(
                          width: 88,
                          height: 88,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.verified_user_rounded,
                            size: 44,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Izin Dibutuhkan',
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Izinkan notifikasi dan lokasi untuk melanjutkan.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.mutedForeground),
                        ),
                        const SizedBox(height: 28),
                        _PermissionTile(
                          icon: Icons.notifications_active_rounded,
                          color: const Color(0xFFF59E0B),
                          title: 'Notifikasi',
                          description:
                              'Kabar status pesanan dan pesan chat kamu.',
                          badge: 'Wajib',
                          granted: notificationGranted,
                          actionLabel: notificationPermanentlyDenied
                              ? 'Pengaturan'
                              : 'Izinkan',
                          onAction: requesting ? null : onRequestNotification,
                        ),
                        const SizedBox(height: 12),
                        _PermissionTile(
                          icon: Icons.location_on_rounded,
                          color: const Color(0xFF0284C7),
                          title: 'Lokasi',
                          description:
                              'Mengatur alamat pengiriman awal sesuai posisi kamu.',
                          badge: 'Wajib',
                          granted: locationGranted,
                          actionLabel: locationPermanentlyDenied
                              ? 'Pengaturan'
                              : 'Izinkan',
                          onAction: requesting ? null : onRequestLocation,
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton(
                    onPressed: requesting ? null : onPrimary,
                    child: Text(primaryLabel),
                  ),
                ),
                const SizedBox(height: 4),
                TextButton(
                  onPressed: () => SystemNavigator.pop(),
                  child: const Text('Keluar Aplikasi'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PermissionTile extends StatelessWidget {
  const _PermissionTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.description,
    required this.badge,
    required this.granted,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String description;
  final String badge;
  final bool granted;
  final String actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: granted ? const Color(0xFFF0FDF4) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: granted ? const Color(0xFFBBF7D0) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.foreground,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 1.5,
                      ),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        badge,
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          color: color,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.mutedForeground,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (granted)
            const Icon(
              Icons.check_circle_rounded,
              color: Color(0xFF22C55E),
              size: 26,
            )
          else
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                foregroundColor: AppColors.primary,
              ),
              child: Text(
                actionLabel,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
        ],
      ),
    );
  }
}

/// Names of the cities the app currently serves (Pengaturan > Cakupan Kota).
final _servedCitiesProvider = FutureProvider.autoDispose<List<String>>((ref) async {
  final regions = ref.read(regionServiceProvider);
  final provinces = await regions.provinces();
  final cities = await Future.wait(provinces.map((p) => regions.cities(p.code)));
  return cities
      .expand((list) => list)
      .map((city) => _titleCase(city.name))
      .toList()
    ..sort();
});

String _titleCase(String value) => value
    .toLowerCase()
    .split(' ')
    .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
    .join(' ');

class _OutOfAreaScreen extends ConsumerWidget {
  const _OutOfAreaScreen({required this.onRetry, required this.onPickManually});

  final VoidCallback onRetry;
  final VoidCallback onPickManually;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cities = ref.watch(_servedCitiesProvider);

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.wrong_location_rounded,
                    size: 48,
                    color: Color(0xFFEF4444),
                  ),
                ),
                const SizedBox(height: 22),
                Text(
                  'Di Luar Jangkauan Area Layanan',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Maaf, lokasi kamu saat ini belum terjangkau layanan '
                  'Inovasi Online. Kamu bisa memilih alamat di wilayah yang '
                  'sudah terjangkau.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.mutedForeground, height: 1.4),
                ),
                const SizedBox(height: 22),
                cities.maybeWhen(
                  data: (names) => names.isEmpty
                      ? const SizedBox.shrink()
                      : Column(
                          children: [
                            const Text(
                              'Area yang sudah terjangkau',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                                color: AppColors.foreground,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              alignment: WrapAlignment.center,
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (final name in names)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary
                                          .withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.location_on_rounded,
                                          size: 14,
                                          color: AppColors.primary,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          name,
                                          style: const TextStyle(
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.primary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                  orElse: () => const SizedBox.shrink(),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton.icon(
                    onPressed: onPickManually,
                    icon: const Icon(Icons.edit_location_alt_rounded),
                    label: const Text('Pilih Alamat Manual'),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Coba Lagi'),
                  ),
                ),
                const SizedBox(height: 4),
                TextButton(
                  onPressed: () => SystemNavigator.pop(),
                  child: const Text('Keluar Aplikasi'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GpsOffScreen extends StatelessWidget {
  const _GpsOffScreen({required this.onEnable, required this.busy});

  final VoidCallback onEnable;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0284C7).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.location_off_rounded,
                    size: 44,
                    color: Color(0xFF0284C7),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'GPS Belum Aktif',
                  style: Theme.of(context).textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Nyalakan GPS di HP kamu untuk menentukan alamat pengiriman. '
                  'Aplikasi akan lanjut otomatis setelah GPS aktif.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.mutedForeground),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton(
                    onPressed: busy ? null : onEnable,
                    child: Text(busy ? 'Menyalakan GPS...' : 'Aktifkan GPS'),
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

class _LocatingScreen extends StatelessWidget {
  const _LocatingScreen({required this.text});

  final String? text;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 44,
                height: 44,
                child: CircularProgressIndicator(strokeWidth: 3.5),
              ),
              if (text != null) ...[
                const SizedBox(height: 22),
                Text(
                  text!,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.foreground,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Untuk mengatur alamat pengiriman',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: AppColors.mutedForeground,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
