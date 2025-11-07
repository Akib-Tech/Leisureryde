import 'dart:convert';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_polyline_points/flutter_polyline_points.dart';

class DirectionsService {
  static const String _apiKey = "AIzaSyBJIRixyDjY3bFicM3oG36yW0Vaj43FZWs";

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

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'OK') {
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

          return DirectionsResult(
            polylinePoints: polylineCoordinates,
            distance: leg['distance']['text'],
            distanceValue: leg['distance']['value'], // in meters
            duration: leg['duration']['text'],
            durationValue: leg['duration']['value'], // in seconds
            startAddress: leg['start_address'],
            endAddress: leg['end_address'],
          );
        }
      }
    } catch (e) {
      print("Error getting directions: $e");
    }

    return null;
  }
}

class DirectionsResult {
  final List<LatLng> polylinePoints;
  final String distance;
  final int distanceValue;
  final String duration;
  final int durationValue;
  final String startAddress;
  final String endAddress;

  DirectionsResult({
    required this.polylinePoints,
    required this.distance,
    required this.distanceValue,
    required this.duration,
    required this.durationValue,
    required this.startAddress,
    required this.endAddress,
  });

  DateTime get eta => DateTime.now().add(Duration(seconds: durationValue));
}