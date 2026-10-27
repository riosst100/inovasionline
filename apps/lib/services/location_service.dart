import 'package:geolocator/geolocator.dart';

class LocationResult {
  const LocationResult({this.position, this.serviceDisabled = false});

  final Position? position;

  /// Device location (GPS) is switched off and the user did not turn it on.
  final bool serviceDisabled;
}

class LocationService {
  static Future<bool> isServiceEnabled() => Geolocator.isLocationServiceEnabled();

  /// Asks the user to switch GPS on. On Android this shows Google's one-tap
  /// "turn on device location" dialog (apps cannot switch GPS on silently);
  /// elsewhere it just reports the current state. Returns whether GPS is on.
  static Future<bool> requestEnableService() async {
    try {
      if (await Geolocator.isLocationServiceEnabled()) return true;
      // With GPS off, Geolocator's Android implementation shows Google's resolution dialog
      // itself; declining it throws LocationServiceDisabledException.
      await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 10),
        ),
      );
    } on LocationServiceDisabledException {
      return false;
    } catch (_) {
      return await Geolocator.isLocationServiceEnabled();
    }

    // The user said yes, but Android flips the GPS switch a moment later and
    // the status can still read "off" right after the dialog closes. Give it
    // a few seconds to settle instead of reporting a false "GPS is off".
    for (var i = 0; i < 20; i++) {
      if (await Geolocator.isLocationServiceEnabled()) return true;
      await Future<void>.delayed(const Duration(milliseconds: 300));
    }
    return Geolocator.isLocationServiceEnabled();
  }

  /// Opens the system location settings so the user can switch GPS on.
  static Future<bool> openSettings() => Geolocator.openLocationSettings();

  /// The position the OS already has cached: instant, and never prompts or
  /// shows a dialog. Null without permission or when there is none.
  static Future<Position?> lastKnownPosition() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }
      return await Geolocator.getLastKnownPosition();
    } catch (_) {
      return null;
    }
  }

  /// Current device position. Never prompts for permission (PermissionGate
  /// owns that), but when GPS is off, Android shows its own "turn on device
  /// location" dialog from here; [LocationResult.serviceDisabled] is set if
  /// the user declines it.
  static Future<LocationResult> currentPosition() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return const LocationResult();
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 15),
        ),
      );
      return LocationResult(position: position);
    } on LocationServiceDisabledException {
      return const LocationResult(serviceDisabled: true);
    } catch (_) {
      // No fix in time or another failure; GPS may still be off.
      final enabled = await Geolocator.isLocationServiceEnabled();
      return LocationResult(serviceDisabled: !enabled);
    }
  }
}
