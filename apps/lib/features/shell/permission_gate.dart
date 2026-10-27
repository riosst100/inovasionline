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
import '../../models/nearest_address.dart';
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

  /// Where the device is now, when that differs from the default address;
  /// offered as an alternative over the app.
  NearestAddress? _currentLocation;
  bool _applyingCurrentLocation = false;

  /// The quiet current-location lookup has finished (or is not going to
  /// happen), so no choice will pop up over the app any more.
  bool _locationSuggestionDone = false;

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
        _locationSuggestionDone = true;
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

    // The checks run alongside the intro; only the system dialogs wait for it
    // so they never pop up mid-animation.
    if (!_notificationGranted && !_notificationPermanentlyDenied) {
      await _introPlayed.future;
      if (!mounted) return;
      await _requestNotification();
    }

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

    if (_locationNeeded) {
      _locationSuggestionDone = true;
    } else {
      _offerCurrentLocation();
    }
  }

  /// A default address exists, so nothing is prompted here: only when
  /// location is already allowed and GPS already on, look up where the device
  /// is and offer it if that is somewhere else.
  Future<void> _offerCurrentLocation() async {
    try {
      if (!_locationGranted || !await LocationService.isServiceEnabled()) {
        return;
      }
      final result = await ref.read(deliveryAddressActionsProvider).locate();
      final found = result.address;
      if (!mounted || found == null) return;
      final current = ref.read(deliveryAddressProvider);
      if (current == null || current.villageCode == found.villageCode) return;
      setState(() => _currentLocation = found);
    } catch (_) {
      // Purely a suggestion; the default address stays in place.
    } finally {
      if (mounted) setState(() => _locationSuggestionDone = true);
    }
  }

  Future<void> _useCurrentLocation() async {
    final found = _currentLocation;
    if (found == null) return;
    setState(() => _applyingCurrentLocation = true);
    final saved = await ref.read(deliveryAddressActionsProvider).apply(found);
    if (!mounted) return;
    setState(() {
      _applyingCurrentLocation = false;
      _currentLocation = null;
    });
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        content: Text(
          saved
              ? 'Alamat pengiriman diatur sesuai lokasi kamu.'
              : 'Gagal menyimpan alamat, alamat utama tetap dipakai.',
        ),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
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

    if (mounted) setState(() => _locatingText = 'Menyalakan lokasi...');
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

    if (!_permissionsDone) {
      return _PermissionScreen(
        notificationGranted: _notificationGranted,
        notificationPermanentlyDenied: _notificationPermanentlyDenied,
        requesting: _requesting,
        onRequestNotification: _onNotificationAction,
      );
    }

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

    // Always a Stack so showing / hiding the choice never remounts the app.
    final current = ref.watch(deliveryAddressProvider);
    final found = _currentLocation;
    if (_locationSuggestionDone &&
        (found == null || current == null) &&
        !ref.read(startupSettledProvider)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) ref.read(startupSettledProvider.notifier).state = true;
      });
    }
    return Stack(
      children: [
        widget.child,
        if (found != null && current != null)
          _LocationChoiceOverlay(
            defaultAddress: current,
            currentLocation: found,
            busy: _applyingCurrentLocation,
            onUseCurrent: _useCurrentLocation,
            onKeepDefault: () => setState(() => _currentLocation = null),
          ),
      ],
    );
  }
}

/// Default address vs. current location, shown over the app. Drawn without
/// a route: this gate sits above the app's Navigator.
class _LocationChoiceOverlay extends StatelessWidget {
  const _LocationChoiceOverlay({
    required this.defaultAddress,
    required this.currentLocation,
    required this.busy,
    required this.onUseCurrent,
    required this.onKeepDefault,
  });

  final NearestAddress defaultAddress;
  final NearestAddress currentLocation;
  final bool busy;
  final VoidCallback onUseCurrent;
  final VoidCallback onKeepDefault;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Material(
        color: Colors.black54,
        child: SafeArea(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Mau dikirim ke mana?',
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      color: AppColors.foreground,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Lokasi kamu sekarang berbeda dari alamat utama.',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: AppColors.mutedForeground,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _ChoiceOption(
                    icon: Icons.my_location_rounded,
                    title: 'Pakai lokasi saya',
                    label: currentLocation.label,
                    onTap: busy ? null : onUseCurrent,
                    busy: busy,
                  ),
                  const SizedBox(height: 10),
                  _ChoiceOption(
                    icon: Icons.home_rounded,
                    title: 'Pakai alamat utama',
                    label: defaultAddress.label,
                    onTap: busy ? null : onKeepDefault,
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Kamu tetap bisa ganti alamat kapan saja dari bagian '
                    '"Dikirim ke" di beranda.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.mutedForeground,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ChoiceOption extends StatelessWidget {
  const _ChoiceOption({
    required this.icon,
    required this.title,
    required this.label,
    required this.onTap,
    this.busy = false,
  });

  final IconData icon;
  final String title;
  final String label;
  final VoidCallback? onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF8FAFC),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: busy
                    ? const Padding(
                        padding: EdgeInsets.all(10),
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      )
                    : Icon(icon, color: AppColors.primary, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.foreground,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.mutedForeground,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.mutedForeground,
              ),
            ],
          ),
        ),
      ),
    );
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

class _PermissionScreen extends StatelessWidget {
  const _PermissionScreen({
    required this.notificationGranted,
    required this.notificationPermanentlyDenied,
    required this.requesting,
    required this.onRequestNotification,
  });

  final bool notificationGranted;
  final bool notificationPermanentlyDenied;
  final bool requesting;
  final VoidCallback onRequestNotification;

  @override
  Widget build(BuildContext context) {
    final primaryLabel = requesting
        ? 'Menunggu...'
        : notificationPermanentlyDenied
        ? 'Buka Pengaturan'
        : 'Izinkan Notifikasi';

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
                          'Izinkan notifikasi untuk melanjutkan.',
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
                      ],
                    ),
                  ),
                ),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton(
                    onPressed: requesting ? null : onRequestNotification,
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

/// Explains why the app needs location before anything is asked of the user.
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
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Expanded(
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
                          Icons.location_on_rounded,
                          size: 44,
                          color: Color(0xFF0284C7),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Nyalakan Lokasi',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Aplikasi perlu menyalakan lokasi untuk menentukan posisi '
                        'kamu, agar katalog produk dan pengiriman sesuai '
                        'dengan tempat kamu berada.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.mutedForeground,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton(
                    onPressed: busy ? null : onEnable,
                    child: Text(
                      busy
                          ? 'Menunggu...'
                          : permanentlyDenied
                          ? 'Buka Pengaturan'
                          : 'Nyalakan Lokasi',
                    ),
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
                  'Lokasi Belum Aktif',
                  style: Theme.of(context).textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Nyalakan lokasi di HP kamu untuk menentukan alamat pengiriman. '
                  'Aplikasi akan lanjut otomatis setelah lokasi aktif.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.mutedForeground),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton(
                    onPressed: busy ? null : onEnable,
                    child: Text(busy ? 'Menyalakan lokasi...' : 'Nyalakan Lokasi'),
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
