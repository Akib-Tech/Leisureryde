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
    List<LatLng> waypoints = const [],
  }) async {
    // Build waypoints parameter
    String waypointsParam = '';
    if (waypoints.isNotEmpty) {
      final waypointStrings = waypoints
          .map((wp) => '${wp.latitude},${wp.longitude}')
          .join('|');
      waypointsParam = '&waypoints=$waypointStrings';
    }

    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/directions/json?'
          'origin=${origin.latitude},${origin.longitude}'
          '&destination=${destination.latitude},${destination.longitude}'
          '$waypointsParam'
          '&units=imperial'
          '&key=$_apiKey',
    );

    debugPrint("DirectionsService: Requesting directions from API: $url");

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        final status = data['status'];
        switch (status) {
          case 'OK':
            final route = data['routes'][0];
            final legs = route['legs'] as List<dynamic>? ?? [];

            if (legs.isEmpty) return null;

            // Decode polyline
            final polylinePoints = PolylinePoints();
            final polylineResult = polylinePoints.decodePolyline(
              route['overview_polyline']['points'],
            );

            final polylineCoordinates = polylineResult
                .map((point) => LatLng(point.latitude, point.longitude))
                .toList();

            // Aggregate data
            int totalDistanceMeters = 0;
            int totalDurationSeconds = 0;
            final allSteps = <RouteStep>[];
            final waypointAddresses = <String>[];

            String startAddress = '';
            String endAddress = '';

            for (int i = 0; i < legs.length; i++) {
              final leg = legs[i] as Map<String, dynamic>;

              if (i == 0) {
                startAddress = leg['start_address'] ?? '';
              }
              if (i == legs.length - 1) {
                endAddress = leg['end_address'] ?? '';
              } else {
                // Intermediate legs' end_address = waypoint address
                final wpAddress = leg['end_address'] as String? ?? '';
                if (wpAddress.isNotEmpty) {
                  waypointAddresses.add(wpAddress);
                }
              }

              totalDistanceMeters += (leg['distance']?['value'] as int?) ?? 0;
              totalDurationSeconds += (leg['duration']?['value'] as int?) ?? 0;

              // Steps
              final rawSteps = leg['steps'] as List<dynamic>? ?? [];
              final legSteps = rawSteps.map<RouteStep>((s) {
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

              allSteps.addAll(legSteps);
            }

            final eta = totalDurationSeconds > 0
                ? DateTime.now().add(Duration(seconds: totalDurationSeconds))
                : null;

            return DirectionsResult(
              polylinePoints: polylineCoordinates,
              distance: _formatDistance(totalDistanceMeters),
              distanceValue: totalDistanceMeters,
              duration: _formatDuration(totalDurationSeconds),
              durationValue: totalDurationSeconds,
              startAddress: startAddress,
              endAddress: endAddress,
              eta: eta,
              startLocation: origin,
              endLocation: destination,
              steps: allSteps,
              waypointAddresses: waypointAddresses,  
              waypointsLocation: waypoints, // ← New field
            );

          // ... your other status cases remain unchanged
          default:
            debugPrint("DirectionsService: API status: $status");
            break;
        }
      }
    } catch (e) {
      debugPrint("DirectionsService: Exception: $e");
    }

    return null;
  }




    String _formatDistance(int meters) {
    if (meters < 1000) {
      final feet = (meters * 3.28084).round();
      return '$feet ft';
    } else {
      final miles = meters / 1609.34;
      if (miles < 10) {
        return '${miles.toStringAsFixed(1)} mi';   // e.g. "1.2 mi"
      } else {
        return '${miles.round()} mi';             // e.g. "245 mi"
      }
    }
  }

  String _formatDuration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;

    if (hours > 0) {
      if (minutes > 0) {
        return '$hours hr $minutes mins';
      } else {
        return '$hours hr';
      }
    } else if (minutes > 0) {
      return '$minutes mins';   // Google usually uses "mins"
    } else {
      return '1 min';
    }
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
  final List<LatLng> waypointsLocation;
  final List<String> waypointAddresses;
  DirectionsResult({
    required this.polylinePoints,
    this.distance,
    this.distanceValue,
    this.duration,
    this.durationValue,
    required this.startAddress,
    required this.endAddress,
    this.eta,
    required this.waypointsLocation,
    required this.startLocation,
    required this.endLocation,
    this.steps = const [],
    this.waypointAddresses = const [],
  });
}

