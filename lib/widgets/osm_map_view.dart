// OpenStreetMap-based stand-in for GoogleMap.
//
// Used only by the passenger and driver home screens, because this project
// currently has no active Google Maps / Apple Maps SDK subscription (the
// GoogleMap widget renders as a blank/white screen without billing enabled).
// It reads the exact same google_maps_flutter Marker/Polyline/LatLng data
// MapViewModel already produces for the rest of the app and renders it on
// free OSM tiles instead — no other part of the map/ride pipeline changes.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart' as fm;
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;
import 'package:latlong2/latlong.dart' as ll;

class OsmMapView extends StatefulWidget {
  final fm.MapController mapController;
  final gmaps.LatLng? currentPosition;
  final Set<gmaps.Marker> markers;
  final Set<gmaps.Polyline> polylines;
  final EdgeInsets padding;

  /// Mirrors GoogleMap's onCameraMoveStarted — fired the moment the user
  /// starts dragging/zooming the map (as opposed to a programmatic move).
  final VoidCallback? onUserGestureStart;

  const OsmMapView({
    super.key,
    required this.mapController,
    required this.currentPosition,
    required this.markers,
    required this.polylines,
    this.padding = EdgeInsets.zero,
    this.onUserGestureStart,
  });

  @override
  State<OsmMapView> createState() => _OsmMapViewState();
}

class _OsmMapViewState extends State<OsmMapView> {
  static final _fallbackCenter = ll.LatLng(33.7490, -84.3880); // Atlanta

  bool _didInitialCenter = false;

  ll.LatLng _toLl(gmaps.LatLng p) => ll.LatLng(p.latitude, p.longitude);

  @override
  Widget build(BuildContext context) {
    final center =
        widget.currentPosition != null ? _toLl(widget.currentPosition!) : _fallbackCenter;

    // GoogleMap only reads initialCameraPosition once; replicate that here
    // by centering the very first time a real device position is known,
    // then leaving the camera alone (manual pan/zoom + recenter FAB take
    // over from there, same as before).
    if (!_didInitialCenter && widget.currentPosition != null) {
      _didInitialCenter = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        try {
          // GoogleMap's `padding` doesn't shrink the map widget — the map
          // still renders edge-to-edge, but it insets which part of that
          // canvas counts as the "visible" area for framing purposes, so
          // the tracked position isn't centered underneath the header/
          // bottom sheet overlaid on top of the map. Replicate that by
          // nudging the actual map center so `center` renders at the
          // midpoint of the unobscured region instead of the widget's
          // literal center.
          final verticalBias = (widget.padding.top - widget.padding.bottom) / 2;
          final centerPoint = widget.mapController.latLngToScreenPoint(center);
          if (verticalBias != 0 && centerPoint != null) {
            final shifted = widget.mapController.pointToLatLng(
              fm.CustomPoint(centerPoint.x, centerPoint.y - verticalBias),
            );
            if (shifted != null) {
              widget.mapController.move(shifted, 15.0);
              return;
            }
          }
          widget.mapController.move(center, 15.0);
        } catch (_) {
          // Controller not attached yet on the very first frame — ignore.
        }
      });
    }

    return fm.FlutterMap(
      mapController: widget.mapController,
      options: fm.MapOptions(
        center: center,
        zoom: 15.0,
        interactiveFlags: fm.InteractiveFlag.all & ~fm.InteractiveFlag.rotate,
        onPositionChanged: (position, hasGesture) {
          if (hasGesture) widget.onUserGestureStart?.call();
        },
      ),
      children: [
        fm.TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.leisureryde.leisureryde',
          maxNativeZoom: 19,
        ),
        fm.PolylineLayer(
          polylines: widget.polylines
              .map((p) => fm.Polyline(
                    points: p.points.map(_toLl).toList(),
                    color: p.color,
                    strokeWidth: p.width.toDouble(),
                  ))
              .toList(),
        ),
        fm.MarkerLayer(
          markers: [
            if (widget.currentPosition != null) _buildMeDot(center),
            ...widget.markers.map(_buildMarker),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(right: 4, bottom: 2),
          child: Align(
            alignment: Alignment.bottomRight,
            child: fm.RichAttributionWidget(
              alignment: fm.AttributionAlignment.bottomRight,
              popupInitialDisplayDuration: const Duration(seconds: 3),
              attributions: [
                fm.TextSourceAttribution(
                  'OpenStreetMap contributors',
                  onTap: () {},
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  fm.Marker _buildMeDot(ll.LatLng point) {
    return fm.Marker(
      point: point,
      width: 20,
      height: 20,
      builder: (_) => Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.blue,
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 4)],
        ),
      ),
    );
  }

  /// Google's BitmapDescriptor hue can't be read back out of a Marker at
  /// render time, so color/icon are inferred from the same markerId/title
  /// conventions MapViewModel and DriverHomeViewModel already use.
  fm.Marker _buildMarker(gmaps.Marker m) {
    final id = m.markerId.value;
    final title = m.infoWindow.title ?? '';

    IconData icon = Icons.location_on;
    Color color = Colors.red;
    double size = 34;
    var anchor = fm.AnchorPos.align(fm.AnchorAlign.bottom);

    if (id == 'driver' || title == 'Your Driver') {
      icon = Icons.directions_car;
      color = const Color(0xFF1565C0);
      size = 30;
      anchor = fm.AnchorPos.align(fm.AnchorAlign.center);
    } else if (title == 'Pickup') {
      icon = Icons.trip_origin;
      color = Colors.green;
    } else if (title.startsWith('Stop')) {
      icon = Icons.tour;
      color = Colors.orange;
    } else if (title == 'Destination') {
      icon = Icons.location_on;
      color = Colors.red;
    }

    return fm.Marker(
      point: _toLl(m.position),
      width: 42,
      height: 42,
      anchorPos: anchor,
      builder: (_) => Transform.rotate(
        angle: m.rotation * (math.pi / 180),
        child: Icon(
          icon,
          color: color,
          size: size,
          shadows: const [Shadow(color: Colors.black45, blurRadius: 3)],
        ),
      ),
    );
  }
}
