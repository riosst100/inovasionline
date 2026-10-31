import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:location/location.dart' as loc;
import 'package:permission_handler/permission_handler.dart';

import 'delivery_service.dart';

/// Sends the driver's GPS position while parcels are on the way, for the buyer's tracking map
/// ("Lacak Pengiriman" in the customer app). Runs as an Android foreground service (sticky
/// notification), so it keeps going with the screen off. Started from the app while it is open, it
/// only needs the while-in-use location permission, not "Allow all the time".
class DeliveryTracker {
  DeliveryTracker(this._service);

  final DeliveryService _service;
  final _location = loc.Location();

  /// Never more often than this, however fast fixes arrive (the endpoint allows 30/min).
  static const _minGap = Duration(seconds: 15);

  StreamSubscription<loc.LocationData>? _sub;
  DateTime? _lastSent;
  bool _starting = false;

  bool get running => _sub != null;

  /// No-op when already running, or when location permission / GPS is missing: prompting happens on
  /// scan (`ensureLocationReady`), and the next parcel list refresh tries again.
  Future<void> start() async {
    if (running || _starting) return;
    _starting = true;
    try {
      if (!await Permission.locationWhenInUse.isGranted) return;
      if (!await Permission.locationWhenInUse.serviceStatus.isEnabled) return;

      await _location.changeNotificationOptions(
        channelName: 'Pengantaran',
        title: 'Sedang mengantar paket',
        subtitle: 'Lokasi dibagikan ke pembeli selama pengantaran',
        onTapBringToFront: true,
      );
      await _location.enableBackgroundMode(requireBackgroundPermission: false);
      await _location.changeSettings(accuracy: loc.LocationAccuracy.high, interval: 15000, distanceFilter: 25);

      _sub = _location.onLocationChanged.listen(_onFix, onError: (Object e) => debugPrint('Tracking error: $e'));
    } catch (e) {
      // e.g. Android refused the foreground service start; tracking just stays off.
      debugPrint('Tracking not started: $e');
    } finally {
      _starting = false;
    }
  }

  Future<void> stop() async {
    final sub = _sub;
    if (sub == null) return;
    _sub = null;
    _lastSent = null;
    await sub.cancel();
    try {
      await _location.enableBackgroundMode(enable: false);
    } catch (_) {}
  }

  void _onFix(loc.LocationData fix) {
    final now = DateTime.now();
    if (_lastSent != null && now.difference(_lastSent!) < _minGap) return;
    _lastSent = now;

    // Fire and forget: a lost ping is replaced by the next one, the buyer only needs the latest.
    _service.reportLocation(latitude: fix.latitude, longitude: fix.longitude, accuracy: fix.accuracy).catchError((Object e) {
      debugPrint('Location not sent: $e');
    });
  }
}
