import 'package:flutter/material.dart';
import 'package:location/location.dart' as loc;
import 'package:permission_handler/permission_handler.dart';

/// Asked once right after the splash, so scanning and proof photos never stop for a camera
/// prompt. Already granted or permanently denied permissions do not show a dialog again.
/// The GPS switch is deliberately not asked here; that only happens on each scan.
Future<void> requestStartupPermissions() async {
  await [Permission.camera, Permission.locationWhenInUse].request();
}

/// Every scan and every delivery confirmation needs location permission and GPS switched on.
/// Returns true when both are fine; otherwise explains what is missing and returns false.
Future<bool> ensureLocationReady(BuildContext context) async {
  while (true) {
    var status = await Permission.locationWhenInUse.status;
    if (!status.isGranted) status = await Permission.locationWhenInUse.request();
    final gpsOn = status.isGranted && await _requestGps();
    if (gpsOn) return true;
    if (!context.mounted) return false;

    final blocked = status.isPermanentlyDenied || status.isRestricted;
    final retry = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.location_off_outlined),
        title: Text(status.isGranted ? 'GPS belum aktif' : 'Izin lokasi dibutuhkan'),
        content: Text(
          status.isGranted
              ? 'Nyalakan GPS (Lokasi) di HP untuk scan dan mengantar pesanan.'
              : blocked
              ? 'Izin lokasi ditolak. Buka pengaturan aplikasi lalu izinkan Lokasi.'
              : 'Aplikasi butuh izin lokasi untuk scan dan mengantar pesanan.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Batal')),
          if (blocked)
            TextButton(
              onPressed: () {
                openAppSettings();
                Navigator.of(context).pop(true);
              },
              child: const Text('Buka pengaturan'),
            ),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Coba lagi')),
        ],
      ),
    );
    if (retry != true || !context.mounted) return false;
  }
}

/// Same as apps/ LocationService.requestEnableService: when GPS is off, Android shows Google's
/// one-tap "turn on device location" popup (apps cannot switch it on silently). Returns whether
/// GPS is on afterwards.
Future<bool> _requestGps() async {
  Future<bool> isOn() => Permission.locationWhenInUse.serviceStatus.isEnabled;
  try {
    if (await isOn()) return true;
    if (!await loc.Location().requestService()) return await isOn();
  } catch (_) {
    return await isOn();
  }

  // Accepted, but Android flips the switch a moment later; let it settle before reporting "off".
  for (var i = 0; i < 20; i++) {
    if (await isOn()) return true;
    await Future<void>.delayed(const Duration(milliseconds: 300));
  }
  return isOn();
}
