import 'dart:convert';
import 'package:flutter/foundation.dart'; // For debugPrint
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_polyline_points/flutter_polyline_points.dart';

class DirectionsService {
  // CRITICAL: Ensure this API key is valid and has Directions API enabled.
  // DO NOT hardcode API keys in production apps. Use environment variables.
  static const String _apiKey = "AIzaSyBJIRixyDjY3bFicM3oG36yW0Vaj43FZWs"; // Placeholder, replace with your actual key

  Future<DirectionsResult?> getDirections({
    required LatLng origin,
    required LatLng destination,
  }) async {
    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/directions/json?'
          'origin=${origin.latitude},${origin.longitude}'
          '&destination=${destination.latitude},${destination.longitude}'
          '&key=$_apiKey',
    );

    debugPrint("DirectionsService: Requesting directions from API: $url");

    try {
      final response = await http.get(url);
      debugPrint("DirectionsService: API Response Status Code: ${response.statusCode}");
      debugPrint("DirectionsService: API Response Body: ${response.body}"); // Log full response for debugging

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        final status = data['status'];
        switch (status) {
          case 'OK':
            debugPrint("DirectionsService: API Status OK. Parsing route...");
            if (data['routes'] == null || data['routes'].isEmpty) {
              debugPrint("DirectionsService: CRITICAL - Status was OK but no routes were provided.");
              return null;
            }
          final route = data['routes'][0];
          final leg = route['legs'][0];

          // Decode polyline
          final polylinePoints = PolylinePoints();
          final polylineResult = polylinePoints.decodePolyline(
            route['overview_polyline']['points'],
          );

          final polylineCoordinates = polylineResult
              .map((point) => LatLng(point.latitude, point.longitude))
              .toList();
          debugPrint("DirectionsService: Polyline decoded successfully with ${polylineCoordinates.length} points.");

          // Extract ETA (Estimated Time of Arrival)
          final durationValue = leg['duration']['value'] as int?; // in seconds
          final eta = durationValue != null ? DateTime.now().add(Duration(seconds: durationValue)) : null;

          return DirectionsResult(
            polylinePoints: polylineCoordinates,
            distance: leg['distance']['text'],
            distanceValue: leg['distance']['value'], // in meters
            duration: leg['duration']['text'],
            durationValue: durationValue,
            startAddress: leg['start_address'],
            endAddress: leg['end_address'],
            eta: eta, // Pass the calculated ETA
            startLocation: origin, // Pass original LatLng as startLocation
            endLocation: destination, // Pass original LatLng as endLocation
          );

          case 'ZERO_RESULTS':
            debugPrint("DirectionsService: API returned ZERO_RESULTS. This means no route could be found between the origin and destination. This is common for long-distance travel over oceans.");
            break; // Fall through to return null

          case 'NOT_FOUND':
            debugPrint("DirectionsService: API returned NOT_FOUND. One of the locations (origin, destination, or waypoint) could not be geocoded.");
            break;

          case 'MAX_WAYPOINTS_EXCEEDED':
            debugPrint("DirectionsService: API returned MAX_WAYPOINTS_EXCEEDED. Too many waypoints were provided in the request.");
            break;

          case 'INVALID_REQUEST':
            debugPrint("DirectionsService: API returned INVALID_REQUEST. The request was missing a required parameter (e.g., origin or destination).");
            break;

          case 'OVER_QUERY_LIMIT':
            debugPrint("DirectionsService: API returned OVER_QUERY_LIMIT. You have exceeded your API usage quota. Check your Google Cloud console.");
            break;

          case 'REQUEST_DENIED':
            debugPrint("DirectionsService: API returned REQUEST_DENIED. The API rejected the request, likely due to an invalid or missing API key.");
            break;

          default: // Includes 'UNKNOWN_ERROR'
            debugPrint("DirectionsService: API returned an unhandled status: $status. Error: ${data['error_message'] ?? 'An unknown server error occurred.'}");
            break;
        }
      }
    } catch (e) {
      debugPrint("DirectionsService: Exception caught while getting directions: $e");
    }

    return null; // Return null if any error or unsuccessful status
  }
}

class DirectionsResult {
  final List<LatLng> polylinePoints;
  final String? distance; // Made nullable
  final int? distanceValue; // Made nullable
  final String? duration; // Made nullable
  final int? durationValue; // Made nullable
  final String startAddress;
  final String endAddress;
  final DateTime? eta; // Make nullable
  final LatLng startLocation; // Added
  final LatLng endLocation; // Added

  DirectionsResult({
    required this.polylinePoints,
    this.distance, // No longer required
    this.distanceValue, // No longer required
    this.duration, // No longer required
    this.durationValue, // No longer required
    required this.startAddress,
    required this.endAddress,
    this.eta, // No longer required
    required this.startLocation, // Added
    required this.endLocation, // Added
  });

// Getter for eta as previously discussed, but now based on nullable durationValue
// Removed this getter to use the `eta` field directly, as it's cleaner to calculate once.
// If `eta` in constructor is null, this will return null.
}