import 'dart:math' as math;
import 'dart:async';
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
import '../../services/analytics.dart';
import '../../services/location_service.dart';
import '../../services/push_notification_handler.dart';
import '../../widgets/app_loading_skeleton.dart';
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
/// 3. Once a default address exists, location permission and GPS are never
///    asked for again. Only when both happen to be on already, the current
///    location is looked up quietly; if it is a different village, the user
///    picks between the default address and their current location.
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

  /// The system notification dialog has been shown once. It comes last, only
  /// for someone who is in the service area and about to enter the app.
  bool _notificationAsked = false;

  bool _askingNotification = false;
  bool _locationGranted = false;
  bool _locationPermanentlyDenied = false;

  /// No default address yet, so location permission/GPS is required.
  bool _locationNeeded = true;

  /// Notifications and location are both granted, so the app can proceed.
  bool _permissionsDone = false;
  bool _locatingStarted = false;
  bool _locatingDone = false;

  /// The location explanation screen has been passed: permission granted and
  /// GPS on (or no location needed at all).
  bool _locationStepDone = false;

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


  /// Completes once the logo + wordmark intro has finished playing, so the
  /// permission dialogs never pop up mid-animation.
  final _introPlayed = Completer<void>();

  /// The intro has faded out and is no longer built.
  bool _introGone = false;

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
    // Back from the background: learn whether the admin refreshed any cached data meanwhile.
    if (state == AppLifecycleState.resumed) {
      unawaited(ref.read(apiClientProvider).refreshCacheVersions());
    }
    // Catches the user granting a permission from system Settings and coming
    // back. This only re-reads the status: a system dialog closing also fires
    // "resumed", and re-asking here would stack a second Android dialog on top
    // of our own screen. Asking only ever happens from a button press.
    if (state == AppLifecycleState.resumed &&
        !_checking &&
        (!_permissionsDone || !_locationStepDone) &&
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

    // Location is only needed to pick the default address. Once one exists
    // the GPS is never touched again (the user changes it by hand instead).
    _locationNeeded = await _needsDefaultAddress();
    if (!mounted) return;

    // Location is not asked here: the explanation screen comes first, and its
    // button asks for permission and then switches GPS on.
    _locationStepDone = !_locationNeeded ||
        (_locationGranted && await LocationService.isServiceEnabled());

    if (!mounted) return;
    setState(() => _checking = false);
    _evaluate();
    if (!_locationStepDone) Analytics.locationIntroShown();

  }

  /// Waits for auth and the saved guest address to load, then reports whether
  /// there is still no default address.
  /// Waits for the session restore (/auth/user); meanwhile the loading screen
  /// shows, not the splash.
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
    setState(() => _permissionsDone = _notificationGranted);
  }

  /// Button on the location explanation screen: ask for permission if it is
  /// missing, then switch GPS on straight away.
  Future<void> _onEnableLocation() async {
    if (_locationPermanentlyDenied && !_locationGranted) {
      await openAppSettings();
      return;
    }
    Analytics.locationButtonTapped();
    setState(() => _requesting = true);
    if (!_locationGranted) {
      await _requestLocation();
      Analytics.locationPermission(
        granted: _locationGranted,
        permanent: _locationPermanentlyDenied,
      );
    }
    if (!mounted) return;
    if (_locationGranted) {
      final enabled = await _requestGps();
      Analytics.locationServiceResult(enabled: enabled);
      if (!mounted) return;
      // Declined GPS is handled later by the "Lokasi Belum Aktif" screen.
      setState(() => _locationStepDone = true);
    }
    setState(() => _requesting = false);
  }

  /// The one automatic system dialog; after that only the popup's button asks.
  Future<void> _askNotification() async {
    if (_notificationAsked) return;
    _notificationAsked = true;
    setState(() => _askingNotification = true);
    await _requestNotification();
    if (!mounted) return;
    setState(() => _askingNotification = false);
    _evaluate();
  }

  Future<void> _requestNotification() async {
    final status = await Permission.notification.request();
    if (status.isGranted) {
      // Registers for push on iOS; a no-op prompt-wise once granted.
      await firebaseReady.future;
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

    if (mounted) setState(() => _locatingText = 'Mengaktifkan lokasi...');
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
    if (ref.read(locationFailureProvider) == LocationFailure.outOfArea) {
      Analytics.outOfArea();
    }
    setState(() {
      _outOfArea = ref.read(locationFailureProvider) == LocationFailure.outOfArea;
      _locatingDone = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Always a Stack so the intro fading out never remounts what is beneath.
    // The intro never waits on the checks below it: whatever is still
    // pending once it has played shows as a loading screen instead.
    final introDone = _introPlayed.isCompleted;
    return Stack(
      fit: StackFit.expand,
      children: [
        _buildGate(context),
        if (!_introGone)
          IgnorePointer(
            ignoring: introDone,
            child: AnimatedOpacity(
              opacity: introDone ? 0 : 1,
              duration: const Duration(milliseconds: 250),
              onEnd: () {
                if (introDone) setState(() => _introGone = true);
              },
              child: _SplashIntro(
                onPlayed: () {
                  if (!mounted || _introPlayed.isCompleted) return;
                  setState(_introPlayed.complete);
                },
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildGate(BuildContext context) {
    // Nothing is built under the intro: building home (and its API calls /
    // images) underneath makes the animation stutter.
    if (!_introPlayed.isCompleted) {
      return const ColoredBox(color: _splashColor);
    }
    // Permission dialogs, the session restore and the address check: the app
    // shows as loading until it knows who the user is and where they are.
    if (_checking) return const AppLoadingSkeleton();

    if (!_locationStepDone) {
      return _LocationIntroScreen(
        busy: _requesting,
        permanentlyDenied: _locationPermanentlyDenied && !_locationGranted,
        onEnable: _onEnableLocation,
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
      // Still waiting on auth: looks like the app loading. The spinner with
      // a status line only shows once a location lookup really happens.
      final text = _locatingText;
      if (text == null) return const AppLoadingSkeleton();
      return _LocatingScreen(text: text);
    }

    // Not building the child at all keeps the router, and with it every home
    // page API call, from starting for someone we cannot serve.
    if (_outOfArea) {
      if (_pickingManually) {
        // Own Navigator: this gate sits above the app's router, and dropdown
        // menus need a Navigator to open into. The popup route is see-through,
        // so the loading skeleton sits behind it.
        return Stack(
          children: [
            const AppLoadingSkeleton(animated: false),
            Navigator(
              onGenerateRoute: (_) => manualAddressRoute(
                onBack: () => setState(() => _pickingManually = false),
                onSaved: () => setState(() {
                  _outOfArea = false;
                  _pickingManually = false;
                }),
              ),
            ),
          ],
        );
      }
      return _OutOfAreaScreen(
        onPickManually: () => setState(() => _pickingManually = true),
      );
    }

    // Last gate before the app: notifications. Out-of-area users never get
    // here. The system dialog goes first; the popup only shows once it was
    // refused.
    if (!_permissionsDone) {
      if (!_notificationAsked && !_notificationPermanentlyDenied ||
          _askingNotification) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _askNotification();
        });
        return const AppLoadingSkeleton();
      }
      return _PermissionScreen(
        notificationPermanentlyDenied: _notificationPermanentlyDenied,
        requesting: _requesting,
        onRequestNotification: _onNotificationAction,
      );
    }

    // Everything the app waits on at startup is settled once it is shown.
    if (!ref.read(startupSettledProvider)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) ref.read(startupSettledProvider.notifier).state = true;
      });
    }
    return widget.child;
  }
}

const _splashColor = Color(0xFF0F9B8E);

/// Just the logo out of the native splash image (logo_splash.png is a 1152px
/// canvas read as 4x, i.e. 288dp, by flutter_native_splash, with the logo
/// 64dp in the middle); small so it decodes quickly.
const _splashLogo = AssetImage('assets/images/logo_splash_mark.png');
const _splashLogoSize = 64.0;

/// Loads the splash logo into the image cache before [runApp], so the first
/// Flutter frame already shows it and swapping out the native splash (which
/// happens on that frame) does not flash an empty screen.
Future<void> precacheSplashLogo() {
  final done = Completer<void>();
  final stream = _splashLogo.resolve(ImageConfiguration.empty);
  late final ImageStreamListener listener;
  listener = ImageStreamListener(
    (_, _) {
      stream.removeListener(listener);
      if (!done.isCompleted) done.complete();
    },
    onError: (_, _) {
      stream.removeListener(listener);
      if (!done.isCompleted) done.complete();
    },
  );
  stream.addListener(listener);
  return done.future;
}

/// Picks up where the native splash (which cannot animate) leaves off: its
/// first frame is pixel-identical to the splash, then the logo slides left
/// while "Inovasi Online" unrolls out from behind it to the right. It then
/// stays like that as the backdrop for the system permission dialogs.
class _SplashIntro extends StatefulWidget {
  const _SplashIntro({required this.onPlayed});

  final VoidCallback onPlayed;

  @override
  State<_SplashIntro> createState() => _SplashIntroState();
}

class _SplashIntroState extends State<_SplashIntro>
    with SingleTickerProviderStateMixin {
  static const _gap = 8.0;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
  );
  late final Animation<double> _reveal = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeInOutCubic,
  );
  late final Animation<double> _fade = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.35, 1, curve: Curves.easeOut),
  );

  @override
  void initState() {
    super.initState();
    _play();
  }

  Future<void> _play() async {
    // The first frames are slow (engine warm-up, native splash going away);
    // starting before they are out would skip the start of the animation.
    await WidgetsBinding.instance.waitUntilFirstFrameRasterized;
    // A beat on the splash-identical frame so the hand-off is seamless.
    await Future<void>.delayed(const Duration(milliseconds: 100));
    if (!mounted) return;
    await _controller.forward();
    await Future<void>.delayed(const Duration(milliseconds: 250));
    if (mounted) widget.onPlayed();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _splashColor,
      child: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) => Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // The Row grows as the wordmark unrolls; Center keeps it
              // centred, which is what slides the logo to the left.
              const RepaintBoundary(
                child: Image(
                  image: _splashLogo,
                  width: _splashLogoSize,
                  height: _splashLogoSize,
                  gaplessPlayback: true,
                ),
              ),
              ClipRect(
                child: Align(
                  alignment: Alignment.centerLeft,
                  widthFactor: _reveal.value,
                  child: Padding(
                    padding: const EdgeInsets.only(left: _gap),
                    child: Transform.translate(
                      offset: Offset(-24 * (1 - _reveal.value), 0),
                      child: Opacity(
                        opacity: _fade.value,
                        child: const Text(
                          'INOVASI ONLINE',
                          maxLines: 1,
                          softWrap: false,
                          style: TextStyle(
                            color: Colors.white,
                            fontFamily: 'Montserrat',
                            fontSize: 19,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 3.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Notification permission, as the same popup card the location steps use.
/// Shown over the loading skeleton once the system dialog was refused.
class _PermissionScreen extends StatelessWidget {
  const _PermissionScreen({
    required this.notificationPermanentlyDenied,
    required this.requesting,
    required this.onRequestNotification,
  });

  final bool notificationPermanentlyDenied;
  final bool requesting;
  final VoidCallback onRequestNotification;

  @override
  Widget build(BuildContext context) {
    return _LocationPopup(
      icon: Icons.notifications_active_rounded,
      title: 'Izinkan Notifikasi',
      message: 'Izinkan notifikasi agar kamu tidak ketinggalan kabar status '
          'pesanan dan pesan chat.',
      buttonText: requesting
          ? 'Menunggu...'
          : notificationPermanentlyDenied
          ? 'Buka Pengaturan'
          : 'Izinkan Notifikasi',
      onPressed: requesting ? null : onRequestNotification,
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
  const _OutOfAreaScreen({required this.onPickManually});

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
                    onPressed: () => SystemNavigator.pop(),
                    icon: const Icon(Icons.logout_rounded),
                    label: const Text('Keluar Aplikasi'),
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

/// Explains why the app needs location before anything is asked of the user.
/// Non-dismissible card over the loading skeleton. The home page is not built behind it, so
/// no API calls start until location is on.
class _LocationPopup extends StatelessWidget {
  const _LocationPopup({
    required this.icon,
    required this.title,
    required this.message,
    required this.buttonText,
    required this.onPressed,
  });

  final IconData icon;
  final String title;
  final String message;
  final String buttonText;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Stack(
        children: [
          const AppLoadingSkeleton(animated: false),
          const ModalBarrier(dismissible: false, color: Colors.black54),
          _PopupShell(
            header: _PulsingLocationIcon(icon: icon),
            title: title,
            message: message,
            button: SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  elevation: 0,
                  shape: const StadiumBorder(),
                  textStyle: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                onPressed: onPressed,
                child: Text(buttonText),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Location icon with radar-style rings spreading out and the pin bobbing.
class _PulsingLocationIcon extends StatefulWidget {
  const _PulsingLocationIcon({required this.icon});

  final IconData icon;

  @override
  State<_PulsingLocationIcon> createState() => _PulsingLocationIconState();
}

class _PulsingLocationIconState extends State<_PulsingLocationIcon>
    with SingleTickerProviderStateMixin {
  static const _color = AppColors.primary;
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _ring(double t) {
    return Opacity(
      opacity: (1 - t) * 0.45,
      child: Container(
        width: 64 + 56 * t,
        height: 64 + 56 * t,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: _color, width: 2),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 120,
      height: 120,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final v = _controller.value;
          final bob = -6 * (0.5 - (v * 2 % 1 - 0.5).abs()) * 2;
          return Stack(
            alignment: Alignment.center,
            children: [
              _ring(v),
              _ring((v + 0.5) % 1),
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: _color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
              ),
              Transform.translate(
                offset: Offset(0, bob),
                child: Icon(widget.icon, size: 34, color: _color),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _LocationIntroScreen extends StatelessWidget {
  const _LocationIntroScreen({
    required this.onEnable,
    required this.busy,
    required this.permanentlyDenied,
  });

  final VoidCallback onEnable;
  final bool busy;
  final bool permanentlyDenied;

  @override
  Widget build(BuildContext context) {
    return _LocationPopup(
      icon: Icons.location_on_rounded,
      title: 'Aktifkan Lokasi',
      message: 'Izinkan akses lokasi agar kami bisa menampilkan produk '
          'yang sesuai dengan tempatmu.',
      buttonText: busy
          ? 'Menunggu...'
          : permanentlyDenied
          ? 'Buka Pengaturan'
          : 'Aktifkan Lokasi',
      onPressed: busy ? null : onEnable,
    );
  }
}

class _GpsOffScreen extends StatelessWidget {
  const _GpsOffScreen({required this.onEnable, required this.busy});

  final VoidCallback onEnable;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return _LocationPopup(
      icon: Icons.location_off_rounded,
      title: 'Lokasi Belum Aktif',
      message: 'Aktifkan GPS di HP-mu untuk menentukan alamat pengiriman. '
          'Kami akan lanjut otomatis begitu lokasi aktif.',
      buttonText: busy ? 'Mengaktifkan lokasi...' : 'Aktifkan Lokasi',
      onPressed: busy ? null : onEnable,
    );
  }
}

/// Rounded card shared by the location popups: tinted header with an
/// animation, then title, message and an optional button.
class _PopupShell extends StatelessWidget {
  const _PopupShell({
    required this.header,
    required this.title,
    required this.message,
    this.button,
  });

  final Widget header;
  final String title;
  final String message;
  final Widget? button;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 32,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: Material(
                color: Colors.white,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            AppColors.primary.withValues(alpha: 0.14),
                            AppColors.primary.withValues(alpha: 0.02),
                          ],
                        ),
                      ),
                      child: Center(child: RepaintBoundary(child: header)),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            title,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: AppColors.foreground,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            message,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: AppColors.mutedForeground,
                              height: 1.5,
                              fontSize: 13.5,
                            ),
                          ),
                          if (button != null) ...[
                            const SizedBox(height: 22),
                            button!,
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Sonar-style search: a radar arm sweeping over rings while the pin hops,
/// for the "finding your location" step.
class _RadarLocatingIcon extends StatefulWidget {
  const _RadarLocatingIcon();

  @override
  State<_RadarLocatingIcon> createState() => _RadarLocatingIconState();
}

class _RadarLocatingIconState extends State<_RadarLocatingIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 120,
      height: 120,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final v = _controller.value;
          // The pin hops during the first half of the loop, then rests.
          final hop = v < 0.5 ? (1 - (v * 4 - 1).abs()) : 0.0;
          return Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: const Size(120, 120),
                painter: _RadarPainter(v * 2 * math.pi),
              ),
              Transform.translate(
                offset: Offset(0, -10 * hop),
                child: const Icon(
                  Icons.location_on_rounded,
                  size: 34,
                  color: AppColors.primary,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _RadarPainter extends CustomPainter {
  _RadarPainter(this.angle);

  final double angle;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = AppColors.primary.withValues(alpha: 0.25);
    for (final f in [0.35, 0.65, 1.0]) {
      canvas.drawCircle(c, r * f - 1, ring);
    }
    final rect = Rect.fromCircle(center: c, radius: r - 1);
    final sweep = Paint()
      ..shader = SweepGradient(
        startAngle: 0,
        endAngle: math.pi / 2,
        colors: [
          AppColors.primary.withValues(alpha: 0),
          AppColors.primary.withValues(alpha: 0.4),
        ],
        transform: GradientRotation(angle - math.pi / 2),
      ).createShader(rect);
    canvas.drawCircle(c, r - 1, sweep);
  }

  @override
  bool shouldRepaint(_RadarPainter old) => old.angle != angle;
}

class _LocatingScreen extends StatelessWidget {
  const _LocatingScreen({required this.text});

  final String? text;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Stack(
        children: [
          const AppLoadingSkeleton(animated: false),
          const ModalBarrier(dismissible: false, color: Colors.black54),
          _PopupShell(
            header: const _RadarLocatingIcon(),
            title: text ?? 'Menentukan lokasi...',
            message: 'Sebentar ya, kami sedang mencari posisimu untuk '
                'mengatur alamat pengiriman.',
          ),
        ],
      ),
    );
  }
}
