import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../config/theme.dart';
import '../../models/order_tracking.dart';
import 'tracking_map.dart';

/// [TrackingMap] on Google Maps. Not used by default (`MAP_PROVIDER=google` turns it on): the Google
/// Cloud account needs a one-time prepayment, and the key goes in gradle.properties / Info.plist.
class GoogleTrackingMap extends StatefulWidget {
  const GoogleTrackingMap({
    super.key,
    required this.tracking,
    required this.follow,
    required this.onUserMoved,
    required this.fitRequest,
  });

  final OrderTracking tracking;
  final bool follow;
  final VoidCallback onUserMoved;
  final int fitRequest;

  @override
  State<GoogleTrackingMap> createState() => _GoogleTrackingMapState();
}

class _GoogleTrackingMapState extends State<GoogleTrackingMap> {
  GoogleMapController? _map;

  /// Set while the camera moves on our own command, so that move doesn't count as the buyer panning.
  bool _animating = false;

  @override
  void didUpdateWidget(GoogleTrackingMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.fitRequest != oldWidget.fitRequest || widget.follow) _frame();
  }

  @override
  void dispose() {
    _map?.dispose();
    super.dispose();
  }

  void _frame() {
    final map = _map;
    if (map == null) return;
    final path = trackingPath(widget.tracking).map(_ll).toList();
    _animating = true;
    if (path.length < 2) {
      map.animateCamera(CameraUpdate.newLatLng(path.first));
      return;
    }
    final lats = path.map((p) => p.latitude);
    final lngs = path.map((p) => p.longitude);
    map.animateCamera(CameraUpdate.newLatLngBounds(
      LatLngBounds(
        southwest: LatLng(lats.reduce((a, b) => a < b ? a : b), lngs.reduce((a, b) => a < b ? a : b)),
        northeast: LatLng(lats.reduce((a, b) => a > b ? a : b), lngs.reduce((a, b) => a > b ? a : b)),
      ),
      56,
    ));
  }

  static LatLng _ll(GeoPoint p) => LatLng(p.latitude, p.longitude);

  @override
  Widget build(BuildContext context) {
    final tracking = widget.tracking;
    final location = tracking.location!;
    final courier = LatLng(location.latitude, location.longitude);
    final destination = tracking.destination;
    final path = trackingPath(tracking).map(_ll).toList();

    return GoogleMap(
      initialCameraPosition: CameraPosition(target: courier, zoom: 16),
      onMapCreated: (controller) {
        _map = controller;
        _frame();
      },
      onCameraMoveStarted: () {
        if (!_animating && widget.follow) widget.onUserMoved();
      },
      onCameraIdle: () => _animating = false,
      myLocationButtonEnabled: false,
      mapToolbarEnabled: false,
      zoomControlsEnabled: false,
      markers: {
        Marker(
          markerId: const MarkerId('courier'),
          position: courier,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
          infoWindow: InfoWindow(title: tracking.driver?.name ?? 'Kurir'),
        ),
        if (destination != null)
          Marker(markerId: const MarkerId('destination'), position: _ll(destination)),
      },
      polylines: {
        if (path.length > 1)
          Polyline(
            polylineId: const PolylineId('route'),
            points: path,
            width: 5,
            color: AppColors.primary,
            patterns: tracking.route == null ? [PatternItem.dash(20), PatternItem.gap(12)] : const [],
          ),
      },
      circles: {
        if (location.accuracy != null && location.accuracy! > 20)
          Circle(
            circleId: const CircleId('accuracy'),
            center: courier,
            radius: location.accuracy!,
            strokeWidth: 1,
            strokeColor: AppColors.primary.withValues(alpha: 0.4),
            fillColor: AppColors.primary.withValues(alpha: 0.1),
          ),
      },
    );
  }
}
