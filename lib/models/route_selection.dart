// lib/models/route_selection.dart
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../services/place_service.dart'; // Ensure PlaceDetails is correctly imported

class RouteSelectionResult {
  final PlaceDetails origin;
  final PlaceDetails destination;
  final String? duration;        // e.g., "15 min"
  final String? distance;        // e.g., "5 km"
  final int? durationValue;     // e.g., 900 seconds
  final int? distanceValue;     // e.g., 5000 meters
  final DateTime? eta;          // Estimated Time of Arrival
  final List<LatLng>? polylinePoints; // Points to draw the route

  RouteSelectionResult({
    required this.origin,
    required this.destination,
    this.duration,
    this.distance,
    this.durationValue,
    this.distanceValue,
    this.eta,
    this.polylinePoints,
  });
}