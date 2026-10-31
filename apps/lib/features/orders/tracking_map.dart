import 'package:flutter/widgets.dart';

import '../../config/env.dart';
import '../../models/order_tracking.dart';
import 'tracking_map_google.dart';
import 'tracking_map_tiles.dart';

/// The order tracking map: courier, destination and the road (or straight line) between them.
/// MapTiler tiles by default; Google Maps is kept for `MAP_PROVIDER=google` but needs a paid-up key.
///
/// Camera: while [follow] is on it keeps courier and destination in view on every update; a pan or
/// zoom by the buyer calls [onUserMoved]. Bumping [fitRequest] frames both again.
class TrackingMap extends StatelessWidget {
  const TrackingMap({
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
  Widget build(BuildContext context) {
    return Env.useGoogleMaps
        ? GoogleTrackingMap(tracking: tracking, follow: follow, onUserMoved: onUserMoved, fitRequest: fitRequest)
        : TileTrackingMap(tracking: tracking, follow: follow, onUserMoved: onUserMoved, fitRequest: fitRequest);
  }
}

/// Courier first, then the route (or destination); what the camera frames and the line connects.
List<GeoPoint> trackingPath(OrderTracking tracking) {
  final location = tracking.location!;
  return [
    GeoPoint(location.latitude, location.longitude),
    ...?tracking.route?.points,
    if (tracking.route == null && tracking.destination != null) tracking.destination!,
  ];
}
