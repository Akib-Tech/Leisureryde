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
          '&units=imperial'
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

          // Parse turn-by-turn steps for voice navigation.
          final rawSteps = leg['steps'] as List<dynamic>? ?? [];
          final steps = rawSteps.map<RouteStep>((s) {
            final html = (s['html_instructions'] as String?) ?? '';
            final maneuver = s['maneuver'] as String?;
            final endLoc = s['end_location'] as Map<String, dynamic>?;
            return RouteStep(
              instruction: _buildInstruction(html, maneuver),
              maneuver: maneuver,
              distanceMeters: (s['distance']?['value'] as int?) ?? 0,
              endLocation: LatLng(
                (endLoc?['lat'] as num?)?.toDouble() ?? 0.0,
                (endLoc?['lng'] as num?)?.toDouble() ?? 0.0,
              ),
            );
          }).toList();

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
            steps: steps,
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

  // Builds a spoken instruction using the machine-readable maneuver code and
  // the road name extracted from Google's bold-tagged HTML. This avoids
  // cardinal directions ("Head north") in favour of left/right language.
  static String _buildInstruction(String html, String? maneuver) {
    // Google always bolds the road/destination name — extract all such parts.
    final boldParts = RegExp(r'<b>(.*?)<\/b>')
        .allMatches(html)
        .map((m) => m.group(1) ?? '')
        .where((s) => s.isNotEmpty)
        .toList();

    const maneuverPhrases = <String, String>{
      'turn-left': 'Turn left',
      'turn-sharp-left': 'Turn sharp left',
      'turn-slight-left': 'Bear left',
      'turn-right': 'Turn right',
      'turn-sharp-right': 'Turn sharp right',
      'turn-slight-right': 'Bear right',
      'straight': 'Continue straight',
      'uturn-left': 'Make a U-turn',
      'uturn-right': 'Make a U-turn',
      'fork-left': 'Keep left',
      'fork-right': 'Keep right',
      'keep-left': 'Keep left',
      'keep-right': 'Keep right',
      'ramp-left': 'Take the left ramp',
      'ramp-right': 'Take the right ramp',
      'merge': 'Merge',
      'roundabout-left': 'At the roundabout, turn left',
      'roundabout-right': 'At the roundabout, turn right',
      'ferry': 'Take the ferry',
      'ferry-train': 'Take the train ferry',
    };

    // Null maneuver = first "Head <cardinal>" step. Use "Continue" instead of
    // cardinal directions so any driver can follow without map knowledge.
    final action = maneuver != null
        ? (maneuverPhrases[maneuver] ?? _cleanHtml(html))
        : 'Continue';

    if (boldParts.isEmpty) return action;

    // Roundabout steps bold both the exit number and the road; the last bold
    // segment is always the destination road name.
    final road = boldParts.last;

    // Turns and merges transition onto a new road; all others continue on one.
    const ontoManeuvers = {
      'turn-left', 'turn-sharp-left', 'turn-slight-left',
      'turn-right', 'turn-sharp-right', 'turn-slight-right',
      'merge', 'ramp-left', 'ramp-right',
      'ferry', 'ferry-train', 'roundabout-left', 'roundabout-right',
    };
    final connector =
        (maneuver != null && ontoManeuvers.contains(maneuver)) ? ' onto ' : ' on ';

    return '$action$connector$road';
  }

  static String _cleanHtml(String html) =>
      html.replaceAll(RegExp(r'<[^>]*>'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
}

/// A single maneuver step returned by the Directions API.
class RouteStep {
  final String instruction;   // HTML-stripped, speech-ready
  final String? maneuver;     // e.g. "turn-left", "turn-right"
  final int distanceMeters;
  final LatLng endLocation;

  const RouteStep({
    required this.instruction,
    this.maneuver,
    required this.distanceMeters,
    required this.endLocation,
  });
}

class DirectionsResult {
  final List<LatLng> polylinePoints;
  final String? distance;
  final int? distanceValue;
  final String? duration;
  final int? durationValue;
  final String startAddress;
  final String endAddress;
  final DateTime? eta;
  final LatLng startLocation;
  final LatLng endLocation;
  final List<RouteStep> steps;

  DirectionsResult({
    required this.polylinePoints,
    this.distance,
    this.distanceValue,
    this.duration,
    this.durationValue,
    required this.startAddress,
    required this.endAddress,
    this.eta,
    required this.startLocation,
    required this.endLocation,
    this.steps = const [],
  });
}

