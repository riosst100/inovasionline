import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../config/env.dart';
import '../../config/theme.dart';
import '../../models/order_tracking.dart';
import 'tracking_map.dart';

/// [TrackingMap] on MapTiler "Streets" tiles (OpenStreetMap data) via flutter_map.
class TileTrackingMap extends StatefulWidget {
  const TileTrackingMap({
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
  State<TileTrackingMap> createState() => _TileTrackingMapState();
}

class _TileTrackingMapState extends State<TileTrackingMap> {
  final _map = MapController();
  bool _ready = false;

  @override
  void didUpdateWidget(TileTrackingMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.fitRequest != oldWidget.fitRequest || widget.follow) _frame();
  }

  @override
  void dispose() {
    _map.dispose();
    super.dispose();
  }

  void _frame() {
    if (!_ready) return;
    final path = trackingPath(widget.tracking).map(_ll).toList();
    if (path.length < 2) {
      _map.move(path.first, _map.camera.zoom);
    } else {
      _map.fitCamera(
        CameraFit.bounds(bounds: LatLngBounds.fromPoints(path), padding: const EdgeInsets.all(56), maxZoom: 17),
      );
    }
  }

  static LatLng _ll(GeoPoint p) => LatLng(p.latitude, p.longitude);

  @override
  Widget build(BuildContext context) {
    final tracking = widget.tracking;
    final location = tracking.location!;
    final courier = LatLng(location.latitude, location.longitude);
    final destination = tracking.destination;
    final path = trackingPath(tracking).map(_ll).toList();
    final key = Env.maptilerKey;

    return FlutterMap(
      mapController: _map,
      options: MapOptions(
        initialCenter: courier,
        initialZoom: 16,
        interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
        onMapReady: () {
          _ready = true;
          _frame();
        },
        onPositionChanged: (_, hasGesture) {
          if (hasGesture && widget.follow) widget.onUserMoved();
        },
      ),
      children: [
        TileLayer(
          urlTemplate: key != null
              ? 'https://api.maptiler.com/maps/streets-v2/256/{z}/{x}/{y}{r}.png?key=$key'
              // Testing only: OpenStreetMap's tile servers forbid app traffic at scale.
              : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          retinaMode: key != null && RetinaMode.isHighDensity(context),
          userAgentPackageName: 'com.inovasionline.app',
          maxZoom: 19,
        ),
        if (location.accuracy != null && location.accuracy! > 20)
          CircleLayer(
            circles: [
              CircleMarker(
                point: courier,
                radius: location.accuracy!,
                useRadiusInMeter: true,
                color: AppColors.primary.withValues(alpha: 0.1),
                borderColor: AppColors.primary.withValues(alpha: 0.4),
                borderStrokeWidth: 1,
              ),
            ],
          ),
        if (path.length > 1)
          PolylineLayer(
            polylines: [
              Polyline(
                points: path,
                strokeWidth: 5,
                color: AppColors.primary,
                // Dashed when it is only a straight line, not the actual road.
                pattern: tracking.route == null
                    ? StrokePattern.dashed(segments: const [12, 8])
                    : const StrokePattern.solid(),
              ),
            ],
          ),
        MarkerLayer(
          markers: [
            if (destination != null)
              Marker(
                point: _ll(destination),
                width: 40,
                height: 40,
                alignment: Alignment.topCenter,
                child: const Icon(Icons.location_on, size: 40, color: Colors.red),
              ),
            Marker(point: courier, width: 40, height: 40, child: const _CourierDot()),
          ],
        ),
        RichAttributionWidget(
          attributions: [
            if (key != null) const TextSourceAttribution('MapTiler'),
            const TextSourceAttribution('OpenStreetMap contributors'),
          ],
        ),
      ],
    );
  }
}

class _CourierDot extends StatelessWidget {
  const _CourierDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.primary,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
      ),
      child: const Icon(Icons.two_wheeler, size: 20, color: Colors.white),
    );
  }
}
